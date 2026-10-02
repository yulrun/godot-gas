## Base class for all gameplay abilities in the GodotGAS framework.
##
## Defines the core execution logic, input routing, and effect application 
## pipelines for an ability. Intended to be extended by specific ability scripts.
##
## @meta_addon: GodotGAS Version 1+ (See plugin version for exact version)
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@abstract
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayAbility extends Node

## Defines how this ability handles multiple overlapping activations.
enum InstancingPolicy {
	INSTANCED_PER_ACTOR,     ## Only one instance exists. Blocks subsequent casts until finished.
	INSTANCED_PER_EXECUTION  ## Duplicates a fresh transient copy for every cast. Allows concurrent overlap.
}

## Fired when the ability finishes.
## UI or Animation systems can listen to this to know if the cast succeeded or got interrupted.
signal ability_ended(was_cancelled: bool)

@export_category("Ability Rules")
## How this ability handles being cast multiple times in rapid succession.
@export var instancing_policy: InstancingPolicy = InstancingPolicy.INSTANCED_PER_ACTOR
## The simple name to be used for logging or UI
@export var ability_name: String = ""
## The tag that uniquely identifies this ability.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var ability_tag: StringName = &"Ability.None"
## The current level of this ability, used for scaling math and effects.
@export var ability_level: float = 1.0
## The query evaluated against the ASC to determine if this ability is allowed to activate.
@export var activation_query: GameplayTagQuery

@export_category("Tag Relationships")
## Abilities currently running on the ASC that possess any of these tags will be instantly aborted when this ability activates.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var cancel_abilities_with_tags: Array[StringName] = []
## While this ability is active, any attempt to activate another ability possessing these tags will be denied.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var block_abilities_with_tags: Array[StringName] = []

@export_category("Ability Mechanics")
## Tags automatically granted to the ASC while this ability is executing.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var activation_owned_tags: Array[StringName] = []
## The gameplay effect applied to the owner to deduct resources upon committing.
@export var cost_effect: GameplayEffect
## The gameplay effect applied to the owner to trigger a cooldown upon committing.
@export var cooldown_effect: GameplayEffect
## Any additional shared effects (like a Global Cooldown) that should be applied when cast.
@export var shared_cooldown_effects: Array[GameplayEffect] = []
## Explicitly list any shared cooldowns (like GCDs) this ability should respect.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var shared_cooldown_tags: Array[StringName] = []

@export_category("Ability Triggers")
## If set, the ASC will automatically try to activate this ability when it receives this exact event tag.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var trigger_event_tag: StringName = &""

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
func try_activate(event_payload: Variant = null) -> bool:
	# --- INSTANCED PER EXECUTION PATH ---
	if instancing_policy == InstancingPolicy.INSTANCED_PER_EXECUTION:
		# 1. Gatekeeper check on the base template first
		if not owner_asc.can_activate_ability(self, true):
			return false
			
		# 2. Spawn a transient clone for this specific execution
		var transient_ability: GameplayAbility = self.duplicate()
		
		# 3. Force the clone to PER_ACTOR so it executes normally without recursively cloning itself
		transient_ability.instancing_policy = InstancingPolicy.INSTANCED_PER_ACTOR
		
		# 4. Attach and register the clone with the ASC so it can be canceled by tags
		owner_asc.add_child(transient_ability)
		transient_ability.owner_asc = owner_asc
		owner_asc._add_active_ability(transient_ability)
		
		# 5. Clean up the clone from memory and ASC tracking the exact moment it finishes
		transient_ability.ability_ended.connect(func(_was_cancelled):
			owner_asc._remove_active_ability(transient_ability)
			transient_ability.queue_free()
		)
		
		# 6. Execute the clone (Awaited to extract the boolean from the coroutine)
		return await transient_ability.try_activate(event_payload)
		
		
	# --- INSTANCED PER ACTOR PATH (Standard) ---
	if is_active or not owner_asc:
		return false
	
	# Gatekeeper check
	if not owner_asc.can_activate_ability(self, true):
		return false
		
	is_active = true
	current_event_payload = event_payload # Store the payload for the logic to use
	
	# DECLARATIVE INTERRUPTION: Cancel overlapping abilities right as we commit to activating
	if cancel_abilities_with_tags.size() > 0:
		owner_asc.cancel_abilities_with_tags(cancel_abilities_with_tags)
		
	# DECLARATIVE STATE: Grant activation tags while executing
	for tag in activation_owned_tags:
		owner_asc.add_tag(tag)
	
	# Logic execution
	var success = await _activate_ability()
	
	# Guaranteed Cleanup
	if is_active:
		end_ability(not success)
		
	current_event_payload = null # Clear it out to prevent memory leaks
	return success


## Applies only the cost of the ability. Useful for granular decoupling of draining mechanics.
func commit_cost() -> void:
	if cost_effect:
		owner_asc.apply_gameplay_effect(cost_effect, owner_asc, ability_level)


## Applies only the cooldowns of the ability.
func commit_cooldown() -> void:
	if cooldown_effect:
		owner_asc.apply_gameplay_effect(cooldown_effect, owner_asc, ability_level)
	
	for shared_effect in shared_cooldown_effects:
		if shared_effect:
			owner_asc.apply_gameplay_effect(shared_effect, owner_asc, ability_level)


## A standard helper to safely deduct resources and apply cooldowns at the EXACT same time.
## Developers should call this manually inside _activate_ability() as soon as the ability is committed.
func commit_ability() -> void:
	commit_cost()
	commit_cooldown()


## Helper to quickly check if the ability can currently afford its cost.
func check_cost() -> bool:
	if owner_asc:
		return owner_asc.check_ability_cost(self)
	return false


## Helper to quickly check if the ability is allowed to cast (not on cooldown).
func check_cooldown() -> bool:
	if owner_asc:
		return owner_asc.check_ability_cooldown(self)
	return false


## Virtual internal method. Override this in your specific ability scripts.
func _activate_ability() -> bool:
	# Example flow:
	# commit_ability()
	# await task_play_animation_and_wait(anim_player, "Attack")
	# apply_effect_to_targets(...)
	return true 


## Forcefully interrupts the ability mid-cast.
func abort_ability() -> void:
	if is_active:
		print("GAS: Ability %s was forcefully aborted." % ability_tag)
		end_ability(true)


## Cleans up the state of the ability.
func end_ability(was_cancelled: bool = false) -> void:
	if not is_active:
		return
		
	is_active = false
	
	# Strip granted state tags safely
	if owner_asc:
		for tag in activation_owned_tags:
			owner_asc.remove_tag(tag)
			
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


#region Async Ability Tasks
## Binds a custom AbilityTask node to this ability's lifecycle.
func bind_task(task: AbilityTask) -> void:
	task.bind_to_ability(self)


## Pauses ability execution for a specific duration in seconds without blocking the thread.
func task_wait_delay(duration: float) -> void:
	var task := AbilityTask_WaitDelay.new()
	bind_task(task)
	task.execute(duration)
	await task.task_finished


## Yields execution until the ASC receives a specific gameplay event tag.
func task_wait_for_event(target_tag: StringName) -> Variant:
	var task := AbilityTask_WaitForEvent.new()
	bind_task(task)
	task.execute(target_tag)
	var payload = await task.task_finished
	return payload if payload != null else {}


## Yields execution until a specific attribute changes on the owner's ASC.
func task_wait_for_attribute_change(attribute_name: String) -> void:
	var task := AbilityTask_WaitForAttribute.new()
	bind_task(task)
	task.execute(attribute_name)
	await task.task_finished


## Plays a specific animation and yields execution until that exact animation finishes.
func task_play_animation_and_wait(anim_player: AnimationPlayer, anim_name: String) -> void:
	var task := AbilityTask_PlayAnimation.new()
	bind_task(task)
	task.execute(anim_player, anim_name)
	await task.task_finished
#endregion
