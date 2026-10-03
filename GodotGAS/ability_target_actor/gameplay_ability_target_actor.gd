## Base class for visual targeting reticles and interactive aiming phases.
##
## Developers extend this node to handle custom raycasting, input reading, 
## or ground-decal positioning, then call confirm_target() to return the hits.
##
## @meta_addon: GodotGAS Version 1+
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@abstract
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayAbilityTargetActor extends Node

## Emitted when the user finishes aiming and selects their targets.
signal target_data_ready(target_data: GameplayAbilityTargetData)

## Emitted when the user explicitly cancels the aiming phase (e.g., right click).
signal target_cancelled


## Called automatically when the Targeting Task spawns this reticle.
## Override this to initialize graphics, reset timers, or begin raycasting.
func start_targeting() -> void:
	pass


## Called by the developer's specific logic (e.g., in _input) when the player confirms the aim.
func confirm_target(data: GameplayAbilityTargetData) -> void:
	target_data_ready.emit(data)


## Called by the developer's specific logic when the player aborts the aim.
func cancel_target() -> void:
	target_cancelled.emit()
