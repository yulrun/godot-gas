## GodotGAS Migration Tool
##
## Automates the conversion of legacy array-based tags into GameplayTagQuery resources.
##
## Instructions:
## 1. BEFORE UPGRADING: Uncomment `export_legacy_tags()` inside `_run()`. 
##    Open this script in the editor and click File -> Run.
## 2. UPGRADE GodotGAS to the new version.
## 3. AFTER UPGRADING: Uncomment `upgrade_to_queries()` inside `_run()`. 
##    Click File -> Run again to inject the new query resources.

@tool
extends EditorScript

const DUMP_PATH = "res://godotgas_migration_data.json"

func _run() -> void:
	# --- PHASE 1: Run this before upgrading ---
	# export_legacy_tags()
	
	# --- PHASE 2: Run this after upgrading ---
	# upgrade_to_queries()
	pass


func export_legacy_tags() -> void:
	var data: Dictionary = {}
	var files: Array[String] = _get_all_tres_files("res://")
	
	for file in files:
		var res: Resource = ResourceLoader.load(file, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not res: continue

		var entry: Dictionary = {}
		var is_valid: bool = false

		# Dynamically check for GameplayAbility Legacy Properties
		if res.get("activation_required_tags") != null or res.get("activation_blocked_tags") != null:
			entry["type"] = "GameplayAbility"
			entry["require"] = res.get("activation_required_tags") if res.get("activation_required_tags") else []
			entry["ignore"] = res.get("activation_blocked_tags") if res.get("activation_blocked_tags") else []
			is_valid = true

		# Dynamically check for GameplayEffect Legacy Properties
		elif res.get("application_required_tags") != null or res.get("application_ignore_tags") != null:
			entry["type"] = "GameplayEffect"
			entry["require"] = res.get("application_required_tags") if res.get("application_required_tags") else []
			entry["ignore"] = res.get("application_ignore_tags") if res.get("application_ignore_tags") else []
			is_valid = true

		if is_valid and (entry["require"].size() > 0 or entry["ignore"].size() > 0):
			data[file] = entry

	var file_obj := FileAccess.open(DUMP_PATH, FileAccess.WRITE)
	if file_obj:
		file_obj.store_string(JSON.stringify(data, "\t"))
		file_obj.close()
		print("GodotGAS Migration: Exported %d resources to %s" % [data.size(), DUMP_PATH])


func upgrade_to_queries() -> void:
	if not FileAccess.file_exists(DUMP_PATH):
		push_error("GodotGAS Migration: No migration data found at " + DUMP_PATH)
		return

	var file_obj := FileAccess.open(DUMP_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(file_obj.get_as_text())
	file_obj.close()
	
	if typeof(data) != TYPE_DICTIONARY:
		push_error("GodotGAS Migration: Invalid JSON data format.")
		return

	var upgraded_count: int = 0
	
	for file_path in (data as Dictionary).keys():
		var res: Resource = ResourceLoader.load(file_path)
		if not res: continue

		var entry: Dictionary = data[file_path]
		var query := GameplayTagQuery.new()

		# Strictly type the loaded JSON arrays back into StringNames for Godot 4.7+
		var req_tags: Array[StringName] = []
		for t in entry["require"]: req_tags.append(StringName(t))

		var ign_tags: Array[StringName] = []
		for t in entry["ignore"]: ign_tags.append(StringName(t))

		# Map the old arrays into the new query fields
		query.require_all_tags = req_tags
		query.ignore_tags = ign_tags

		# Dynamically set the new property to bypass script compilation sequence errors
		if entry["type"] == "GameplayAbility":
			res.set("activation_query", query)
		elif entry["type"] == "GameplayEffect":
			res.set("application_query", query)

		ResourceSaver.save(res, file_path)
		upgraded_count += 1

	print("GodotGAS Migration: Successfully upgraded %d resources to use GameplayTagQuery." % upgraded_count)


func _get_all_tres_files(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			# Avoid hidden directories like .godot
			if dir.current_is_dir() and not file_name.begins_with("."):
				files.append_array(_get_all_tres_files(path.path_join(file_name)))
			else:
				if file_name.ends_with(".tres"):
					files.append(path.path_join(file_name))
			file_name = dir.get_next()
			
	return files
