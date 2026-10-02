## A mathematical rule detailing how a Gameplay Effect alters an Attribute.
##
## Supports flat values, level-based curve scaling, SetByCaller injection, and Attribute-Based scaling.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayEffectModifier extends Resource

## Defines the mathematical operation applied to the attribute.
## Formula: Current = (Base + ADD) * (1.0 + PERCENT_ADD) * MULTIPLY / DIVIDE
enum Operation {
	ADD,         # Flat additions applied BEFORE percentages (+20 Ring of Health)
	PERCENT_ADD, # Additive percentages scaling off (Base + ADD) (+0.5 and +0.2 = +0.7)
	MULTIPLY,    # Multiplicative percentages applied to the running total (1.5 * 1.2 = 1.8)
	DIVIDE,      # Division applied to the final calculated total
	OVERRIDE     # Hard stat override, bypassing all other math
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

## Defines whether an Attribute-Based modifier reads the buffed total or the unbuffed base.
enum AttributeCaptureType {
	CURRENT_VALUE, # The running, buffed total
	BASE_VALUE     # The permanent, unbuffed base stat
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
## Determines if the modifier scales off the target's currently buffed stat or unbuffed base stat.
@export var attribute_capture_type: AttributeCaptureType = AttributeCaptureType.CURRENT_VALUE
## A multiplier applied to the fetched attribute's current value (e.g., 1.5 * AttackPower).
@export var attribute_multiplier: float = 1.0


#region Math Evaluation
## Evaluates the final magnitude of this modifier based on the character's level.
## NOTE: Only runs if the calculation type is STATIC.
func calculate_magnitude(level: float = 1.0) -> float:
	if scaling_curve:
		var curve_value = scaling_curve.sample(level)
		return curve_value * magnitude
		
	return magnitude
#endregion
