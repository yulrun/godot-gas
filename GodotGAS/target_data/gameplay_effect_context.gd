## A runtime payload containing information about an effect's origin and targets.
##
## Wraps the instigator, causer, and TargetData into a single object 
## to be passed safely through the execution pipeline.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayEffectContext extends RefCounted

## The overarching entity that activated the ability (e.g., the Player Character).
var instigator: Node

## The physical entity that caused the effect (e.g., a Fireball projectile). 
## Often defaults to the instigator if no secondary actor exists.
var causer: Node

## The payload containing who, what, and where the ability hit.
var target_data: GameplayAbilityTargetData


#region Initialization
## Initializes the context. Defaults the causer to the instigator if omitted.
func _init(_instigator: Node, _causer: Node = null) -> void:
	instigator = _instigator
	causer = _causer if _causer else _instigator
	target_data = GameplayAbilityTargetData.new()
#endregion


#region Payload Helpers
## Helper to quickly check if this context successfully captured any targets.
func has_targets() -> bool:
	return target_data != null and not target_data.get_target_nodes().is_empty()


## Helper to quickly fetch the unique targets.
func get_target_nodes() -> Array[Node]:
	return target_data.get_target_nodes() if target_data else []
#endregion
