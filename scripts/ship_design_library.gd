extends RefCounted

const MODULES := preload("res://scripts/ship_modules.gd")
const PATH := "user://ship_designs.json"

static func read() -> Variant:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return null
	var contents: Variant = JSON.parse_string(file.get_as_text())
	return contents if contents is Dictionary else null

static func write(entries: Dictionary) -> bool:
	var temporary := PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(entries))
	file.flush()
	var saved := file.get_error() == OK
	file.close()
	if saved:
		saved = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(PATH)) == OK
	if not saved:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return saved

static func restore_design(data: Variant) -> Array:
	if not data is Array:
		return []
	var parts := MODULES.migrate_legacy(data)
	if MODULES.validate(parts, false, false) != "":
		return []
	MODULES.add_legacy_command_deck(parts)
	return parts
