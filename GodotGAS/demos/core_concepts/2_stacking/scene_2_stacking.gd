## GAS - Demo Project : Phase 1, Scene 2
## Demonstrates REFRESH_DURATION stacking, stack limits, overflow payloads,
## OVERRIDE modifiers, application queries, and the Cleanser pattern.

extends Control

@onready var lbl_speed: Label = $VBoxContainer/Stats/LblSpeed
@onready var btn_chill: Button = $VBoxContainer/Actions/BtnChill
@onready var btn_thaw: Button = $VBoxContainer/Actions/BtnThaw
@onready var lbl_log: RichTextLabel = $VBoxContainer/LblLog

var asc: AbilitySystemComponent

var chill_effect: GameplayEffect
var frozen_effect: GameplayEffect
var thaw_effect: GameplayEffect

#region Lifecycle & Setup
func _ready() -> void:
	_setup_asc()
	_build_effects()
	_setup_ui_connections()
	_update_ui()
	_log_message("Stacking Engine Initialized. Ready to apply effects.", "cyan")


func _setup_asc() -> void:
	asc = AbilitySystemComponent.new()
	asc.name = "PlayerASC"
	
	var attributes := DemoAttributeSet.new()
	asc.attribute_sets.append(attributes)
	add_child(asc)
	
	# Inject the starting movement speed dynamically so UI catches the change
	var starting_stats: Dictionary[String, float] = {
		"movement_speed": 300.0
	}
	asc.initialize_attribute_overrides(starting_stats)
	
	# Dock the Visual Debugger to watch the live stack counts and duration refreshes
	var debugger := GASRuntimeDebugger.new()
	debugger.name = "GASRuntimeDebugger"
	debugger.target_asc = asc
	debugger.dock_position = GASRuntimeDebugger.DockPosition.TOP_RIGHT
	add_child(debugger)
	
	asc.attribute_changed.connect(_on_attribute_changed)
	asc.tag_added.connect(_on_tag_added)


func _build_effects() -> void:
	# --- 1. OVERFLOW PAYLOAD (FROZEN) ---
	# This effect applies an OVERRIDE to movement_speed, forcing it to exactly 0.0,
	# bypassing any other math or base speed calculations.
	var freeze_mod := GameplayEffectModifier.new()
	freeze_mod.attribute_name = "movement_speed"
	freeze_mod.operation = GameplayEffectModifier.Operation.OVERRIDE
	freeze_mod.magnitude = 0.0
	
	frozen_effect = GameplayEffect.new()
	frozen_effect.resource_name = "Frozen"
	frozen_effect.policy = GameplayEffect.DurationPolicy.INFINITE
	frozen_effect.modifiers.append(freeze_mod)
	frozen_effect.granted_tags.append(GameplayTags.Status_Debuff_Frozen)
	
	# --- 2. STACKING PAYLOAD (CHILL) ---
	# This effect stacks up to 3 times. A 4th application triggers the overflow and clears these stacks.
	
	# The Application Query prevents this effect from applying if the target is already Frozen.
	# We don't want to chill a target that is already trapped in ice!
	var chill_query := GameplayTagQuery.new()
	chill_query.ignore_tags.append(GameplayTags.Status_Debuff_Frozen)
	
	var chill_mod := GameplayEffectModifier.new()
	chill_mod.attribute_name = "movement_speed"
	chill_mod.operation = GameplayEffectModifier.Operation.ADD
	chill_mod.magnitude = -50.0
	
	chill_effect = GameplayEffect.new()
	chill_effect.resource_name = "Chilled"
	chill_effect.policy = GameplayEffect.DurationPolicy.DURATION
	chill_effect.duration = 4.0
	
	# REFRESH_DURATION means applying a new stack resets the 4.0s timer back to full.
	chill_effect.stacking_policy = GameplayEffect.StackingPolicy.REFRESH_DURATION
	chill_effect.max_stacks = 3
	chill_effect.clear_stack_on_overflow = true
	chill_effect.application_query = chill_query
	chill_effect.modifiers.append(chill_mod)
	chill_effect.granted_tags.append(GameplayTags.Status_Debuff_Chilled)
	
	# Link the overflow so the system knows what to apply when max_stacks is breached
	chill_effect.overflow_effects.append(frozen_effect)
	
	# --- 3. CLEANSER PAYLOAD (THAW) ---
	# An instant effect that purges any active effect currently granting the 'Frozen' tag.
	# This demonstrates the 'Cleanser Pattern' common in RPGs (e.g., Antidote removing Poison).
	thaw_effect = GameplayEffect.new()
	thaw_effect.resource_name = "Thaw Cleanser"
	thaw_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	thaw_effect.remove_effects_with_tags.append(GameplayTags.Status_Debuff_Frozen)


func _setup_ui_connections() -> void:
	btn_chill.pressed.connect(func():
		_log_message("Attempting to apply Chill Stack...", "gray")
		var active_eff = asc.apply_gameplay_effect(chill_effect, asc, 1.0)
		
		# Check if the effect successfully applied (i.e. the Application Query passed)
		if active_eff:
			_log_message("Chill Stack applied! Current Stacks: %d" % active_eff.stack_count, "cyan")
		else:
			# If it returned null, we know the application query blocked it because the target had the Frozen tag
			_log_message("Cannot chill a frozen target!", "red")
	)
	
	btn_thaw.pressed.connect(func():
		_log_message("Casting Thaw Cleanser...", "gray")
		asc.apply_gameplay_effect(thaw_effect, asc, 1.0)
		_log_message("Thaw complete. If Frozen was present, it has been purged.", "green")
	)
#endregion

#region Event Responders & UI
func _on_attribute_changed(_attribute_name: String, _old_value: float, _new_value: float, _spec: GameplayEffectSpec) -> void:
	_update_ui()


func _on_tag_added(tag: StringName) -> void:
	# Listen for the exact moment the overflow tag hits the system
	if tag == GameplayTags.Status_Debuff_Frozen:
		_log_message("CRITICAL: Stack limit breached! OVERFLOW triggered! Target is now FROZEN.", "orange")


func _update_ui() -> void:
	var speed_attr = asc.get_attribute("movement_speed")
	if speed_attr:
		lbl_speed.text = "Movement Speed: %.1f" % speed_attr.current_value


func _log_message(msg: String, color: String = "white") -> void:
	lbl_log.text += "[color=%s]%s[/color]\n" % [color, msg]
#endregion
