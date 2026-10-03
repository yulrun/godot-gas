## GAS - Demo Project : Phase 1, Scene 1
## Demonstrates dynamic ASC creation, code-first GameplayAbilities,
## instantaneous effect application, cost/cooldown mechanics, and error signal handling.

extends Control

@onready var lbl_health: Label = $VBoxContainer/Stats/LblHealth
@onready var lbl_mana: Label = $VBoxContainer/Stats/LblMana
@onready var btn_damage: Button = $VBoxContainer/Actions/BtnDamage
@onready var btn_heal: Button = $VBoxContainer/Actions/BtnHeal
@onready var lbl_log: RichTextLabel = $VBoxContainer/LblLog

var asc: AbilitySystemComponent
var damage_ability: DamageAbility
var heal_ability: HealAbility

#region Inner Ability Classes
## A code-first ability demonstrating a 20 Mana cost and a 2-second cooldown.
class DamageAbility extends GameplayAbility:
	func _init() -> void:
		ability_name = "Damage Spell"
		ability_tag = GameplayTags.Ability_Basic_Damage
		
		# --- COST SETUP ---
		# Costs are just Instant GameplayEffects applied to the caster when they commit the ability.
		var cost_mod := GameplayEffectModifier.new()
		cost_mod.attribute_name = "mana"
		cost_mod.operation = GameplayEffectModifier.Operation.ADD
		cost_mod.magnitude = -20.0
		
		cost_effect = GameplayEffect.new()
		cost_effect.policy = GameplayEffect.DurationPolicy.INSTANT
		cost_effect.modifiers.append(cost_mod)
		
		# --- COOLDOWN SETUP ---
		# Cooldowns are Duration GameplayEffects that grant a blocking tag to the caster.
		cooldown_effect = GameplayEffect.new()
		cooldown_effect.policy = GameplayEffect.DurationPolicy.DURATION
		cooldown_effect.duration = 2.0
		cooldown_effect.granted_tags.append(GameplayTags.Cooldown_Damage)

	## The main execution block of the ability. Called automatically if try_activate() succeeds.
	func _activate_ability() -> bool:
		# commit_ability() deducts the cost and applies the cooldown tags to our ASC immediately.
		# Always call this before doing your damage logic so the player pays for the spell.
		commit_ability()
		
		# --- PAYLOAD SETUP ---
		# This is the actual damage we are dealing to the target (or ourselves in this demo).
		var dmg_mod := GameplayEffectModifier.new()
		dmg_mod.attribute_name = "health"
		dmg_mod.operation = GameplayEffectModifier.Operation.ADD
		dmg_mod.magnitude = -15.0
		
		var dmg_effect := GameplayEffect.new()
		dmg_effect.policy = GameplayEffect.DurationPolicy.INSTANT
		dmg_effect.modifiers.append(dmg_mod)
		
		# Apply the damage! Because this is a self-target demo, we apply it to our own owner_asc.
		owner_asc.apply_gameplay_effect(dmg_effect, owner_asc, ability_level)
		
		return true


## A code-first ability demonstrating a 30 Mana cost and a 1-second cooldown.
class HealAbility extends GameplayAbility:
	func _init() -> void:
		ability_name = "Heal Spell"
		ability_tag = GameplayTags.Ability_Basic_Heal
		
		var cost_mod := GameplayEffectModifier.new()
		cost_mod.attribute_name = "mana"
		cost_mod.operation = GameplayEffectModifier.Operation.ADD
		cost_mod.magnitude = -30.0
		
		cost_effect = GameplayEffect.new()
		cost_effect.policy = GameplayEffect.DurationPolicy.INSTANT
		cost_effect.modifiers.append(cost_mod)
		
		cooldown_effect = GameplayEffect.new()
		cooldown_effect.policy = GameplayEffect.DurationPolicy.DURATION
		cooldown_effect.duration = 1.0
		cooldown_effect.granted_tags.append(GameplayTags.Cooldown_Heal)

	func _activate_ability() -> bool:
		commit_ability()
		
		var heal_mod := GameplayEffectModifier.new()
		heal_mod.attribute_name = "health"
		heal_mod.operation = GameplayEffectModifier.Operation.ADD
		heal_mod.magnitude = 25.0
		
		var heal_effect := GameplayEffect.new()
		heal_effect.policy = GameplayEffect.DurationPolicy.INSTANT
		heal_effect.modifiers.append(heal_mod)
		
		owner_asc.apply_gameplay_effect(heal_effect, owner_asc, ability_level)
		return true
#endregion

#region Lifecycle & Setup
func _ready() -> void:
	_setup_asc()
	_setup_abilities()
	_setup_ui_connections()
	_update_ui()
	_log_message("System Initialized. Ready to cast.", "cyan")


func _setup_asc() -> void:
	# 1. Create the brain of the framework
	asc = AbilitySystemComponent.new()
	asc.name = "PlayerASC"
	
	# 2. Attach our custom AttributeSet module (which holds Health, Mana, etc.)
	var attributes := DemoAttributeSet.new()
	asc.attribute_sets.append(attributes)
	add_child(asc)
	
	# 3. Initialize starting values dynamically
	# Using initialize_attribute_overrides() ensures the math passes through the safety clamps
	# and fires the attribute_changed signals so our UI updates on frame one!
	var starting_stats: Dictionary[String, float] = {
		"health": 100.0,
		"mana": 100.0
	}
	asc.initialize_attribute_overrides(starting_stats)
	
	# 4. Dock the Visual Debugger to expose internal state changes (Cooldown timers, resource drops)
	var debugger := GASRuntimeDebugger.new()
	debugger.name = "GASRuntimeDebugger"
	debugger.target_asc = asc
	debugger.dock_position = GASRuntimeDebugger.DockPosition.TOP_RIGHT
	add_child(debugger)
	
	# 5. Connect to the global broadcast signals for our UI
	asc.attribute_changed.connect(_on_attribute_changed)
	asc.ability_activation_failed.connect(_on_ability_activation_failed)


func _setup_abilities() -> void:
	# Instantiate our custom ability classes and grant them to the ASC.
	# The ASC takes ownership of them and manages their memory.
	damage_ability = DamageAbility.new()
	heal_ability = HealAbility.new()
	
	asc.grant_ability(damage_ability)
	asc.grant_ability(heal_ability)


func _setup_ui_connections() -> void:
	btn_damage.pressed.connect(func():
		_log_message("Attempting to cast Damage Spell...", "gray")
		
		# try_activate() asks the ASC's Gatekeeper if we have enough mana and aren't on cooldown.
		# If it returns true, _activate_ability() ran successfully.
		var success = await damage_ability.try_activate()
		if success:
			_log_message("Damage Spell cast successfully!", "green")
	)
	
	btn_heal.pressed.connect(func():
		_log_message("Attempting to cast Heal Spell...", "gray")
		var success = await heal_ability.try_activate()
		if success:
			_log_message("Heal Spell cast successfully!", "green")
	)
#endregion

#region Event Responders & UI
## Fired by the ASC anytime a base stat or active buff changes the current value of an attribute.
func _on_attribute_changed(_attribute_name: String, _old_value: float, _new_value: float, _spec: GameplayEffectSpec) -> void:
	_update_ui()


## Fired by the ASC's Gatekeeper when an ability's try_activate() evaluates to false.
func _on_ability_activation_failed(ability: GameplayAbility, reason: AbilitySystemComponent.ActivationError, _payload: Dictionary) -> void:
	var reason_str := ""
	
	# The enum tells us exactly why the gatekeeper denied the ability cast.
	match reason:
		AbilitySystemComponent.ActivationError.ON_COOLDOWN:
			reason_str = "Ability is on Cooldown!"
		AbilitySystemComponent.ActivationError.INSUFFICIENT_RESOURCES:
			reason_str = "Insufficient Mana!"
		_:
			reason_str = "Blocked (Code: %d)" % reason
			
	_log_message("Activation Failed [%s]: %s" % [ability.ability_name, reason_str], "red")


func _update_ui() -> void:
	var health_attr = asc.get_attribute("health")
	var mana_attr = asc.get_attribute("mana")
	
	if health_attr and mana_attr:
		lbl_health.text = "Health: %d / 100" % int(health_attr.current_value)
		lbl_mana.text = "Mana: %d / 100" % int(mana_attr.current_value)


func _log_message(msg: String, color: String = "white") -> void:
	lbl_log.text += "[color=%s]%s[/color]\n" % [color, msg]
#endregion
