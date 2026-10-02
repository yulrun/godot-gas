## Standard Ability Task: Pauses execution for a specific duration.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name AbilityTask_WaitDelay extends AbilityTask

## Kicks off the delay timer.
func execute(duration: float) -> void:
	if duration <= 0.0:
		finish_task()
		return
		
	# Yield for a single frame before starting the clock. 
	# This protects the SceneTreeTimer from instantly absorbing massive delta spikes 
	# that occur when abilities are cast during _ready() or heavy scene loads.
	await get_tree().process_frame
	
	if is_aborted:
		return
		
	await get_tree().create_timer(duration).timeout
	
	if not is_aborted:
		finish_task()
