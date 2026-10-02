## Standard Ability Task: Pauses execution until a specific attribute changes on the ASC.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name AbilityTask_WaitForAttribute extends AbilityTask

var _target_attribute: String


## Begins listening to the ASC's attribute modification bus.
func execute(target_attribute: String) -> void:
	_target_attribute = target_attribute
	
	if not ability or not ability.owner_asc:
		finish_task()
		return
		
	ability.owner_asc.attribute_changed.connect(_on_attribute_changed)


func _on_attribute_changed(attribute_name: String, _old: float, _new: float, _spec: GameplayEffectSpec) -> void:
	if attribute_name == _target_attribute and not is_aborted:
		if ability.owner_asc.attribute_changed.is_connected(_on_attribute_changed):
			ability.owner_asc.attribute_changed.disconnect(_on_attribute_changed)
			
		finish_task()
