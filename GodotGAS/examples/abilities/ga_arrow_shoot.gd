## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name GA_ArrowShoot extends GameplayAbility

@export var arrow_scene: PackedScene
@export var damage_effect: GameplayEffect

func _activate_ability() -> bool:
	# 1. Commit the ability (Instantly applies the 5-second Cooldown effect)
	commit_ability()
	
	# 2. Trigger the Shoot Cue (e.g., Bow twang sound, arrow spawn particle)
	execute_cue(GameplayTags.Example_Ability_Arrow_Shoot)
	
	# 3. Spawn the arrow into the world
	if arrow_scene:
		var arrow = arrow_scene.instantiate()
		
		# Assuming the ASC's parent is the actual Player node (Node2D/Node3D)
		var player_node = owner_asc.get_parent()
		
		# Add to the active scene tree
		player_node.get_parent().add_child(arrow)
		arrow.global_position = player_node.global_position
		
		# Pass the ASC and Effect down to the projectile so it can handle the hit logic
		if arrow.has_method("initialize_projectile"):
			arrow.initialize_projectile(owner_asc, damage_effect)
			
	# 4. Finish the cast state
	end_ability()
	return true
