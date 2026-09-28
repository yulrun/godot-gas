## The central brain of the GodotGAS framework.
##
## Manages tags, attributes, and abilities for a specific entity.
##
## @meta_addon: GodotGAS Version 1+ (See plugin version for exact version)
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name AbilitySystemComponent extends Node

## Fired the moment a tag's count goes from 0 to 1.
signal tag_added(tag: StringName)

## Fired when a tag's count increments
signal tag_count_changed(tag: StringName, new_count: int)

## Fired the moment a tag's count drops to 0 and is completely removed.
signal tag_removed(tag: StringName)

## Fired whenever an attribute's current_value is actually modified.
## Useful for connecting UI Health Bars or checking for Death (Health <= 0).
signal attribute_changed(attribute_name: String, old_value: float, new_value: float, effect_spec: GameplayEffectSpec)

## Fired by the ATTACKER to tell its own systems "I successfully hit someone"
signal effect_applied_to_target(target_asc: AbilitySystemComponent, spec: GameplayEffectSpec)

## Fired anytime we receive a gameplay_event
signal gameplay_event_received(event_tag: StringName, payload: Variant)

## Fired when a Duration or Infinite effect is successfully applied to this ASC.
## The UI uses this to start Cooldown Sweeps or display Buff/Debuff Icons.
signal active_effect_added(active_effect: ActiveGameplayEffect)

## Fired when an effect expires naturally or is forcefully purged.
## The UI uses this to clear Cooldowns early or remove Buff/Debuff Icons.
signal active_effect_removed(active_effect: ActiveGameplayEffect)

## Fired when a physical attempt to activate an ability fails.
## The payload dictionary contains context (e.g., {"tags": [array of blocking tags]}).
signal ability_activation_failed(ability: GameplayAbility, reason: ActivationError, payload: Dictionary)

## Fired when THIS ASC receives an effect from someone else. 
## UI listens to this to spawn Damage Numbers, "Miss!", or "Blocked!" text.
signal effect_received(source_asc: AbilitySystemComponent, spec: GameplayEffectSpec)

## Fired when an ability is added to this ASC
## Holds reference to the ability that was added..
signal ability_granted(ability: GameplayAbility)

## Fired when an ability is removed to this ASC.
## Holds reference to the ability that was removed.
signal ability_removed(ability: GameplayAbility)


@export_category("State Management")
@export var attribute_sets: Array[AttributeSet] = []

## If false, this ASC will create a unique deep copy of its attribute sets on start.
## If true, it will share the exact resource memory with other entities (Unreal default is false).
@export var share_attributes: bool = false

@export_category("Networking")
## If true, this ASC will automatically spawn a Synchronizer to handle Attributes and Tags,
## while also intercepting and routing Inputs/Effects via RPCs for Server Authority.
@export var is_networked: bool = false

@export_category("Debugging")
@export var debug_signal_log: bool = false

## Array of integer IDs representing currently held inputs.
var _active_inputs: Array[int] = []

## Array of actively granted and managed abilities.
var _active_abilities: Array[GameplayAbility] = []

## Dictionary tracking all currently active tags and their reference counts.
var _active_tags: Dictionary = {}

## Array tracking all active gameplay effects currently applied to this component.
var _active_effects: Array[ActiveGameplayEffect] = []

## Recursion-guard flags to safely cascade suppression evaluations when tags change.
var _is_evaluating_suppression: bool = false
var _suppression_queued: bool = false

## Defines the exact reason an ability failed to activate.
enum ActivationError {
	ALREADY_ACTIVE,
	ON_COOLDOWN,
	FAILED_QUERY,
	INSUFFICIENT_RESOURCES,
	BLOCKED_BY_OTHER_ABILITY,
	INTERNAL_ERROR
}


#region Core Virtuals
func _ready() -> void:
	# Enforce Memory Isolation (Unreal GAS Standard)
	if not share_attributes:
		for i in range(attribute_sets.size()):
			if attribute_sets[i]:
				# duplicate(true) ensures the internal AttributeData nodes are also cloned
				attribute_sets[i] = attribute_sets[i].duplicate(true)
	
	# Auto-Networking Synchronization Setup
	if is_networked:
		var sync = MultiplayerSynchronizer.new()
		sync.name = "GASSynchronizer"
		var rep_config = SceneReplicationConfig.new()
		
		# 1. Sync Active Tags Array
		rep_config.add_property(NodePath(".:_active_tags"))
		
		# 2. Dynamically map and sync all instanced Attributes!
		for i in range(attribute_sets.size()):
			if attribute_sets[i]:
				var set_path = ".:attribute_sets:" + str(i)
				for prop in attribute_sets[i].get_property_list():
					if prop.class_name == &"AttributeData":
						rep_config.add_property(NodePath(set_path + ":" + prop.name + ":current_value"))
						rep_config.add_property(NodePath(set_path + ":" + prop.name + ":base_value"))
		
		sync.replication_config = rep_config
		add_child(sync)
	
	# Debug Binding
	if debug_signal_log:
		tag_added.connect(_debug_tag_added)
		tag_count_changed.connect(_debug_tag_count_changed)
		tag_removed.connect(_debug_tag_removed)
		attribute_changed.connect(_debug_attribute_changed)
		effect_applied_to_target.connect(_debug_effect_applied_to_target)
		gameplay_event_received.connect(_debug_gameplay_event_received)
		active_effect_added.connect(_debug_active_effect_added)
		active_effect_removed.connect(_debug_active_effect_removed)


func _process(delta: float) -> void:
	for i in range(_active_effects.size() - 1, -1, -1):
		var active_effect = _active_effects[i]
		
		# Handle Periodic Ticks (Skip if Turn-Based)
		if active_effect.spec.period > 0.0 and active_effect.spec.effect_def.policy != GameplayEffect.DurationPolicy.TURN_BASED:
			active_effect.time_until_next_tick -= delta
			if active_effect.time_until_next_tick <= 0.0:
				
				# Skip tick outputs if suppressed, but continue tracking tick interval
				if not active_effect.is_suppressed:
					# 1. Trigger Periodic Cues
					for cue_tag in active_effect.spec.effect_def.periodic_cue_tags:
						execute_cue(cue_tag, {"target": get_parent()})
					
					# 2. Broadcast Periodic Events (Wakes up passives!)
					_trigger_effect_events(active_effect.spec)
						
					# 3. Re-Evaluate and Apply the math natively
					# Doing this per tick allows DoTs to dynamically update if attacker stats change!
					_evaluate_spec(active_effect.spec) 
					_commit_spec_math(active_effect.spec)
				
				# Reset the clock for the next tick
				active_effect.time_until_next_tick += active_effect.spec.period
		
		# Handle Expiration
		if active_effect.spec.effect_def.policy == GameplayEffect.DurationPolicy.DURATION:
			active_effect.time_remaining -= delta
			
			if active_effect.time_remaining <= 0.0:
				remove_active_effect(active_effect)


## Called by your external Turn Manager to process turn-based effects.
func advance_turn() -> void:
	for i in range(_active_effects.size() - 1, -1, -1):
		var active_effect = _active_effects[i]
		var spec = active_effect.spec
		
		if spec.effect_def.policy == GameplayEffect.DurationPolicy.TURN_BASED:
			
			# 1. Handle Turn-Based Periodic Ticks (DoTs / HoTs)
			if spec.period > 0.0 and spec.effect_def.tick_on_turn_start:
				if not active_effect.is_suppressed:
					# 1a. Trigger Cues
					for cue_tag in spec.effect_def.periodic_cue_tags:
						execute_cue(cue_tag, {"target": get_parent()})
					
					# 1b. Broadcast Events
					_trigger_effect_events(spec)
					
					# 1c. Re-evaluate and apply math
					_evaluate_spec(spec)
					_commit_spec_math(spec)
			
			# 2. Decrement the turn counter
			spec.remaining_turns -= 1
			
			# 3. Check for expiration
			if spec.remaining_turns <= 0:
				remove_active_effect(active_effect)


## Safely halts all abilities, removes all active effects, and clears internal state.
## Call this immediately before queue_free()'ing the owning Entity to prevent memory leaks and orphaned cues.
func cleanup() -> void:
	# 1. Forcefully abort all granted abilities
	for ability in _active_abilities:
		if ability.is_active:
			ability.abort_ability()
			
	# 2. Reverse math and drop tags, but SKIP the expensive array erasure
	for i in range(_active_effects.size() - 1, -1, -1):
		remove_active_effect(_active_effects[i], true)
		
	# 3. Clear all tracking arrays atomically in O(1) time
	_active_inputs.clear()
	_active_abilities.clear()
	_active_tags.clear()
	_active_effects.clear()
#endregion


#region General Networking
## Server executes inputs sent from the network Client.
@rpc("any_peer", "call_remote", "reliable")
func _server_receive_input_pressed(input_id: int) -> void:
	if is_multiplayer_authority():
		_ability_local_input_pressed(input_id)


## Server executes inputs sent from the network Client.
@rpc("any_peer", "call_remote", "reliable")
func _server_receive_input_released(input_id: int) -> void:
	if is_multiplayer_authority():
		_ability_local_input_released(input_id)


## Clients execute cues broadcasted by the Server.
@rpc("authority", "call_remote", "reliable")
func _client_execute_cue(tag: StringName, payload: Dictionary = {}) -> void:
	_execute_local_cue(tag, payload)
#endregion


#region Cues
## Triggers a visual/audio cue by forwarding the request to the global manager.
## Intercepts and blasts the request to clients if running on the Server.
func execute_cue(tag: StringName, payload: Dictionary = {}) -> void:
	if is_networked and multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		rpc("_client_execute_cue", tag, payload)
		
	_execute_local_cue(tag, payload)


## Physically executes the cue locally.
func _execute_local_cue(tag: StringName, payload: Dictionary = {}) -> void:
	# We pass get_parent() as the target. 
	# This ensures the visual cue attaches to the Character/Enemy, not the ASC node itself.
	GameplayCueManager.execute_cue(tag, get_parent(), payload)
#endregion


#region Ability Management
## Grants an ability to this ASC.
func grant_ability(ability_node: GameplayAbility) -> void:
	if not ability_node.is_inside_tree():
		add_child(ability_node)
	
	ability_node.owner_asc = self
	_add_active_ability(ability_node)
	ability_granted.emit(ability_node)


## Grants an ability directly from a GDScript resource (Code-First approach).
## Instantiates the node, attaches it to the ASC, and returns the reference for dynamic configuration.
func grant_ability_from_script(ability_script: Script) -> GameplayAbility:
	if not ability_script:
		push_error("GodotGAS: Cannot grant ability. Provided script is null.")
		return null
		
	var ability_instance = ability_script.new()
	
	if not ability_instance is GameplayAbility:
		push_error("GodotGAS: Script must extend GameplayAbility to be granted.")
		ability_instance.free()
		return null
		
	# Funnel it through our standard grant logic (which handles tree insertion and tracking)
	grant_ability(ability_instance)
	ability_granted.emit(ability_instance)
	
	return ability_instance


## Removes an ability from this ASC.
func remove_ability(ability: GameplayAbility) -> void:
	_remove_active_ability(ability)
	ability_removed.emit(ability)
	ability.queue_free()


## The Gatekeeper: ASC checks if the ability is allowed to run.
func can_activate_ability(ability: GameplayAbility, emit_failure: bool = false) -> bool:
	if ability == null:
		if emit_failure:
			ability_activation_failed.emit(ability, ActivationError.INTERNAL_ERROR, {"message": "Null Ability"})
		return false
	
	if ability.is_active:
		if emit_failure:
			ability_activation_failed.emit(ability, ActivationError.ALREADY_ACTIVE, {})
		return false
		
	# 1. Check Tag Relationship Blocking (Is another active ability blocking this one?)
	for active_ability in _active_abilities:
		if active_ability.is_active and active_ability != ability:
			for blocked_tag in active_ability.block_abilities_with_tags:
				# Support hierarchical blocking (e.g. blocking "Ability.Action" also blocks "Ability.Action.Melee")
				if ability.ability_tag == blocked_tag or String(ability.ability_tag).begins_with(String(blocked_tag) + "."):
					if emit_failure:
						ability_activation_failed.emit(ability, ActivationError.BLOCKED_BY_OTHER_ABILITY, {"blocking_ability": active_ability})
					return false
	
	# 2. Check Activation Query
	if ability.activation_query and not ability.activation_query.matches(self):
		if emit_failure: 
			ability_activation_failed.emit(ability, ActivationError.FAILED_QUERY, {"query": ability.activation_query})
		return false
	
	# 3. Check Cooldowns (Personal + Shared)
	if ability.has_method("get_cooldown_tags"):
		var cooldown_tags = ability.get_cooldown_tags()
		if has_any_tags(cooldown_tags):
			if emit_failure: 
				ability_activation_failed.emit(ability, ActivationError.ON_COOLDOWN, {"tags": cooldown_tags})
			return false
	
	# 4. Check Resource Costs, Fully supports ExecCalcs predicting math
	if ability.cost_effect and not can_afford_cost(ability.cost_effect, ability.ability_level):
		if emit_failure: 
			ability_activation_failed.emit(ability, ActivationError.INSUFFICIENT_RESOURCES, {"effect": ability.cost_effect})
		return false
		
	return true


## Tracks an active ability (e.g., for canceling channeled spells).
func _add_active_ability(ability: GameplayAbility) -> void:
	if not _active_abilities.has(ability):
		_active_abilities.append(ability)


## Cleans up an ability reference.
func _remove_active_ability(ability: GameplayAbility) -> void:
	_active_abilities.erase(ability)


## Checks if the entity has enough resources to pay for a GameplayEffect cost.
func can_afford_cost(effect: GameplayEffect, effect_level: float = 1.0) -> bool:
	if not effect:
		return true
		
	# 1. Generate a mock spec to hold the context for our calculations
	var context = GameplayEffectContext.new(get_parent())
	var spec = GameplayEffectSpec.new(effect, context, effect_level)
	
	# 2. Evaluate the Spec (This runs the ExecCalcs to mutate magnitudes safely!)
	_evaluate_spec(spec)
	
	# 3. Verify the predicted math against our actual attributes
	for attr_name in spec.calculated_deltas:
		var attr_data = get_attribute(attr_name)
		var current_val = attr_data.current_value if attr_data else 0.0
		
		# If any resource drops below 0 after dynamic math, we cannot afford it!
		if current_val + spec.calculated_deltas[attr_name] < 0.0:
			return false
			
	return true


## Cancels any currently running abilities that possess the given tags, 
## or are blocked by the given tags.
func cancel_abilities_with_tags(tags: Array[StringName]) -> void:
	for ability in _active_abilities:
		if not ability.is_active:
			continue
			
		for tag in tags:
			# Support hierarchical cancellation 
			if ability.ability_tag == tag or String(ability.ability_tag).begins_with(String(tag) + "."):
				ability.abort_ability()
				break 
				
			if ability.activation_query:
				if tag in ability.activation_query.ignore_tags or tag in ability.activation_query.ignore_exact_tags:
					ability.abort_ability()
					break 


## Attempts to activate all granted abilities that match the given tag.
## Returns true if at least one ability successfully activated (concurrently).
func try_activate_abilities_by_tag(tag: StringName, event_payload: Variant = null) -> bool:
	var activated_any: bool = false
	
	for ability in _active_abilities:
		if ability.ability_tag == tag:
			# Check the gatekeeper manually so we get an instant true/false
			if can_activate_ability(ability):
				# Fire and forget! Do not await, let it run concurrently in the background.
				ability.try_activate(event_payload)
				activated_any = true
				
	return activated_any
#endregion


#region Attributes
## Retrieves an AttributeData resource by its string name.
func get_attribute(attribute_name: String) -> AttributeData:
	for set in attribute_sets:
		if attribute_name in set: 
			var found_attr = set.get(attribute_name)
			if found_attr is AttributeData:
				return found_attr
				
	return null


## Helper function to determine if a AttributeData resource exists.
func has_attribute(attribute_name: String) -> bool:
	for set in attribute_sets:
		if attribute_name in set:
			if set.get(attribute_name) is AttributeData:
				return true
	return false


## A helper to safely modify the current value of an attribute (Should not be used outside of this class).
func _apply_attribute_change(attribute_name: String, amount: float, spec: GameplayEffectSpec = null) -> float:
	for set in attribute_sets:
		if attribute_name in set: 
			var attr = set.get(attribute_name)
			if attr is AttributeData:
				var old_value = attr.current_value 
				var proposed_value = old_value + amount
				
				var final_value = set.pre_attribute_change(attribute_name, proposed_value)
				var actual_delta = final_value - old_value
				
				if final_value != old_value:
					attr.current_value = final_value
					attribute_changed.emit(attribute_name, old_value, final_value, spec)
					
					set.post_attribute_change(self, attribute_name, old_value, final_value)
					
				return actual_delta
				
	push_warning("GodotGAS: Attempted to modify '%s', but the ASC does not possess that attribute." % attribute_name)
	return 0.0


## Takes a strongly-typed dictionary of {"attribute_name": override_value} and dynamically
## generates an Initialization Effect to safely apply them through the GAS pipeline.
func initialize_attribute_overrides(overrides: Dictionary[String, float]) -> void:
	if overrides.is_empty():
		return
		
	# Dynamically generate an Instant Effect
	var init_effect: GameplayEffect = GameplayEffect.new()
	init_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	
	# Build the OVERRIDE modifiers based on the user's dictionary
	for attr_name: String in overrides.keys():
		var modifier: GameplayEffectModifier = GameplayEffectModifier.new()
		modifier.attribute_name = attr_name
		modifier.operation = GameplayEffectModifier.Operation.OVERRIDE
		modifier.magnitude = overrides[attr_name]
		init_effect.modifiers.append(modifier)
		
	# Create Context and Spec (Passing the instigator directly into the constructor)
	var context: GameplayEffectContext = GameplayEffectContext.new(self.get_parent())
	var spec: GameplayEffectSpec = GameplayEffectSpec.new(init_effect, context)
	
	# Apply to self (This routes through the clamps and fires UI signals!)
	apply_effect_spec(spec)
#endregion


#region Gameplay Effects Execution
## Applies an effect to a target ASC and broadcasts the success to our local UI/Passives.
## Returns the resulting ActiveGameplayEffect on success, or null on failure.
func apply_effect_spec_to_target(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> ActiveGameplayEffect:
	if target_asc == null:
		return null
		
	# 1. We shove the payload onto the Enemy's ASC
	var resulting_effect = target_asc.apply_effect_spec(spec)
	
	# 2. If the enemy successfully received the effect (resulting_effect evaluates to true if not null)...
	if resulting_effect:
		# 3. WE (The Attacker's ASC) emit the signal to our own UI and Passives!
		effect_applied_to_target.emit(target_asc, spec)
		
	return resulting_effect


## QoL Wrapper: Automatically packages a raw GameplayEffect into a Spec for execution.
## Returns the resulting ActiveGameplayEffect on success, or null on failure.
func apply_gameplay_effect(effect: GameplayEffect, source_asc: AbilitySystemComponent = self, effect_level: float = 1.0) -> ActiveGameplayEffect:
	if not effect:
		return null
	
	# Create a basic context and spec so the developer doesn't have to do it manually every time
	var instigator = source_asc.get_parent() if source_asc else get_parent()
	var context = GameplayEffectContext.new(instigator)
	var spec = GameplayEffectSpec.new(effect, context, effect_level)
	
	return apply_effect_spec(spec)


## The main engine entry point for an Ability to apply a live effect (Spec) to this ASC.
## Intercepts and denies math calculation if executed by a network Client.
func apply_effect_spec(spec: GameplayEffectSpec) -> ActiveGameplayEffect:
	if is_networked and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return null
		
	return _apply_effect_spec(spec)


## Internal function that processes the actual mathematical application and state changes.
func _apply_effect_spec(spec: GameplayEffectSpec) -> ActiveGameplayEffect:
	if not spec or not spec.effect_def:
		return null
		
	var effect = spec.effect_def
	
	# 1 & 2. Check Application Query
	if effect.application_query and not effect.application_query.matches(self):
		return null
	
	# 3. The Cleanser Pattern (Purge targeted effects BEFORE evaluating new math)
	for purge_tag in effect.remove_effects_with_tags:
		remove_effects_with_tag(purge_tag)
	
	_evaluate_spec(spec)
	
	# 4. Handle Stacking & Refreshing
	if effect.policy != GameplayEffect.DurationPolicy.INSTANT:
		if effect.stacking_policy == GameplayEffect.StackingPolicy.REFRESH_DURATION:
			# Search to see if we already have this exact effect definition running
			for active_effect in _active_effects:
				if active_effect.spec.effect_def == effect:
					
					if effect.max_stacks > 0 and active_effect.stack_count >= effect.max_stacks:
						# OVERFLOW
						var source_asc = self
						if spec.context and spec.context.instigator:
							var instigator_asc = spec.context.instigator as AbilitySystemComponent
							if not instigator_asc:
								instigator_asc = spec.context.instigator.get_node_or_null("AbilitySystemComponent")
							if instigator_asc:
								source_asc = instigator_asc
								
						# FIX: Remove the stack BEFORE applying the overflow, so OVERRIDE evaluates against the clean base stat
						if effect.clear_stack_on_overflow:
							remove_active_effect(active_effect)
								
						for overflow_effect in effect.overflow_effects:
							if overflow_effect:
								apply_gameplay_effect(overflow_effect, source_asc, spec.level)
								
						if effect.clear_stack_on_overflow:
							return null # Bypasses refresh and application
					else:
						# Add a new stack and accumulate math!
						active_effect.stack_count += 1
						
						if spec.period <= 0.0:
							var new_deltas = _commit_spec_math(spec)
							for attr_name in new_deltas:
								active_effect.applied_deltas[attr_name] = active_effect.applied_deltas.get(attr_name, 0.0) + new_deltas[attr_name]
							
							# MATH TRAP FIX: If it is currently suppressed, immediately back out the newly added deltas!
							if active_effect.is_suppressed:
								for attr_name in new_deltas:
									_apply_attribute_change(attr_name, -new_deltas[attr_name])
					
					# We found it! Reset its clock back to full based on the dynamically altered Spec!
					if effect.policy == GameplayEffect.DurationPolicy.DURATION:
						active_effect.time_remaining = spec.duration 
					elif effect.policy == GameplayEffect.DurationPolicy.TURN_BASED:
						active_effect.spec.remaining_turns = spec.remaining_turns
					
					# REFRESH EDGE CASE: Do not fire application cues or events if suppressed!
					if not active_effect.is_suppressed:
						for cue_tag in effect.application_cue_tags:
							execute_cue(cue_tag, {"target": get_parent()})
						
						var source_asc = null
						if spec.context and spec.context.instigator:
							source_asc = spec.context.instigator as AbilitySystemComponent
							if not source_asc:
								source_asc = spec.context.instigator.get_node_or_null("AbilitySystemComponent")
							
						effect_received.emit(source_asc, spec)
						_trigger_effect_events(spec)
					
					return active_effect
	
	# 5. Create a variable to hold the newly generated effect
	var resulting_effect: ActiveGameplayEffect = null
	
	match effect.policy:
		GameplayEffect.DurationPolicy.INSTANT:
			resulting_effect = _execute_instant_spec(spec)
		GameplayEffect.DurationPolicy.DURATION, GameplayEffect.DurationPolicy.INFINITE, GameplayEffect.DurationPolicy.TURN_BASED:
			resulting_effect = _execute_active_spec(spec)
	
	# 6. Notify the Defender's UI that an effect was fully processed
	var source_asc = null
	if spec.context and spec.context.instigator:
		source_asc = spec.context.instigator as AbilitySystemComponent
		if not source_asc:
			source_asc = spec.context.instigator.get_node_or_null("AbilitySystemComponent")
		
	effect_received.emit(source_asc, spec)
	
	# 7. Wake up any passives listening for this application!
	_trigger_effect_events(spec)
	
	# 8. Return the finalized effect reference
	return resulting_effect


## Processes effects that happen immediately and permanently (like taking damage).
## Returns a temporary ActiveGameplayEffect so the framework registers a success (truthy), but it is NOT saved to memory.
func _execute_instant_spec(spec: GameplayEffectSpec) -> ActiveGameplayEffect:
	# 1. Trigger Application Cues
	for cue_tag in spec.effect_def.application_cue_tags:
		execute_cue(cue_tag, {"target": get_parent()})
		
	# 2. Create a temporary container to return
	var active_effect = ActiveGameplayEffect.new(spec)
	
	# 3. Actually apply the mathematical damage/healing!
	active_effect.applied_deltas = _commit_spec_math(spec)
	
	# We return it so the caller knows it succeeded, but we DO NOT add it to _active_effects
	return active_effect


## Processes effects that stay on the character over time.
## Returns the persistent ActiveGameplayEffect stored in memory.
func _execute_active_spec(spec: GameplayEffectSpec) -> ActiveGameplayEffect:
	# Note: Initializes using the dynamic 'spec' variable, not the static 'effect_def' variable!
	var active_effect = ActiveGameplayEffect.new(spec) 
	var effect = spec.effect_def
	
	# 1. Trigger Application Cues
	for cue_tag in effect.application_cue_tags:
		execute_cue(cue_tag, {"target": get_parent()})
	
	# 2. Grant Tags
	for tag in effect.granted_tags:
		add_tag(tag)
		
	# 3. Apply Math and record it to reverse later (ONLY if not periodic)
	if spec.period <= 0.0:
		active_effect.applied_deltas = _commit_spec_math(spec)
			
	_active_effects.append(active_effect)
	
	# Broadcast to the UI and passive listeners
	active_effect_added.emit(active_effect)
	
	# Explicitly check if it should be immediately suppressed upon application
	_reevaluate_suppression_state()
	
	# Return the persistent effect so the inventory/ability can store the reference!
	return active_effect


## Perfectly undoes an Active Effect's math and tags, and cleans it out of memory.
func remove_active_effect(active_effect: ActiveGameplayEffect, skip_array_erase: bool = false) -> void:
	# Only reverse tags and attribute deltas if the effect is not currently suppressed
	if not active_effect.is_suppressed:
		for tag in active_effect.get_effect_def().granted_tags:
			remove_tag(tag)
			
		for attr_name in active_effect.applied_deltas.keys():
			var reverse_delta = -active_effect.applied_deltas[attr_name]
			_apply_attribute_change(attr_name, reverse_delta)
			
	# Trigger Removal Cues
	for cue_tag in active_effect.get_effect_def().removal_cue_tags:
		execute_cue(cue_tag, {"target": get_parent()})
		
	if not skip_array_erase and _active_effects.has(active_effect):
		active_effect_removed.emit(active_effect)
		_active_effects.erase(active_effect)
	elif skip_array_erase:
		# Still emit the signal for UI cleanup during a bulk wipe
		active_effect_removed.emit(active_effect)


## Removes ALL active Gameplay Effects that are currently granting the specified tag.
func remove_effects_with_tag(tag: StringName) -> void:
	for i in range(_active_effects.size() - 1, -1, -1):
		var active_effect = _active_effects[i]
		if tag in active_effect.get_effect_def().granted_tags:
			remove_active_effect(active_effect)


## Removes ALL active Gameplay Effects that were applied by a specific Instigator (source node).
func remove_effects_from_source(source_node: Node) -> void:
	if not source_node:
		return
		
	# Iterate backwards since we are removing items from the array
	for i in range(_active_effects.size() - 1, -1, -1):
		var active_effect = _active_effects[i]
		
		# Safely check if the effect has a spec, a context, and an instigator that matches our query
		if active_effect.spec and active_effect.spec.context and active_effect.spec.context.instigator == source_node:
			remove_active_effect(active_effect)
#endregion


#region Effect Inhibition (Tag Suppression)
## Evaluates all active gameplay effects against their suppression queries.
## Safely handles cascading tag changes using an evaluation lock and queue flag.
func _reevaluate_suppression_state() -> void:
	if _is_evaluating_suppression:
		_suppression_queued = true
		return
		
	_is_evaluating_suppression = true
	_suppression_queued = false
	
	for active_effect in _active_effects:
		var effect = active_effect.get_effect_def()
		if effect and effect.ongoing_suppression_query:
			var should_be_suppressed = effect.ongoing_suppression_query.matches(self)
			
			if should_be_suppressed and not active_effect.is_suppressed:
				_suppress_effect(active_effect)
			elif not should_be_suppressed and active_effect.is_suppressed:
				_unsuppress_effect(active_effect)
				
	_is_evaluating_suppression = false
	
	# If any granted tags added/removed during this sweep cascaded another request, evaluate it now safely.
	if _suppression_queued:
		_reevaluate_suppression_state()


## Temporarily suspends an active effect's applied attribute deltas and granted tags.
func _suppress_effect(active_effect: ActiveGameplayEffect) -> void:
	active_effect.is_suppressed = true
	
	for attr_name in active_effect.applied_deltas.keys():
		_apply_attribute_change(attr_name, -active_effect.applied_deltas[attr_name])
		
	for tag in active_effect.get_effect_def().granted_tags:
		remove_tag(tag)


## Restores a previously suppressed active effect's attribute deltas and granted tags.
func _unsuppress_effect(active_effect: ActiveGameplayEffect) -> void:
	active_effect.is_suppressed = false
	
	for attr_name in active_effect.applied_deltas.keys():
		_apply_attribute_change(attr_name, active_effect.applied_deltas[attr_name])
		
	for tag in active_effect.get_effect_def().granted_tags:
		add_tag(tag)
#endregion


#region Math & Modifiers

## STEP 1: Evaluates all Executions and Modifiers to predict the final mathematical changes.
## This populates `spec.calculated_deltas` and allows ExecCalcs to mutate duration/magnitudes safely.
func _evaluate_spec(spec: GameplayEffectSpec) -> void:
	var projected_deltas: Dictionary = {}
	
	if not spec or not spec.effect_def:
		return
		
	var effect = spec.effect_def
	
	# 1. Process Execution Calculations (Dynamic Math & Spec Mutation)
	for execution in effect.executions:
		if execution:
			# Executions can edit spec.duration, spec.period, spec.mutated_magnitudes, OR return flat deltas
			var exec_deltas = execution.execute(spec, self)
			
			for attr_name in exec_deltas:
				projected_deltas[attr_name] = projected_deltas.get(attr_name, 0.0) + exec_deltas[attr_name]

	# 2. Process Standard Modifiers
	for mod in effect.modifiers:
		if not mod or mod.attribute_name == "":
			continue
			
		var attr_name = mod.attribute_name
		var magnitude = 0.0
		
		# Intercept the calculation type!
		match mod.magnitude_calculation:
			GameplayEffectModifier.MagnitudeCalculationType.STATIC:
				magnitude = spec.mutated_magnitudes.get(attr_name, 0.0) 
			GameplayEffectModifier.MagnitudeCalculationType.SET_BY_CALLER:
				magnitude = spec.get_set_by_caller_magnitude(mod.set_by_caller_tag)
			GameplayEffectModifier.MagnitudeCalculationType.ATTRIBUTE_BASED:
				var backing_val: float = 0.0
				
				if mod.attribute_source == GameplayEffectModifier.AttributeSource.SOURCE:
					# Grab from the Instigator (Attacker)
					if spec.context and spec.context.instigator:
						var source_asc = spec.context.instigator as AbilitySystemComponent
						if not source_asc:
							source_asc = spec.context.instigator.get_node_or_null("AbilitySystemComponent")
						if source_asc:
							var attr_data = source_asc.get_attribute(mod.backing_attribute_name)
							if attr_data:
								backing_val = attr_data.current_value
				else:
					# Grab from the Target (Defender)
					var attr_data = get_attribute(mod.backing_attribute_name)
					if attr_data:
						backing_val = attr_data.current_value
						
				magnitude = backing_val * mod.attribute_multiplier
		
		var current_val = 0.0
		var attr_data = get_attribute(attr_name)
		if attr_data:
			current_val = attr_data.current_value
			
		var delta = 0.0
		match mod.operation:
			GameplayEffectModifier.Operation.ADD:
				delta = magnitude
			GameplayEffectModifier.Operation.MULTIPLY:
				delta = (current_val * magnitude) - current_val
			GameplayEffectModifier.Operation.DIVIDE:
				if magnitude != 0:
					delta = (current_val / magnitude) - current_val
			GameplayEffectModifier.Operation.OVERRIDE:
				delta = magnitude - current_val
				
		projected_deltas[attr_name] = projected_deltas.get(attr_name, 0.0) + delta
			
	# Save the final projections directly into the spec
	spec.calculated_deltas = projected_deltas


## STEP 2: Actually applies the pre-calculated deltas to the ASC's attributes.
func _commit_spec_math(spec: GameplayEffectSpec) -> Dictionary:
	var final_clamped_deltas: Dictionary = {}
	
	if not spec or spec.calculated_deltas.is_empty():
		return final_clamped_deltas
	
	# Physically modify the stats
	for attr_name in spec.calculated_deltas:
		var actual_change = _apply_attribute_change(attr_name, spec.calculated_deltas[attr_name], spec)
		if actual_change != 0.0:
			final_clamped_deltas[attr_name] = actual_change
	
	# Update the spec to reflect the true reality of what happened (after stats clamped)
	spec.calculated_deltas = final_clamped_deltas
	return final_clamped_deltas

#endregion


#region Tag Management
## Increments the reference count of a given tag.
func add_tag(tag: StringName) -> void:
	if _active_tags.has(tag):
		_active_tags[tag] += 1
	else:
		_active_tags[tag] = 1
		tag_added.emit(tag)
	
	tag_count_changed.emit(tag, _active_tags[tag])
	_reevaluate_suppression_state()


## Decrements the reference count of a given tag, removing it if it reaches 0.
func remove_tag(tag: StringName) -> void:
	if not _active_tags.has(tag): 
		return
		
	_active_tags[tag] -= 1
	
	if _active_tags[tag] <= 0:
		_active_tags.erase(tag)
		tag_removed.emit(tag)
	else:
		tag_count_changed.emit(tag, _active_tags[tag])
		
	_reevaluate_suppression_state()


## Forcefully removes a tag regardless of its current reference count.
func clear_tag(tag: StringName) -> void:
	if _active_tags.has(tag):
		_active_tags.erase(tag)
		tag_removed.emit(tag)
		_reevaluate_suppression_state()
#endregion


#region Tag Queries
## Returns the maximum remaining duration of any active effect granting this tag.
func get_tag_duration_remaining(tag: StringName) -> float:
	var max_time: float = 0.0
	for active_effect in _active_effects:
		if tag in active_effect.get_effect_def().granted_tags:
			if active_effect.time_remaining > max_time:
				max_time = active_effect.time_remaining
	return max_time


## Checks if the ASC has the exact given tag.
func has_tag_exact(tag: StringName) -> bool:
	return _active_tags.has(tag)


## Checks if the ASC has the given tag or any of its children.
func has_tag(tag: StringName) -> bool:
	if _active_tags.has(tag):
		return true
		
	var tag_str = String(tag)
	for active_tag in _active_tags.keys():
		var active_str = String(active_tag)
		if active_str.begins_with(tag_str + "."):
			return true
			
	return false


## Returns true if the ASC has at least one of the tags in the array.
func has_any_tags(tags: Array[StringName]) -> bool:
	for t in tags:
		if has_tag(t):
			return true
	return false


## Returns true only if the ASC has every tag in the array.
func has_all_tags(tags: Array[StringName]) -> bool:
	if tags.is_empty():
		return false
	for t in tags:
		if not has_tag(t):
			return false
	return true
#endregion


#region Input Routing
## Safely binds an active ability to an input slot.
## If unbind_others is true, it kicks out any other ability using that ID.
func bind_ability_to_input(ability: GameplayAbility, new_input_id: int, unbind_others: bool = true) -> void:
	if not _active_abilities.has(ability):
		push_error("GodotGAS: Cannot bind ability to input. It has not been granted to this ASC.")
		return
		
	if unbind_others:
		for active_ability in _active_abilities:
			if active_ability.input_id == new_input_id and active_ability != ability:
				active_ability.input_id = -1 # Unbind the old ability
				
	ability.input_id = new_input_id


## Called by a Player Controller when an input is PRESSED. Routes to the matching ability.
## Forwards input to the Server if the player is a networked client.
func ability_local_input_pressed(input_id: int) -> void:
	if is_networked and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		rpc_id(1, "_server_receive_input_pressed", input_id)
		return
		
	_ability_local_input_pressed(input_id)


func _ability_local_input_pressed(input_id: int) -> void:
	if not _active_inputs.has(input_id):
		_active_inputs.append(input_id)
		
	for ability in _active_abilities:
		if ability.input_id == input_id:
			ability._input_pressed(self)


## Called by a Player Controller when an input is RELEASED. Routes to the matching ability.
## Forwards input to the Server if the player is a networked client.
func ability_local_input_released(input_id: int) -> void:
	if is_networked and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		rpc_id(1, "_server_receive_input_released", input_id)
		return
		
	_ability_local_input_released(input_id)


func _ability_local_input_released(input_id: int) -> void:
	if _active_inputs.has(input_id):
		_active_inputs.erase(input_id)
		
	for ability in _active_abilities:
		if ability.input_id == input_id:
			ability._input_released(self)
#endregion


#region Gameplay Events
## Sweeps a spec and fires all static and dynamic events.
func _trigger_effect_events(spec: GameplayEffectSpec) -> void:
	# 1. Trigger static events defined by the designer in the Inspector
	for event_tag in spec.effect_def.event_tags:
		send_gameplay_event(event_tag, spec)
		
	# 2. Trigger dynamic events injected by Execution Calculations!
	for dynamic_tag in spec.dynamic_tags:
		send_gameplay_event(dynamic_tag, spec)


## Sends a global event to this ASC. If any granted abilities are listening for this tag, 
## they will attempt to activate and receive the payload.
func send_gameplay_event(event_tag: StringName, payload: Variant = null) -> void:
	if event_tag == "":
		return
	
	# Announce event to outside world
	gameplay_event_received.emit(event_tag, payload)
	
	# Loop through granted abilities and check their triggers
	for ability in _active_abilities:
		if ability.trigger_event_tag == event_tag:
			# The ability was listening for this! Try to activate it and pass the data.
			if payload is GameplayEffectSpec:
				ability.try_activate(payload.context)
			else:
				# If `payload` is `GameplayEffectContext` or else.
				ability.try_activate(payload)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# The node is being destroyed in memory. Clean up timers, orphaned effects, and array references!
		cleanup()
#endregion


#region Debug Signal Logging Functions
func _debug_tag_added(tag: StringName) -> void:
	print_rich("[color=gray]> (DEBUG)[/color] [color=cyan]<%s>[/color] signal [color=orange][tag_added][/color] added [color=green]'%s'[/color] Tag to %s's ASC" % [self.get_parent().name, tag, self.get_parent().name])


func _debug_tag_count_changed(tag: StringName, new_count: int) -> void:
	print_rich("[color=gray]> (DEBUG)[/color] [color=cyan]<%s>[/color] signal [color=orange][tag_count_changed][/color] changed [color=green]'%s'[/color] stack count to [color=yellow]%d[/color] on %s's ASC" % [self.get_parent().name, tag, new_count, self.get_parent().name])


func _debug_tag_removed(tag: StringName) -> void:
	print_rich("[color=gray]> (DEBUG)[/color] [color=cyan]<%s>[/color] signal [color=orange][tag_removed][/color] removed [color=green]'%s'[/color] Tag from %s's ASC" % [self.get_parent().name, tag, self.get_parent().name])


func _debug_attribute_changed(attribute_name: String, old_value: float, new_value: float, effect_spec: GameplayEffectSpec) -> void:
	var effect_name = _get_debug_spec_name(effect_spec)
	print_rich("[color=gray]> (DEBUG)[/color] [color=cyan]<%s>[/color] signal [color=orange][attribute_changed][/color] changed attribute [color=green]'%s'[/color] from [color=yellow]%s[/color] to [color=yellow]%s[/color] via [color=green]'%s'[/color]" % [self.get_parent().name, attribute_name, old_value, new_value, effect_name])


func _debug_effect_applied_to_target(target_asc: AbilitySystemComponent, spec: GameplayEffectSpec) -> void:
	var effect_name = _get_debug_spec_name(spec)
	print_rich("[color=gray]> (DEBUG)[/color] [color=cyan]<%s>[/color] signal [color=orange][effect_applied_to_target][/color] %s's ASC applied [color=green]'%s'[/color] to [color=cyan]%s's[/color] ASC" % [self.get_parent().name, self.get_parent().name, effect_name, target_asc.get_parent().name])


func _debug_gameplay_event_received(event_tag: StringName, payload: Variant) -> void:
	var payload_desc = "[color=red]Null Payload[/color]"

	var instigator = null
	if payload is GameplayEffectContext:
		instigator = payload.instigator
	elif payload is GameplayEffectSpec and payload.context:
		instigator = payload.context.instigator

	if instigator:
		payload_desc = "Payload(From: [color=cyan]%s[/color])" % instigator.name
	elif payload != null:
		payload_desc = "Payload([color=purple]%s[/color])" % payload

	print_rich("[color=gray]> (DEBUG)[/color] [color=cyan]<%s>[/color] signal [color=orange][gameplay_event_received][/color] %s's ASC received [color=green]'%s'[/color] event with %s" % [self.get_parent().name, self.get_parent().name, event_tag, payload_desc])


func _debug_active_effect_added(active_effect: ActiveGameplayEffect) -> void:
	var effect_name = _get_debug_spec_name(active_effect.spec)
	var duration = active_effect.spec.duration if active_effect.spec.duration > 0.0 else "Infinite"
	print_rich("[color=gray]> (DEBUG)[/color] [color=cyan]<%s>[/color] signal [color=orange][active_effect_added][/color] added [color=green]'%s'[/color] with duration [color=yellow]%s[/color]s" % [self.get_parent().name, effect_name, duration])

func _debug_active_effect_removed(active_effect: ActiveGameplayEffect) -> void:
	var effect_name = _get_debug_spec_name(active_effect.spec)
	print_rich("[color=gray]> (DEBUG)[/color] [color=cyan]<%s>[/color] signal [color=orange][active_effect_removed][/color] removed [color=green]'%s'[/color]" % [self.get_parent().name, effect_name])


## --- Internal Debug Helper ---
func _get_debug_spec_name(spec: GameplayEffectSpec) -> String:
	if spec == null or spec.effect_def == null:
		return "[color=red]Manual/Unknown Effect[/color]"
		
	if spec.effect_def.resource_name != "":
		return spec.effect_def.resource_name
		
	if spec.effect_def.resource_path != "":
		return spec.effect_def.resource_path.get_file().get_basename()
		
	return "[color=gray]Unnamed Effect Resource[/color]"
#endregion
