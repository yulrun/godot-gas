## Base class for all modular Gameplay Ability Tasks.
##
## Defines the transient node lifecycle, automatically binding to a parent
## GameplayAbility and safely destroying itself if the ability is interrupted.
##
## @meta_addon: GodotGAS Version 1+
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@abstract
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name AbilityTask extends Node

## Emitted when the task naturally concludes its logic.
signal task_finished(payload: Variant)

## Reference to the parent ability executing this task.
var ability: GameplayAbility

## Internal flag to prevent execution/signals if the task is interrupted.
var is_aborted: bool = false


#region Initialization
## Instantiation safety check. Verifies the extending script implemented an execute method.
func _init() -> void:
	if not has_method("execute"):
		var script_name: String = "Unknown Task"
		if get_script():
			script_name = get_script().resource_path.get_file().get_basename()
		push_warning("GodotGAS: Custom AbilityTask '%s' is missing an 'execute()' method." % script_name)
#endregion


#region Lifecycle
## Initializes the task, parents it to the ability, and listens for cancellations.
func bind_to_ability(parent_ability: GameplayAbility) -> void:
	ability = parent_ability
	ability.add_child(self)
	
	if not ability.ability_ended.is_connected(_on_ability_ended):
		ability.ability_ended.connect(_on_ability_ended)


## Triggered instantly if the parent ability is forcefully aborted by an interruption matrix.
func _on_ability_ended(_was_cancelled: bool) -> void:
	is_aborted = true
	queue_free()


## Called by the specific task script when its logic has naturally completed.
func finish_task(payload: Variant = null) -> void:
	if not is_aborted:
		task_finished.emit(payload)
		queue_free()
#endregion
