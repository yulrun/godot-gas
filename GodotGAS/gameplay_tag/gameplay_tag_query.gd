## A structured query for evaluating complex gameplay tag requirements.
##
## Replaces raw tag arrays with a single boolean evaluation matching 
## Unreal Engine's standard GameplayTagQuery architecture.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayTagQuery extends Resource

@export_category("Tag Query Rules")
## The target must have AT LEAST ONE of these tags (hierarchical match).
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var require_any_tags: Array[StringName] = []

## The target must have ALL of these tags (hierarchical match).
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var require_all_tags: Array[StringName] = []

## The target must have ALL of these tags (exact match only).
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var require_exact_tags: Array[StringName] = []

## If the target has ANY of these tags (hierarchical), the query fails.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var ignore_tags: Array[StringName] = []

## If the target has ANY of these tags (exact match only), the query fails.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var ignore_exact_tags: Array[StringName] = []


#region Evaluation
## Evaluates the query against a specific Ability System Component.
func matches(asc: AbilitySystemComponent) -> bool:
	if not asc:
		return false
		
	# 1. Fail fast on ignored tags
	if ignore_tags.size() > 0 and asc.has_any_tags(ignore_tags):
		return false
		
	if ignore_exact_tags.size() > 0:
		for tag in ignore_exact_tags:
			if asc.has_tag_exact(tag):
				return false
				
	# 2. Enforce absolute requirements
	if require_all_tags.size() > 0 and not asc.has_all_tags(require_all_tags):
		return false
		
	if require_exact_tags.size() > 0:
		for tag in require_exact_tags:
			if not asc.has_tag_exact(tag):
				return false
				
	# 3. Enforce partial requirements
	if require_any_tags.size() > 0 and not asc.has_any_tags(require_any_tags):
		return false
		
	return true
#endregion
