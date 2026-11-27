extends RefCounted
## Persistent, scene-independent contract ledger. Coordinates are derived by the world controller.

const KINDS := ["mining", "survey", "bounty", "freight"]
const TYPES := {"mining": "Mining", "survey": "Exploration", "bounty": "Pirate bounty", "freight": "Trade / transport"}
const TITLES := {
	"mining": ["Iron for the foundries", "Veins of the frontier", "Prospector's quota"],
	"survey": ["Uncharted signals", "Frontier survey", "Chart the quiet lanes"],
	"bounty": ["Clear the raider lane", "Wanted: local raiders", "Break the blockade"],
	"freight": ["Medical supplies", "Machine parts", "Food for the frontier"],
}
const TIERS := ["Routine", "Challenging", "Dangerous"]
const ACTIVE_LIMIT := 6
const HISTORY_LIMIT := 16
const ROUND_SIZE := 12
const MAX_ROUND := 1000000000

var round_number := 0
var credits := 0
var offers: Array[Dictionary] = []
var active: Array[Dictionary] = []
var history: Array[Dictionary] = []
var ambient_defeated := {} # One independent raider per system, permanently cleared.

func refresh(seed_value: int, systems: Array[Dictionary], source: int, ore_available: Callable) -> void:
	if round_number >= MAX_ROUND:
		return
	round_number += 1
	offers.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("job-board/%d/%d/%d" % [seed_value, round_number, source])
	var nearby: Array[int] = []
	for index in systems.size():
		nearby.append(index)
	var center: Vector2 = systems[source].center
	nearby.sort_custom(func(a: int, b: int) -> bool:
		var da := center.distance_squared_to(systems[a].center)
		var db := center.distance_squared_to(systems[b].center)
		return a < b if da == db else da < db)
	var reserves := {}
	for tier in TIERS.size():
		for kind_index in KINDS.size():
			var kind: String = KINDS[kind_index]
			var low := mini(nearby.size() - 1, [0, 1, 3][tier])
			var high := mini(nearby.size() - 1, [2, 5, 9][tier])
			var target := nearby[rng.randi_range(low, high)]
			var amount := tier + 1
			if kind == "freight":
				if nearby.size() > 1 and target == source:
					target = nearby[rng.randi_range(1, maxi(1, high))]
				amount = [8, 24, 48][tier] + rng.randi_range(0, 4)
			elif kind == "mining":
				amount = [6, 16, 32][tier] + rng.randi_range(0, 4)
				# Prefer the rolled distance band; fall back to other nearby deposits.
				var candidates := nearby.slice(low, high + 1)
				candidates.append_array(nearby.slice(0, mini(12, nearby.size())))
				candidates.push_front(target)
				target = -1
				for candidate in candidates:
					if not reserves.has(candidate):
						reserves[candidate] = ore_available.call(candidate)
					if reserves[candidate] >= amount:
						target = candidate
						break
				if target < 0:
					continue
			var base: int = [80, 95, 120, 105][kind_index]
			offers.append({"id": (round_number - 1) * ROUND_SIZE + tier * KINDS.size() + kind_index + 1,
				"kind": kind, "tier": tier, "variant": rng.randi_range(0, 2), "source": source, "target": target,
				"amount": amount, "reward": base * (tier + 1) + amount * 2 + rng.randi_range(0, 20),
				"progress": 0, "carrier": "", "defeated": 0})

static func title(job: Dictionary) -> String:
	return TITLES[job.kind][job.variant]

static func find(jobs: Array[Dictionary], id: int) -> Dictionary:
	for job in jobs:
		if job.id == id:
			return job
	return {}

func accept(id: int) -> String:
	var job := find(offers, id)
	if job.is_empty():
		return "That offer is no longer available."
	if active.size() >= ACTIVE_LIMIT:
		return "Finish or abandon a contract first (maximum %d active)." % ACTIVE_LIMIT
	for existing in active:
		if job.kind == "bounty" and existing.kind == "bounty" and existing.target == job.target:
			return "Finish the active bounty in this system first."
	offers.erase(job)
	active.append(job)
	return ""

func abandon(id: int) -> Dictionary:
	var job := find(active, id)
	if not job.is_empty():
		active.erase(job)
	return job

func _advance(job: Dictionary, units: int) -> bool:
	job.progress += units
	if job.progress < job.amount:
		return false
	active.erase(job)
	credits += job.reward
	history.push_front(job)
	if history.size() > HISTORY_LIMIT:
		history.pop_back()
	return true

func record_mining(system: int, amount: int) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	# Each unit can count toward only one contract, oldest accepted first.
	for job: Dictionary in active.duplicate():
		if amount <= 0:
			break
		if job.kind != "mining" or job.target != system:
			continue
		var allocated := mini(amount, int(job.amount) - int(job.progress))
		amount -= allocated
		if _advance(job, allocated):
			completed.append(job)
	return completed

func record_scan(id: int, waypoint: int) -> Dictionary:
	var job := find(active, id)
	return job if not job.is_empty() and job.kind == "survey" and job.progress == waypoint and _advance(job, 1) else {}

func record_kill(id: int, pirate: int) -> Dictionary:
	var job := find(active, id)
	if job.is_empty() or job.kind != "bounty" or pirate < 0 or pirate >= job.amount or (job.defeated & (1 << pirate)) != 0:
		return {}
	job.defeated |= 1 << pirate
	return job if _advance(job, 1) else {}

func load_freight(id: int, ship_id: String, free_space: int) -> bool:
	var job := find(active, id)
	if job.is_empty() or job.kind != "freight" or job.carrier != "" or free_space < job.amount or ship_id.is_empty():
		return false
	job.carrier = ship_id
	return true

func deliver_freight(id: int, ship_id: String) -> Dictionary:
	var job := find(active, id)
	return job if not job.is_empty() and job.kind == "freight" and not ship_id.is_empty() and job.carrier == ship_id and _advance(job, job.amount) else {}

func freight_units(ship_id: String) -> int:
	var units := 0
	for job in active:
		if job.kind == "freight" and job.carrier == ship_id:
			units += int(job.amount)
	return units

func snapshot() -> Dictionary:
	return {"round": round_number, "credits": credits, "offers": offers, "active": active,
		"history": history, "ambient_defeated": ambient_defeated}.duplicate(true)

func restore(data: Dictionary) -> void:
	round_number = data.round
	credits = data.credits
	offers.assign(data.offers.duplicate(true))
	active.assign(data.active.duplicate(true))
	history.assign(data.history.duplicate(true))
	ambient_defeated = data.ambient_defeated.duplicate()

static func valid(data: Variant, systems: int, ships: Dictionary) -> bool:
	if not data is Dictionary or not _within(data.get("round"), 0, MAX_ROUND) or not _within(data.get("credits"), 0, 9000000000000000):
		return false
	var ids := {}
	var bounties := {}
	var limits := {"offers": ROUND_SIZE, "active": ACTIVE_LIMIT, "history": HISTORY_LIMIT}
	for key: String in limits:
		if not data.get(key) is Array or data[key].size() > limits[key]:
			return false
		for job in data[key]:
			if not _valid_job(job, systems, data.round) or ids.has(job.id):
				return false
			ids[job.id] = true
			if key == "history":
				if job.progress != job.amount:
					return false
			elif key == "offers":
				if job.progress != 0 or job.carrier != "" or (job.id - 1) / ROUND_SIZE + 1 != data.round:
					return false
			else:
				if job.progress >= job.amount or (job.carrier != "" and not ships.has(job.carrier)):
					return false
				if job.kind == "bounty":
					if bounties.has(job.target):
						return false
					bounties[job.target] = true
	if not data.get("ambient_defeated") is Dictionary or data.ambient_defeated.size() > systems:
		return false
	for index in data.ambient_defeated:
		if not _within(index, 0, systems - 1) or data.ambient_defeated[index] != true:
			return false
	return true

static func _valid_job(job: Variant, systems: int, round_id: int) -> bool:
	if not job is Dictionary or not _within(job.get("id"), 1, round_id * ROUND_SIZE) or job.get("kind") not in KINDS \
		or not _within(job.get("tier"), 0, 2) or not _within(job.get("variant"), 0, 2) or not _within(job.get("source"), 0, systems - 1) \
		or not _within(job.get("target"), 0, systems - 1) or not _within(job.get("amount"), 1, 64) \
		or not _within(job.get("reward"), 1, 1000) or not _within(job.get("progress"), 0, job.amount) \
		or not job.get("carrier") is String or not _within(job.get("defeated"), 0, 7):
		return false
	if job.kind != "freight" and job.carrier != "":
		return false
	if job.kind == "freight" and job.progress not in [0, job.amount]:
		return false
	if job.kind in ["bounty", "survey"] and job.amount != job.tier + 1:
		return false
	if job.kind == "bounty":
		return job.defeated < (1 << job.amount) and job.progress == ((job.defeated & 1) + ((job.defeated >> 1) & 1) + ((job.defeated >> 2) & 1))
	return job.defeated == 0

static func _within(value: Variant, low: int, high: int) -> bool:
	return value is int and value >= low and value <= high
