## GAS - Demo Project: Phase 1, Scene 3
## Demonstrates dynamic runtime math using SetByCaller injection
## and Attribute-Based scaling (Target's Armor).

extends Control

@onready var lbl_health: Label = $VBoxContainer/Stats/LblHealth
@onready var lbl_armor: Label = $VBoxContainer/Stats/LblArmor
@onready var lbl_slider: Label = $VBoxContainer/Inputs/LblSlider
@onready var slider_damage: HSlider = $VBoxContainer/Inputs/SliderDamage
@onready var btn_dynamic_damage: Button = $VBoxContainer/Actions/BtnDynamicDamage
@onready var btn_armor_heal: Button = $VBoxContainer/Actions/BtnArmorHeal
@onready var lbl_log: RichTextLabel = $VBoxContainer/LblLog

var asc: AbilitySystemComponent

var sbc_damage_effect: GameplayEffect
var attr_based_heal_effect: GameplayEffect

#region Lifecycle & Setup
func _ready() -> void:
	_setup_asc()
	_build_effects()
	_setup_ui_connections()
	_update_ui()
	_log_message("Dynamic Math Engine Initialized.", "cyan")


func _setup_asc() -> void:
	asc = AbilitySystemComponent.new()
	asc.name = "PlayerASC"
	
	var attributes := DemoAttributeSet.new()
	asc.attribute_sets.append(attributes)
	add_child(asc)
	
	# The correct way to inject starting stats dynamically
	var starting_stats: Dictionary[String, float] = {
		"health": 100.0,
		"armor": 60.0
	}
	asc.initialize_attribute_overrides(starting_stats)
	
	var debugger := GASRuntimeDebugger.new()
	debugger.name = "GASRuntimeDebugger"
	debugger.target_asc = asc
	debugger.dock_position = GASRuntimeDebugger.DockPosition.TOP_RIGHT
	add_child(debugger)
	
	asc.attribute_changed.connect(_on_attribute_changed)


func _build_effects() -> void:
	# --- 1. SET BY CALLER DAMAGE EFFECT ---
	# Instructs the ASC to ignore hardcoded numbers and wait for a dynamic payload
	# keyed to the "Data.Damage" tag at runtime. This allows you to pass in random
	# weapon damage rolls or UI slider values.
	var sbc_mod := GameplayEffectModifier.new()
	sbc_mod.attribute_name = "health"
	sbc_mod.operation = GameplayEffectModifier.Operation.ADD
	sbc_mod.magnitude_calculation = GameplayEffectModifier.MagnitudeCalculationType.SET_BY_CALLER
	sbc_mod.set_by_caller_tag = &"Data.Damage" # The 'Key' we use to inject the value later
	
	sbc_damage_effect = GameplayEffect.new()
	sbc_damage_effect.resource_name = "Dynamic Damage"
	sbc_damage_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	sbc_damage_effect.modifiers.append(sbc_mod)
	
	# --- 2. ATTRIBUTE BASED HEAL EFFECT ---
	# Instructs the ASC to dynamically look at the Target's currently buffed Armor value,
	# multiply that number by 0.5 (50%), and add the result to the Target's Health.
	var attr_mod := GameplayEffectModifier.new()
	attr_mod.attribute_name = "health"
	attr_mod.operation = GameplayEffectModifier.Operation.ADD
	
	attr_mod.magnitude_calculation = GameplayEffectModifier.MagnitudeCalculationType.ATTRIBUTE_BASED
	attr_mod.attribute_source = GameplayEffectModifier.AttributeSource.TARGET
	attr_mod.backing_attribute_name = "armor"
	attr_mod.attribute_capture_type = GameplayEffectModifier.AttributeCaptureType.CURRENT_VALUE # Reads buffed total, not unbuffed base
	attr_mod.attribute_multiplier = 0.5 # 50% scaling
	
	attr_based_heal_effect = GameplayEffect.new()
	attr_based_heal_effect.resource_name = "Armor-Scaling Heal"
	attr_based_heal_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	attr_based_heal_effect.modifiers.append(attr_mod)


func _setup_ui_connections() -> void:
	# Keep the slider label updated as the user drags it
	slider_damage.value_changed.connect(func(value: float):
		lbl_slider.text = "SetByCaller Damage: %.1f" % value
	)
	
	btn_dynamic_damage.pressed.connect(func():
		var damage_val: float = slider_damage.value
		_log_message("Injecting SetByCaller magnitude: -%.1f" % damage_val, "gray")
		
		# To pass dynamic SetByCaller math, we MUST manually create a GameplayEffectSpec wrapper
		# because we cannot mutate the base Resource definition.
		var context := GameplayEffectContext.new(asc)
		var spec := GameplayEffectSpec.new(sbc_damage_effect, context, 1.0)
		
		# Inject the negative damage value matching the exact tag we defined in the modifier
		spec.set_set_by_caller_magnitude(&"Data.Damage", -damage_val)
		
		# Apply the fully configured Spec to the ASC
		asc.apply_effect_spec(spec)
	)
	
	btn_armor_heal.pressed.connect(func():
		_log_message("Applying Attribute-Based Heal (50% of Armor)...", "gray")
		# We don't need a custom Spec for Attribute-Based scaling, the ASC calculates it automatically!
		asc.apply_gameplay_effect(attr_based_heal_effect, asc, 1.0)
	)
#endregion

#region Event Responders & UI
func _on_attribute_changed(_attribute_name: String, _old_value: float, _new_value: float, spec: GameplayEffectSpec) -> void:
	_update_ui()
	
	# We can dynamically inspect the calculated deltas inside the Spec payload
	# to see exactly how much health was changed after safety clamps were applied.
	if spec and spec.calculated_deltas.has("health"):
		var delta_health: float = spec.calculated_deltas["health"]
		var color := "green" if delta_health > 0 else "red"
		_log_message("-> Health modified by: [color=%s]%+.1f[/color]" % [color, delta_health])


func _update_ui() -> void:
	var health_attr = asc.get_attribute("health")
	var armor_attr = asc.get_attribute("armor")
	
	if health_attr and armor_attr:
		lbl_health.text = "Health: %.1f / 100" % health_attr.current_value
		lbl_armor.text = "Armor: %.1f" % armor_attr.current_value


func _log_message(msg: String, color: String = "white") -> void:
	lbl_log.text += "[color=%s]%s[/color]\n" % [color, msg]
#endregion
