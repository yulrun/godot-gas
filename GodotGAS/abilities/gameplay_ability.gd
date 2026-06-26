## Base class for all gameplay abilities in the GodotGAS framework.
##
## Defines the core execution logic, input routing, and effect application 
## pipelines for an ability. Intended to be extended by specific ability scripts.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@abstract
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayAbility extends Node

## Fired when the ability finishes.
## UI or Animation systems can listen to this to know if the cast succeeded or got interrupted.
signal ability_ended(was_cancelled: bool)

@export_category("Ability Rules")
## The simple name to be used for logging or UI
@export var ability_name: String = ""
## The tag that uniquely identifies this ability.
@export var ability_tag: StringName = "Ability.None"
## The current level of this ability, used for scaling math and effects.
@export var ability_level: float = 1.0
## Tags that, if present on the ASC, will prevent this ability from activating.
@export var activation_blocked_tags: Array[StringName] = []
## Tags that, if not present on the ASC, will prevent this ability from activating.
@export var activation_required_tags: Array[StringName] = []

@export_category("Ability Mechanics")
## The gameplay effect applied to the owner to deduct resources upon committing.
@export var cost_effect: GameplayEffect
## The gameplay effect applied to the owner to trigger a cooldown upon committing.
@export var cooldown_effect: GameplayEffect
## Any additional shared effects (like a Global Cooldown) that should be applied when cast.
@export var shared_cooldown_effects: Array[GameplayEffect] = []
## Explicitly list any shared cooldowns (like GCDs) this ability should respect.
@export var shared_cooldown_tags: Array[StringName] = []

@export_category("Ability Triggers")
## If set, the ASC will automatically try to activate this ability when it receives this exact event tag.
@export var trigger_event_tag: StringName = ""

@export_category("Input Routing")
## The integer ID this ability is currently bound to. -1 means unbound.
## Usually handled automatically by UI Action Bars calling ASC.bind_ability_to_input().
@export var input_id: int = -1

## Temporarily holds the payload if this ability was activated via an event.
## This can be a GameplayEffectSpec, a Dictionary, or a Godot Node!
var current_event_payload: Variant

## A reference to the AbilitySystemComponent that owns this ability.
var owner_asc: AbilitySystemComponent

## Tracks whether this ability is currently executing.
var is_active: bool = false


#region Initialization
## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not owner_asc:
		var parent = get_parent()
		if parent is AbilitySystemComponent:
			parent.grant_ability(self)
#endregion


#region Execution & State
## The public entry point. Accepts an optional payload if triggered by an event.
func try_activate(event_payload: GameplayEffectContext = null) -> bool:
	if is_active or not owner_asc:
		return false
	
	# Gatekeeper check
	if not owner_asc.can_activate_ability(self, true):
		return false
		
	is_active = true
	current_event_payload = event_payload # Store the payload for the logic to use
	
	# Logic execution
	var success = await _activate_ability()
	
	# Guaranteed Cleanup
	if is_active:
		end_ability(not success)
		
	current_event_payload = null # Clear it out to prevent memory leaks
	return success


## A standard helper to safely deduct resources and apply cooldowns at the EXACT same time.
## Developers should call this manually inside _activate_ability() as soon as the ability is committed.
func commit_ability() -> void:
	if cost_effect:
		owner_asc.apply_gameplay_effect(cost_effect, owner_asc, ability_level)
	
	if cooldown_effect:
		owner_asc.apply_gameplay_effect(cooldown_effect, owner_asc, ability_level)
	
	for shared_effect in shared_cooldown_effects:
		if shared_effect:
			owner_asc.apply_gameplay_effect(shared_effect, owner_asc, ability_level)


## Virtual internal method. Override this in your specific ability scripts.
func _activate_ability() -> bool:
	# Example flow:
	# commit_ability()
	# await play_animation()
	# apply_effect_to_targets(...)
	return true 


## Forcefully interrupts the ability mid-cast.
func abort_ability() -> void:
	if is_active:
		print("GAS: Ability %s was forcefully aborted." % ability_tag)
		end_ability(true)


## Cleans up the state of the ability.
func end_ability(was_cancelled: bool = false) -> void:
	is_active = false
	# We intentionally DO NOT remove the ability from the ASC here, 
	# otherwise it gets permanently un-granted.
	
	ability_ended.emit(was_cancelled)
#endregion


#region Helper Methods
## Triggers multiple visual/audio cues through the ASC.
func execute_cue(tag: StringName) -> void:
	if owner_asc:
		owner_asc.execute_cue(tag)


## A massive QoL helper. Takes target data, builds the Context, wraps the Effect in a Spec, 
## and shoots it at every target's ASC.
func apply_effect_to_targets(effect_res: GameplayEffect, target_data: GameplayAbilityTargetData) -> void:
	if not effect_res or not target_data:
		return
		
	# The instigator and the causer both default to the persistent parent entity (e.g., the Player).
	# Do NOT pass `self` (the transient ability) as the causer.
	var persistent_avatar = owner_asc.get_parent()
	var context = GameplayEffectContext.new(persistent_avatar, persistent_avatar)
	
	context.target_data = target_data
	var spec = GameplayEffectSpec.new(effect_res, context, ability_level)
	
	var targets = target_data.get_target_nodes()
	for target in targets:
		var target_asc = _find_asc_on_node(target)
		if target_asc:
			owner_asc.apply_effect_spec_to_target(spec, target_asc)


## Internal helper to search for an ASC on a given node or its immediate children.
func _find_asc_on_node(node: Node) -> AbilitySystemComponent:
	if node is AbilitySystemComponent: 
		return node
		
	for child in node.get_children():
		if child is AbilitySystemComponent: 
			return child
			
	return null


## Returns ALL tags that represent a cooldown for this ability 
## (Personal + Shared explicitly assigned by the designer).
func get_cooldown_tags() -> Array[StringName]:
	var cooldown_tags: Array[StringName] = []
	
	# 1. Pull granted tags directly from the assigned Cooldown Resource
	if cooldown_effect != null:
		cooldown_tags.append_array(cooldown_effect.granted_tags)
	
	# 2. Automatically pull tags from the applied shared effects (like the GCD)
	for effect in shared_cooldown_effects:
		if effect != null:
			cooldown_tags.append_array(effect.granted_tags)
	
	# 3. Pull explicit shared cooldown tags
	cooldown_tags.append_array(shared_cooldown_tags)
	
	return cooldown_tags
#endregion


#region Input Routing
## Virtual function triggered by the ASC when the assigned input_id is PRESSED.
func _input_pressed(asc: AbilitySystemComponent) -> void:
	if is_active:
		# If already casting/channeling, route to the active override
		_active_input_pressed(asc)
		return
		
	# Kick off the robust activation pipeline (try_activate handles gatekeeping, state, and cleanup)
	try_activate()


## Virtual function triggered by the ASC when the assigned input_id is RELEASED.
func _input_released(asc: AbilitySystemComponent) -> void:
	if is_active:
		_active_input_released(asc)


## Triggered when the ability's input is PRESSED, but the ability is ALREADY active.
## Override this for mechanics like 'Press again to cancel' or 'Press again to detonate'.
func _active_input_pressed(asc: AbilitySystemComponent) -> void:
	pass


## Triggered when the ability's input is RELEASED, but the ability is ALREADY active.
## Override this for 'Hold to charge, Release to fire' mechanics.
func _active_input_released(asc: AbilitySystemComponent) -> void:
	pass
#endregion
