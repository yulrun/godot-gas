## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name GA_PoisonRecovery extends GameplayAbility

@export var heal_effect: GameplayEffect

func _activate_ability() -> bool:
	# 1. Because this ability is event-driven, the ASC automatically populated `current_event_payload`
	if not current_event_payload:
		end_ability(true)
		return false

	# 2. Extract the target data (which contains who hit us, and potentially the damage dealt)
	var target_data = current_event_payload.target_data
	
	# 3. For this specific passive, the Dummy heals itself. 
	# We create a fresh payload targeting ourselves.
	var self_target_data = GameplayAbilityTargetData.new()
	if "_target_nodes" in self_target_data:
		self_target_data._target_nodes.append(owner_asc.get_parent())
		
	# 4. Apply the flat heal effect
	apply_effect_to_targets(heal_effect, self_target_data)
	
	# 5. Instantly end the ability so it can be triggered again on the next hit
	end_ability()
	return true
