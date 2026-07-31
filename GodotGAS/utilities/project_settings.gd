extends Object

enum EditorTagsTagEditorPropertyMatchType {
	PREFIX,
	SUFFIX,
	ANYWHERE,
}

const PROJECT_SETTINGS_NAME: = "godot_gas"
const PROJECT_SETTINGS_NAME_EDITOR: = PROJECT_SETTINGS_NAME + "/editor"
const PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR: = PROJECT_SETTINGS_NAME_EDITOR + "/tag_property_editor"
const PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_ENABLE: = PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR + "/enable"
const PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH: = PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR + "/match"
const PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON: = PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH + "/on"
const PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE: = PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH + "/type"
const PROJECT_SETTINGS_NAME_RESOURCES: = PROJECT_SETTINGS_NAME + "/resources"
const PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES: = PROJECT_SETTINGS_NAME_RESOURCES + "/attributes"
const PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE: = PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES + "/draft_configuration_file"
const PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_OUTPUT_DIR: = PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES + "/output_directory"
const PROJECT_SETTINGS_NAME_RESOURCES_CUES: = PROJECT_SETTINGS_NAME_RESOURCES + "/cues"
const PROJECT_SETTINGS_NAME_RESOURCES_CUES_REGISTRY: = PROJECT_SETTINGS_NAME_RESOURCES_CUES + "/registry_file"
const PROJECT_SETTINGS_NAME_RESOURCES_TAGS: = PROJECT_SETTINGS_NAME_RESOURCES + "/tags"
const PROJECT_SETTINGS_NAME_RESOURCES_TAGS_REGISTRY: = PROJECT_SETTINGS_NAME_RESOURCES_TAGS + "/registry_file"
const PROJECT_SETTINGS_NAME_RESOURCES_TAGS_GENERATED_SCRIPT: = PROJECT_SETTINGS_NAME_RESOURCES_TAGS + "/generated_script"

const PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_ENABLE: = true
const PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON: = "gas_tag,gas_tags"
const PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE: = EditorTagsTagEditorPropertyMatchType.SUFFIX

const PROJECT_SETTINGS_DEFAULT_PATH: = "res://godot_gas"
const PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE: = PROJECT_SETTINGS_DEFAULT_PATH + "/attributes_draft.cfg"
const PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_ATTRIBUTES_OUTPUT_DIR: = PROJECT_SETTINGS_DEFAULT_PATH + "/attributes"
const PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_CUES_REGISTRY: = PROJECT_SETTINGS_DEFAULT_PATH + "/cue_registry.tres"
const PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_TAGS_REGISTRY: = PROJECT_SETTINGS_DEFAULT_PATH + "/tag_registry.tres"
const PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_TAGS_GENERATED_SCRIPT: = PROJECT_SETTINGS_DEFAULT_PATH + "/gameplay_tags.gd"


static func init_project_settings() -> void:
	_init_project_settings_attributes_draft_config_path()
	_init_project_settings_attributes_output_dir()
	_init_project_settings_generated_tag_script_path()
	_init_project_settings_registry_cue()
	_init_project_settings_registry_tag()
	_init_project_settings_editor_tag_property_editor()


static func get_attributes_draft_config_path() -> String:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE)
	return ProjectSettings.get_setting(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE)


static func get_attributes_output_dir_path() -> String:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_OUTPUT_DIR):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_OUTPUT_DIR, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_ATTRIBUTES_OUTPUT_DIR)
	return ProjectSettings.get_setting(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_OUTPUT_DIR)


static func get_generated_tag_script_path() -> String:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_GENERATED_SCRIPT):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_GENERATED_SCRIPT, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_TAGS_GENERATED_SCRIPT)
	return ProjectSettings.get_setting(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_GENERATED_SCRIPT)


static func get_registry_cue_path() -> String:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_RESOURCES_CUES_REGISTRY):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_RESOURCES_CUES_REGISTRY, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_CUES_REGISTRY)
	return ProjectSettings.get_setting(PROJECT_SETTINGS_NAME_RESOURCES_CUES_REGISTRY)


static func get_registry_tag_path() -> String:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_REGISTRY):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_REGISTRY, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_TAGS_REGISTRY)
	return ProjectSettings.get_setting(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_REGISTRY)


static func get_editor_tag_property_editor_enabled() -> bool:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_ENABLE):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_ENABLE, PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_ENABLE)
	return ProjectSettings.get_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_ENABLE)


static func get_editor_tag_property_editor_match_on() -> PackedStringArray:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON, PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON)
	var match_on_list: = ProjectSettings.get_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON) as String
	return match_on_list.split(",", false)


static func get_editor_tag_property_editor_match_type() -> EditorTagsTagEditorPropertyMatchType:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE, PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE)
	return ProjectSettings.get_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE)


static func _init_project_settings_attributes_output_dir() -> void:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_OUTPUT_DIR):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_OUTPUT_DIR, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_ATTRIBUTES_OUTPUT_DIR)
	ProjectSettings.set_initial_value(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_OUTPUT_DIR, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_ATTRIBUTES_OUTPUT_DIR)
	ProjectSettings.add_property_info({
		"name": PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_OUTPUT_DIR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
	})
	var output_dir: String = ProjectSettings.get_setting(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)


static func _init_project_settings_attributes_draft_config_path() -> void:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE)
	ProjectSettings.set_initial_value(PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE)
	ProjectSettings.add_property_info({
		"name": PROJECT_SETTINGS_NAME_RESOURCES_ATTRIBUTES_DRAFT_CONFIG_FILE,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE_PATH,
	})


static func _init_project_settings_generated_tag_script_path() -> void:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_GENERATED_SCRIPT):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_GENERATED_SCRIPT, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_TAGS_GENERATED_SCRIPT)
	ProjectSettings.set_initial_value(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_GENERATED_SCRIPT, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_TAGS_GENERATED_SCRIPT)
	ProjectSettings.add_property_info({
		"name": PROJECT_SETTINGS_NAME_RESOURCES_TAGS_GENERATED_SCRIPT,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE_PATH,
	})


static func _init_project_settings_registry_cue() -> void:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_RESOURCES_CUES_REGISTRY):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_RESOURCES_CUES_REGISTRY, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_CUES_REGISTRY)
	ProjectSettings.set_initial_value(PROJECT_SETTINGS_NAME_RESOURCES_CUES_REGISTRY, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_CUES_REGISTRY)
	ProjectSettings.add_property_info({
		"name": PROJECT_SETTINGS_NAME_RESOURCES_CUES_REGISTRY,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE_PATH,
	})
	var registry_path: String = ProjectSettings.get_setting(PROJECT_SETTINGS_NAME_RESOURCES_CUES_REGISTRY)
	if not FileAccess.file_exists(registry_path):
		var default_registry = GameplayCueRegistry.new()
		DirAccess.make_dir_recursive_absolute(registry_path.get_base_dir())
		ResourceSaver.save(default_registry, registry_path)


static func _init_project_settings_registry_tag() -> void:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_REGISTRY):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_REGISTRY, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_TAGS_REGISTRY)
	ProjectSettings.set_initial_value(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_REGISTRY, PROJECT_SETTINGS_DEFAULT_PATH_RESOURCES_TAGS_REGISTRY)
	ProjectSettings.add_property_info({
		"name": PROJECT_SETTINGS_NAME_RESOURCES_TAGS_REGISTRY,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE_PATH,
	})
	var registry_path: String = ProjectSettings.get_setting(PROJECT_SETTINGS_NAME_RESOURCES_TAGS_REGISTRY)
	if not FileAccess.file_exists(registry_path):
		var default_registry = GameplayTagRegistry.new()
		default_registry.add_tag(&"Example.Ability.Arrow.Impact")
		default_registry.add_tag(&"Example.Ability.Arrow.Shoot")
		default_registry.add_tag(&"Example.Ability.Heal.Triggered")
		default_registry.add_tag(&"Example.Ability.Poison.Applied")
		default_registry.add_tag(&"Example.Ability.Poison.Cast")
		default_registry.add_tag(&"Example.Event.Damage.Critical")
		default_registry.add_tag(&"Example.Event.Damage.Missed")
		default_registry.add_tag(&"Example.Event.Damage.Normal")
		default_registry.add_tag(&"Example.Event.Defend.Hit")
		default_registry.add_tag(&"Example.State.Cooldown.Arrow")
		default_registry.add_tag(&"Example.State.Cooldown.Poison")

		DirAccess.make_dir_recursive_absolute(registry_path.get_base_dir())
		ResourceSaver.save(default_registry, registry_path)


static func _init_project_settings_editor_tag_property_editor() -> void:
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_ENABLE):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_ENABLE, PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_ENABLE)
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON, PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON)
	if not ProjectSettings.has_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE):
		ProjectSettings.set_setting(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE, PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE)

	ProjectSettings.set_initial_value(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_ENABLE, PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_ENABLE)
	ProjectSettings.set_initial_value(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON, PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON)
	ProjectSettings.set_initial_value(PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE, PROJECT_SETTINGS_DEFAULT_VALUE_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE)

	ProjectSettings.add_property_info({
		"name": PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_ENABLE,
		"type": TYPE_BOOL,
	})
	ProjectSettings.add_property_info({
		"name": PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_ON,
		"type": TYPE_STRING,
	})
	ProjectSettings.add_property_info({
		"name": PROJECT_SETTINGS_NAME_EDITOR_TAG_PROPERTY_EDITOR_MATCH_TYPE,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Prefix,Suffix,Anywhere",
	})


## Dynamically parses an SVG file in memory, replacing pure white/grey with the native Editor color.
## Automatically scales the rasterized image to perfectly match the user's Editor UI Scale (e.g., 4K monitors).
static func get_svg_icon(path: String) -> Texture2D:
	if not Engine.is_editor_hint():
		return load(path)
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: 
		return load(path)
	
	var svg_text = file.get_as_text()
	file.close()
	
	var theme = EditorInterface.get_editor_theme()
	var font_color = "#" + theme.get_color("font_color", "Editor").to_html(false)
	
	svg_text = svg_text.replace("#e0e0e0", font_color)
	svg_text = svg_text.replace("#E0E0E0", font_color)
	svg_text = svg_text.replace("#ffffff", font_color)
	svg_text = svg_text.replace("#FFFFFF", font_color)
	
	var img = Image.new()
	var editor_scale = EditorInterface.get_editor_scale()
	var err = img.load_svg_from_string(svg_text, editor_scale)
	
	if err == OK:
		return ImageTexture.create_from_image(img)
		
	return load(path)
