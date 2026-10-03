## Standard Ability Task: Spawns a targeting reticle and yields until confirmed.
##
## @meta_addon: GodotGAS Version 1+
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name AbilityTask_WaitForTargetData extends AbilityTask

var _target_actor: GameplayAbilityTargetActor


## Instantiates the target actor scene and pauses execution until a target is confirmed.
func execute(target_actor_scene: PackedScene) -> void:
	if not target_actor_scene:
		finish_task(null)
		return
		
	var instance = target_actor_scene.instantiate()
	if not instance is GameplayAbilityTargetActor:
		push_error("GodotGAS: Provided scene must extend GameplayAbilityTargetActor.")
		instance.free()
		finish_task(null)
		return
		
	_target_actor = instance
	
	# Attach the reticle directly to the overarching entity/avatar so it moves with them.
	var avatar = ability.owner_asc.get_parent() if ability and ability.owner_asc else self
	avatar.add_child(_target_actor)
	
	_target_actor.target_data_ready.connect(_on_target_data_ready)
	_target_actor.target_cancelled.connect(_on_target_cancelled)
	
	_target_actor.start_targeting()


func _on_target_data_ready(target_data: GameplayAbilityTargetData) -> void:
	if not is_aborted:
		_cleanup_actor()
		finish_task(target_data)


func _on_target_cancelled() -> void:
	if not is_aborted:
		_cleanup_actor()
		finish_task(null)


## Intercepts the base AbilityTask abortion hook to safely purge the visual reticle.
func _on_ability_ended(was_cancelled: bool) -> void:
	_cleanup_actor()
	super._on_ability_ended(was_cancelled)


## Helper to ensure the reticle node is removed gracefully from memory.
func _cleanup_actor() -> void:
	if is_instance_valid(_target_actor) and not _target_actor.is_queued_for_deletion():
		if _target_actor.get_parent():
			_target_actor.get_parent().remove_child(_target_actor)
		_target_actor.queue_free()
