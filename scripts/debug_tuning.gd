extends RefCounted
## Transient tuning for a throwaway flight. Never written to campaign saves.

const FLIGHT := [
	["speed", "Normal speed limit", 0.05, 20.0],
	["acceleration", "Thrust / travel acceleration", 0.05, 20.0],
	["turn", "Maximum turn rate", 0.05, 10.0],
	["drag", "Drift drag", 0.0, 10.0],
	["boost", "Boost speed", 0.05, 20.0],
	["hyperdrive", "Hyperjump speed", 0.05, 20.0],
]
const WORLD := [
	["planet", "Planet orbit speed", 0.0, 100.0],
	["moon", "Moon orbit speed", 0.0, 100.0],
]
const BLOCK_STATS := ["mass", "health", "power", "thrust", "turn", "cargo", "shield", "mining", "weapon"]
const MIN_SPACING := 0.25
const MAX_SPACING := 5.0
const SAMPLE_TICKS := 300 # 5 simulation seconds at 60 Hz.

var factors := {}
var blocks := {}
var invulnerable := false
var waves := false
var speeds := PackedFloat64Array()
var sample_cursor := 0
var speed_total := 0.0
var peak_speed := 0.0

func factor(key: String) -> float:
	return float(factors.get(key, 1.0))

func sample(speed: float) -> void:
	if speeds.size() == SAMPLE_TICKS:
		speed_total -= speeds[sample_cursor]
		speeds[sample_cursor] = speed
		sample_cursor = (sample_cursor + 1) % SAMPLE_TICKS
	else:
		speeds.append(speed)
	speed_total += speed
	peak_speed = maxf(peak_speed, speed)

func average_speed() -> float:
	return speed_total / maxi(1, speeds.size())

func reset_samples() -> void:
	speeds.clear()
	sample_cursor = 0
	speed_total = 0.0
	peak_speed = 0.0

static func scaled_map(original: Dictionary, spacing: float) -> Dictionary:
	var map := original.duplicate(true)
	if not is_equal_approx(spacing, 1.0):
		# Scale star-to-star distances (and the chart), not the systems' local geometry.
		for star: Dictionary in map.systems:
			star.center *= spacing
		map.world_size *= spacing
		if map.has("spiral"):
			map.spiral.scale *= spacing
	return map
