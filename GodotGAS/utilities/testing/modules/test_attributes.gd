## Self-contained exhaustive test suite for the GodotGAS Attributes Subsystem.
##
## Tests AttributeData initialization, deep-cloning memory isolation,
## pre/post attribute pipelines, clamping goalposts, and dynamic overrides.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name TestAttributes extends GASTestBase

# ---------------------------------------------------------
# Mock Classes for Testing Environment
# ---------------------------------------------------------
class MockClampingAttributeSet extends AttributeSet:
	@export var health: AttributeData = AttributeData.new(100.0)
	@export var max_health: AttributeData = AttributeData.new(100.0)
	@export var mana: AttributeData = AttributeData.new(50.0)
	@export var max_mana: AttributeData = AttributeData.new(50.0)
	@export var shield: AttributeData = AttributeData.new(0.0)
	
	func pre_attribute_change(attribute_name: String, proposed_value: float) -> float:
		match attribute_name:
			"health":
				return clampf(proposed_value, 0.0, max_health.current_value)
			"mana":
				return clampf(proposed_value, 0.0, max_mana.current_value)
			"shield":
				return maxf(0.0, proposed_value)
			_:
				return proposed_value

	func post_attribute_change(asc: Node, attribute_name: String, _old_value: float, new_value: float) -> void:
		match attribute_name:
			"max_health":
				if health.current_value > new_value:
					var asc_ref := asc as AbilitySystemComponent
					if asc_ref:
						asc_ref._apply_attribute_change("health", new_value - health.current_value)
			"max_mana":
				if mana.current_value > new_value:
					var asc_ref := asc as AbilitySystemComponent
					if asc_ref:
						asc_ref._apply_attribute_change("mana", new_value - mana.current_value)


# Signal tracking buffers
var _attr_changes: Array[Dictionary] = []


func _ready() -> void:
	if get_parent() == get_tree().root:
		await run_all_tests()


func run_all_tests() -> void:
	print_header("GodotGAS Subsystem Test: Attributes Pipeline")
	
	await _battery_attribute_data_core()
	await _battery_memory_isolation_and_cloning()
	await _battery_attribute_queries()
	await _battery_pre_change_clamping()
	await _battery_post_change_goalposts()
	await _battery_dynamic_overrides()
	
	print_summary()


func _reset_signal_buffers() -> void:
	_attr_changes.clear()


func _on_attribute_changed(attribute_name: String, old_value: float, new_value: float, spec: GameplayEffectSpec) -> void:
	_attr_changes.append({
		"name": attribute_name,
		"old": old_value,
		"new": new_value,
		"spec": spec
	})


# ---------------------------------------------------------
# Battery 1: AttributeData Core Behavior & Direct Math
# ---------------------------------------------------------
func _battery_attribute_data_core() -> void:
	print_rich("\n[color=yellow]--- Battery 1: AttributeData Core State & Syncing ---[/color]")
	
	var data := AttributeData.new(100.0)
	assert_eq(data.base_value, 100.0, "1.01: AttributeData initializes base_value correctly")
	assert_eq(data.current_value, 100.0, "1.02: AttributeData initializes current_value to base_value")
	
	# Current value divergence
	data.current_value = 65.0
	assert_eq(data.current_value, 65.0, "1.03: current_value can mutate independently")
	assert_eq(data.base_value, 100.0, "1.04: base_value remains unchanged when current_value mutates")
	
	# Base value setter synchronization
	data.base_value = 150.0
	assert_eq(data.base_value, 150.0, "1.05: base_value updated via setter")
	assert_eq(data.current_value, 150.0, "1.06: current_value automatically synced when base_value changes")
	
	# Zero and negative handling
	var negative_data := AttributeData.new(-25.0)
	assert_eq(negative_data.base_value, -25.0, "1.07: AttributeData accepts negative initial base_value")
	assert_eq(negative_data.current_value, -25.0, "1.08: AttributeData accepts negative initial current_value")


# ---------------------------------------------------------
# Battery 2: Memory Isolation & Deep Cloning (share_attributes)
# ---------------------------------------------------------
func _battery_memory_isolation_and_cloning() -> void:
	print_rich("\n[color=yellow]--- Battery 2: Memory Isolation & Deep Cloning ---[/color]")
	
	var shared_template := MockClampingAttributeSet.new()
	shared_template.health.base_value = 100.0
	shared_template.max_health.base_value = 100.0
	
	# 1. Entity A: Isolated cloning (share_attributes = false)
	var asc_a := AbilitySystemComponent.new()
	asc_a.name = "EntityA_ASC"
	asc_a.share_attributes = false
	asc_a.attribute_sets.append(shared_template)
	add_child(asc_a) # Triggers _ready() cloning
	
	# 2. Entity B: Isolated cloning (share_attributes = false)
	var asc_b := AbilitySystemComponent.new()
	asc_b.name = "EntityB_ASC"
	asc_b.share_attributes = false
	asc_b.attribute_sets.append(shared_template)
	add_child(asc_b) # Triggers _ready() cloning
	
	assert_true(asc_a.attribute_sets[0] != shared_template, "2.01: Entity A cloned its own AttributeSet")
	assert_true(asc_b.attribute_sets[0] != shared_template, "2.02: Entity B cloned its own AttributeSet")
	assert_true(asc_a.attribute_sets[0] != asc_b.attribute_sets[0], "2.03: Entity A and Entity B do not share AttributeSet pointers")
	
	# Mutate Entity A
	asc_a._apply_attribute_change("health", -40.0)
	assert_eq(asc_a.get_attribute("health").current_value, 60.0, "2.04: Entity A health modified to 60.0")
	assert_eq(asc_b.get_attribute("health").current_value, 100.0, "2.05: Entity B health unaffected by Entity A damage")
	assert_eq(shared_template.health.current_value, 100.0, "2.06: Original template resource completely untouched")
	
	asc_a.queue_free()
	asc_b.queue_free()
	
	# 3. Entity C & D: Shared memory (share_attributes = true)
	var shared_set := MockClampingAttributeSet.new()
	shared_set.max_health.base_value = 200.0
	shared_set.health.base_value = 200.0
	
	var asc_c := AbilitySystemComponent.new()
	asc_c.name = "EntityC_ASC"
	asc_c.share_attributes = true
	asc_c.attribute_sets.append(shared_set)
	add_child(asc_c)
	
	var asc_d := AbilitySystemComponent.new()
	asc_d.name = "EntityD_ASC"
	asc_d.share_attributes = true
	asc_d.attribute_sets.append(shared_set)
	add_child(asc_d)
	
	assert_true(asc_c.attribute_sets[0] == shared_set, "2.07: Entity C retained exact resource reference")
	assert_true(asc_d.attribute_sets[0] == shared_set, "2.08: Entity D retained exact resource reference")
	
	asc_c._apply_attribute_change("health", -50.0)
	assert_eq(asc_d.get_attribute("health").current_value, 150.0, "2.09: Entity D observed stat mutation performed by Entity C")
	var shared_add := GameplayEffect.new()
	shared_add.policy = GameplayEffect.DurationPolicy.INFINITE
	shared_add.granted_tags = [&"Test.SharedAdd"]
	var shared_add_mod := GameplayEffectModifier.new()
	shared_add_mod.attribute_name = "health"
	shared_add_mod.operation = GameplayEffectModifier.Operation.ADD
	shared_add_mod.magnitude = 20.0
	shared_add.modifiers = [shared_add_mod]
	var shared_mult := GameplayEffect.new()
	shared_mult.policy = GameplayEffect.DurationPolicy.INFINITE
	shared_mult.granted_tags = [&"Test.SharedMultiply"]
	var shared_mult_mod := GameplayEffectModifier.new()
	shared_mult_mod.attribute_name = "health"
	shared_mult_mod.operation = GameplayEffectModifier.Operation.MULTIPLY
	shared_mult_mod.magnitude = 0.5
	shared_mult.modifiers = [shared_mult_mod]
	asc_c.apply_gameplay_effect(shared_add)
	asc_d.apply_gameplay_effect(shared_mult)
	assert_approx(shared_set.health.current_value, 85.0, 0.0001, "2.10: Shared ASC modifiers combine on one resource")
	asc_c.remove_effects_with_tag(&"Test.SharedAdd")
	assert_approx(shared_set.health.current_value, 75.0, 0.0001, "2.11: Removing one ASC effect preserves the other's modifier")
	asc_d.remove_effects_with_tag(&"Test.SharedMultiply")
	assert_approx(shared_set.health.current_value, 150.0, 0.0001, "2.12: Removing both ASC effects restores shared base")
	
	asc_c.queue_free()
	asc_d.queue_free()


# ---------------------------------------------------------
# Battery 3: Attribute Queries & Lookups
# ---------------------------------------------------------
func _battery_attribute_queries() -> void:
	print_rich("\n[color=yellow]--- Battery 3: Attribute Queries & Null Safety ---[/color]")
	
	var asc := AbilitySystemComponent.new()
	asc.name = "QueryASC"
	asc.attribute_sets.append(MockClampingAttributeSet.new())
	add_child(asc)
	
	assert_true(asc.has_attribute("health"), "3.01: has_attribute returns true for health")
	assert_true(asc.has_attribute("mana"), "3.02: has_attribute returns true for mana")
	assert_true(asc.has_attribute("shield"), "3.03: has_attribute returns true for shield")
	assert_false(asc.has_attribute("stamina"), "3.04: has_attribute returns false for missing stamina")
	assert_false(asc.has_attribute(""), "3.05: has_attribute returns false for empty string")
	
	var attr_health = asc.get_attribute("health")
	assert_true(attr_health is AttributeData, "3.06: get_attribute returns valid AttributeData instance")
	assert_eq(attr_health.current_value, 100.0, "3.07: get_attribute retrieves correct current_value")
	
	var attr_missing = asc.get_attribute("non_existent_stat")
	assert_eq(attr_missing, null, "3.08: get_attribute returns null on non-existent attribute")
	
	asc.queue_free()


# ---------------------------------------------------------
# Battery 4: Pre-Attribute Change Pipeline (Clamping & Math)
# ---------------------------------------------------------
func _battery_pre_change_clamping() -> void:
	print_rich("\n[color=yellow]--- Battery 4: pre_attribute_change Clamping Pipeline ---[/color]")
	
	var asc := AbilitySystemComponent.new()
	asc.name = "ClampASC"
	asc.attribute_sets.append(MockClampingAttributeSet.new())
	asc.attribute_changed.connect(_on_attribute_changed)
	add_child(asc)
	
	_reset_signal_buffers()
	
	# Normal damage within bounds
	var delta_1 := asc._apply_attribute_change("health", -30.0)
	assert_eq(delta_1, -30.0, "4.01: Unclamped change returns exact requested delta")
	assert_eq(asc.get_attribute("health").current_value, 70.0, "4.02: Health dropped to 70.0")
	assert_eq(_attr_changes.size(), 1, "4.03: attribute_changed signal emitted once")
	assert_eq(_attr_changes[0]["name"], "health", "4.04: Signal carried attribute name")
	assert_eq(_attr_changes[0]["old"], 100.0, "4.05: Signal old_value was 100.0")
	assert_eq(_attr_changes[0]["new"], 70.0, "4.06: Signal new_value was 70.0")
	
	# Over-damage clamp to 0.0
	_reset_signal_buffers()
	var delta_2 := asc._apply_attribute_change("health", -150.0)
	assert_eq(delta_2, -70.0, "4.07: Over-damage clamped delta to -70.0 (stopped at 0.0)")
	assert_eq(asc.get_attribute("health").current_value, 0.0, "4.08: Health safely stopped at 0.0 clamp")
	assert_eq(_attr_changes[0]["old"], 70.0, "4.09: Signal recorded previous 70.0")
	assert_eq(_attr_changes[0]["new"], 0.0, "4.10: Signal recorded clamped 0.0")
	
	# Damage when already at 0.0 (Zero-delta signal suppression)
	_reset_signal_buffers()
	var delta_3 := asc._apply_attribute_change("health", -50.0)
	assert_eq(delta_3, 0.0, "4.11: Applying damage at 0.0 returns 0.0 actual delta")
	assert_eq(asc.get_attribute("health").current_value, 0.0, "4.12: Health remains at 0.0")
	assert_eq(_attr_changes.size(), 0, "4.13: attribute_changed NOT emitted when final_value == old_value")
	assert_eq(asc.get_attribute("health").base_value, 0.0, "4.13a: Clamped damage does not push base below zero")
	asc._apply_attribute_change("health", 10.0)
	assert_eq(asc.get_attribute("health").current_value, 10.0, "4.13b: Small heal works after over-damage")
	asc._apply_attribute_change("health", -10.0)
	
	# Over-heal clamp to max_health (100.0)
	_reset_signal_buffers()
	var delta_4 := asc._apply_attribute_change("health", 500.0)
	assert_eq(delta_4, 100.0, "4.14: Massive heal clamped delta to +100.0")
	assert_eq(asc.get_attribute("health").current_value, 100.0, "4.15: Health clamped at max_health (100.0)")
	assert_eq(_attr_changes.size(), 1, "4.16: attribute_changed emitted for clamped heal")
	
	# Over-heal when already full
	_reset_signal_buffers()
	var delta_5 := asc._apply_attribute_change("health", 25.0)
	assert_eq(delta_5, 0.0, "4.17: Over-heal while full returns 0.0 delta")
	assert_eq(_attr_changes.size(), 0, "4.18: attribute_changed suppressed when healing full health")
	
	asc.queue_free()


# ---------------------------------------------------------
# Battery 5: Post-Attribute Change Pipeline (Moving Goalposts)
# ---------------------------------------------------------
func _battery_post_change_goalposts() -> void:
	print_rich("\n[color=yellow]--- Battery 5: post_attribute_change Moving Goalposts ---[/color]")
	
	var asc := AbilitySystemComponent.new()
	asc.name = "GoalpostASC"
	asc.attribute_sets.append(MockClampingAttributeSet.new())
	asc.attribute_changed.connect(_on_attribute_changed)
	add_child(asc)
	
	_reset_signal_buffers()
	
	# Health is at 100.0, max_health is at 100.0
	# Reduce max_health to 60.0 (Goalpost moves down below current health)
	asc._apply_attribute_change("max_health", -40.0)
	
	assert_eq(asc.get_attribute("max_health").current_value, 60.0, "5.01: max_health lowered to 60.0")
	assert_eq(asc.get_attribute("health").current_value, 60.0, "5.02: post_attribute_change forcefully pulled health down to 60.0")
	
	# Verify two separate signals fired: one for max_health, one for health
	assert_eq(_attr_changes.size(), 2, "5.03: Exactly two signals fired for cascading goalpost reduction")
	assert_eq(_attr_changes[0]["name"], "max_health", "5.04: First signal was max_health change")
	assert_eq(_attr_changes[0]["new"], 60.0, "5.05: max_health new value was 60.0")
	assert_eq(_attr_changes[1]["name"], "health", "5.06: Second signal was reactive health reduction")
	assert_eq(_attr_changes[1]["new"], 60.0, "5.07: health new value was clamped to 60.0")
	
	# Increasing max_health should NOT automatically raise current health
	_reset_signal_buffers()
	asc._apply_attribute_change("max_health", 40.0)
	assert_eq(asc.get_attribute("max_health").current_value, 100.0, "5.08: max_health restored to 100.0")
	assert_eq(asc.get_attribute("health").current_value, 60.0, "5.09: current health remained at 60.0 without free healing")
	assert_eq(_attr_changes.size(), 1, "5.10: Only max_health emitted a signal when raised")
	
	asc.queue_free()


# ---------------------------------------------------------
# Battery 6: Dynamic Attribute Overrides (initialize_attribute_overrides)
# ---------------------------------------------------------
func _battery_dynamic_overrides() -> void:
	print_rich("\n[color=yellow]--- Battery 6: initialize_attribute_overrides Pipeline ---[/color]")
	
	var asc := AbilitySystemComponent.new()
	asc.name = "OverrideASC"
	asc.attribute_sets.append(MockClampingAttributeSet.new())
	asc.attribute_changed.connect(_on_attribute_changed)
	add_child(asc)
	
	_reset_signal_buffers()
	
	# Apply standard valid overrides dictionary
	var overrides: Dictionary[String, float] = {
		"health": 45.0,
		"mana": 20.0,
		"shield": 75.0
	}
	asc.initialize_attribute_overrides(overrides)
	
	assert_eq(asc.get_attribute("health").current_value, 45.0, "6.01: Health successfully overridden to 45.0")
	assert_eq(asc.get_attribute("mana").current_value, 20.0, "6.02: Mana successfully overridden to 20.0")
	assert_eq(asc.get_attribute("shield").current_value, 75.0, "6.03: Shield successfully overridden to 75.0")
	assert_eq(_attr_changes.size(), 3, "6.04: Three attribute_changed signals emitted through the GAS pipeline")
	
	# Overrides must respect pre_attribute_change clamping!
	_reset_signal_buffers()
	var out_of_bounds: Dictionary[String, float] = {
		"health": 999.0, # max_health is 100.0
		"mana": -50.0    # min_mana is 0.0
	}
	asc.initialize_attribute_overrides(out_of_bounds)
	
	assert_eq(asc.get_attribute("health").current_value, 100.0, "6.05: Override above max_health clamped to 100.0")
	assert_eq(asc.get_attribute("mana").current_value, 0.0, "6.06: Override below min_mana clamped to 0.0")
	
	# Empty dictionary safety
	_reset_signal_buffers()
	var empty_dict: Dictionary[String, float] = {}
	asc.initialize_attribute_overrides(empty_dict)
	assert_eq(_attr_changes.size(), 0, "6.07: Empty overrides dictionary safely completes without action")
	
	asc.queue_free()
