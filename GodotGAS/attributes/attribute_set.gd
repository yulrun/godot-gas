## The foundational class for all attribute modules.
##
## Do not instantiate directly; inherit to define specific stats.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool @abstract
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name AttributeSet extends Resource


#region Core Virtuals
## Called by the ASC right BEFORE an attribute's current_value is actually modified.
## This allows the AttributeSet to clamp or modify the incoming value.
## Override this in your specific child sets (e.g., HealthAttributeSet).
func pre_attribute_change(attribute_name: String, proposed_value: float) -> float:
	# By default, we just allow the value to pass through unchanged
	return proposed_value
#endregion
