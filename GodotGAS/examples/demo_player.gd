## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name DemoPlayer extends CharacterBody2D

@export var mana_regen_effect: GameplayEffect

@onready var asc: AbilitySystemComponent = $AbilitySystemComponent
@onready var arrow_ability: GameplayAbility = $AbilitySystemComponent/GaArrowShoot
@onready var poison_ability: GameplayAbility = $AbilitySystemComponent/GaPoisonCast

func _ready() -> void:
	# 1. Grant the abilities to the ASC
	asc.grant_ability(arrow_ability)
	asc.grant_ability(poison_ability)
	
	# 2. Bind them to Input IDs
	asc.bind_ability_to_input(arrow_ability, 0)
	asc.bind_ability_to_input(poison_ability, 1)
	
	# 3. Apply the Passive Mana Regen
	if mana_regen_effect:
		var context = GameplayEffectContext.new(self, self)
		var spec = GameplayEffectSpec.new(mana_regen_effect, context)
		asc.apply_effect_spec(spec)
	
	# 4. Connect signals
	asc.ability_activation_failed.connect(_on_ability_activation_failed)

func _process(_delta: float) -> void:
	# Route Hardware Inputs to the GAS Pipeline
	# 0 = Arrow, 1 = Poison
	
	if Input.is_action_just_pressed("ui_accept"):
		asc.ability_local_input_pressed(0)
	elif Input.is_action_just_released("ui_accept"):
		asc.ability_local_input_released(0)
		
	if Input.is_action_just_pressed("ui_cancel"):
		asc.ability_local_input_pressed(1)
	elif Input.is_action_just_released("ui_cancel"):
		asc.ability_local_input_released(1)

func _on_ability_activation_failed(ability: GameplayAbility, reason: AbilitySystemComponent.ActivationError, payload: Dictionary):
	match reason:
		AbilitySystemComponent.ActivationError.ON_COOLDOWN:
			var remaining_time: float = asc.get_tag_duration_remaining(ability.cooldown_effect.granted_tags[0])
			print("%s Ability is not ready yet! %.1f remaining seconds." % [ability.ability_name, remaining_time])
		AbilitySystemComponent.ActivationError.INSUFFICIENT_RESOURCES:
			print("Not enough Mana!")
		AbilitySystemComponent.ActivationError.BLOCKED_TAG:
			print("You cannot do that right now!")
