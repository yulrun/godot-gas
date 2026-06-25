## A mathematical rule detailing how a Gameplay Effect alters an Attribute.
##
## Supports both flat values and level-based curve scaling.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayEffectModifier extends Resource

## Defines the mathematical operation applied to the attribute.
enum Operation {
	ADD,      # Adds the magnitude (use negative values for damage/subtraction)
	MULTIPLY, # Multiplies the current value (e.g., 1.5 for a 50% increase)
	DIVIDE,   # Divides the current value
	OVERRIDE  # Completely replaces the current value with the magnitude
}

## The exact variable name of the attribute in the AttributeSet (e.g., "health" or "mana").
@export var attribute_name: String = ""

## How the math should be applied.
@export var operation: Operation = Operation.ADD

@export_category("Magnitude Calculation")
## A flat number used if no curve is provided. 
## If a curve IS provided, this acts as a Multiplier to the curve's output.
@export var magnitude: float = 0.0
## Optional: A Godot Curve resource. The X-axis is the Character Level, 
## and the Y-axis is the base value of the modifier.
@export var scaling_curve: Curve


#region Math Evaluation
## Evaluates the final magnitude of this modifier based on the character's level.
func calculate_magnitude(level: float = 1.0) -> float:
	if scaling_curve:
		# Godot curves evaluate between X=0.0 and X=1.0 by default, but we can sample 
		# beyond 1.0 if the curve domain is set up for it. 
		# We sample the curve, then multiply it by the base magnitude.
		var curve_value = scaling_curve.sample(level)
		return curve_value * magnitude
		
	# If no curve, just return the flat static number
	return magnitude
#endregion
