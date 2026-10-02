## A resource container for a single gameplay attribute.
##
## Holds both the permanent base value and the temporary current value of an
## attribute. The ASC derives current from base and active effects. Direct writes
## to this resource bypass that recalculation; use ASC-mediated changes instead.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name AttributeData extends Resource

## The permanent, unbuffed stat (e.g., your naked Max Health).
@export var base_value: float = 0.0 : set = _set_base_value
## The temporary, buffed/debuffed stat used for actual gameplay math.
@export var current_value: float = 0.0


#region Initialization
func _init(initial_value: float = 0.0) -> void:
	base_value = initial_value
	current_value = initial_value
#endregion


#region Setters & Math
func _set_base_value(new_value: float) -> void:
	base_value = new_value
	
	# This setter also runs for direct writes outside the ASC. Only the ASC can
	# reaggregate active effects after changing the base.
	current_value = new_value
#endregion
