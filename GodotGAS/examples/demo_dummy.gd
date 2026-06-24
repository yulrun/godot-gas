class_name DemoDummy extends CharacterBody2D

@onready var asc: AbilitySystemComponent = $AbilitySystemComponent
@onready var passive_heal: GameplayAbility = $AbilitySystemComponent/GaPoisonRecovery

func _ready() -> void:
	asc.grant_ability(passive_heal)
	
	# Listen to our own health changes
	asc.attribute_changed.connect(_on_attribute_changed)

# Broadcast the Hit Event if we lose health from ANY source (Arrow or Poison)
func _on_attribute_changed(attribute_name: String, old_value: float, new_value: float, effect_spec: GameplayEffectSpec) -> void:
	if attribute_name == "health" and new_value < old_value:
		# Build a context payload so the Heal knows who we are
		var context = GameplayEffectContext.new(self, self)
		asc.send_gameplay_event(GameplayTags.Example_Event_Defend_Hit, context)
		
		if effect_spec.has_tag(GameplayTags.Example_Event_Damage_Missed):
			asc.send_gameplay_event(GameplayTags.Example_Event_Damage_Missed, context)
		
		if effect_spec.has_tag(GameplayTags.Example_Event_Damage_Critical):
			asc.send_gameplay_event(GameplayTags.Example_Event_Damage_Critical,  context)
