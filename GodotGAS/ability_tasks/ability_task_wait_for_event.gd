## Standard Ability Task: Pauses execution until the ASC receives a specific event tag.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name AbilityTask_WaitForEvent extends AbilityTask

var _target_tag: StringName


## Begins listening to the ASC's event bus.
func execute(target_tag: StringName) -> void:
	_target_tag = target_tag
	
	if not ability or not ability.owner_asc:
		finish_task({})
		return
		
	ability.owner_asc.gameplay_event_received.connect(_on_event_received)


func _on_event_received(event_tag: StringName, payload: Variant) -> void:
	if event_tag == _target_tag and not is_aborted:
		if ability.owner_asc.gameplay_event_received.is_connected(_on_event_received):
			ability.owner_asc.gameplay_event_received.disconnect(_on_event_received)
			
		finish_task(payload)
