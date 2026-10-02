## Standard Ability Task: Plays an animation and pauses execution until it finishes.
##
## @meta_addon: GodotGAS Version 1+
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name AbilityTask_PlayAnimation extends AbilityTask

var _anim_player: AnimationPlayer
var _target_anim: String


## Plays the target animation and begins listening for its completion signal.
func execute(anim_player: AnimationPlayer, anim_name: String) -> void:
	_anim_player = anim_player
	_target_anim = anim_name
	
	if not _anim_player or not _anim_player.has_animation(_target_anim):
		push_warning("GodotGAS: Animation '%s' not found on %s." % [_target_anim, _anim_player.name if _anim_player else "Null Player"])
		finish_task()
		return
		
	_anim_player.animation_finished.connect(_on_animation_finished)
	_anim_player.play(_target_anim)


func _on_animation_finished(anim_name: String) -> void:
	if anim_name == _target_anim and not is_aborted:
		if _anim_player.animation_finished.is_connected(_on_animation_finished):
			_anim_player.animation_finished.disconnect(_on_animation_finished)
			
		finish_task()
