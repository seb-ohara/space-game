extends RefCounted

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const SAVE_DIR := "user://galaxies"
const EXTENSION := ".save"
const FORMAT_VERSION := 3
const CLOCK := preload("res://scripts/simulation/simulation_clock.gd")
const RECENT_PATH := "user://recent_galaxy.cfg"

static func new_id() -> String:
	return "%d-%08x" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]

static func write(slot_id: String, state: Dictionary) -> bool:
	if not _valid_id(slot_id) or not CLOCK.valid_snapshot(state.get("clock")) or DirAccess.make_dir_recursive_absolute(SAVE_DIR) != OK:
		return false
	var path := SAVE_DIR.path_join(slot_id + EXTENSION)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	state.format_version = FORMAT_VERSION
	state.saved_at = int(Time.get_unix_time_from_system())
	file.store_var(state)
	file.flush()
	var saved := file.get_error() == OK
	file.close()
	if saved:
		saved = DirAccess.rename_absolute(temporary, path) == OK
	if not saved:
		DirAccess.remove_absolute(temporary)
	return saved

static func read(slot_id: String) -> Dictionary:
	if not _valid_id(slot_id):
		return {}
	var file := FileAccess.open(SAVE_DIR.path_join(slot_id + EXTENSION), FileAccess.READ)
	if file == null or file.get_length() < 4 or file.get_length() > 16000000:
		return {}
	var data: Variant = file.get_var(false)
	if file.get_error() != OK or not data is Dictionary:
		return {}
	var format: Variant = data.get("format_version")
	if format == 1:
		var legacy_time: Variant = data.get("elapsed", 0.0)
		data.clock = {"seconds": _nonnegative_seconds(legacy_time), "rate": 1, "paused": false}
		if not CLOCK.valid_snapshot(data.clock):
			data.clock.seconds = 0.0
	elif format not in [2, FORMAT_VERSION] or not CLOCK.valid_snapshot(data.get("clock")):
		return {}
	data.play_time = play_seconds(data)
	if not data.get("name") is String or not data.get("seed") is int or not data.get("count") is int:
		return {}
	var version: Variant = data.get("generator_version")
	if version not in [GALAXY.GRID_VERSION, GALAXY.SPIRAL_VERSION, GALAXY.CLOUD_VERSION, GALAXY.WIDE_VERSION, GALAXY.VERSION]:
		return {}
	var maximum := GALAXY.GRID_MAX_SYSTEMS if version == GALAXY.GRID_VERSION else GALAXY.MAX_SYSTEMS
	if data.count < GALAXY.MIN_SYSTEMS or data.count > maximum:
		return {}
	if GALAXY.is_wide_version(version):
		var arms: Variant = data.get("arms", GALAXY.DEFAULT_ARMS)
		if not arms is int or arms < GALAXY.MIN_ARMS or arms > GALAXY.MAX_ARMS:
			return {}
		data.arms = arms
	return data

static func slots() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return results
	for filename in DirAccess.get_files_at(SAVE_DIR):
		if not filename.ends_with(EXTENSION):
			continue
		var slot_id := filename.trim_suffix(EXTENSION)
		var saved := read(slot_id)
		var path := SAVE_DIR.path_join(filename)
		results.append({"id": slot_id, "name": saved.get("name", "Unreadable save"), "count": saved.get("count", 0),
			"seed": saved.get("seed"), "saved_at": FileAccess.get_modified_time(path), "readable": not saved.is_empty(),
			"play_time": play_seconds(saved)})
	results.sort_custom(func(a: Dictionary, b: Dictionary): return a.saved_at > b.saved_at)
	return results

static func mark_recent(slot_id: String) -> void:
	if not _valid_id(slot_id):
		return
	var config := ConfigFile.new()
	config.set_value("recent", "slot_id", slot_id)
	if config.save(RECENT_PATH) != OK:
		push_warning("Could not remember the last played galaxy.")

static func recent_slot() -> String:
	var config := ConfigFile.new()
	var slot_id := ""
	if config.load(RECENT_PATH) == OK:
		slot_id = str(config.get_value("recent", "slot_id", ""))
	if not read(slot_id).is_empty():
		return slot_id
	for slot in slots():
		if slot.readable:
			return slot.id
	return ""

static func delete(slot_id: String) -> bool:
	if not _valid_id(slot_id):
		return false
	var path := SAVE_DIR.path_join(slot_id + EXTENSION)
	return FileAccess.file_exists(path) and DirAccess.remove_absolute(path) == OK

static func play_seconds(state: Dictionary) -> float:
	return _nonnegative_seconds(state.get("play_time", state.get("clock", {}).get("seconds", 0.0)))

static func _nonnegative_seconds(value: Variant) -> float:
	return maxf(0.0, float(value)) if (value is int or value is float) and is_finite(value) else 0.0

static func _valid_id(slot_id: String) -> bool:
	return not slot_id.is_empty() and slot_id.is_valid_filename() and not slot_id.begins_with(".")
