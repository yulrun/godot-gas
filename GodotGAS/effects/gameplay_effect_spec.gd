## A runtime payload that combines a static GameplayEffect definition
## with the specific context (instigator, targets, level) of its application.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayEffectSpec extends RefCounted

## The static data definition (your existing Resource).
var effect_def: GameplayEffect

## The runtime payload containing the instigator, causer, and target data.
var context: GameplayEffectContext

## The level of the ability/effect, used later to scale mathematical modifiers.
var level: float = 1.0

## The exact time this effect was applied (useful for durations).
var application_time: float = 0.0

## Tags injected dynamically at runtime by ExecCalcs or Abilities
var dynamic_tags: Array[StringName] = []

## A dictionary populated by the ASC after modifiers are applied, storing the EXACT final clamped changes (e.g., {"Health": -50.0})
var calculated_deltas: Dictionary = {}


#region Initialization
## Initializes the live effect instance.
func _init(in_effect: GameplayEffect, in_context: GameplayEffectContext, in_level: float = 1.0) -> void:
	effect_def = in_effect
	context = in_context
	level = in_level
	application_time = Time.get_ticks_msec() / 1000.0
#endregion


#region Context Helpers
## Helper to quickly grab the unique target nodes from the attached context.
func get_target_nodes() -> Array[Node]:
	if context and context.target_data:
		return context.target_data.get_target_nodes()
		
	return []

## QoL Helper: Checks if the spec has a tag natively OR dynamically
func has_tag(tag: StringName) -> bool:
	# Assuming your base effect has an array of identifier tags like 'asset_tags' or 'granted_tags'
	if effect_def.granted_tags.has(tag):
		return true
	return dynamic_tags.has(tag)

## QoL Helper: Injects a tag into our Dynamic Tag Array (Useful for applying 'Critical' 'Dodge' etc. During Exec. Calculations
func inject_tag(tag: StringName) -> void:
	if not dynamic_tags.has(tag):
		dynamic_tags.append(tag)
#endregion
