## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name DemoArrow extends Area2D

@export var speed: float = 400.0

var source_asc: AbilitySystemComponent
var damage_effect: GameplayEffect

## Called by the GA_ArrowShoot ability upon instantiation
func initialize_projectile(_source_asc: AbilitySystemComponent, _damage_effect: GameplayEffect) -> void:
	source_asc = _source_asc
	damage_effect = _damage_effect

func _physics_process(delta: float) -> void:
	# Move positively on the X axis (to the right)
	position.x += speed * delta

## Connect this to the Area2D's body_entered signal
func _on_body_entered(body: Node2D) -> void:
	# Ignore ourselves (the shooter)
	if source_asc and body == source_asc.get_parent():
		return
		
	# Check if the hit body has an AbilitySystemComponent
	var target_asc: AbilitySystemComponent = null
	for child in body.get_children():
		if child is AbilitySystemComponent:
			target_asc = child
			break
			
	if target_asc and damage_effect:
		_apply_damage_to_target(body, target_asc)
		
	# Destroy the arrow upon hitting anything
	queue_free()

func _apply_damage_to_target(target_node: Node, target_asc: AbilitySystemComponent) -> void:
	# 1. Manually construct the TargetData payload
	var target_data = GameplayAbilityTargetData.new()
	if "_target_nodes" in target_data:
		target_data.append_node(target_node)
		
	# 2. Build the Effect Context (Instigator = Player, Causer = This Arrow)
	var instigator = source_asc.get_parent() if source_asc else self
	var context = GameplayEffectContext.new(instigator, self)
	context.target_data = target_data
	
	# 3. Build the Spec and push it to the Target's ASC
	# (We bypass strong typed _init parameters by setting properties directly to be safe)
	var spec = GameplayEffectSpec.new(damage_effect, context)
	
	# 4. Apply it!
	if target_asc.has_method("apply_effect_spec"):
		target_asc.apply_effect_spec(spec)
