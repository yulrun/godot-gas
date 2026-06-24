## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name GA_PoisonCast extends GameplayAbility

@export var poison_dot_effect: GameplayEffect

func _activate_ability() -> bool:
	# 1. First, verify we have enough Mana. The Cost Effect handles the exact deduction amount.
	if not owner_asc.can_afford_cost(cost_effect):
		end_ability(true)
		return false
		
	# 2. Commit the ability (This INSTANTLY deducts the 25 Mana via the cost_effect)
	commit_ability()
	
	# 3. Trigger the Cast Cue (e.g., A magic circle appearing under the player)
	execute_cue(GameplayTags.Example_Ability_Poison_Cast)
	
	# 4. Simulate a Cast Time (1 Second)
	await get_tree().create_timer(1.0).timeout
	
	# 5. Safety Check: If the player was stunned/killed during the cast, is_active will be false
	if not is_active:
		return false
		
	# 6. Locate the target (For the demo, we will just grab the Dummy directly)
	var dummies = get_tree().get_nodes_in_group("dummy")
	if dummies.size() > 0:
		var target_dummy = dummies[0]
		
		# 7. Manually build the TargetData payload
		var target_data = GameplayAbilityTargetData.new()
		
		# Add the dummy to the payload's target list
		# (Note: Assuming _target_nodes or append_target based on your data structure)
		if "_target_nodes" in target_data:
			target_data._target_nodes.append(target_dummy)
		
		# 8. Fire the fully loaded effect through the ASC pipeline
		apply_effect_to_targets(poison_dot_effect, target_data)
		
	# 9. Clean up and finish
	end_ability()
	return true
