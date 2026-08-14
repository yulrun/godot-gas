## Custom inspector plugin for the GodotGAS framework.
##
## Intercepts exported properties containing the word 'tag' and replaces 
## their default inspector UI with the custom GameplayTagEditorProperty.
##
## @meta_addon: GodotGAS Version 1 (See plugin version for exact version)
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
extends EditorInspectorPlugin

## The preloaded custom editor property script used for tag selection.
const GameplayTagEditorProperty = preload("res://addons/GodotGAS/gameplay_tag/gameplay_tag_editor_property.gd")

## Addon project settings.
const GodotGasProjectSettings: = preload("res://addons/GodotGAS/utilities/project_settings.gd")


#region Inspector Parsing
## Native Godot virtual to determine if this plugin handles the current object.
func _can_handle(object: Object) -> bool:
	# We want to look at any object/resource editing tags
	return true


## Native Godot virtual that intercepts property rendering to inject custom UI.
func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	# Here, we check if the object in the inspector is literally a `GameplayTagRegistry`.
	var is_native: = name.to_lower() == "tags" and object is GameplayTagRegistry
	if not GodotGasProjectSettings.get_editor_tag_property_editor_enabled() or is_native:
		# Make sure to return `false` when `is native` because we don't want the tag editor property
		# to show up in the registries. People could start to click on tags to deactivate them,
		# but it would instead delete them permanently.
		return false
	var matches_on: = GodotGasProjectSettings.get_editor_tag_property_editor_match_on()
	var match_type: = GodotGasProjectSettings.get_editor_tag_property_editor_match_type()

	# We intercept arrays or strings containing the needle.
	# Here, we match 
	var matched: = false
	if not matched:
		for match_on in matches_on:
			match match_type:
				GodotGasProjectSettings.EditorTagsTagEditorPropertyMatchType.PREFIX:
					matched = name.to_lower().begins_with(match_on)
				GodotGasProjectSettings.EditorTagsTagEditorPropertyMatchType.SUFFIX:
					matched = name.to_lower().ends_with(match_on)
				GodotGasProjectSettings.EditorTagsTagEditorPropertyMatchType.ANYWHERE:
					matched = match_on in name.to_lower()
			if matched:
				break

	if matched:
		match type:
			TYPE_ARRAY, \
			TYPE_PACKED_STRING_ARRAY, \
			TYPE_STRING, \
			TYPE_STRING_NAME:
				var editor_property = GameplayTagEditorProperty.new()
				add_property_editor(name, editor_property)
				return true # Tells Godot to skip rendering the default input field
			
	return false
#endregion
