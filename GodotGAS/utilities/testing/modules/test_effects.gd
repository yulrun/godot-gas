## Self-contained exhaustive test suite for the GodotGAS Effects Subsystem.
##
## Tests lifecycles, advanced stacking and overflows, SetByCaller injection,
## Attribute-based scaling, tag suppression (inhibition), and cleansers.
##
## @meta_addon: GodotGAS Version 1.1.0+
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name TestEffects extends GASTestBase

# ---------------------------------------------------------
# Mock Classes for Testing Environment
# ---------------------------------------------------------
class EffectsAttributeSet extends AttributeSet:
	@export var health: AttributeData = AttributeData.new(100.0)
	@export var mana: AttributeData = AttributeData.new(100.0)
	@export var armor: AttributeData = AttributeData.new(0.0)
	@export var attack_power: AttributeData = AttributeData.new(50.0)


func _ready() -> void:
	if get_parent() == get_tree().root:
		await run_all_tests()


func run_all_tests() -> void:
	print_header("GodotGAS Subsystem Test: Gameplay Effects Engine")
	
	await _battery_lifecycles_and_turns()
	await _battery_stacking_and_overflow()
	await _battery_attribute_based_scaling()
	await _battery_set_by_caller()
	await _battery_inhibition_and_cleansers()
	await _battery_attribute_aggregation()
	await _battery_capture_and_percent_add()
	
	print_summary()


# ---------------------------------------------------------
# Battery 1: Lifecycles & Turn-Based Processing
# ---------------------------------------------------------
func _battery_lifecycles_and_turns() -> void:
	print_rich("\n[color=yellow]--- Battery 1: Duration Policies & Turn-Based Math ---[/color]")
	
	var asc := AbilitySystemComponent.new()
	asc.name = "LifecycleASC"
	asc.attribute_sets.append(EffectsAttributeSet.new())
	add_child(asc)
	
	# 1. Instant Policy
	var inst_mod := GameplayEffectModifier.new()
	inst_mod.attribute_name = "health"
	inst_mod.operation = GameplayEffectModifier.Operation.ADD
	inst_mod.magnitude = -20.0
	
	var inst_effect := GameplayEffect.new()
	inst_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	inst_effect.modifiers.append(inst_mod)
	inst_effect.granted_tags.append(&"Status.ShouldFail") # Instant cannot grant tags
	
	var inst_result = asc.apply_gameplay_effect(inst_effect, asc, 1.0)
	assert_true(inst_result != null, "1.01: Instant effect returns a valid tracking wrapper")
	assert_eq(asc.get_attribute("health").current_value, 80.0, "1.02: Instant math evaluates immediately")
	assert_false(asc.has_tag(&"Status.ShouldFail"), "1.03: Instant effects successfully ignore granted_tags")
	assert_false(asc._active_effects.has(inst_result), "1.04: Instant wrapper is not permanently stored in memory")
	
	# 2. Duration Policy
	var dur_mod := GameplayEffectModifier.new()
	dur_mod.attribute_name = "armor"
	dur_mod.operation = GameplayEffectModifier.Operation.ADD
	dur_mod.magnitude = 50.0
	
	var dur_effect := GameplayEffect.new()
	dur_effect.policy = GameplayEffect.DurationPolicy.DURATION
	dur_effect.duration = 0.2
	dur_effect.modifiers.append(dur_mod)
	dur_effect.granted_tags.append(&"Status.Armored")
	
	var dur_result = asc.apply_gameplay_effect(dur_effect, asc, 1.0)
	assert_eq(asc.get_attribute("armor").current_value, 50.0, "1.05: Duration effect math applies immediately")
	assert_true(asc.has_tag(&"Status.Armored"), "1.06: Duration effect granted state tag")
	assert_true(asc._active_effects.has(dur_result), "1.07: Duration effect stored in ASC memory")
	
	await get_tree().create_timer(0.25).timeout # Yield for expiration
	
	assert_eq(asc.get_attribute("armor").current_value, 0.0, "1.08: Duration expiration perfectly reversed math")
	assert_false(asc.has_tag(&"Status.Armored"), "1.09: Duration expiration purged granted tags")
	assert_false(asc._active_effects.has(dur_result), "1.10: Expired effect safely erased from ASC memory")
	
	# 3. Turn-Based Policy
	asc.get_attribute("health").base_value = 100.0
	
	var turn_mod := GameplayEffectModifier.new()
	turn_mod.attribute_name = "health"
	turn_mod.operation = GameplayEffectModifier.Operation.ADD
	turn_mod.magnitude = -10.0
	
	var turn_effect := GameplayEffect.new()
	turn_effect.policy = GameplayEffect.DurationPolicy.TURN_BASED
	turn_effect.duration_turns = 2
	turn_effect.period = 1.0 # Tells system it's a DoT
	turn_effect.tick_on_turn_start = true
	turn_effect.modifiers.append(turn_mod)
	
	var turn_result = asc.apply_gameplay_effect(turn_effect, asc, 1.0)
	assert_eq(asc.get_attribute("health").current_value, 100.0, "1.11: Turn-Based DoT does not apply initial math immediately")
	
	asc.advance_turn()
	assert_eq(asc.get_attribute("health").current_value, 90.0, "1.12: Turn 1 successfully evaluated DoT math")
	assert_true(asc._active_effects.has(turn_result), "1.13: Turn-based effect survives first turn")
	
	asc.advance_turn()
	assert_eq(asc.get_attribute("health").current_value, 80.0, "1.14: Turn 2 successfully evaluated DoT math")
	assert_false(asc._active_effects.has(turn_result), "1.15: Turn-based effect auto-expires after final turn")

	asc.queue_free()




# ---------------------------------------------------------
# Battery 2: Advanced Stacking & Overflow Engine
# ---------------------------------------------------------
func _battery_stacking_and_overflow() -> void:
	print_rich("\n[color=yellow]--- Battery 2: Advanced Stacking & Overflows ---[/color]")
	
	var asc := AbilitySystemComponent.new()
	asc.name = "StackingASC"
	asc.attribute_sets.append(EffectsAttributeSet.new())
	add_child(asc)
	
	# Overflow Payload (Frozen)
	var frozen_mod := GameplayEffectModifier.new()
	frozen_mod.attribute_name = "armor"
	frozen_mod.operation = GameplayEffectModifier.Operation.OVERRIDE
	frozen_mod.magnitude = -100.0
	
	var frozen_effect := GameplayEffect.new()
	frozen_effect.policy = GameplayEffect.DurationPolicy.INFINITE
	frozen_effect.modifiers.append(frozen_mod)
	frozen_effect.granted_tags.append(&"Status.Frozen")
	
	# Stacking Payload (Chill)
	var chill_mod := GameplayEffectModifier.new()
	chill_mod.attribute_name = "armor"
	chill_mod.operation = GameplayEffectModifier.Operation.ADD
	chill_mod.magnitude = -10.0
	
	var chill_effect := GameplayEffect.new()
	chill_effect.policy = GameplayEffect.DurationPolicy.INFINITE
	chill_effect.stacking_policy = GameplayEffect.StackingPolicy.REFRESH_DURATION
	chill_effect.max_stacks = 3
	chill_effect.clear_stack_on_overflow = true
	chill_effect.modifiers.append(chill_mod)
	chill_effect.granted_tags.append(&"Status.Chilled")
	chill_effect.overflow_effects.append(frozen_effect)
	
	# Execute
	var chill_instance = asc.apply_gameplay_effect(chill_effect, asc, 1.0)
	assert_eq(asc.get_attribute("armor").current_value, -10.0, "2.01: Base stack applied correctly")
	
	asc.apply_gameplay_effect(chill_effect, asc, 1.0)
	assert_eq(asc.get_attribute("armor").current_value, -20.0, "2.02: Second stack accumulates math properly")
	assert_eq(chill_instance.stack_count, 2, "2.03: Stack count increments safely")
	
	asc.apply_gameplay_effect(chill_effect, asc, 1.0)
	assert_eq(asc.get_attribute("armor").current_value, -30.0, "2.04: Third stack reached (Max)")
	
	asc.apply_gameplay_effect(chill_effect, asc, 1.0) # OVERFLOW
	assert_true(asc.has_tag(&"Status.Frozen"), "2.05: Overflow triggered the secondary payload")
	assert_false(asc.has_tag(&"Status.Chilled"), "2.06: clear_stack_on_overflow purged original stacks")
	assert_eq(asc.get_attribute("armor").current_value, -100.0, "2.07: Math perfectly evaluated stack purge and new overflow baseline")

	asc.queue_free()


# ---------------------------------------------------------
# Battery 3: Attribute-Based Scaling (Source & Target)
# ---------------------------------------------------------
func _battery_attribute_based_scaling() -> void:
	print_rich("\n[color=yellow]--- Battery 3: Attribute-Based Modifiers ---[/color]")
	
	var defender := AbilitySystemComponent.new()
	defender.name = "DefenderASC"
	var def_attrs := EffectsAttributeSet.new()
	def_attrs.health.current_value = 100.0
	def_attrs.attack_power.current_value = 20.0
	defender.attribute_sets.append(def_attrs)
	add_child(defender)
	
	var attacker := AbilitySystemComponent.new()
	attacker.name = "AttackerASC"
	var att_attrs := EffectsAttributeSet.new()
	att_attrs.attack_power.current_value = 80.0
	attacker.attribute_sets.append(att_attrs)
	add_child(attacker)
	
	# Target-Based Heal (Defender heals 50% of their own 20 AP)
	var tgt_mod := GameplayEffectModifier.new()
	tgt_mod.attribute_name = "health"
	tgt_mod.operation = GameplayEffectModifier.Operation.ADD
	tgt_mod.magnitude_calculation = GameplayEffectModifier.MagnitudeCalculationType.ATTRIBUTE_BASED
	tgt_mod.attribute_source = GameplayEffectModifier.AttributeSource.TARGET
	tgt_mod.backing_attribute_name = "attack_power"
	tgt_mod.attribute_multiplier = 0.5
	
	var tgt_effect := GameplayEffect.new()
	tgt_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	tgt_effect.modifiers.append(tgt_mod)
	
	defender.apply_gameplay_effect(tgt_effect, defender, 1.0)
	assert_eq(defender.get_attribute("health").current_value, 110.0, "3.01: TARGET-sourced math evaluated correctly (100 + 10)")
	
	# Source-Based Damage (Defender takes 1.5x Attacker's 80 AP)
	var src_mod := GameplayEffectModifier.new()
	src_mod.attribute_name = "health"
	src_mod.operation = GameplayEffectModifier.Operation.ADD
	src_mod.magnitude_calculation = GameplayEffectModifier.MagnitudeCalculationType.ATTRIBUTE_BASED
	src_mod.attribute_source = GameplayEffectModifier.AttributeSource.SOURCE
	src_mod.backing_attribute_name = "attack_power"
	src_mod.attribute_multiplier = -1.5
	
	var src_effect := GameplayEffect.new()
	src_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	src_effect.modifiers.append(src_mod)
	
	# Explicitly pass the attacker via Spec
	var spec := GameplayEffectSpec.new(src_effect, GameplayEffectContext.new(attacker), 1.0)
	defender.apply_effect_spec(spec)
	
	assert_eq(defender.get_attribute("health").current_value, -10.0, "3.02: SOURCE-sourced math evaluated correctly (110 - 120)")

	defender.queue_free()
	attacker.queue_free()


# ---------------------------------------------------------
# Battery 4: SetByCaller Injection
# ---------------------------------------------------------
func _battery_set_by_caller() -> void:
	print_rich("\n[color=yellow]--- Battery 4: SetByCaller Math Injection ---[/color]")
	
	var asc := AbilitySystemComponent.new()
	asc.name = "CallerASC"
	asc.attribute_sets.append(EffectsAttributeSet.new())
	add_child(asc)
	
	asc.get_attribute("mana").current_value = 100.0
	
	var sbc_mod := GameplayEffectModifier.new()
	sbc_mod.attribute_name = "mana"
	sbc_mod.operation = GameplayEffectModifier.Operation.ADD
	sbc_mod.magnitude_calculation = GameplayEffectModifier.MagnitudeCalculationType.SET_BY_CALLER
	sbc_mod.set_by_caller_tag = &"Data.Damage.Mana"
	
	var sbc_effect := GameplayEffect.new()
	sbc_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	sbc_effect.modifiers.append(sbc_mod)
	
	# Uninjected Execution
	var spec1 := GameplayEffectSpec.new(sbc_effect, GameplayEffectContext.new(asc), 1.0)
	asc.apply_effect_spec(spec1)
	assert_eq(asc.get_attribute("mana").current_value, 100.0, "4.01: SetByCaller safely defaults to 0.0 if not injected")
	
	# Injected Execution
	var spec2 := GameplayEffectSpec.new(sbc_effect, GameplayEffectContext.new(asc), 1.0)
	spec2.set_set_by_caller_magnitude(&"Data.Damage.Mana", -60.0)
	asc.apply_effect_spec(spec2)
	assert_eq(asc.get_attribute("mana").current_value, 40.0, "4.02: SetByCaller successfully extracted and evaluated dynamic math")
	
	# Fallback/Default test via getter
	assert_eq(spec2.get_set_by_caller_magnitude(&"Data.Ghost.Tag", 5.0), 5.0, "4.03: Spec getter safely routes default values")

	asc.queue_free()


# ---------------------------------------------------------
# Battery 5: Inhibition & Cleansers
# ---------------------------------------------------------
func _battery_inhibition_and_cleansers() -> void:
	print_rich("\n[color=yellow]--- Battery 5: Tag Suppression & Cleansers ---[/color]")
	
	var asc := AbilitySystemComponent.new()
	asc.name = "InhibitASC"
	asc.attribute_sets.append(EffectsAttributeSet.new())
	add_child(asc)
	
	asc.get_attribute("armor").current_value = 0.0
	
	# 1. Inhibition
	var supp_query := GameplayTagQuery.new()
	supp_query.require_exact_tags.append(&"State.Silenced")
	
	var buff_mod := GameplayEffectModifier.new()
	buff_mod.attribute_name = "armor"
	buff_mod.operation = GameplayEffectModifier.Operation.ADD
	buff_mod.magnitude = 50.0
	
	var buff_effect := GameplayEffect.new()
	buff_effect.policy = GameplayEffect.DurationPolicy.INFINITE
	buff_effect.modifiers.append(buff_mod)
	buff_effect.granted_tags.append(&"Status.Armored")
	buff_effect.ongoing_suppression_query = supp_query
	
	var active_buff = asc.apply_gameplay_effect(buff_effect, asc, 1.0)
	assert_eq(asc.get_attribute("armor").current_value, 50.0, "5.01: Inhibitable effect applied stats correctly")
	
	asc.add_tag(&"State.Silenced")
	assert_eq(asc.get_attribute("armor").current_value, 0.0, "5.02: Effect suppressed (Math reversed)")
	assert_false(asc.has_tag(&"Status.Armored"), "5.03: Effect suppressed (Tags dropped)")
	assert_true(active_buff.is_suppressed, "5.04: Wrapper physically tracking suppressed state")
	
	asc.remove_tag(&"State.Silenced")
	assert_eq(asc.get_attribute("armor").current_value, 50.0, "5.05: Effect unsuppressed (Math restored)")
	assert_true(asc.has_tag(&"Status.Armored"), "5.06: Effect unsuppressed (Tags restored)")
	
	# 2. Cleanser Pattern
	var cure_effect := GameplayEffect.new()
	cure_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	cure_effect.remove_effects_with_tags.append(&"Status.Armored")
	
	asc.apply_gameplay_effect(cure_effect, asc, 1.0)
	assert_false(asc._active_effects.has(active_buff), "5.07: Cleanser pattern physically stripped targeted effect")
	assert_eq(asc.get_attribute("armor").current_value, 0.0, "5.08: Math correctly reversed upon forced cleanse")
	asc.add_tag(&"State.Silenced")
	var initially_suppressed = asc.apply_gameplay_effect(buff_effect, asc, 1.0)
	assert_eq(asc.get_attribute("armor").current_value, 0.0, "5.09: Already matching suppression query prevents initial math")
	assert_false(asc.has_tag(&"Status.Armored"), "5.10: Initially suppressed effect does not grant tags")
	asc.remove_tag(&"State.Silenced")
	assert_eq(asc.get_attribute("armor").current_value, 50.0, "5.11: Initially suppressed effect activates when query clears")
	asc.remove_active_effect(initially_suppressed)

	asc.queue_free()


# ---------------------------------------------------------
# Battery 6: Order-independent active attribute aggregation
# ---------------------------------------------------------
func _aggregation_effect(operation: GameplayEffectModifier.Operation, magnitude: float, tag: StringName) -> GameplayEffect:
	var effect := GameplayEffect.new()
	effect.policy = GameplayEffect.DurationPolicy.INFINITE
	effect.granted_tags = [tag]
	var modifier := GameplayEffectModifier.new()
	modifier.attribute_name = "health"
	modifier.operation = operation
	modifier.magnitude = magnitude
	effect.modifiers = [modifier]
	return effect


func _battery_attribute_aggregation() -> void:
	print_rich("\n[color=yellow]--- Battery 6: Attribute Aggregation ---[/color]")
	for reverse in [false, true]:
		var asc := AbilitySystemComponent.new()
		asc.attribute_sets.append(EffectsAttributeSet.new())
		add_child(asc)
		var add := _aggregation_effect(GameplayEffectModifier.Operation.ADD, 20.0, &"Test.Add")
		var multiply := _aggregation_effect(GameplayEffectModifier.Operation.MULTIPLY, 0.5, &"Test.Multiply")
		if reverse:
			asc.apply_gameplay_effect(multiply)
			asc.apply_gameplay_effect(add)
		else:
			asc.apply_gameplay_effect(add)
			asc.apply_gameplay_effect(multiply)
		assert_approx(asc.get_attribute("health").current_value, 60.0, 0.0001, "6.01: Mixed application order")
		if reverse:
			asc.remove_effects_with_tag(&"Test.Multiply")
			assert_approx(asc.get_attribute("health").current_value, 120.0, 0.0001, "6.02: Remove multiplier first")
			asc.remove_effects_with_tag(&"Test.Add")
		else:
			asc.remove_effects_with_tag(&"Test.Add")
			assert_approx(asc.get_attribute("health").current_value, 50.0, 0.0001, "6.03: Remove additive first")
			asc.remove_effects_with_tag(&"Test.Multiply")
		assert_approx(asc.get_attribute("health").current_value, 100.0, 0.0001, "6.04: Removing both restores base")
		asc.queue_free()

	var asc := AbilitySystemComponent.new()
	asc.attribute_sets.append(EffectsAttributeSet.new())
	add_child(asc)
	asc.apply_gameplay_effect(_aggregation_effect(GameplayEffectModifier.Operation.MULTIPLY, 0.8, &"Test.M08"))
	asc.apply_gameplay_effect(_aggregation_effect(GameplayEffectModifier.Operation.MULTIPLY, 0.7, &"Test.M07"))
	assert_approx(asc.get_attribute("health").current_value, 56.0, 0.0001, "6.05: Multipliers compound")
	asc.remove_effects_with_tag(&"Test.M08")
	assert_approx(asc.get_attribute("health").current_value, 70.0, 0.0001, "6.06: Remove older multiplier")
	asc.remove_effects_with_tag(&"Test.M07")

	asc.apply_gameplay_effect(_aggregation_effect(GameplayEffectModifier.Operation.MULTIPLY, 0.5, &"Test.Multiply"))
	var instant := _aggregation_effect(GameplayEffectModifier.Operation.ADD, 20.0, &"Test.Instant")
	instant.policy = GameplayEffect.DurationPolicy.INSTANT
	asc.apply_gameplay_effect(instant)
	assert_approx(asc.get_attribute("health").base_value, 120.0, 0.0001, "6.07: Instant effect changes base")
	assert_approx(asc.get_attribute("health").current_value, 60.0, 0.0001, "6.08: Active effect aggregates over new base")
	asc.remove_effects_with_tag(&"Test.Multiply")
	assert_approx(asc.get_attribute("health").current_value, 120.0, 0.0001, "6.09: Removing buff exposes changed base")
	asc.queue_free()

	var combined_asc := AbilitySystemComponent.new()
	combined_asc.attribute_sets.append(EffectsAttributeSet.new())
	add_child(combined_asc)
	var combined := _aggregation_effect(GameplayEffectModifier.Operation.ADD, 20.0, &"Test.Combined")
	var combined_multiplier := GameplayEffectModifier.new()
	combined_multiplier.attribute_name = "health"
	combined_multiplier.operation = GameplayEffectModifier.Operation.MULTIPLY
	combined_multiplier.magnitude = 0.5
	combined.modifiers.append(combined_multiplier)
	combined_asc.apply_gameplay_effect(combined)
	assert_approx(combined_asc.get_attribute("health").current_value, 60.0, 0.0001, "6.10: Modifiers sharing one attribute keep their own magnitudes")
	combined_asc.queue_free()

	var rule_asc := AbilitySystemComponent.new()
	rule_asc.attribute_sets.append(EffectsAttributeSet.new())
	add_child(rule_asc)
	rule_asc.apply_gameplay_effect(_aggregation_effect(GameplayEffectModifier.Operation.DIVIDE, 2.0, &"Test.Divide"))
	rule_asc.apply_gameplay_effect(_aggregation_effect(GameplayEffectModifier.Operation.ADD, 20.0, &"Test.Add"))
	assert_approx(rule_asc.get_attribute("health").current_value, 60.0, 0.0001, "6.11: Division uses aggregated additive base")
	rule_asc.remove_effects_with_tag(&"Test.Divide")
	rule_asc.remove_effects_with_tag(&"Test.Add")
	var lower_priority := _aggregation_effect(GameplayEffectModifier.Operation.OVERRIDE, 70.0, &"Test.LowPriority")
	var higher_priority := _aggregation_effect(GameplayEffectModifier.Operation.OVERRIDE, 30.0, &"Test.HighPriority")
	higher_priority.modifiers[0].override_priority = 10
	rule_asc.apply_gameplay_effect(lower_priority)
	rule_asc.apply_gameplay_effect(higher_priority)
	assert_approx(rule_asc.get_attribute("health").current_value, 30.0, 0.0001, "6.12: Override priority is order independent")
	rule_asc.remove_effects_with_tag(&"Test.HighPriority")
	assert_approx(rule_asc.get_attribute("health").current_value, 70.0, 0.0001, "6.13: Removing priority winner exposes remaining override")
	rule_asc.apply_gameplay_effect(_aggregation_effect(GameplayEffectModifier.Operation.OVERRIDE, 80.0, &"Test.EqualPriority"))
	assert_approx(rule_asc.get_attribute("health").current_value, 80.0, 0.0001, "6.13a: Equal-priority overrides choose higher magnitude")
	rule_asc.remove_effects_with_tag(&"Test.EqualPriority")
	rule_asc.remove_effects_with_tag(&"Test.LowPriority")
	var snapshot := _aggregation_effect(GameplayEffectModifier.Operation.MULTIPLY, 0.0, &"Test.Snapshot")
	snapshot.modifiers[0].magnitude_calculation = GameplayEffectModifier.MagnitudeCalculationType.SET_BY_CALLER
	snapshot.modifiers[0].set_by_caller_tag = &"Test.Magnitude"
	var snapshot_spec := GameplayEffectSpec.new(snapshot, GameplayEffectContext.new(rule_asc))
	snapshot_spec.set_set_by_caller_magnitude(&"Test.Magnitude", 0.5)
	rule_asc.apply_effect_spec(snapshot_spec)
	snapshot_spec.set_set_by_caller_magnitude(&"Test.Magnitude", 0.25)
	rule_asc.apply_gameplay_effect(_aggregation_effect(GameplayEffectModifier.Operation.ADD, 20.0, &"Test.Add"))
	assert_approx(rule_asc.get_attribute("health").current_value, 60.0, 0.0001, "6.14: Persistent SetByCaller magnitude stays frozen")
	rule_asc.queue_free()


# ---------------------------------------------------------
# Battery 7: Capture Types & Percent Add Aggregation
# ---------------------------------------------------------
func _battery_capture_and_percent_add() -> void:
	print_rich("\n[color=yellow]--- Battery 7: Capture Types & Percent Add ---[/color]")
	
	var asc := AbilitySystemComponent.new()
	asc.attribute_sets.append(EffectsAttributeSet.new())
	add_child(asc)
	
	# Set a clean base of 100 Health and 0 Armor
	asc.get_attribute("health").base_value = 100.0
	asc.get_attribute("armor").base_value = 0.0
	
	# 1. Verify PERCENT_ADD Aggregation Math
	# Formula: (Base + FlatAdd) * (1.0 + Sum(PercentAdd)) * Product(Multiply)
	var flat_add := GameplayEffect.new()
	flat_add.policy = GameplayEffect.DurationPolicy.INFINITE
	var flat_mod := GameplayEffectModifier.new()
	flat_mod.attribute_name = "health"
	flat_mod.operation = GameplayEffectModifier.Operation.ADD
	flat_mod.magnitude = 20.0
	flat_add.modifiers.append(flat_mod)
	
	var pct_add_1 := GameplayEffect.new()
	pct_add_1.policy = GameplayEffect.DurationPolicy.INFINITE
	var pct_mod_1 := GameplayEffectModifier.new()
	pct_mod_1.attribute_name = "health"
	pct_mod_1.operation = GameplayEffectModifier.Operation.PERCENT_ADD
	pct_mod_1.magnitude = 0.5 # +50%
	pct_add_1.modifiers.append(pct_mod_1)
	
	var pct_add_2 := GameplayEffect.new()
	pct_add_2.policy = GameplayEffect.DurationPolicy.INFINITE
	var pct_mod_2 := GameplayEffectModifier.new()
	pct_mod_2.attribute_name = "health"
	pct_mod_2.operation = GameplayEffectModifier.Operation.PERCENT_ADD
	pct_mod_2.magnitude = 0.2 # +20%
	pct_add_2.modifiers.append(pct_mod_2)
	
	asc.apply_gameplay_effect(flat_add)
	asc.apply_gameplay_effect(pct_add_1)
	assert_approx(asc.get_attribute("health").current_value, 180.0, 0.0001, "7.01: PERCENT_ADD correctly scales off (Base + Flat) -> (100 + 20) * 1.5")
	
	asc.apply_gameplay_effect(pct_add_2)
	assert_approx(asc.get_attribute("health").current_value, 204.0, 0.0001, "7.02: Multiple PERCENT_ADD modifiers stack additively -> 120 * (1.0 + 0.5 + 0.2)")
	
	# 2. Verify AttributeCaptureType (Current vs Base)
	# Current buffed health is exactly 204.0. Base is exactly 100.0.
	var capture_current_mod := GameplayEffectModifier.new()
	capture_current_mod.attribute_name = "armor"
	capture_current_mod.operation = GameplayEffectModifier.Operation.ADD
	capture_current_mod.magnitude_calculation = GameplayEffectModifier.MagnitudeCalculationType.ATTRIBUTE_BASED
	capture_current_mod.attribute_source = GameplayEffectModifier.AttributeSource.TARGET
	capture_current_mod.backing_attribute_name = "health"
	capture_current_mod.attribute_capture_type = GameplayEffectModifier.AttributeCaptureType.CURRENT_VALUE
	capture_current_mod.attribute_multiplier = 0.1 # 10%
	
	var effect_current := GameplayEffect.new()
	effect_current.policy = GameplayEffect.DurationPolicy.INSTANT
	effect_current.modifiers.append(capture_current_mod)
	
	asc.apply_gameplay_effect(effect_current)
	assert_approx(asc.get_attribute("armor").current_value, 20.4, 0.0001, "7.03: CURRENT_VALUE capture scales off actively buffed total (204 * 0.1)")
	
	var capture_base_mod := GameplayEffectModifier.new()
	capture_base_mod.attribute_name = "armor"
	capture_base_mod.operation = GameplayEffectModifier.Operation.OVERRIDE 
	capture_base_mod.magnitude_calculation = GameplayEffectModifier.MagnitudeCalculationType.ATTRIBUTE_BASED
	capture_base_mod.attribute_source = GameplayEffectModifier.AttributeSource.TARGET
	capture_base_mod.backing_attribute_name = "health"
	capture_base_mod.attribute_capture_type = GameplayEffectModifier.AttributeCaptureType.BASE_VALUE
	capture_base_mod.attribute_multiplier = 0.1 # 10%
	
	var effect_base := GameplayEffect.new()
	effect_base.policy = GameplayEffect.DurationPolicy.INSTANT
	effect_base.modifiers.append(capture_base_mod)
	
	asc.apply_gameplay_effect(effect_base)
	assert_approx(asc.get_attribute("armor").current_value, 10.0, 0.0001, "7.04: BASE_VALUE capture ignores active buffs and overrides using unbuffed base (100 * 0.1)")
	
	asc.queue_free()
