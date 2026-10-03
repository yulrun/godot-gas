## GAS - Demo Project: Phase 1, Scene 6
## Demonstrates Event-Driven Passive Abilities.
## Teaches how GameplayEffects can broadcast global event tags on periodic ticks,
## and how GameplayAbilities can listen for those tags to automatically activate.

extends Control

@onready var lbl_health: Label = $VBoxContainer/Stats/LblHealth
@onready var btn_burn: Button = $VBoxContainer/Actions/BtnBurn
@onready var btn_douse: Button = $VBoxContainer/Actions/BtnDouse
@onready var lbl_log: RichTextLabel = $VBoxContainer/LblLog

var asc: AbilitySystemComponent

var initial_ignite_effect: GameplayEffect
var burning_dot_effect: GameplayEffect
var douse_cleanser_effect: GameplayEffect
var reactive_heal_ability: ReactiveHealAbility

#region Inner Passive Ability Class
## An ability that requires no input_id or manual try_activate() calls.
## It wakes up automatically when its trigger_event_tag is broadcasted to the ASC.
class ReactiveHealAbility extends GameplayAbility:
	
	var heal_effect: GameplayEffect
	
	func _init() -> void:
		ability_name = "Passive: Reactive Heal"
		ability_tag = GameplayTags.Ability_Basic_Heal
		
		# --- THE MAGIC TRIGGER ---
		# This tells the ASC's Gatekeeper: "If you ever hear this event tag, activate me!"
		trigger_event_tag = GameplayTags.Event_Combat_Hit
		
		# Prepare the payload it will fire when it wakes up
		var heal_mod := GameplayEffectModifier.new()
		heal_mod.attribute_name = "health"
		heal_mod.operation = GameplayEffectModifier.Operation.ADD
		heal_mod.magnitude = 5.0 # Heals for 5 to mitigate some of the burn damage
		
		heal_effect = GameplayEffect.new()
		heal_effect.resource_name = "Reactive Heal Payload"
		heal_effect.policy = GameplayEffect.DurationPolicy.INSTANT
		heal_effect.modifiers.append(heal_mod)

	## Automatically executed by the ASC when Event.Combat.Hit is received
	func _activate_ability() -> bool:
		# --- ASYNCHRONOUS DELAY ---
		# Because the ASC broadcasts the event and commits the DoT damage in the exact same frame,
		# the UI updates too fast to read. We inject a 1-second delay so the player visually sees 
		# the damage hit, and then a moment later, the reactive heal kicks in.
		await task_wait_delay(1.0)
		
		# Ensure we weren't violently killed/aborted during the 1-second wait
		if is_active:
			owner_asc.apply_gameplay_effect(heal_effect, owner_asc, ability_level)
			
		return true
#endregion

#region Lifecycle & Setup
func _ready() -> void:
	_setup_asc()
	_build_effects()
	_setup_ui_connections()
	_update_ui()
	_log_message("Passive Event Engine Initialized.", "cyan")


func _setup_asc() -> void:
	asc = AbilitySystemComponent.new()
	asc.name = "PlayerASC"
	
	var attributes := DemoAttributeSet.new()
	asc.attribute_sets.append(attributes)
	add_child(asc)
	
	var starting_stats: Dictionary[String, float] = {
		"health": 100.0
	}
	asc.initialize_attribute_overrides(starting_stats)
	
	var debugger := GASRuntimeDebugger.new()
	debugger.name = "GASRuntimeDebugger"
	debugger.target_asc = asc
	debugger.dock_position = GASRuntimeDebugger.DockPosition.TOP_RIGHT
	add_child(debugger)
	
	# Grant the passive ability right as the scene starts. It will sit dormant.
	reactive_heal_ability = ReactiveHealAbility.new()
	
	# Because the burn ticks every 3 seconds, and the heal waits 1 second, they will overlap.
	# We set this to PER_EXECUTION so multiple rapid triggers don't block each other!
	reactive_heal_ability.instancing_policy = GameplayAbility.InstancingPolicy.INSTANCED_PER_EXECUTION
	asc.grant_ability(reactive_heal_ability)
	
	# Hook up signal listeners to track what happens under the hood
	asc.attribute_changed.connect(_on_attribute_changed)
	asc.gameplay_event_received.connect(_on_gameplay_event_received)


func _build_effects() -> void:
	var burn_mod := GameplayEffectModifier.new()
	burn_mod.attribute_name = "health"
	burn_mod.operation = GameplayEffectModifier.Operation.ADD
	burn_mod.magnitude = -15.0
	
	# --- 1. INITIAL IGNITE IMPACT ---
	# Periodic effects don't apply their math until the first period finishes.
	# To ensure the player takes damage the exact moment the button is clicked, we build
	# an instant effect to pair with the DoT.
	initial_ignite_effect = GameplayEffect.new()
	initial_ignite_effect.resource_name = "Ignite Impact"
	initial_ignite_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	initial_ignite_effect.modifiers.append(burn_mod)

	# --- 2. BURNING DAMAGE OVER TIME (DoT) ---
	burning_dot_effect = GameplayEffect.new()
	burning_dot_effect.resource_name = "Burning DoT"
	
	# We set this to INFINITE so it burns them continuously until they hit 0 HP,
	# forcing them to use the Douse button or die.
	burning_dot_effect.policy = GameplayEffect.DurationPolicy.INFINITE
	
	# Ticks every 3.0 seconds. Combined with the Passive's 1.0s wait, this gives a 
	# perfect readable rhythm: (0s: Damage, 1s: Heal, 3s: Damage, 4s: Heal).
	burning_dot_effect.period = 3.0
	
	burning_dot_effect.modifiers.append(burn_mod)
	burning_dot_effect.granted_tags.append(GameplayTags.Status_Debuff_Burning)
	
	# --- THE EVENT BROADCASTER ---
	# event_tags fire twice: once on application, and once every periodic tick.
	# The application broadcast will cover our "Initial Ignite Impact", and the
	# tick broadcasts will cover the continuing DoT damage!
	burning_dot_effect.event_tags.append(GameplayTags.Event_Combat_Hit)
	
	# --- 3. DOUSE CLEANSER ---
	douse_cleanser_effect = GameplayEffect.new()
	douse_cleanser_effect.resource_name = "Douse Cleanser"
	douse_cleanser_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	douse_cleanser_effect.remove_effects_with_tags.append(GameplayTags.Status_Debuff_Burning)


func _setup_ui_connections() -> void:
	btn_burn.pressed.connect(func():
		_log_message("Applying Infinite Burning DoT...", "orange")
		
		# Apply the instant damage first, followed immediately by the DoT
		asc.apply_gameplay_effect(initial_ignite_effect, asc, 1.0)
		asc.apply_gameplay_effect(burning_dot_effect, asc, 1.0)
	)
	
	btn_douse.pressed.connect(func():
		_log_message("Dousing Fire...", "cyan")
		asc.apply_gameplay_effect(douse_cleanser_effect, asc, 1.0)
	)
#endregion

#region Event Responders & UI
## Fires every time the DoT hits its periodic tick, OR on initial application!
func _on_gameplay_event_received(event_tag: StringName, _payload: Variant) -> void:
	if event_tag == GameplayTags.Event_Combat_Hit:
		_log_message("-> System Event Broadcasted: [color=yellow]%s[/color]" % event_tag)


func _on_attribute_changed(attribute_name: String, _old_value: float, new_value: float, spec: GameplayEffectSpec) -> void:
	_update_ui()
	
	if attribute_name == "health" and spec and spec.effect_def:
		var delta: float = spec.calculated_deltas.get("health", 0.0)
		
		# Log the DoT tick or the Initial Ignite
		if (spec.effect_def.resource_name == "Burning DoT" or spec.effect_def.resource_name == "Ignite Impact") and delta != 0.0:
			_log_message("   [Burn] Dealt [color=red]%+.1f Damage[/color]!" % delta)
			
		# Log the Passive response
		elif spec.effect_def.resource_name == "Reactive Heal Payload" and delta != 0.0:
			_log_message("   [Passive] Reacted to Hit! [color=green]%+.1f Health[/color] restored." % delta)


func _update_ui() -> void:
	var health_attr = asc.get_attribute("health")
	if health_attr:
		lbl_health.text = "Health: %.1f / 100" % health_attr.current_value


func _log_message(msg: String, color: String = "white") -> void:
	lbl_log.text += "[color=%s]%s[/color]\n" % [color, msg]
#endregion
