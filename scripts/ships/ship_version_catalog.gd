extends RefCounted
## Galaxy-wide version library keyed by hull design ID, never by ship instance.

static func valid(catalog: Variant) -> bool:
	if not catalog is Dictionary:
		return false
	for design_id in catalog:
		var entry: Variant = catalog[design_id]
		if not design_id is String or not entry is Dictionary or not entry.get("versions") is Dictionary:
			return false
		var default_name: Variant = entry.get("default", "")
		if not default_name is String or (not default_name.is_empty() and not entry.versions.has(default_name)):
			return false
		if not valid_versions(entry.versions):
			return false
	return true

static func valid_versions(versions: Variant) -> bool:
	if not versions is Dictionary:
		return false
	for version_name in versions:
		if not version_name is String or version_name.is_empty() or not versions[version_name] is Dictionary:
			return false
	return true

static func matching_name(versions: Dictionary, version_name: String) -> String:
	for existing_name: String in versions:
		if existing_name.nocasecmp_to(version_name) == 0:
			return existing_name
	return ""

static func restore(state: Dictionary) -> Dictionary:
	var catalog: Dictionary = state.get("ship_versions", {}).duplicate(true)
	for ship: Dictionary in state.fleet:
		var legacy: Dictionary = ship.get("admin_versions", {})
		for design_id: String in legacy:
			var entry: Dictionary = catalog.get_or_add(design_id, {"versions": {}, "default": ""})
			var versions: Dictionary = entry.versions
			for version_name: String in legacy[design_id]:
				var snapshot: Dictionary = legacy[design_id][version_name]
				var candidate := version_name
				var suffix := 2
				var match_name := matching_name(versions, candidate)
				while not match_name.is_empty() and versions[match_name] != snapshot:
					candidate = "%s (%d)" % [version_name, suffix]
					suffix += 1
					match_name = matching_name(versions, candidate)
				if match_name.is_empty():
					versions[candidate] = snapshot.duplicate(true)
	return catalog
