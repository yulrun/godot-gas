## A mathematical rule detailing how a Gameplay Effect alters an Attribute.
##
## Supports flat values, level-based curve scaling, SetByCaller injection, and Attribute-Based scaling.
##
## @meta_addon: GodotGAS Version 1+ (See plugin version for exact version)
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayEffectModifier extends Resource

## Defines the mathematical operation applied to the attribute.
enum Operation {
	ADD,      # Adds the magnitude (use negative values for damage/subtraction)
	MULTIPLY, # Active effects multiply the summed base and additions (1.5 = +50%)
	DIVIDE,   # Active effects divide the result after multiplication
	OVERRIDE  # An active override replaces the aggregate with its magnitude
}

## Defines where the modifier gets its mathematical value from.
enum MagnitudeCalculationType {
	STATIC,         # Uses the flat magnitude or scaling curve defined in the inspector
	SET_BY_CALLER,  # Ignores static values; pulls the number from the Spec at runtime using a tag
	ATTRIBUTE_BASED # Scales directly off an existing attribute from the source or target
}

## Defines which entity to pull the backing attribute from.
enum AttributeSource {
	SOURCE, # The entity that cast the effect
	TARGET  # The entity receiving the effect
}

## The exact variable name of the attribute in the AttributeSet (e.g., "health" or "mana").
@export var attribute_name: String = ""

## How the math should be applied.
@export var operation: Operation = Operation.ADD

## Higher priority wins when several active OVERRIDE modifiers target one attribute.
## Equal priorities choose the higher magnitude, independent of application order.
@export var override_priority: int = 0

## The source of the mathematical value.
@export var magnitude_calculation: MagnitudeCalculationType = MagnitudeCalculationType.STATIC

@export_group("Static Calculation")
## A flat number used if no curve is provided. 
## If a curve IS provided, this acts as a Multiplier to the curve's output.
@export var magnitude: float = 0.0

## Optional: A Godot Curve resource. The X-axis is the Character Level, 
## and the Y-axis is the base value of the modifier.
@export var scaling_curve: Curve

@export_group("Set By Caller Calculation")
## If magnitude_calculation is SET_BY_CALLER, this is the tag the ASC will look for
## inside the Spec to find the dynamic value.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var set_by_caller_tag: StringName = &""

@export_group("Attribute Based Calculation")
## Whether to pull the attribute from the entity casting the effect (SOURCE) or receiving the effect (TARGET).
@export var attribute_source: AttributeSource = AttributeSource.SOURCE
## The exact name of the attribute to scale off of (e.g., "attack_power").
@export var backing_attribute_name: String = ""
## A multiplier applied to the fetched attribute's current value (e.g., 1.5 * AttackPower).
@export var attribute_multiplier: float = 1.0


#region Math Evaluation
## Evaluates the final magnitude of this modifier based on the character's level.
## NOTE: Only runs if the calculation type is STATIC.
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
