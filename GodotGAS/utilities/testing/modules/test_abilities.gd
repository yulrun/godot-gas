## Self-contained exhaustive test suite for the GodotGAS Abilities Subsystem.
##
## Tests granting/revoking, code-first instantiation, costs, cooldowns, 
## queries, instancing policies, interruption matrices, input routing, activation tags, 
## granular commits, modular ability tasks, and visual target actors.
##
## @meta_addon: GodotGAS Version 1.1.0+
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name TestAbilities extends GASTestBase

# ---------------------------------------------------------
# Mock Classes for Testing Environment
# ---------------------------------------------------------
class AbilitiesAttributeSet extends AttributeSet:
	@export var mana: AttributeData = AttributeData.new(100.0)

class AbilitiesTestASC extends AbilitySystemComponent:
	var last_error: int = -1
	
	func _ready() -> void:
		super._ready()
		ability_activation_failed.connect(_on_fail)
		
	func _on_fail(_ability: GameplayAbility, reason: int, _payload: Dictionary) -> void:
		last_error = reason

class MockInstantAbility extends GameplayAbility:
	var activation_count: int = 0
	func _activate_ability() -> bool:
		activation_count += 1
		commit_ability()
		return true

class MockChanneledAbility extends GameplayAbility:
	var was_aborted: bool = false
	func _activate_ability() -> bool:
		commit_ability()
		await task_wait_delay(0.5)
		return true
	func end_ability(was_cancelled: bool = false) -> void:
		was_aborted = was_cancelled
		super.end_ability(was_cancelled)

class MockAsyncAbility extends GameplayAbility:
	var payload_captured: Variant = null
	func _activate_ability() -> bool:
		var p = await task_wait_for_event(&"Event.Test.Signal")
		payload_captured = p
		return true

class CodeFirstAbility extends GameplayAbility:
	var execution_count: int = 0
	func _activate_ability() -> bool:
		execution_count += 1
		return true

class MockTargetActor extends GameplayAbilityTargetActor:
	var _timer: SceneTreeTimer
	func start_targeting() -> void:
		_timer = get_tree().create_timer(0.1)
		_timer.timeout.connect(_on_timeout)
	func _on_timeout() -> void:
		var data = GameplayAbilityTargetData.new()
		confirm_target(data)

class MockTargetingAbility extends GameplayAbility:
	var hit_data: GameplayAbilityTargetData = null
	var targeting_scene: PackedScene = null
	func _activate_ability() -> bool:
		hit_data = await task_wait_for_target_data(targeting_scene)
		return hit_data != null


# ---------------------------------------------------------
# Global Test Tracking
# ---------------------------------------------------------
var _async_tracker: Dictionary = {}


func _ready() -> void:
	if get_parent() == get_tree().root:
		await run_all_tests()


func run_all_tests() -> void:
	print_header("GodotGAS Subsystem Test: Gameplay Abilities")
	
	# Stabilize the startup frame delta to protect async timers
	await get_tree().process_frame
	await get_tree().process_frame
	
	await _battery_1_granting_and_code_first()
	await _battery_2_costs_cooldowns_and_queries()
	await _battery_3_instancing_policies()
	await _battery_4_interruption_matrices()
	await _battery_5_async_tasks_and_input()
	await _battery_6_activation_owned_tags()
	await _battery_7_granular_commits_and_checks()
	await _battery_8_modular_ability_tasks()
	await _battery_9_targeting_actors()
	
	print_summary()


# ---------------------------------------------------------
# Battery 1: Granting, Revoking, and Code-First
# ---------------------------------------------------------
func _battery_1_granting_and_code_first() -> void:
	print_rich("\n[color=yellow]--- Battery 1: Granting, Revoking, and Code-First ---[/color]")
	
	var asc := AbilitiesTestASC.new()
	asc.name = "GrantASC"
	add_child(asc)
	
	# Standard Grant
	var instant_ab := MockInstantAbility.new()
	asc.grant_ability(instant_ab)
	assert_true(asc._active_abilities.has(instant_ab), "1.01: grant_ability successfully registers ability in ASC")
	assert_eq(instant_ab.owner_asc, asc, "1.02: Ability owner_asc reference correctly assigned")
	assert_eq(instant_ab.get_parent(), asc, "1.03: Ability successfully parented to ASC node")
	
	# Code-First Grant
	var cf_ab := asc.grant_ability_from_script(CodeFirstAbility) as CodeFirstAbility
	assert_true(cf_ab != null, "1.04: grant_ability_from_script successfully instantiates and returns a wrapper")
	assert_true(asc._active_abilities.has(cf_ab), "1.05: Code-First ability correctly registered in ASC")
	assert_eq(cf_ab.get_parent(), asc, "1.06: Code-First ability successfully parented to ASC node")
	
	# Revoke
	asc.remove_ability(instant_ab)
	assert_false(asc._active_abilities.has(instant_ab), "1.07: remove_ability successfully deregisters ability")
	assert_true(instant_ab.is_queued_for_deletion(), "1.08: removed ability is safely queued for deletion")
	
	asc.queue_free()


# ---------------------------------------------------------
# Battery 2: Costs, Cooldowns, and Queries
# ---------------------------------------------------------
func _battery_2_costs_cooldowns_and_queries() -> void:
	print_rich("\n[color=yellow]--- Battery 2: Costs, Cooldowns, and Activation Queries ---[/color]")
	
	var asc := AbilitiesTestASC.new()
	asc.name = "GatekeeperASC"
	asc.attribute_sets.append(AbilitiesAttributeSet.new())
	add_child(asc)
	
	asc.get_attribute("mana").current_value = 100.0
	
	var ability := MockInstantAbility.new()
	ability.ability_tag = &"Ability.Test"
	
	# 1. Activation Query Setup (Require 'State.Ready')
	var act_query := GameplayTagQuery.new()
	act_query.require_exact_tags.append(&"State.Ready")
	ability.activation_query = act_query
	
	# 2. Cost Setup (-60 Mana)
	var cost_mod := GameplayEffectModifier.new()
	cost_mod.attribute_name = "mana"
	cost_mod.operation = GameplayEffectModifier.Operation.ADD
	cost_mod.magnitude = -60.0
	var cost_ef := GameplayEffect.new()
	cost_ef.policy = GameplayEffect.DurationPolicy.INSTANT
	cost_ef.modifiers.append(cost_mod)
	ability.cost_effect = cost_ef
	
	# 3. Cooldown Setup (2s duration)
	var cd_ef := GameplayEffect.new()
	cd_ef.policy = GameplayEffect.DurationPolicy.DURATION
	cd_ef.duration = 2.0
	cd_ef.granted_tags.append(&"State.Cooldown")
	ability.cooldown_effect = cd_ef
	
	asc.grant_ability(ability)
	
	# Test Query Failure
	asc.last_error = -1
	var cast_fail_query = await ability.try_activate()
	assert_false(cast_fail_query, "2.01: Gatekeeper correctly denies activation if query fails")
	assert_eq(asc.last_error, AbilitySystemComponent.ActivationError.FAILED_QUERY, "2.02: ASC emits FAILED_QUERY enum code")
	
	# Satisfy Query
	asc.add_tag(&"State.Ready")
	asc.last_error = -1
	var cast_success = await ability.try_activate()
	assert_true(cast_success, "2.03: Gatekeeper allows activation when query is satisfied")
	assert_eq(asc.get_attribute("mana").current_value, 40.0, "2.04: Cost cleanly deducted upon commit (Mana 100 -> 40)")
	assert_true(asc.has_tag(&"State.Cooldown"), "2.05: Cooldown effect applied and tags granted")
	
	# Test Cooldown Failure
	var cast_fail_cd = await ability.try_activate()
	assert_false(cast_fail_cd, "2.06: Gatekeeper blocks activation while on cooldown")
	assert_eq(asc.last_error, AbilitySystemComponent.ActivationError.ON_COOLDOWN, "2.07: ASC emits ON_COOLDOWN enum code")
	
	# Purge Cooldown, test Resource Failure
	asc.remove_effects_with_tag(&"State.Cooldown")
	var cast_fail_cost = await ability.try_activate()
	assert_false(cast_fail_cost, "2.08: Gatekeeper blocks activation if predicted cost results in < 0 resources")
	assert_eq(asc.last_error, AbilitySystemComponent.ActivationError.INSUFFICIENT_RESOURCES, "2.09: ASC emits INSUFFICIENT_RESOURCES enum code")
	
	asc.queue_free()

	# Cost prediction uses the prospective base plus active modifiers.
	var buffed_asc := AbilitiesTestASC.new()
	buffed_asc.attribute_sets.append(AbilitiesAttributeSet.new())
	add_child(buffed_asc)
	var buff_mod := GameplayEffectModifier.new()
	buff_mod.attribute_name = "mana"
	buff_mod.operation = GameplayEffectModifier.Operation.MULTIPLY
	buff_mod.magnitude = 0.5
	var buff_effect := GameplayEffect.new()
	buff_effect.policy = GameplayEffect.DurationPolicy.INFINITE
	buff_effect.modifiers.append(buff_mod)
	buffed_asc.apply_gameplay_effect(buff_effect)
	assert_true(buffed_asc.can_afford_cost(cost_ef), "2.10: Cost prediction accounts for active multiplier")
	buffed_asc.apply_gameplay_effect(cost_ef)
	assert_eq(buffed_asc.get_attribute("mana").base_value, 40.0, "2.11: Cost deducts from base")
	assert_eq(buffed_asc.get_attribute("mana").current_value, 20.0, "2.12: Active multiplier applies to remaining base")
	assert_false(buffed_asc.can_afford_cost(cost_ef), "2.13: Cost rejects insufficient remaining base")
	var persistent_cost := GameplayEffect.new()
	persistent_cost.policy = GameplayEffect.DurationPolicy.INFINITE
	var persistent_cost_mod := GameplayEffectModifier.new()
	persistent_cost_mod.attribute_name = "mana"
	persistent_cost_mod.operation = GameplayEffectModifier.Operation.ADD
	persistent_cost_mod.magnitude = -100.0
	persistent_cost.modifiers.append(persistent_cost_mod)
	assert_false(buffed_asc.can_afford_cost(persistent_cost), "2.14: Persistent cost predicts combined modifiers")
	var override_mod := GameplayEffectModifier.new()
	override_mod.attribute_name = "mana"
	override_mod.operation = GameplayEffectModifier.Operation.OVERRIDE
	override_mod.magnitude = 100.0
	var override_effect := GameplayEffect.new()
	override_effect.policy = GameplayEffect.DurationPolicy.INFINITE
	override_effect.modifiers.append(override_mod)
	buffed_asc.apply_gameplay_effect(override_effect)
	assert_false(buffed_asc.can_afford_cost(cost_ef), "2.15: Override cannot conceal insufficient base resources")
	buffed_asc.queue_free()


# ---------------------------------------------------------
# Battery 3: Instancing Policies
# ---------------------------------------------------------
func _battery_3_instancing_policies() -> void:
	print_rich("\n[color=yellow]--- Battery 3: Instancing Policies ---[/color]")
	
	var asc := AbilitiesTestASC.new()
	asc.name = "InstanceASC"
	add_child(asc)
	
	_async_tracker.clear()
	
	# Test PER_ACTOR
	var actor_ab := MockChanneledAbility.new()
	actor_ab.ability_tag = &"Ability.Channeled.Actor"
	actor_ab.instancing_policy = GameplayAbility.InstancingPolicy.INSTANCED_PER_ACTOR
	asc.grant_ability(actor_ab)
	
	_fire_async_task(actor_ab, "actor_1")
	_fire_async_task(actor_ab, "actor_2")
	
	await get_tree().process_frame
	assert_eq(_async_tracker.get("actor_2", true), false, "3.01: PER_ACTOR policy instantly blocks overlapping casts")
	
	# Test PER_EXECUTION
	var exec_ab := MockChanneledAbility.new()
	exec_ab.ability_tag = &"Ability.Channeled.Exec"
	exec_ab.instancing_policy = GameplayAbility.InstancingPolicy.INSTANCED_PER_EXECUTION
	asc.grant_ability(exec_ab)
	
	_fire_async_task(exec_ab, "exec_1")
	_fire_async_task(exec_ab, "exec_2")
	
	await get_tree().process_frame # Let clones spawn
	var clones = 0
	for child in asc.get_children():
		if child is GameplayAbility and child.ability_tag == &"Ability.Channeled.Exec" and child != exec_ab:
			clones += 1
	assert_eq(clones, 2, "3.02: PER_EXECUTION policy spawns transient duplicate nodes for overlapping casts")
	
	# Wait for all channeled abilities to conclude (0.5s channel + safety)
	await get_tree().create_timer(0.7).timeout
	
	assert_eq(_async_tracker.get("actor_1", false), true, "3.03: PER_ACTOR first cast finishes successfully")
	assert_eq(_async_tracker.get("exec_1", false), true, "3.04: PER_EXECUTION clone 1 finishes successfully")
	assert_eq(_async_tracker.get("exec_2", false), true, "3.05: PER_EXECUTION clone 2 finishes successfully")
	
	await get_tree().process_frame # Let queue_free resolve
	var remaining_clones = 0
	for child in asc.get_children():
		if child is GameplayAbility and child.ability_tag == &"Ability.Channeled.Exec" and child != exec_ab:
			remaining_clones += 1
	assert_eq(remaining_clones, 0, "3.06: Transient clones dynamically purge themselves from memory")
	
	asc.queue_free()


# ---------------------------------------------------------
# Battery 4: Interruption & Blocking Matrices
# ---------------------------------------------------------
func _battery_4_interruption_matrices() -> void:
	print_rich("\n[color=yellow]--- Battery 4: Interruption & Blocking Matrices ---[/color]")
	
	var asc := AbilitiesTestASC.new()
	asc.name = "MatrixASC"
	add_child(asc)
	
	var sprint := MockChanneledAbility.new()
	sprint.ability_tag = &"Movement.Sprint"
	sprint.block_abilities_with_tags.append(&"Action")
	asc.grant_ability(sprint)
	
	var shoot := MockInstantAbility.new()
	shoot.ability_tag = &"Action.Shoot"
	asc.grant_ability(shoot)
	
	var interrupt := MockInstantAbility.new()
	interrupt.ability_tag = &"Spell.Interrupt"
	interrupt.cancel_abilities_with_tags.append(&"Movement")
	asc.grant_ability(interrupt)
	
	_fire_async_task(sprint, "sprint")
	await get_tree().process_frame # Let sprint channel
	
	asc.last_error = -1
	var shoot_cast = await shoot.try_activate()
	assert_false(shoot_cast, "4.01: Hierarchical blocking matrix successfully prevents activation")
	assert_eq(asc.last_error, AbilitySystemComponent.ActivationError.BLOCKED_BY_OTHER_ABILITY, "4.02: Gatekeeper correctly throws BLOCKED_BY_OTHER_ABILITY error")
	
	var interrupt_cast = await interrupt.try_activate()
	assert_true(interrupt_cast, "4.03: Interruption spell casts successfully")
	assert_true(sprint.was_aborted, "4.04: Hierarchical cancellation matrix successfully aborts the channeled ability")
	
	asc.queue_free()


# ---------------------------------------------------------
# Battery 5: Async Tasks & Input Routing
# ---------------------------------------------------------
func _battery_5_async_tasks_and_input() -> void:
	print_rich("\n[color=yellow]--- Battery 5: Async Tasks & Input Routing ---[/color]")
	
	var asc := AbilitiesTestASC.new()
	asc.name = "InputASC"
	add_child(asc)
	
	_async_tracker.clear()
	
	# Async Task Execution (Testing the wrapper logic)
	var async_ab := MockAsyncAbility.new()
	async_ab.ability_tag = &"Ability.WaitEvent"
	asc.grant_ability(async_ab)
	
	_fire_async_task(async_ab, "async")
	await get_tree().process_frame # Yield so ability can spawn task node and wait
	
	assert_false(_async_tracker.has("async"), "5.01: task_wait_for_event wrapper correctly yields ability thread without blocking")
	
	# Send incorrect event
	asc.send_gameplay_event(&"Event.Ghost", {"data": 0})
	await get_tree().process_frame
	assert_false(_async_tracker.has("async"), "5.02: task_wait_for_event safely ignores unmatched event tags")
	
	# Send correct event
	asc.send_gameplay_event(&"Event.Test.Signal", {"damage": 50})
	await get_tree().process_frame
	assert_true(_async_tracker.has("async"), "5.03: task_wait_for_event resumes when exact tag is intercepted")
	assert_eq(async_ab.payload_captured.get("damage", 0), 50, "5.04: task_wait_for_event correctly captures and returns the payload")
	
	# Input Routing & Concurrent Tags
	var input_ab_1 := MockInstantAbility.new()
	input_ab_1.ability_tag = &"Ability.Input"
	asc.grant_ability(input_ab_1)
	
	var input_ab_2 := MockInstantAbility.new()
	input_ab_2.ability_tag = &"Ability.Input"
	asc.grant_ability(input_ab_2)
	
	# Test Input Execution
	asc.bind_ability_to_input(input_ab_1, 1, true)
	asc.ability_local_input_pressed(1)
	await get_tree().process_frame
	assert_eq(input_ab_1.activation_count, 1, "5.05: Input routing successfully activates bound ability")
	
	# Test Concurrent Tag Activation
	var activated_any = asc.try_activate_abilities_by_tag(&"Ability.Input")
	await get_tree().process_frame
	assert_true(activated_any, "5.06: try_activate_abilities_by_tag reports success")
	assert_eq(input_ab_1.activation_count, 2, "5.07: try_activate_abilities_by_tag triggered first instance")
	assert_eq(input_ab_2.activation_count, 1, "5.08: try_activate_abilities_by_tag triggered second instance concurrently")

	asc.queue_free()


# ---------------------------------------------------------
# Battery 6: Activation-Owned Tags
# ---------------------------------------------------------
func _battery_6_activation_owned_tags() -> void:
	print_rich("\n[color=yellow]--- Battery 6: Activation-Owned Tags ---[/color]")
	
	var asc := AbilitiesTestASC.new()
	asc.name = "OwnedTagsASC"
	add_child(asc)
	
	var ability := MockChanneledAbility.new()
	ability.ability_tag = &"Ability.Action.OwnedTags"
	ability.activation_owned_tags.append(&"State.Attacking")
	asc.grant_ability(ability)
	
	_fire_async_task(ability, "owned_tags")
	await get_tree().process_frame # Let channel begin
	
	assert_true(asc.has_tag(&"State.Attacking"), "6.01: ASC successfully gained activation_owned_tags upon ability start")
	
	ability.end_ability()
	assert_false(asc.has_tag(&"State.Attacking"), "6.02: ASC successfully lost activation_owned_tags upon ability end")
	
	asc.queue_free()


# ---------------------------------------------------------
# Battery 7: Granular Commits and Dynamic Checks
# ---------------------------------------------------------
func _battery_7_granular_commits_and_checks() -> void:
	print_rich("\n[color=yellow]--- Battery 7: Granular Commits and Dynamic Checks ---[/color]")
	
	var asc := AbilitiesTestASC.new()
	asc.name = "GranularASC"
	asc.attribute_sets.append(AbilitiesAttributeSet.new())
	add_child(asc)
	
	asc.get_attribute("mana").current_value = 100.0
	
	var ability := MockInstantAbility.new()
	ability.ability_tag = &"Ability.Granular"
	
	var cost_mod := GameplayEffectModifier.new()
	cost_mod.attribute_name = "mana"
	cost_mod.operation = GameplayEffectModifier.Operation.ADD
	cost_mod.magnitude = -20.0
	var cost_ef := GameplayEffect.new()
	cost_ef.policy = GameplayEffect.DurationPolicy.INSTANT
	cost_ef.modifiers.append(cost_mod)
	ability.cost_effect = cost_ef
	
	var cd_ef := GameplayEffect.new()
	cd_ef.policy = GameplayEffect.DurationPolicy.DURATION
	cd_ef.duration = 2.0
	cd_ef.granted_tags.append(&"State.Cooldown.Granular")
	ability.cooldown_effect = cd_ef
	
	asc.grant_ability(ability)
	
	# Test decoupled check and commit
	assert_true(ability.check_cost(), "7.01: check_cost() evaluates independently to true")
	ability.commit_cost()
	assert_eq(asc.get_attribute("mana").current_value, 80.0, "7.02: commit_cost() applies only resource deduction without cooldown")
	assert_false(asc.has_tag(&"State.Cooldown.Granular"), "7.03: Cooldown remains unapplied after commit_cost")
	
	assert_true(ability.check_cooldown(), "7.04: check_cooldown() evaluates independently to true")
	ability.commit_cooldown()
	assert_true(asc.has_tag(&"State.Cooldown.Granular"), "7.05: commit_cooldown() independently applies cooldown tags")
	assert_false(ability.check_cooldown(), "7.06: check_cooldown() evaluates independently to false after commit")
	
	asc.queue_free()


# ---------------------------------------------------------
# Battery 8: Modular Ability Tasks & Cancellation
# ---------------------------------------------------------
func _battery_8_modular_ability_tasks() -> void:
	print_rich("\n[color=yellow]--- Battery 8: Modular Ability Tasks & Cancellation ---[/color]")
	
	var asc := AbilitiesTestASC.new()
	asc.name = "TaskASC"
	add_child(asc)
	
	var channel_ab := MockChanneledAbility.new() # uses task_wait_delay(0.5)
	channel_ab.ability_tag = &"Ability.Channeled"
	asc.grant_ability(channel_ab)
	
	_fire_async_task(channel_ab, "task_test")
	
	# Wait 2 frames so the task is cleanly instantiated and added to the tree
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Find the task node
	var found_task: Node = null
	for child in channel_ab.get_children():
		if child is AbilityTask:
			found_task = child
			break
			
	assert_true(found_task != null, "8.01: Legacy task_wait_delay automatically spawns an AbilityTask child node")
	
	# Abort the ability while the task is still actively yielding
	channel_ab.abort_ability()
	
	await get_tree().process_frame
	
	assert_false(is_instance_valid(found_task) and not found_task.is_queued_for_deletion(), "8.02: AbilityTask node instantly queued for deletion upon parent ability abort")
	
	asc.queue_free()


# ---------------------------------------------------------
# Battery 9: Targeting Actors & Visual Reticles
# ---------------------------------------------------------
func _battery_9_targeting_actors() -> void:
	print_rich("\n[color=yellow]--- Battery 9: Targeting Actors & Visual Reticles ---[/color]")
	
	var avatar := Node.new()
	add_child(avatar)
	
	var asc := AbilitiesTestASC.new()
	asc.name = "TargetASC"
	avatar.add_child(asc)
	
	var pack := PackedScene.new()
	var mock_actor := MockTargetActor.new()
	mock_actor.name = "MockTargetActor"
	pack.pack(mock_actor)
	mock_actor.queue_free()
	
	var targeting_ab := MockTargetingAbility.new()
	targeting_ab.ability_tag = &"Ability.Targeting"
	targeting_ab.targeting_scene = pack
	asc.grant_ability(targeting_ab)
	
	_fire_async_task(targeting_ab, "targeting_test")
	
	# Yield long enough for the AbilityTask to dynamically spawn the actor
	await get_tree().process_frame
	await get_tree().process_frame
	
	var spawned_actor = avatar.get_node_or_null("MockTargetActor")
	assert_true(spawned_actor != null, "9.01: Targeting task dynamically instantiated the visual reticle scene and attached it to the Avatar")
	
	# Wait for the MockTargetActor's 0.1s timer to expire and confirm its own hit
	await get_tree().create_timer(0.15).timeout
	
	assert_true(targeting_ab.hit_data != null, "9.02: Ability correctly received the target data payload upon reticle confirmation")
	assert_false(is_instance_valid(spawned_actor) and not spawned_actor.is_queued_for_deletion(), "9.03: Target task safely cleaned up the visual reticle from the world upon completion")
	
	# Test Interruption & GC Cleanup
	var cancel_ab := MockTargetingAbility.new()
	cancel_ab.ability_tag = &"Ability.Targeting.Cancel"
	cancel_ab.targeting_scene = pack
	asc.grant_ability(cancel_ab)
	
	_fire_async_task(cancel_ab, "targeting_cancel_test")
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var abort_actor = avatar.get_node_or_null("MockTargetActor")
	assert_true(abort_actor != null, "9.04: Second reticle successfully spawned")
	
	# Forcefully stun/cancel the player while they are aiming the reticle
	cancel_ab.abort_ability()
	
	await get_tree().process_frame
	
	assert_false(is_instance_valid(abort_actor) and not abort_actor.is_queued_for_deletion(), "9.05: Interrupted ability safely memory-managed the target actor and prevented orphans")
	
	avatar.queue_free()


# ---------------------------------------------------------
# Utilities
# ---------------------------------------------------------
func _fire_async_task(ability: GameplayAbility, id: String) -> void:
	var result = await ability.try_activate()
	_async_tracker[id] = result
