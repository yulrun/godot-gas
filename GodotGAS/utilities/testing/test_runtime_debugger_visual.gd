## Visual test suite for the GASRuntimeDebugger overlay.
##
## Mount this script on a Node2D in a test scene. It automatically constructs
## the AbilitySystemComponent and GASRuntimeDebugger child hierarchy, then executes
## timed visual test stages with 2.5-second pauses so each section update can be observed.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name TestRuntimeDebuggerVisual extends Node2D

#region Inner Mock Classes
## Mock AttributeSet providing core attributes for visual inspection.
class VisualTestAttributeSet extends AttributeSet:
	@export var health: AttributeData = AttributeData.new(100.0)
	@export var mana: AttributeData = AttributeData.new(50.0)
	@export var armor: AttributeData = AttributeData.new(0.0)


## Mock Ability that channels for 2 seconds to showcase ability state changes.
class VisualTestChannelAbility extends GameplayAbility:
	func _activate_ability() -> bool:
		commit_ability()
		await task_wait_delay(2.0)
		return true
#endregion


var _asc: AbilitySystemComponent
var _debugger: GASRuntimeDebugger
var _channel_ability: VisualTestChannelAbility


#region Lifecycle
func _ready() -> void:
	_setup_hierarchy()
	_print_expectations_manifest()
	_run_visual_suite()


## Builds the Node2D -> AbilitySystemComponent -> GASRuntimeDebugger hierarchy.
func _setup_hierarchy() -> void:
	_asc = AbilitySystemComponent.new()
	_asc.name = "AbilitySystemComponent"
	_asc.attribute_sets.append(VisualTestAttributeSet.new())
	add_child(_asc)

	# Adding the debugger as a direct child of the ASC validates the parent fallback
	_debugger = GASRuntimeDebugger.new()
	_debugger.name = "GASRuntimeDebugger"
	_asc.add_child(_debugger)

	_channel_ability = VisualTestChannelAbility.new()
	_channel_ability.ability_tag = &"Ability.Action.ChanneledCast"
	_asc.grant_ability(_channel_ability)
#endregion


#region Test Runner
## Executes each stage with delays to give human eyes time to observe the UI.
func _run_visual_suite() -> void:
	await get_tree().create_timer(1.0).timeout

	# Stage 1: Initial Baseline
	_log_stage(1, "Baseline Inspection: Default Attributes & Idle Ability")
	await get_tree().create_timer(2.5).timeout

	# Stage 2: Modify Attribute Base Values
	_log_stage(2, "Attribute Mutation: Deducting 35 Health and adding 20 Mana")
	_asc._apply_attribute_change("health", -35.0)
	_asc._apply_attribute_change("mana", 20.0)
	await get_tree().create_timer(2.5).timeout

	# Stage 3: Tag Reference Counting
	_log_stage(3, "Tag Addition: Adding State.Buff.Haste (Stack 1 then Stack 2)")
	_asc.add_tag(&"State.Buff.Haste")
	await get_tree().create_timer(1.0).timeout
	_asc.add_tag(&"State.Buff.Haste")
	await get_tree().create_timer(2.5).timeout

	# Stage 4: Duration Effect with Live Countdown
	_log_stage(4, "Duration Effect: Applying 5.0s Fortify (+30 Armor, Status.Buff.Shielded)")
	var fortify_mod := GameplayEffectModifier.new()
	fortify_mod.attribute_name = "armor"
	fortify_mod.operation = GameplayEffectModifier.Operation.ADD
	fortify_mod.magnitude = 30.0

	var fortify_effect := GameplayEffect.new()
	fortify_effect.resource_name = "FortifyEffect"
	fortify_effect.policy = GameplayEffect.DurationPolicy.DURATION
	fortify_effect.duration = 5.0
	fortify_effect.granted_tags.append(&"Status.Buff.Shielded")
	fortify_effect.modifiers.append(fortify_mod)
	_asc.apply_gameplay_effect(fortify_effect)
	await get_tree().create_timer(2.5).timeout

	# Stage 5: Infinite Effect & Ongoing Suppression
	_log_stage(5, "Inhibition: Applying Infinite Health Regeneration, then Suppressing with State.Debuff.Silence")
	var regen_mod := GameplayEffectModifier.new()
	regen_mod.attribute_name = "health"
	regen_mod.operation = GameplayEffectModifier.Operation.ADD
	regen_mod.magnitude = 25.0

	var silence_query := GameplayTagQuery.new()
	silence_query.require_exact_tags.append(&"State.Debuff.Silence")

	var regen_effect := GameplayEffect.new()
	regen_effect.resource_name = "AuraRegen"
	regen_effect.policy = GameplayEffect.DurationPolicy.INFINITE
	regen_effect.ongoing_suppression_query = silence_query
	regen_effect.modifiers.append(regen_mod)
	_asc.apply_gameplay_effect(regen_effect)

	await get_tree().create_timer(1.2).timeout
	_asc.add_tag(&"State.Debuff.Silence")
	await get_tree().create_timer(2.5).timeout

	# Stage 6: Unsuppress Effect
	_log_stage(6, "Unsuppress: Removing State.Debuff.Silence to restore AuraRegen")
	_asc.remove_tag(&"State.Debuff.Silence")
	await get_tree().create_timer(2.5).timeout

	# Stage 7: Ability Execution Lifecycle
	_log_stage(7, "Ability Lifecycle: Activating 2-second Channeled Ability")
	_channel_ability.try_activate()
	await get_tree().create_timer(2.5).timeout

	# Stage 8: Cleanup and Teardown
	_log_stage(8, "Purge / Reset: Clearing remaining tags")
	_asc.clear_tag(&"State.Buff.Haste")
	_asc.remove_effects_with_tag(&"Status.Buff.Shielded")
	await get_tree().create_timer(2.5).timeout

	print_rich("\n[b][color=green]=== Visual Test Suite Concluded Successfully ===[/color][/b]")
#endregion


#region Print Helpers
func _log_stage(number: int, description: String) -> void:
	print_rich("\n[color=yellow][STAGE %d][/color] [b]%s[/b]" % [number, description])


func _print_expectations_manifest() -> void:
	print_rich("\n[b][color=cyan]======================================================================[/color][/b]")
	print_rich("[b][color=cyan]          GASRuntimeDebugger Visual Test Verification Manifest       [/color][/b]")
	print_rich("[b][color=cyan]======================================================================[/color][/b]")
	print_rich("[b]Stage 1 (Baseline):[/b]")
	print_rich("  - ATTRIBUTES: Health: 100.0, Mana: 50.0, Armor: 0.0")
	print_rich("  - TAGS: [color=gray]No Active Tags[/color]")
	print_rich("  - ACTIVE EFFECTS: [color=gray]No Active Effects[/color]")
	print_rich("  - ABILITIES: Ability.Action.ChanneledCast: [color=gray]Idle[/color]")
	print_rich("\n[b]Stage 2 (Attribute Mutation):[/b]")
	print_rich("  - Health drops to [color=cyan]65.0[/color] (Base: 65.0)")
	print_rich("  - Mana increases to [color=cyan]70.0[/color] (Base: 70.0)")
	print_rich("\n[b]Stage 3 (Tag Counts):[/b]")
	print_rich("  - TAGS displays [b]State.Buff.Haste[/b] appearing, then incrementing to [color=yellow]x2[/color]")
	print_rich("\n[b]Stage 4 (Duration Effect):[/b]")
	print_rich("  - ACTIVE EFFECTS shows [b]FortifyEffect x1 (X.Xs)[/b] counting down in real-time")
	print_rich("  - Armor jumps to [color=cyan]30.0[/color]")
	print_rich("  - TAGS gains [b]Status.Buff.Shielded x1[/b]")
	print_rich("\n[b]Stage 5 (Inhibition / Suppression):[/b]")
	print_rich("  - ACTIVE EFFECTS shows [b]AuraRegen x1 (Infinite)[/b]")
	print_rich("  - Silence tag applied: AuraRegen appends [color=red](Suppressed)[/color]")
	print_rich("  - Health drops by 25.0 while suppressed")
	print_rich("\n[b]Stage 6 (Unsuppression):[/b]")
	print_rich("  - [color=red](Suppressed)[/color] label vanishes from AuraRegen")
	print_rich("  - Health re-aggregates back up by 25.0")
	print_rich("\n[b]Stage 7 (Ability Execution):[/b]")
	print_rich("  - Ability.Action.ChanneledCast status turns [color=green]Executing[/color]")
	print_rich("  - After 2.0s channel finishes, reverts to [color=gray]Idle[/color]")
	print_rich("\n[b]Stage 8 (Cleanup):[/b]")
	print_rich("  - State.Buff.Haste is removed from TAGS")
	print_rich("  - Expired duration effect cleanly vanishes from ACTIVE EFFECTS")
	print_rich("[b][color=cyan]======================================================================[/color][/b]\n")
#endregion
