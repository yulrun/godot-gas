## GAS - Demo Project: Phase 1, Scene 4
## Demonstrates Inhibition (temporarily pausing an active effect's math and tags)
## and the Cleanser pattern (permanently purging effects).

extends Control

@onready var lbl_armor: Label = $VBoxContainer/Stats/LblArmor
@onready var btn_aura: Button = $VBoxContainer/Actions/BtnAura
@onready var btn_silence: Button = $VBoxContainer/Actions/BtnSilence
@onready var btn_purge: Button = $VBoxContainer/Actions/BtnPurge
@onready var lbl_log: RichTextLabel = $VBoxContainer/LblLog

var asc: AbilitySystemComponent

var shield_aura_effect: GameplayEffect
var silence_debuff_effect: GameplayEffect
var purge_cleanser_effect: GameplayEffect

#region Lifecycle & Setup
func _ready() -> void:
	_setup_asc()
	_build_effects()
	_setup_ui_connections()
	_update_ui()
	_log_message("Inhibition Engine Initialized.", "cyan")


func _setup_asc() -> void:
	asc = AbilitySystemComponent.new()
	asc.name = "PlayerASC"
	
	var attributes := DemoAttributeSet.new()
	asc.attribute_sets.append(attributes)
	add_child(asc)
	
	# Explicitly start with 0 Armor so the Aura's +50 is obvious
	var starting_stats: Dictionary[String, float] = {
		"armor": 0.0
	}
	asc.initialize_attribute_overrides(starting_stats)
	
	var debugger := GASRuntimeDebugger.new()
	debugger.name = "GASRuntimeDebugger"
	debugger.target_asc = asc
	debugger.dock_position = GASRuntimeDebugger.DockPosition.TOP_RIGHT
	add_child(debugger)
	
	asc.attribute_changed.connect(_on_attribute_changed)
	asc.tag_added.connect(_on_tag_added)
	asc.tag_removed.connect(_on_tag_removed)


func _build_effects() -> void:
	# --- 1. SHIELD AURA (Inhibitable Effect) ---
	# This effect grants +50 Armor and the 'Shielded' tag indefinitely.
	# HOWEVER, it possesses an ongoing_suppression_query. If the ASC ever gains the
	# 'Silenced' tag, this aura will instantly reverse its +50 Armor and strip the
	# 'Shielded' tag. When the Silence ends, the Aura automatically turns back on!
	var suppression_query := GameplayTagQuery.new()
	suppression_query.require_exact_tags.append(GameplayTags.Status_Debuff_Silenced)
	
	var aura_mod := GameplayEffectModifier.new()
	aura_mod.attribute_name = "armor"
	aura_mod.operation = GameplayEffectModifier.Operation.ADD
	aura_mod.magnitude = 50.0
	
	shield_aura_effect = GameplayEffect.new()
	shield_aura_effect.resource_name = "Shield Aura"
	shield_aura_effect.policy = GameplayEffect.DurationPolicy.INFINITE
	shield_aura_effect.ongoing_suppression_query = suppression_query
	shield_aura_effect.granted_tags.append(GameplayTags.Status_Buff_Shielded)
	shield_aura_effect.modifiers.append(aura_mod)
	
	# --- 2. SILENCE DEBUFF ---
	# A simple infinite effect that grants the 'Silenced' tag to the target.
	# Applying this will trigger the suppression query on the Shield Aura.
	silence_debuff_effect = GameplayEffect.new()
	silence_debuff_effect.resource_name = "Silence Debuff"
	silence_debuff_effect.policy = GameplayEffect.DurationPolicy.INFINITE
	silence_debuff_effect.granted_tags.append(GameplayTags.Status_Debuff_Silenced)
	
	# --- 3. PURGE CLEANSER ---
	# An instant effect that physically hunts down and destroys any active effects
	# granting the 'Silenced' tag. This is how you build Antidotes or Dispels!
	purge_cleanser_effect = GameplayEffect.new()
	purge_cleanser_effect.resource_name = "Purge Spell"
	purge_cleanser_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	purge_cleanser_effect.remove_effects_with_tags.append(GameplayTags.Status_Debuff_Silenced)


func _setup_ui_connections() -> void:
	btn_aura.pressed.connect(func():
		# Prevent stacking the infinite aura for clarity in the demo
		if asc.has_tag(GameplayTags.Status_Buff_Shielded):
			_log_message("Aura is already active!", "gray")
			return
			
		_log_message("Casting Shield Aura...", "cyan")
		asc.apply_gameplay_effect(shield_aura_effect, asc, 1.0)
	)
	
	btn_silence.pressed.connect(func():
		if asc.has_tag(GameplayTags.Status_Debuff_Silenced):
			_log_message("Target is already Silenced!", "gray")
			return
			
		_log_message("Applying Silence Debuff. Watch the Aura suppress!", "orange")
		asc.apply_gameplay_effect(silence_debuff_effect, asc, 1.0)
	)
	
	btn_purge.pressed.connect(func():
		_log_message("Casting Purge Cleanser...", "green")
		asc.apply_gameplay_effect(purge_cleanser_effect, asc, 1.0)
	)
#endregion

#region Event Responders & UI
func _on_attribute_changed(_attribute_name: String, _old_value: float, _new_value: float, _spec: GameplayEffectSpec) -> void:
	_update_ui()


## We listen to state changes directly from the ASC to log when Inhibition triggers.
func _on_tag_added(tag: StringName) -> void:
	if tag == GameplayTags.Status_Buff_Shielded:
		_log_message("--> Shield Aura is ACTIVE.", "cyan")
	elif tag == GameplayTags.Status_Debuff_Silenced:
		_log_message("--> Target SILENCED. Aura is SUPPRESSED.", "red")


func _on_tag_removed(tag: StringName) -> void:
	if tag == GameplayTags.Status_Buff_Shielded:
		# If we lose the Shielded tag but the effect is still in memory, it was suppressed
		_log_message("--> Shield Aura deactivated.", "gray")
	elif tag == GameplayTags.Status_Debuff_Silenced:
		_log_message("--> Silence Purged. Aura RESTORED.", "green")


func _update_ui() -> void:
	var armor_attr = asc.get_attribute("armor")
	if armor_attr:
		lbl_armor.text = "Armor: %.1f" % armor_attr.current_value


func _log_message(msg: String, color: String = "white") -> void:
	lbl_log.text += "[color=%s]%s[/color]\n" % [color, msg]
#endregion
