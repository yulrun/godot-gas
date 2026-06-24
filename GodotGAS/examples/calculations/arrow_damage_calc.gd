## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name ArrowDamageCalc extends GameplayExecutionCalculation

## Executes complex combat math: Damage = (Attack - Defense) * Crit / Evasion
func execute(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var final_damage: float = 0.0
	
	# 1. Safely find the Source (Attacker's) ASC
	var source_asc: AbilitySystemComponent = null
	if spec.context and spec.context.instigator:
		for child in spec.context.instigator.get_children():
			if child is AbilitySystemComponent:
				source_asc = child
				break
				
	# If we can't find the source's stats, we can't calculate attack damage
	if not source_asc:
		return {}

	# 2. Fetch the relevant Attributes
	var source_attack = source_asc.get_attribute("attack").current_value
	var source_crit = source_asc.get_attribute("critical_rate").current_value
	
	var target_def = target_asc.get_attribute("defence").current_value
	var target_evasion = target_asc.get_attribute("evasion").current_value
	
	# 3. Evasion Check
	var hit_roll = randf() * 100.0
	if hit_roll <= target_evasion:
		# Attack was evaded! Send a Miss event if desired, but deal 0 damage.
		spec.inject_tag(GameplayTags.Example_Event_Damage_Missed)
		return {"health": 0.0}
		
	# 4. Critical Hit Check
	var crit_multiplier: float = 1.0
	var crit_roll = randf() * 100.0
	if crit_roll <= source_crit:
		spec.inject_tag(GameplayTags.Example_Event_Damage_Critical)
		crit_multiplier = 2.0 # 200% Damage on Crit
		
	# 5. Final Math Mitigation (Ensure we deal at least 1 damage on a hit)
	var mitigated_damage = maxf((source_attack * crit_multiplier) - target_def, 1.0)
	
	# 6. Return the exact flat change to be applied to the target
	return {
		"health": -mitigated_damage
	}
