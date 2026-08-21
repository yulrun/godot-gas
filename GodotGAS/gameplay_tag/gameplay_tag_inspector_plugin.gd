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
	var enable_editor_property: = false
	var name_lowered: = name.to_lower()
	var is_tag_property: = \
		(object is GameplayCueEntry and name == "tag") \
		or (object is GameplayAbility and ( \
			name == "ability_tag" \
			or name == "activation_blocked_tags" \
			or name == "activation_required_tags" \
			or name == "shared_cooldown_tags" \
			or name == "trigger_event_tag" \
		)) \
		or (object is GameplayEffect and ( \
			name == "application_required_tags" \
			or name == "application_ignore_tags" \
			or name == "application_cue_tags" \
			or name == "periodic_cue_tags" \
			or name == "granted_tags" \
			or name == "event_tags" \
		)) \
		or (object is GameplayEffectSpec and name == "dynamic_tags")
	var is_registry: =  \
		(object is GameplayTagRegistry and name == "tags")

	if not GodotGasProjectSettings.get_editor_tag_property_editor_enabled() or is_registry:
		# Make sure to return `false` when `is_registry` because we don't want the tag editor
        # property to show up in the registries. People could start to click on tags to deactivate
        # them, but it would instead delete them permanently.
		return false
	elif is_tag_property:
		enable_editor_property = true
	else:
		var matches_on: = GodotGasProjectSettings.get_editor_tag_property_editor_match_on()
		var match_type: = GodotGasProjectSettings.get_editor_tag_property_editor_match_type()

		# We intercept arrays or strings containing the needle.
		# Here, we match 
		var matched: = false
		if not matched:
			for match_on in matches_on:
				match match_type:
					GodotGasProjectSettings.EditorTagsTagEditorPropertyMatchType.PREFIX:
						matched = name_lowered.begins_with(match_on)
					GodotGasProjectSettings.EditorTagsTagEditorPropertyMatchType.SUFFIX:
						matched = name_lowered.ends_with(match_on)
					GodotGasProjectSettings.EditorTagsTagEditorPropertyMatchType.ANYWHERE:
						matched = match_on in name_lowered
				if matched:
					break

		if matched:
			match type:
				TYPE_ARRAY, \
				TYPE_PACKED_STRING_ARRAY, \
				TYPE_STRING, \
				TYPE_STRING_NAME:
					enable_editor_property = true
			
	if enable_editor_property:
		var editor_property = GameplayTagEditorProperty.new(type)
		add_property_editor(name, editor_property)
		return true # Tells Godot to skip rendering the default input field

	return false
#endregion
