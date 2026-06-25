## Custom inspector plugin for the GodotGAS framework.
##
## Intercepts exported properties containing the word 'tag' and replaces 
## their default inspector UI with the custom GameplayTagEditorProperty.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
extends EditorInspectorPlugin

## The preloaded custom editor property script used for tag selection.
const GameplayTagEditorProperty = preload("res://addons/GodotGAS/gameplay_tag/gameplay_tag_editor_property.gd")


#region Inspector Parsing
## Native Godot virtual to determine if this plugin handles the current object.
func _can_handle(object: Object) -> bool:
	# We want to look at any object/resource editing tags
	return true


## Native Godot virtual that intercepts property rendering to inject custom UI.
func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	# We intercept Array[StringName] or StringName variables that contain the word 'tag'
	if "tag" in name.to_lower():
		if type == TYPE_ARRAY or type == TYPE_STRING_NAME or type == TYPE_STRING:
			var editor_property = GameplayTagEditorProperty.new()
			add_property_editor(name, editor_property)
			
			return true # Tells Godot to skip rendering the default input field
			
	return false
#endregion
