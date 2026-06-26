## The central brain of the GodotGAS framework.
##
## Manages tags, attributes, and abilities for a specific entity.
##
## @meta_addon: GodotGAS 1.0
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

@export var attribute_sets: Array[AttributeSet] = []

@export var debug_signal_log: bool = false

## Array of integer IDs representing currently held inputs.
var _active_inputs: Array[int] = []

## Array of actively granted and managed abilities.
var _active_abilities: Array[GameplayAbility] = []

## Dictionary tracking all currently active tags and their reference counts.
var _active_tags: Dictionary = {}

## Array tracking all active gameplay effects currently applied to this component.
var _active_effects: Array[ActiveGameplayEffect] = []

## Defines the exact reason an ability failed to activate.
enum ActivationError {
	ALREADY_ACTIVE,
	ON_COOLDOWN,
	BLOCKED_TAG,
	MISSING_TAG,
	INSUFFICIENT_RESOURCES,
	INTERNAL_ERROR
}


#region Core Virtuals
func _ready() -> void:
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
		var effect_data = active_effect.get_effect_def()
		
		# Handle Periodic Ticks
		if effect_data.period > 0.0:
			active_effect.time_until_next_tick -= delta
			if active_effect.time_until_next_tick <= 0.0:
				
				# 1. Trigger Periodic Cues
				for cue_tag in effect_data.periodic_cue_tags:
					execute_cue(cue_tag, {"target": get_parent()})
				
				# 2. Broadcast Periodic Events (Wakes up passives!)
				_trigger_effect_events(active_effect.spec)
					
				# 3. Apply the math natively
				_apply_modifiers(active_effect.spec) 
				
				# Reset the clock for the next tick
				active_effect.time_until_next_tick += effect_data.period
		
		# Handle Expiration
		if effect_data.policy == GameplayEffect.DurationPolicy.DURATION:
			active_effect.time_remaining -= delta
			
			if active_effect.time_remaining <= 0.0:
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


#region Cues
## Triggers a visual/audio cue by forwarding the request to the global manager.
func execute_cue(tag: StringName, payload: Dictionary = {}) -> void:
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


## Removes an ability from this ASC.
func remove_ability(ability: GameplayAbility) -> void:
	_remove_active_ability(ability)
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
	
	# 1. Check Blocked Tags (e.g., Status.Stunned)
	if has_any_tags(ability.activation_blocked_tags):
		if emit_failure: 
			ability_activation_failed.emit(ability, ActivationError.BLOCKED_TAG, {"tags": ability.activation_blocked_tags})
		return false
	
	# 2. Check Cooldowns (Personal + Shared)
	if ability.has_method("get_cooldown_tags"):
		var cooldown_tags = ability.get_cooldown_tags()
		if has_any_tags(cooldown_tags):
			if emit_failure: 
				ability_activation_failed.emit(ability, ActivationError.ON_COOLDOWN, {"tags": cooldown_tags})
			return false
	
	# 3. Check Required Tags (e.g., Stance.Stealth)
	if not ability.activation_required_tags.is_empty() and not has_all_tags(ability.activation_required_tags):
		if emit_failure: 
			ability_activation_failed.emit(ability, ActivationError.MISSING_TAG, {"tags": ability.activation_required_tags})
		return false
	
	# 4. Check Resource Costs
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
	if not effect.modifiers: 
		return true 
	
	for modifier in effect.modifiers:
		var attr = get_attribute(modifier.attribute_name)
		if not attr:
			return false
			
		var current_val = attr.current_value
		var magnitude = modifier.calculate_magnitude(effect_level)
		var projected_val = current_val
		
		match modifier.operation:
			GameplayEffectModifier.Operation.ADD:
				projected_val += magnitude
			GameplayEffectModifier.Operation.MULTIPLY:
				projected_val *= magnitude
			GameplayEffectModifier.Operation.DIVIDE:
				if magnitude != 0:
					projected_val /= magnitude
			GameplayEffectModifier.Operation.OVERRIDE:
				projected_val = magnitude
				
		# If the proposed cost drops the resource below zero, we cannot afford it.
		if projected_val < 0.0:
			return false
					
	return true


## Cancels any currently running abilities that possess the given tags, 
## or are blocked by the given tags.
func cancel_abilities_with_tags(tags: Array[StringName]) -> void:
	for ability in _active_abilities:
		if not ability.is_active:
			continue
			
		for tag in tags:
			if ability.ability_tag == tag or tag in ability.activation_blocked_tags:
				ability.abort_ability()
				break 
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
func has_attribute(attribtue_name: String) -> bool:
	for set in attribute_sets:
		if attribtue_name in set:
			if set.get(attribtue_name) is AttributeData:
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
					
				return actual_delta
				
	push_warning("GodotGAS: Attempted to modify '%s', but the ASC does not possess that attribute." % attribute_name)
	return 0.0
#endregion


#region Gameplay Effects Execution
## Applies an effect to a target ASC and broadcasts the success to our local UI/Passives.
func apply_effect_spec_to_target(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> bool:
	if target_asc == null:
		return false
		
	# 1. We shove the payload onto the Enemy's ASC
	var success = target_asc.apply_effect_spec(spec)
	
	# 2. If the enemy successfully received the effect...
	if success:
		# 3. WE (The Attacker's ASC) emit the signal to our own UI and Passives!
		effect_applied_to_target.emit(target_asc, spec)
		
	return success


## QoL Wrapper: Automatically packages a raw GameplayEffect into a Spec for execution.
func apply_gameplay_effect(effect: GameplayEffect, source_asc: AbilitySystemComponent = self, effect_level: float = 1.0) -> bool:
	if not effect:
		return false
	
	# Create a basic context and spec so the developer doesn't have to do it manually every time
	var instigator = source_asc.get_parent() if source_asc else get_parent()
	var context = GameplayEffectContext.new(instigator)
	var spec = GameplayEffectSpec.new(effect, context, effect_level)
	
	return apply_effect_spec(spec)


## The main engine entry point for an Ability to apply a live effect (Spec) to this ASC.
func apply_effect_spec(spec: GameplayEffectSpec) -> bool:
	if not spec or not spec.effect_def:
		return false
		
	var effect = spec.effect_def
	
	# 1. Check for Immunities (Ignored Tags)
	for tag in effect.application_ignore_tags:
		if has_tag(tag):
			return false
	
	# 2. Check for Conditions (Required Tags)
	for tag in effect.application_required_tags:
		if not has_tag(tag):
			return false
	
	# 3. Handle Stacking & Refreshing
	if effect.policy == GameplayEffect.DurationPolicy.DURATION:
		if effect.stacking_policy == GameplayEffect.StackingPolicy.REFRESH_DURATION:
			# Search to see if we already have this exact effect definition running
			for active_effect in _active_effects:
				if active_effect.spec.effect_def == effect:
					# We found it! Reset its clock back to full.
					active_effect.time_remaining = effect.duration
					
					# Re-trigger application cues so the player knows it refreshed!
					for cue_tag in effect.application_cue_tags:
						execute_cue(cue_tag, {"target": get_parent()})
					
					# Determine the source for the UI signals
					var source_asc = null
					if spec.context and spec.context.instigator:
						source_asc = spec.context.instigator.get_node_or_null("AbilitySystemComponent")
						
					# Notify the Defender's UI that it was "received" again
					effect_received.emit(source_asc, spec)
					
					# Wake up any passives for the refresh!
					_trigger_effect_events(spec)
					
					# EXIT EARLY: We refreshed the old one, do not add the new one!
					return true
	
	match effect.policy:
		GameplayEffect.DurationPolicy.INSTANT:
			_execute_instant_spec(spec)
		GameplayEffect.DurationPolicy.DURATION, GameplayEffect.DurationPolicy.INFINITE:
			_execute_active_spec(spec)
	
	# 1. Notify the Defender's UI that an effect was fully processed
	var source_asc = null
	if spec.context and spec.context.instigator:
		source_asc = spec.context.instigator.get_node_or_null("AbilitySystemComponent") # Adjust based on your node path
		
	effect_received.emit(source_asc, spec)
	
	# Wake up any passives listening for this application!
	_trigger_effect_events(spec)
	
	return true


## Processes effects that happen immediately and permanently (like taking damage).
func _execute_instant_spec(spec: GameplayEffectSpec) -> void:
	# 1. Trigger Application Cues
	for cue_tag in spec.effect_def.application_cue_tags:
		execute_cue(cue_tag, {"target": get_parent()})
		
	# 2. Apply Math
	_apply_modifiers(spec)


## Processes effects that stay on the character over time.
func _execute_active_spec(spec: GameplayEffectSpec) -> void:
	var active_effect = ActiveGameplayEffect.new(spec)
	var effect = spec.effect_def
	
	# 1. Trigger Application Cues
	for cue_tag in effect.application_cue_tags:
		execute_cue(cue_tag, {"target": get_parent()})
	
	# 2. Grant Tags
	for tag in effect.granted_tags:
		add_tag(tag)
		
	# 3. Apply Math and record it to reverse later (ONLY if not periodic)
	if effect.period <= 0.0:
		active_effect.applied_deltas = _apply_modifiers(spec)
			
	_active_effects.append(active_effect)
	
	# Broadcast to the UI and passive listeners
	active_effect_added.emit(active_effect)


## Perfectly undoes an Active Effect's math and tags, and cleans it out of memory.
func remove_active_effect(active_effect: ActiveGameplayEffect, skip_array_erase: bool = false) -> void:
	for tag in active_effect.get_effect_def().granted_tags:
		remove_tag(tag)
		
	for attr_name in active_effect.applied_deltas.keys():
		var reverse_delta = -active_effect.applied_deltas[attr_name]
		_apply_attribute_change(attr_name, reverse_delta)
		
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
#endregion


#region Math & Modifiers
## Applies modifiers and Execution Calculations from a spec, returning a dictionary 
## of the actual flat deltas applied. This handles pure math. No cues, no tags.
func _apply_modifiers(spec: GameplayEffectSpec) -> Dictionary:
	var applied_deltas: Dictionary = {}
	
	if not spec or not spec.effect_def:
		return applied_deltas
		
	var effect = spec.effect_def
	
	# 1. Process Execution Calculations (Dynamic Math)
	for execution in effect.executions:
		if execution:
			# Pass the spec (which holds the caster context) and this ASC (the target)
			var exec_deltas = execution.execute(spec, self)
			
			# Merge the resulting calculated deltas
			for attr_name in exec_deltas:
				if applied_deltas.has(attr_name):
					applied_deltas[attr_name] += exec_deltas[attr_name]
				else:
					applied_deltas[attr_name] = exec_deltas[attr_name]

	# 2. Process Standard Modifiers (Static/Curve Math)
	for mod in effect.modifiers:
		if not mod or mod.attribute_name == "":
			continue
			
		var attr_name = mod.attribute_name
		var magnitude = mod.calculate_magnitude(spec.level)
		
		var current_val = 0.0
		var attr_data = get_attribute(attr_name)
		if attr_data:
			current_val = attr_data.current_value
			
		var delta = 0.0
		
		# Convert operations into a flat delta so it can be merged safely
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
				
		if applied_deltas.has(attr_name):
			applied_deltas[attr_name] += delta
		else:
			applied_deltas[attr_name] = delta
			
	# 3. Apply Final Aggregated Deltas
	var final_clamped_deltas: Dictionary = {}
	
	for attr_name in applied_deltas:
		var actual_change = _apply_attribute_change(attr_name, applied_deltas[attr_name], spec)
		if actual_change != 0.0:
			final_clamped_deltas[attr_name] = actual_change
	
	# NEW: Save the final results directly into the spec before returning!
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


## Forcefully removes a tag regardless of its current reference count.
func clear_tag(tag: StringName) -> void:
	if _active_tags.has(tag):
		_active_tags.erase(tag)
		tag_removed.emit(tag)
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
func ability_local_input_pressed(input_id: int) -> void:
	if not _active_inputs.has(input_id):
		_active_inputs.append(input_id)
		
	for ability in _active_abilities:
		if ability.input_id == input_id:
			ability._input_pressed(self)


## Called by a Player Controller when an input is RELEASED. Routes to the matching ability.
func ability_local_input_released(input_id: int) -> void:
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
			if payload is GameplayEffectContext:
				ability.try_activate(payload)
			elif payload is GameplayEffectSpec:
				ability.try_activate(payload.context)
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


func _debug_gameplay_event_received(event_tag: StringName, payload: GameplayEffectContext) -> void:
	var payload_desc = "[color=red]Null Payload[/color]"
	if payload and payload.instigator:
		payload_desc = "Payload(From: [color=cyan]%s[/color])" % payload.instigator.name
		
	print_rich("[color=gray]> (DEBUG)[/color] [color=cyan]<%s>[/color] signal [color=orange][gameplay_event_received][/color] %s's ASC received [color=green]'%s'[/color] event with %s" % [self.get_parent().name, self.get_parent().name, event_tag, payload_desc])


func _debug_active_effect_added(active_effect: ActiveGameplayEffect) -> void:
	var effect_name = _get_debug_spec_name(active_effect.spec)
	var duration = active_effect.get_effect_def().duration if active_effect.get_effect_def().duration > 0.0 else "Infinite"
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
