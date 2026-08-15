##
## @meta_addon: GodotGAS 1.0.5
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayEffectModifierMagnitudeCalculation extends Resource

var should_allow_non_net_authority_dependency_registration: bool:
	set(value):
		pass
	get:
		return _should_allow_non_net_authority_dependency_registration()	


func calculate_base_magnitude(gameplay_effect_spec: GameplayEffectSpec) -> float:
	return _calculate_base_magnitude(gameplay_effect_spec)


func _calculate_base_magnitude(gameplay_effect_spec: GameplayEffectSpec) -> float:
	return 0.0


func _should_allow_non_net_authority_dependency_registration() -> bool:
	return false
	
