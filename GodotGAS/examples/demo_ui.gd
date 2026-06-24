## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name DemoUI extends CanvasLayer

@export var player_asc: AbilitySystemComponent
@export var dummy_asc: AbilitySystemComponent

@export var player_hp_label: Label
@export var player_mp_label: Label
@export var dummy_hp_label: Label

func _ready() -> void:
	# Wait one frame to ensure both ASCs have fully initialized their Attribute Sets
	await get_tree().process_frame
	
	if player_asc:
		player_asc.attribute_changed.connect(_on_player_attribute_changed)
		_update_player_ui()
		
	if dummy_asc:
		dummy_asc.attribute_changed.connect(_on_dummy_attribute_changed)
		_update_dummy_ui()

func _on_player_attribute_changed(_attribute_name: String, _old_value: float, _new_value: float, effect_spec: GameplayEffectSpec) -> void:
	_update_player_ui()

func _on_dummy_attribute_changed(_attribute_name: String, _old_value: float, _new_value: float, effect_spec: GameplayEffectSpec) -> void:
	_update_dummy_ui()

func _update_player_ui() -> void:
	if player_hp_label and player_asc.get_attribute("health") != null:
		var hp = player_asc.get_attribute("health").current_value
		player_hp_label.text = "Player HP: " + str(snapped(hp, 0.1))
		
	if player_mp_label and player_asc.get_attribute("mana") != null:
		var mp = player_asc.get_attribute("mana").current_value
		player_mp_label.text = "Player MP: " + str(snapped(mp, 0.1))

func _update_dummy_ui() -> void:
	if dummy_hp_label and dummy_asc.get_attribute("health")  != null:
		var hp = dummy_asc.get_attribute("health").current_value
		dummy_hp_label.text = "Dummy HP: " + str(snapped(hp, 0.1))
