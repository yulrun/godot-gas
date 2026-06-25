## Base class for all visual and audio effects triggered by the ASC.
##
## Attach this script to the root of a scene containing your particles or 
## AudioStreamPlayers to manage their lifecycle and object pooling.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayCueNotify extends Node

## Emitted when the visual/audio effect is 100% complete so the manager can pool it.
signal cue_finished(cue_node: GameplayCueNotify, tag: StringName)

@export_category("Lifecycle")
## If true, this node will automatically pool itself after playing.
## (Set to false for looping effects like a glowing aura).
@export var auto_destroy: bool = true
## How long to wait before pooling this node. 
## Set this slightly longer than your longest particle/audio duration.
@export var destroy_delay: float = 2.0

## The specific gameplay tag assigned to this instantiated cue.
var gameplay_cue_tag: StringName


#region Execution Lifecycle
## Called by the Manager when pulled from the pool and added to the target.
func execute_cue(target: Node, payload: Dictionary = {}) -> void:
	# 1. Trigger the visual/audio logic
	play_cue()
	
	# 2. Setup the automatic garbage collection (Pooling)
	if auto_destroy:
		# We use a safe Godot 4 timer connection to finish the cue instead of queue_free
		get_tree().create_timer(destroy_delay).timeout.connect(finish_cue)


## Call this from your inherited scripts when the visual/audio effect is 100% done.
## (e.g., hook this up to the 'finished' signal of an AudioStreamPlayer or a Timer).
func finish_cue() -> void:
	# Emits the signal so the Manager pulls it off the target and puts it back to sleep
	cue_finished.emit(self, gameplay_cue_tag)


## Virtual internal method. Override this in your specific effect scripts if you need custom logic.
## (e.g., attaching to a specific bone on a 3D model, or playing a specific AnimationTree).
func play_cue() -> void:
	# By default, if you have an AnimationPlayer, you could auto-play an 'Activate' animation here.
	pass
#endregion
