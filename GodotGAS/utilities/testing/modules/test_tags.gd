## Self-contained exhaustive test suite for the GodotGAS Tag Subsystem.
##
## Tests reference counting, hierarchical inheritance, exact matching,
## signal dispatch, and full GameplayTagQuery rule variations.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name TestTags extends GASTestBase

# Signal tracking buffers
var _tags_added: Array[StringName] = []
var _tags_removed: Array[StringName] = []
var _tag_counts: Dictionary = {}


func _ready() -> void:
	# Allows standalone scene execution
	if get_parent() == get_tree().root:
		await run_all_tests()


func run_all_tests() -> void:
	print_header("GodotGAS Subsystem Test: Tags & Queries")
	
	var asc := AbilitySystemComponent.new()
	asc.name = "TagTestASC"
	add_child(asc)
	
	_connect_signals(asc)
	
	await _battery_reference_counting(asc)
	await _battery_hierarchical_lookups(asc)
	await _battery_tag_queries(asc)
	await _battery_tag_edge_cases(asc)
	
	print_summary()
	asc.queue_free()


func _connect_signals(asc: AbilitySystemComponent) -> void:
	asc.tag_added.connect(func(tag: StringName) -> void: _tags_added.append(tag))
	asc.tag_removed.connect(func(tag: StringName) -> void: _tags_removed.append(tag))
	asc.tag_count_changed.connect(func(tag: StringName, count: int) -> void: _tag_counts[tag] = count)


func _reset_signal_buffers() -> void:
	_tags_added.clear()
	_tags_removed.clear()
	_tag_counts.clear()


# ---------------------------------------------------------
# Battery 1: Reference Counting & Signals
# ---------------------------------------------------------
func _battery_reference_counting(asc: AbilitySystemComponent) -> void:
	print_rich("\n[color=yellow]--- Battery 1: Tag Reference Counting & Signal Lifecycles ---[/color]")
	_reset_signal_buffers()
	
	# 1. Add first instance
	asc.add_tag(&"State.Buff.Haste")
	assert_true(asc.has_tag_exact(&"State.Buff.Haste"), "1.01: Tag exists on ASC with 1 reference")
	assert_eq(_tags_added.size(), 1, "1.02: tag_added signal fired exactly once")
	assert_eq(_tags_added[0], &"State.Buff.Haste", "1.03: tag_added payload matches tag")
	assert_eq(_tag_counts.get(&"State.Buff.Haste", 0), 1, "1.04: tag_count_changed fired with count 1")
	
	# 2. Add second instance (stack reference)
	_reset_signal_buffers()
	asc.add_tag(&"State.Buff.Haste")
	assert_eq(_tags_added.size(), 0, "1.05: tag_added does NOT fire on duplicate stack addition")
	assert_eq(_tag_counts.get(&"State.Buff.Haste", 0), 2, "1.06: tag_count_changed fired with count 2")
	
	# 3. Add third instance
	asc.add_tag(&"State.Buff.Haste")
	assert_eq(_tag_counts.get(&"State.Buff.Haste", 0), 3, "1.07: Reference count successfully scaled to 3")
	
	# 4. Decrement once
	_reset_signal_buffers()
	asc.remove_tag(&"State.Buff.Haste")
	assert_true(asc.has_tag_exact(&"State.Buff.Haste"), "1.08: Tag remains on ASC when count drops from 3 to 2")
	assert_eq(_tags_removed.size(), 0, "1.09: tag_removed does NOT fire while count > 0")
	assert_eq(_tag_counts.get(&"State.Buff.Haste", 0), 2, "1.10: tag_count_changed fired with count 2 on decrement")
	
	# 5. Decrement to 1
	asc.remove_tag(&"State.Buff.Haste")
	assert_true(asc.has_tag_exact(&"State.Buff.Haste"), "1.11: Tag remains active with 1 stack remaining")
	
	# 6. Decrement to 0 (Full purge)
	_reset_signal_buffers()
	asc.remove_tag(&"State.Buff.Haste")
	assert_false(asc.has_tag_exact(&"State.Buff.Haste"), "1.12: Tag removed from active dictionary at 0")
	assert_eq(_tags_removed.size(), 1, "1.13: tag_removed fired when count reached 0")
	assert_eq(_tags_removed[0], &"State.Buff.Haste", "1.14: tag_removed payload matches purged tag")
	
	# 7. Force clear with high stack count
	_reset_signal_buffers()
	asc.add_tag(&"State.Debuff.Bleed")
	asc.add_tag(&"State.Debuff.Bleed")
	asc.add_tag(&"State.Debuff.Bleed")
	assert_eq(asc.has_tag_exact(&"State.Debuff.Bleed"), true, "1.15: Bleed stacked to 3")
	
	asc.clear_tag(&"State.Debuff.Bleed")
	assert_false(asc.has_tag_exact(&"State.Debuff.Bleed"), "1.16: clear_tag violently erases tag regardless of stacks")
	assert_eq(_tags_removed.has(&"State.Debuff.Bleed"), true, "1.17: clear_tag emits tag_removed")


# ---------------------------------------------------------
# Battery 2: Exact vs Hierarchical Lookups
# ---------------------------------------------------------
func _battery_hierarchical_lookups(asc: AbilitySystemComponent) -> void:
	print_rich("\n[color=yellow]--- Battery 2: Exact vs Hierarchical Matching ---[/color]")
	
	asc.clear_tag(&"State.Combat.Stunned.Deep")
	asc.add_tag(&"State.Combat.Stunned.Deep")
	
	# Exact Lookups
	assert_true(asc.has_tag_exact(&"State.Combat.Stunned.Deep"), "2.01: has_tag_exact matches full leaf path")
	assert_false(asc.has_tag_exact(&"State.Combat.Stunned"), "2.02: has_tag_exact fails on direct parent")
	assert_false(asc.has_tag_exact(&"State.Combat"), "2.03: has_tag_exact fails on grandparent")
	assert_false(asc.has_tag_exact(&"State"), "2.04: has_tag_exact fails on root")
	
	# Hierarchical Lookups
	assert_true(asc.has_tag(&"State.Combat.Stunned.Deep"), "2.05: has_tag matches exact leaf")
	assert_true(asc.has_tag(&"State.Combat.Stunned"), "2.06: has_tag matches parent prefix")
	assert_true(asc.has_tag(&"State.Combat"), "2.07: has_tag matches grandparent prefix")
	assert_true(asc.has_tag(&"State"), "2.08: has_tag matches root prefix")
	assert_false(asc.has_tag(&"State.Movement"), "2.09: has_tag rejects sibling branch")
	
	# Dot boundary safety (Avoid State.Comb matching State.Combat)
	asc.add_tag(&"State.CombatExtra")
	assert_false(asc.has_tag(&"State.Comb"), "2.10: has_tag does not match partial substring without dot delimiter")
	asc.clear_tag(&"State.CombatExtra")
	
	# Array helpers (has_any_tags / has_all_tags)
	var any_check_pass: Array[StringName] = [&"NonExistent.Tag", &"State.Combat"]
	var any_check_fail: Array[StringName] = [&"NonExistent.A", &"NonExistent.B"]
	assert_true(asc.has_any_tags(any_check_pass), "2.11: has_any_tags matches hierarchically")
	assert_false(asc.has_any_tags(any_check_fail), "2.12: has_any_tags fails when zero match")
	
	asc.add_tag(&"Element.Fire")
	var all_check_pass: Array[StringName] = [&"State", &"Element.Fire"]
	var all_check_fail: Array[StringName] = [&"State", &"Element.Ice"]
	assert_true(asc.has_all_tags(all_check_pass), "2.13: has_all_tags passes when every tag matches")
	assert_false(asc.has_all_tags(all_check_fail), "2.14: has_all_tags fails when one tag is missing")
	
	var empty_tags: Array[StringName] = []
	assert_false(asc.has_all_tags(empty_tags), "2.15: has_all_tags returns false on empty array")
	
	asc.clear_tag(&"State.Combat.Stunned.Deep")
	asc.clear_tag(&"Element.Fire")


# ---------------------------------------------------------
# Battery 3: GameplayTagQuery Permutations
# ---------------------------------------------------------
func _battery_tag_queries(asc: AbilitySystemComponent) -> void:
	print_rich("\n[color=yellow]--- Battery 3: GameplayTagQuery Combinatorial Engine ---[/color]")
	
	asc.add_tag(&"Status.Burning")
	asc.add_tag(&"Class.Mage.Pyromancer")
	
	# Require Any
	var q_any_pass := GameplayTagQuery.new()
	q_any_pass.require_any_tags = [&"Status.Poison", &"Class.Mage"]
	assert_true(q_any_pass.matches(asc), "3.01: Query require_any_tags matches hierarchical branch")
	
	var q_any_fail := GameplayTagQuery.new()
	q_any_fail.require_any_tags = [&"Status.Frozen", &"Class.Warrior"]
	assert_false(q_any_fail.matches(asc), "3.02: Query require_any_tags fails when disjoint")
	
	# Require All
	var q_all_pass := GameplayTagQuery.new()
	q_all_pass.require_all_tags = [&"Status.Burning", &"Class.Mage"]
	assert_true(q_all_pass.matches(asc), "3.03: Query require_all_tags matches all present branches")
	
	var q_all_fail := GameplayTagQuery.new()
	q_all_fail.require_all_tags = [&"Status.Burning", &"Class.Rogue"]
	assert_false(q_all_fail.matches(asc), "3.04: Query require_all_tags fails when one branch is missing")
	
	# Require Exact
	var q_exact_pass := GameplayTagQuery.new()
	q_exact_pass.require_exact_tags = [&"Class.Mage.Pyromancer"]
	assert_true(q_exact_pass.matches(asc), "3.05: Query require_exact_tags succeeds on full leaf match")
	
	var q_exact_fail := GameplayTagQuery.new()
	q_exact_fail.require_exact_tags = [&"Class.Mage"]
	assert_false(q_exact_fail.matches(asc), "3.06: Query require_exact_tags fails against parent node")
	
	# Ignore (Hierarchical)
	var q_ignore_fail := GameplayTagQuery.new()
	q_ignore_fail.ignore_tags = [&"Status"]
	assert_false(q_ignore_fail.matches(asc), "3.07: Query ignore_tags fails due to child of forbidden tag")
	
	var q_ignore_pass := GameplayTagQuery.new()
	q_ignore_pass.ignore_tags = [&"Status.Frozen"]
	assert_true(q_ignore_pass.matches(asc), "3.08: Query ignore_tags passes when forbidden branch is absent")
	
	# Ignore Exact
	var q_ignore_exact_pass := GameplayTagQuery.new()
	q_ignore_exact_pass.ignore_exact_tags = [&"Status"]
	assert_true(q_ignore_exact_pass.matches(asc), "3.09: Query ignore_exact_tags passes parent (only child present)")
	
	var q_ignore_exact_fail := GameplayTagQuery.new()
	q_ignore_exact_fail.ignore_exact_tags = [&"Status.Burning"]
	assert_false(q_ignore_exact_fail.matches(asc), "3.10: Query ignore_exact_tags fails on matching exact tag")
	
	# Complex multi-clause query: (Require Mage AND Burning) AND (Ignore Frozen)
	var q_complex := GameplayTagQuery.new()
	q_complex.require_all_tags = [&"Class.Mage", &"Status.Burning"]
	q_complex.ignore_tags = [&"Status.Frozen"]
	assert_true(q_complex.matches(asc), "3.11: Complex compound query passes valid setup")
	
	asc.add_tag(&"Status.Frozen")
	assert_false(q_complex.matches(asc), "3.12: Complex compound query immediately fails when ignored tag is acquired")
	
	# Edge: Null ASC test
	assert_false(q_complex.matches(null), "3.13: Query safely returns false when evaluated on null ASC")
	
	asc.clear_tag(&"Status.Burning")
	asc.clear_tag(&"Class.Mage.Pyromancer")
	asc.clear_tag(&"Status.Frozen")


# ---------------------------------------------------------
# Battery 4: Subsystem Edge Cases & API Boundaries
# ---------------------------------------------------------
func _battery_tag_edge_cases(asc: AbilitySystemComponent) -> void:
	print_rich("\n[color=yellow]--- Battery 4: Defensive Boundaries & Edge Cases ---[/color]")
	_reset_signal_buffers()
	
	# Removing a tag that was never granted
	asc.remove_tag(&"Ghost.Tag.NeverAdded")
	assert_eq(_tags_removed.size(), 0, "4.01: Removing ungranted tag does not crash or fire signals")
	
	# Clearing a tag that was never granted
	asc.clear_tag(&"Ghost.Tag.NeverAdded")
	assert_eq(_tags_removed.size(), 0, "4.02: Clearing ungranted tag does not crash or fire signals")
	
	# Duration remaining helper when tag has no effects attached
	var duration_empty = asc.get_tag_duration_remaining(&"State.Cooldown")
	assert_eq(duration_empty, 0.0, "4.03: get_tag_duration_remaining returns 0.0 when no effects exist")
	
	# Empty query matches empty ASC
	var empty_query := GameplayTagQuery.new()
	assert_true(empty_query.matches(asc), "4.04: Empty tag query matches an empty ASC without constraints")
