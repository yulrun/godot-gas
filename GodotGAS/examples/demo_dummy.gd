class_name DemoDummy extends CharacterBody2D

@onready var asc: AbilitySystemComponent = $AbilitySystemComponent
@onready var passive_heal: GameplayAbility = $AbilitySystemComponent/GaPoisonRecovery

func _ready() -> void:
	asc.grant_ability(passive_heal)
