## Final integration test suite for the GodotGAS Framework.
##
## Simulates a real-world combat loop consisting of 20 continuous scenarios 
## to verify that all subsystems (Tags, Attributes, Effects, Abilities, Cues) 
## interact flawlessly without degradation.
##
## @meta_addon: GodotGAS Version 1.1.0+
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name TestFullSystem extends GASTestBase

# ---------------------------------------------------------
# Mock Classes for Testing Environment
# ---------------------------------------------------------
class IntegrationAttributeSet extends AttributeSet:
	@export var health: AttributeData = AttributeData.new(100.0)
	@export var max_health: AttributeData = AttributeData.new(100.0)
	@export var mana: AttributeData = AttributeData.new(50.0)
	@export var attack_power: AttributeData = AttributeData.new(20.0)
	@export var run_speed: AttributeData = AttributeData.new(100.0)

	func pre_attribute_change(attribute_name: String, proposed_value: float) -> float:
		match attribute_name:
			"health": return clampf(proposed_value, 0.0, max_health.current_value)
			"mana": return maxf(0.0, proposed_value)
			_: return proposed_value

	func post_attribute_change(asc: Node, attribute_name: String, _old_value: float, new_value: float) -> void:
		if attribute_name == "max_health" and health.current_value > new_value:
			var asc_ref := asc as AbilitySystemComponent
			if asc_ref:
				asc_ref._apply_attribute_change("health", new_value - health.current_value)


class IntegrationASC extends AbilitySystemComponent:
	var last_error: int = -1
	func _ready() -> void:
		super._ready()
		ability_activation_failed.connect(_on_fail)
	func _on_fail(_a, reason, _p):
		last_error = reason


class MockInstantAbility extends GameplayAbility:
	func _activate_ability() -> bool:
		commit_ability()
		return true


class MagicMissileAbility extends GameplayAbility:
	var hit_targets: int = 0
	func _activate_ability() -> bool:
		commit_ability()
		
		# Build Dynamic Damage Effect
		var dmg_mod := GameplayEffectModifier.new()
		dmg_mod.attribute_name = "health"
		dmg_mod.operation = GameplayEffectModifier.Operation.ADD
		dmg_mod.magnitude_calculation = GameplayEffectModifier.MagnitudeCalculationType.SET_BY_CALLER
		dmg_mod.set_by_caller_tag = &"Data.Damage"
		
		var dmg_effect := GameplayEffect.new()
		dmg_effect.policy = GameplayEffect.DurationPolicy.INSTANT
		dmg_effect.modifiers.append(dmg_mod)
		
		# Target payload logic
		if current_event_payload is GameplayEffectContext:
			var ctx := current_event_payload as GameplayEffectContext
			var spec := GameplayEffectSpec.new(dmg_effect, ctx, 1.0)
			spec.set_set_by_caller_magnitude(&"Data.Damage", -25.0) # Inject 25 damage
			
			hit_targets = ctx.get_target_nodes().size()
			for target in ctx.get_target_nodes():
				var asc = target.get_node_or_null("IntegrationASC")
				if asc: owner_asc.apply_effect_spec_to_target(spec, asc)
				
		return true


class ChanneledSprintAbility extends GameplayAbility:
	func _activate_ability() -> bool:
		commit_ability()
		await task_wait_delay(1.0)
		return true


class AsyncCounterAbility extends GameplayAbility:
	var triggered: bool = false
	func _activate_ability() -> bool:
		commit_ability()
		await task_wait_for_event(&"Event.Combat.Hit")
		triggered = true
		return true


# ---------------------------------------------------------
# Test Suite
# ---------------------------------------------------------
var _async_tracker: Dictionary = {}

func _ready() -> void:
	if get_parent() == get_tree().root:
		await run_all_tests()


func run_all_tests() -> void:
	print_header("GodotGAS Subsystem Test: Full System Integration (20 Scenarios)")
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Setup Entities
	var attacker := Node.new()
	var att_asc := IntegrationASC.new()
	att_asc.name = "IntegrationASC"
	att_asc.attribute_sets.append(IntegrationAttributeSet.new())
	attacker.add_child(att_asc)
	add_child(attacker)
	
	var defender := Node.new()
	var def_asc := IntegrationASC.new()
	def_asc.name = "IntegrationASC"
	def_asc.attribute_sets.append(IntegrationAttributeSet.new())
	defender.add_child(def_asc)
	add_child(defender)

	await _combat_integration_phase(att_asc, attacker, def_asc, defender)
	
	print_summary()
	attacker.queue_free()
	defender.queue_free()


func _combat_integration_phase(att_asc: IntegrationASC, attacker: Node, def_asc: IntegrationASC, defender: Node) -> void:
	# ========================================================
	# Scenarios 1-5: Gatekeeping & Basic Combat
	# ========================================================
	var missile := MagicMissileAbility.new()
	missile.ability_tag = &"Action.Magic.Missile"
	
	var cost_mod := GameplayEffectModifier.new()
	cost_mod.attribute_name = "mana"
	cost_mod.operation = GameplayEffectModifier.Operation.ADD
	cost_mod.magnitude = -20.0
	var cost_ef := GameplayEffect.new()
	cost_ef.policy = GameplayEffect.DurationPolicy.INSTANT
	cost_ef.modifiers.append(cost_mod)
	missile.cost_effect = cost_ef
	
	var cd_ef := GameplayEffect.new()
	cd_ef.policy = GameplayEffect.DurationPolicy.DURATION
	cd_ef.duration = 0.5
	cd_ef.granted_tags.append(&"State.Cooldown.Missile")
	missile.cooldown_effect = cd_ef
	
	att_asc.grant_ability(missile)
	
	# Scenario 1, 2, 3: Cast, Cost, Cooldown
	var context := GameplayEffectContext.new(attacker)
	context.target_data.append_node(defender)
	var cast_1 = await missile.try_activate(context)
	
	assert_true(cast_1, "01. Ability Gatekeeper permits valid activation")
	assert_eq(att_asc.get_attribute("mana").current_value, 30.0, "02. Resource cost cleanly deducted (50 -> 30)")
	assert_true(att_asc.has_tag(&"State.Cooldown.Missile"), "03. Cooldown effect applied and tag granted")
	
	# Scenario 4: Cooldown Block
	att_asc.last_error = -1
	var cast_2 = await missile.try_activate(context)
	assert_false(cast_2, "04. Gatekeeper successfully blocks casting while on cooldown")
	
	# Scenario 5: Resource Block
	att_asc.remove_effects_with_tag(&"State.Cooldown.Missile")
	att_asc.get_attribute("mana").base_value = 10.0
	var cast_3 = await missile.try_activate(context)
	assert_false(cast_3, "05. Gatekeeper successfully blocks due to insufficient resources")


	# ========================================================
	# Scenarios 6-10: Stacking, Overflow & Cleansing
	# ========================================================
	# Scenario 6: SetByCaller Damage applied from Scenario 1
	assert_eq(def_asc.get_attribute("health").current_value, 75.0, "06. SetByCaller injected exactly 25 damage into target")
	
	var freeze_mod := GameplayEffectModifier.new()
	freeze_mod.attribute_name = "run_speed"
	freeze_mod.operation = GameplayEffectModifier.Operation.OVERRIDE
	freeze_mod.magnitude = 0.0
	var freeze_ef := GameplayEffect.new()
	freeze_ef.policy = GameplayEffect.DurationPolicy.INFINITE
	freeze_ef.modifiers.append(freeze_mod)
	freeze_ef.granted_tags.append(&"Status.Frozen")
	
	var chill_mod := GameplayEffectModifier.new()
	chill_mod.attribute_name = "run_speed"
	chill_mod.operation = GameplayEffectModifier.Operation.ADD
	chill_mod.magnitude = -25.0
	var chill_ef := GameplayEffect.new()
	chill_ef.policy = GameplayEffect.DurationPolicy.INFINITE
	chill_ef.stacking_policy = GameplayEffect.StackingPolicy.REFRESH_DURATION
	chill_ef.max_stacks = 2
	chill_ef.clear_stack_on_overflow = true
	chill_ef.modifiers.append(chill_mod)
	chill_ef.overflow_effects.append(freeze_ef)
	chill_ef.granted_tags.append(&"Status.Chilled")
	
	# Scenario 7: Stacking
	def_asc.apply_gameplay_effect(chill_ef, att_asc, 1.0)
	def_asc.apply_gameplay_effect(chill_ef, att_asc, 1.0)
	assert_eq(def_asc.get_attribute("run_speed").current_value, 50.0, "07. Stacking policy successfully accumulated math (100 -> 50)")
	
	# Scenario 8 & 9: Overflow and Purge
	def_asc.apply_gameplay_effect(chill_ef, att_asc, 1.0) # Trip limit
	assert_true(def_asc.has_tag(&"Status.Frozen"), "08. Stack limit breached; Overflow payload successfully applied")
	assert_false(def_asc.has_tag(&"Status.Chilled"), "09. clear_stack_on_overflow successfully purged original effect")
	
	# Scenario 10: Cleansing
	var fire_ef := GameplayEffect.new()
	fire_ef.policy = GameplayEffect.DurationPolicy.INSTANT
	fire_ef.remove_effects_with_tags.append(&"Status.Frozen")
	def_asc.apply_gameplay_effect(fire_ef, att_asc, 1.0)
	assert_eq(def_asc.get_attribute("run_speed").current_value, 100.0, "10. Cleanser successfully purged Status.Frozen and reversed math")


	# ========================================================
	# Scenarios 11-15: Inhibition & Interruption Matrices
	# ========================================================
	var sprint := ChanneledSprintAbility.new()
	sprint.ability_tag = &"Movement.Sprint"
	sprint.block_abilities_with_tags.append(&"Action")
	att_asc.grant_ability(sprint)
	
	_fire_async_task(sprint, "sprint")
	await get_tree().process_frame # Let channel begin
	
	# Scenario 11: Hierarchical Blocking
	att_asc.get_attribute("mana").base_value = 100.0
	att_asc.remove_effects_with_tag(&"State.Cooldown.Missile")
	var cast_blocked = await missile.try_activate()
	assert_false(cast_blocked, "11. Hierarchical blocking matrix successfully denied cast")
	
	# Scenario 12: Hierarchical Cancellation
	var stun_ab := MockInstantAbility.new()
	# FIX: Bypasses the "Action" block applied by sprint so the stun can actually cast and interrupt
	stun_ab.ability_tag = &"Spell.CC.Stun" 
	stun_ab.cancel_abilities_with_tags.append(&"Movement")
	att_asc.grant_ability(stun_ab)
	
	await stun_ab.try_activate()
	assert_false(sprint.is_active, "12. Hierarchical cancellation matrix successfully aborted channeled state")

	# Scenario 13 & 14: Inhibition
	var aura_query := GameplayTagQuery.new()
	aura_query.require_exact_tags.append(&"State.Silenced")
	
	var ap_mod := GameplayEffectModifier.new()
	ap_mod.attribute_name = "attack_power"
	ap_mod.operation = GameplayEffectModifier.Operation.ADD
	ap_mod.magnitude = 30.0
	var aura_ef := GameplayEffect.new()
	aura_ef.policy = GameplayEffect.DurationPolicy.INFINITE
	aura_ef.modifiers.append(ap_mod)
	aura_ef.ongoing_suppression_query = aura_query
	
	att_asc.apply_gameplay_effect(aura_ef, att_asc, 1.0)
	att_asc.add_tag(&"State.Silenced")
	assert_eq(att_asc.get_attribute("attack_power").current_value, 20.0, "13. Ongoing Inhibition safely suspended active math")
	
	att_asc.remove_tag(&"State.Silenced")
	assert_eq(att_asc.get_attribute("attack_power").current_value, 50.0, "14. Removing suppression safely restored active math")
	
	# Scenario 15: Moving Goalposts
	def_asc._apply_attribute_change("max_health", -50.0)
	assert_eq(def_asc.get_attribute("health").current_value, 50.0, "15. Lowering maximum boundary actively clamped current attribute")


	# ========================================================
	# Scenarios 16-20: TargetData, Async & Cleanup
	# ========================================================
	# Scenario 16: TargetData execution
	var multi_context := GameplayEffectContext.new(attacker)
	multi_context.target_data.append_node(defender)
	multi_context.target_data.append_node(attacker) # Hit self too
	
	att_asc.get_attribute("mana").base_value = 100.0
	await missile.try_activate(multi_context)
	assert_eq(missile.hit_targets, 2, "16. TargetData correctly captured and routed to multiple entities")
	
	# Scenario 17: Instancing Overlaps
	var async_counter := AsyncCounterAbility.new()
	async_counter.ability_tag = &"Ability.Counter"
	async_counter.instancing_policy = GameplayAbility.InstancingPolicy.INSTANCED_PER_EXECUTION
	att_asc.grant_ability(async_counter)
	
	_fire_async_task(async_counter, "counter_1")
	_fire_async_task(async_counter, "counter_2")
	await get_tree().process_frame 
	
	var clones = 0
	for child in att_asc.get_children():
		if child is GameplayAbility and child.ability_tag == &"Ability.Counter" and child != async_counter:
			clones += 1
	assert_eq(clones, 2, "17. PER_EXECUTION spawned transient ability clones for overlapping casts")
	
	# Scenario 18: Async Event Triggers
	# Explicitly pass empty dict to avoid nulls, though the framework is now patched to handle it
	att_asc.send_gameplay_event(&"Event.Combat.Hit", {})
	
	# Wait for the async wrappers to finish storing the boolean results
	while not _async_tracker.has("counter_1") or not _async_tracker.has("counter_2"):
		await get_tree().process_frame 
		
	var c1 = _async_tracker.get("counter_1", false)
	var c2 = _async_tracker.get("counter_2", false)
	assert_true(c1 and c2, "18. task_wait_for_event correctly resumed multiple overlapping coroutines")
	
	# Scenario 19: Transient Cleanup
	await get_tree().process_frame 
	var remaining_clones = 0
	for child in att_asc.get_children():
		if child is GameplayAbility and child.ability_tag == &"Ability.Counter" and child != async_counter:
			remaining_clones += 1
	assert_eq(remaining_clones, 0, "19. Transient clones dynamically freed themselves upon completion")
	
	# Scenario 20: ASC Master Cleanup
	var active_effect_count = att_asc._active_effects.size()
	att_asc.cleanup()
	assert_true(active_effect_count > 0 and att_asc._active_effects.size() == 0, "20. ASC cleanup() forcefully purged all active states and prevented memory leaks")


func _fire_async_task(ability: GameplayAbility, id: String, payload: Variant = null) -> void:
	var result = await ability.try_activate(payload)
	_async_tracker[id] = result
