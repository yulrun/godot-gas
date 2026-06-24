## A tracked, runtime instance of a GameplayEffectSpec currently applied to an ASC.
##
## Manages the state, duration, and periodic ticks of an active effect,
## while recording applied modifiers so they can be safely reversed.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name ActiveGameplayEffect extends RefCounted

## The live, wrapped instance of the effect being applied.
## This securely holds the Context, Target Data, Level, and the base Definition.
var spec: GameplayEffectSpec

## A dictionary tracking the exact flat mathematical changes this effect applied.
## Used to perfectly reverse the math when the effect expires or is cleansed.
## Format: { "attribute_name": amount_changed }
var applied_deltas: Dictionary = {}

## The remaining duration of the effect.
var time_remaining: float = 0.0

## The internal clock tracking the time until the next periodic tick.
var time_until_next_tick: float = 0.0


#region Initialization
func _init(in_spec: GameplayEffectSpec) -> void:
	spec = in_spec
	
	var effect = spec.effect_def
	if effect.policy == GameplayEffect.DurationPolicy.DURATION:
		time_remaining = effect.duration
		
	if effect.period > 0.0:
		time_until_next_tick = effect.period
#endregion


#region QoL Helpers
## Quickly access the base Resource definition.
func get_effect_def() -> GameplayEffect:
	return spec.effect_def if spec else null


## Quickly access the overarching Entity that cast this effect.
func get_instigator() -> Node:
	if spec and spec.context and spec.context.instigator:
		return spec.context.instigator
		
	return null


## Quickly retrieve the unique targets captured when this effect was fired.
func get_target_nodes() -> Array[Node]:
	if spec and spec.context and spec.context.target_data:
		return spec.context.target_data.get_target_nodes()
		
	return []
#endregion
