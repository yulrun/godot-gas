## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name ManaRegenCalc extends GameplayExecutionCalculation

## Executes passive mana regeneration by reading the target's mana_regen attribute
func execute(_spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var regen_amount = target_asc.get_attribute("mana_regen").current_value
	return {
		"mana": regen_amount
	}
