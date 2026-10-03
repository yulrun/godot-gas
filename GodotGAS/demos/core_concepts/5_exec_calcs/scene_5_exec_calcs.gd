## GAS - Demo Project: Phase 1, Scene 5
## Demonstrates GameplayExecutionCalculations (ExecCalcs).
## ExecCalcs allow you to write complex, custom GDScript formulas for effects
## (e.g., Final Damage = Attack Power - Target Armor) rather than relying on
## simple addition or multiplication in the Inspector.

extends Control

@onready var lbl_health: Label = $VBoxContainer/Stats/LblHealth
@onready var lbl_armor: Label = $VBoxContainer/Stats/LblArmor
@onready var lbl_power: Label = $VBoxContainer/Inputs/LblPower
@onready var slider_power: HSlider = $VBoxContainer/Inputs/SliderPower
@onready var btn_attack: Button = $VBoxContainer/Actions/BtnAttack
@onready var btn_armor: Button = $VBoxContainer/Actions/BtnArmor
@onready var lbl_log: RichTextLabel = $VBoxContainer/LblLog

var defender_asc: AbilitySystemComponent
var exec_calc_effect: GameplayEffect
var buff_armor_effect: GameplayEffect

#region Inner ExecCalc Class
## This is where the magic happens. We extend GameplayExecutionCalculation
## and override the execute() function to write our custom RPG math.
class RPGDamageCalculation extends GameplayExecutionCalculation:
	
	## Called by the ASC when the effect is applied.
	## Takes the live Spec (containing our dynamic variables) and the Target's ASC.
	## Must return a Dictionary of exact numerical changes to apply to attributes.
	func execute(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
		# 1. Fetch the incoming Attack Power we injected via SetByCaller in the UI.
		var attack_power: float = spec.get_set_by_caller_magnitude(&"Data.Damage", 0.0)
		
		# 2. Fetch the Defender's current buffed Armor value.
		var armor: float = 0.0
		var armor_attr = target_asc.get_attribute("armor")
		if armor_attr:
			armor = armor_attr.current_value
			
		# 3. Perform our custom math!
		# Formula: Damage = Attack Power - Armor. (If armor is too high, deal a minimum of 1 damage).
		var final_damage: float = maxf(1.0, attack_power - armor)
		
		# 4. Return the calculated delta. 
		# We use negative final_damage because we are subtracting from health.
		return {
			"health": -final_damage
		}
#endregion

#region Lifecycle & Setup
func _ready() -> void:
	_setup_asc()
	_build_effects()
	_setup_ui_connections()
	_update_ui()
	_log_message("Execution Calculation Engine Initialized.", "cyan")


func _setup_asc() -> void:
	defender_asc = AbilitySystemComponent.new()
	defender_asc.name = "DefenderASC"
	
	var attributes := DemoAttributeSet.new()
	defender_asc.attribute_sets.append(attributes)
	add_child(defender_asc)
	
	# Start the defender with 100 Health and 10 base Armor
	var starting_stats: Dictionary[String, float] = {
		"health": 100.0,
		"armor": 10.0
	}
	defender_asc.initialize_attribute_overrides(starting_stats)
	
	var debugger := GASRuntimeDebugger.new()
	debugger.name = "GASRuntimeDebugger"
	debugger.target_asc = defender_asc
	debugger.dock_position = GASRuntimeDebugger.DockPosition.TOP_RIGHT
	add_child(debugger)
	
	defender_asc.attribute_changed.connect(_on_attribute_changed)


func _build_effects() -> void:
	# --- 1. THE EXECUTION CALCULATION EFFECT ---
	exec_calc_effect = GameplayEffect.new()
	exec_calc_effect.resource_name = "ExecCalc Attack"
	exec_calc_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	
	# Instead of adding Modifiers, we append an instance of our custom RPGDamageCalculation.
	# The ASC will run our GDScript formula instead of looking at static modifier math.
	var rpg_calc := RPGDamageCalculation.new()
	exec_calc_effect.executions.append(rpg_calc)
	
	# --- 2. INFINITE ARMOR BUFF ---
	# Used to demonstrate how the ExecCalc dynamically reacts to changing target stats.
	var armor_mod := GameplayEffectModifier.new()
	armor_mod.attribute_name = "armor"
	armor_mod.operation = GameplayEffectModifier.Operation.ADD
	armor_mod.magnitude = 5.0
	
	buff_armor_effect = GameplayEffect.new()
	buff_armor_effect.resource_name = "Armor Buff"
	buff_armor_effect.policy = GameplayEffect.DurationPolicy.INFINITE
	buff_armor_effect.modifiers.append(armor_mod)


func _setup_ui_connections() -> void:
	slider_power.value_changed.connect(func(value: float):
		lbl_power.text = "Incoming Attack Power: %.1f" % value
	)
	
	btn_attack.pressed.connect(func():
		var atk_power: float = slider_power.value
		var armor: float = defender_asc.get_attribute("armor").current_value if defender_asc.has_attribute("armor") else 0.0
		
		_log_message("Incoming Attack! Power: %.1f vs Armor: %.1f" % [atk_power, armor], "gray")
		
		# Build the Spec and inject the Attack Power so our ExecCalc can read it.
		var context := GameplayEffectContext.new(defender_asc)
		var spec := GameplayEffectSpec.new(exec_calc_effect, context, 1.0)
		spec.set_set_by_caller_magnitude(&"Data.Damage", atk_power)
		
		# Apply it! The ASC will fire execute() on our RPGDamageCalculation.
		defender_asc.apply_effect_spec(spec)
	)
	
	btn_armor.pressed.connect(func():
		_log_message("Buffed Armor (+5). Watch the ExecCalc adapt!", "cyan")
		# Because this is INFINITE with default FREE stacking, 
		# every click adds another persistent +5 armor wrapper to the ASC.
		defender_asc.apply_gameplay_effect(buff_armor_effect, defender_asc, 1.0)
	)
#endregion

#region Event Responders & UI
func _on_attribute_changed(attribute_name: String, _old_value: float, _new_value: float, spec: GameplayEffectSpec) -> void:
	_update_ui()
	
	# Intercept and log damage dealt specifically by the ExecCalc
	if attribute_name == "health" and spec and spec.effect_def == exec_calc_effect:
		var delta: float = spec.calculated_deltas.get("health", 0.0)
		_log_message("-> ExecCalc Formula evaluated. Dealt [color=red]%.1f Damage[/color]!" % abs(delta))


func _update_ui() -> void:
	var health_attr = defender_asc.get_attribute("health")
	var armor_attr = defender_asc.get_attribute("armor")
	
	if health_attr and armor_attr:
		lbl_health.text = "Defender Health: %.1f / 100" % health_attr.current_value
		lbl_armor.text = "Defender Armor: %.1f" % armor_attr.current_value


func _log_message(msg: String, color: String = "white") -> void:
	lbl_log.text += "[color=%s]%s[/color]\n" % [color, msg]
#endregion
