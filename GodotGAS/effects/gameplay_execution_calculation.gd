## Base class for custom mathematical calculations inside the GodotGAS framework.
##
## Override the execute() function to perform complex combat math 
## (e.g., Damage = Caster.Attack - Target.Defense).
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@abstract
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayExecutionCalculation extends Resource


#region Execution
## Takes in the live Effect Spec and the Target's ASC.
## Returns a dictionary of exact flat numerical changes to be applied to the target's attributes.
## Expected return format: { "attribute_name": flat_delta_amount }
func execute(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	push_error("GodotGAS: execute() called on base GameplayExecutionCalculation. You must override this in your specific child script.")
	return {}
#endregion
