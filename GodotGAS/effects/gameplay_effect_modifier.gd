## A mathematical rule detailing how a Gameplay Effect alters an Attribute.
##
## Supports both flat values and level-based curve scaling.
##
## @meta_addon: GodotGAS 1.0.5
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayEffectModifier extends Resource

## Defines the mathematical operation applied to the attribute.
enum Operation {
	ADD,      # Adds the magnitude (use negative values for damage/subtraction)
	MULTIPLY, # Multiplies the current value (e.g., 1.5 for a 50% increase)
	DIVIDE,   # Divides the current value
	OVERRIDE  # Completely replaces the current value with the magnitude
}

enum MagnitudeCalculation {
	SCALABLE_FLOAT,
	ATTRIBUTE_BASED,
	# CUSTOM_CALCULATION_CLASS,
 	SET_BY_CALLER,
}

enum AttributeBasedFloatCalculationType {
    ATTRIBUTE_MAGNITUDE,
    ATTRIBUTE_BASE_VALUE,
    ATTRIBUTE_BONUS_MAGNITUDE,
    # ATTRIBUTE_MAGNITUDE_EVALUATED_UP_TO_CHANNEL,
}

# enum GameplayModifierEvaluationChannel {
#     CHANNEL_0,
#     CHANNEL_1,
#     CHANNEL_2,
#     CHANNEL_3,
#     CHANNEL_4,
#     CHANNEL_5,
#     CHANNEL_6,
#     CHANNEL_7,
#     CHANNEL_8,
#     CHANNEL_9,
#     CHANNEL_MAX,
# }

## The exact variable name of the attribute in the AttributeSet (e.g., "health" or "mana").
@export var attribute_name: = ""

## How the math should be applied.
@export var operation: = Operation.ADD

@export var magnitude_calculation: = MagnitudeCalculation.SCALABLE_FLOAT:
	set(value):
		magnitude_calculation = value
		notify_property_list_changed()
	get:
		return magnitude_calculation

@export_group("Magnitude Calculation")

# == Scalable float.
## A flat number used if no curve is provided. 
## If a curve IS provided, this acts as a Multiplier to the curve's output.
var magnitude: = 0.0
## Optional: A Godot Curve resource. The X-axis is the Character Level, 
## and the Y-axis is the base value of the modifier.
var scaling_curve: Curve = null

# == Attribute based.
var coefficient: = 0.0
var pre_multiply_additive_value: = 0.0
var post_multiply_additive_value: = 0.0
var backing_attribute: GameplayEffectAttributeCaptureDefinition = null
var attribute_curve: Curve = null
var attribute_based_float_calculation_type: = AttributeBasedFloatCalculationType.ATTRIBUTE_BASE_VALUE:
	set(value):
		if value == attribute_based_float_calculation_type:
			return
		attribute_based_float_calculation_type = value
		notify_property_list_changed()
	get:
		return attribute_based_float_calculation_type
# var final_channel: = GameplayModifierEvaluationChannel.CHANNEL_0
var source_tag_filter: Array[StringName]
var target_tag_filter: Array[StringName]

# == Set by caller.
var set_by_caller_tag: StringName


func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{
			"name": "Magnitude Calculation",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
		},
	]

	match magnitude_calculation:
		MagnitudeCalculation.SCALABLE_FLOAT:
			list.append_array(
				[
					{
						"name": "magnitude",
						"type": TYPE_FLOAT,
						"hint": PROPERTY_HINT_NONE,
					},
					{
						"name": "scaling_curve",
						"type": TYPE_OBJECT,
						"hint": PROPERTY_HINT_RESOURCE_TYPE,
						"hint_string": "Curve",
					},
				]
			)

		MagnitudeCalculation.ATTRIBUTE_BASED:
			list.append_array(
				[
					{
						"name": "coefficient",
						"type": TYPE_FLOAT,
						"hint": PROPERTY_HINT_NONE,
						"hint_string": "suffix:×",
					},
					{
						"name": "pre_multiply_additive_value",
						"type": TYPE_FLOAT,
						"hint": PROPERTY_HINT_NONE,
					},
					{
						"name": "post_multiply_additive_value",
						"type": TYPE_FLOAT,
						"hint": PROPERTY_HINT_NONE,
					},
					{
						"name": "backing_attribute",
						"type": TYPE_OBJECT,
						"hint": PROPERTY_HINT_RESOURCE_TYPE,
						"hint_string": "GameplayEffectAttributeCaptureDefinition",
					},
					{
						"name": "attribute_curve",
						"type": TYPE_OBJECT,
						"hint": PROPERTY_HINT_NONE,
					},
					{
						"name": "attribute_based_float_calculation_type",
						"type": TYPE_INT,
						"hint": PROPERTY_HINT_ENUM,
						"hint_string": ",".join(
							[
								"Magnitude",
								"Base value",
								"Bonus magnitude",
								# "Magnitude evaluated up to channel",
							],
						),
					},
				],
			)

			# if attribute_based_float_calculation_type == \
			# AttributeBasedFloatCalculationType.ATTRIBUTE_MAGNITUDE_EVALUATED_UP_TO_CHANNEL:
			# 	list.append_array(
			# 		[
			# 			{
			# 				"name": "final_channel",
			# 				"type": TYPE_INT,
			# 				"hint": PROPERTY_HINT_ENUM,
			# 				"hint_string": ",".join(
			# 					[
			# 						"0",
			# 						"1",
			# 						"2",
			# 						"3",
			# 						"4",
			# 						"5",
			# 						"6",
			# 						"7",
			# 						"8",
			# 						"9",
			# 					],
			# 				),
			# 			},
			# 		]
			# 	)

			list.append_array(
				[
					{
						"name": "source_tag_filter",
						"type": TYPE_ARRAY,
						"hint": PROPERTY_HINT_ARRAY_TYPE,
						"hint_string": "StringName,gas::tag",
					},
					{
						"name": "target_tag_filter",
						"type": TYPE_ARRAY,
						"hint": PROPERTY_HINT_ARRAY_TYPE,
						"hint_string": "StringName,gas::tag",
					},
				]
			)

		MagnitudeCalculation.SET_BY_CALLER:
			list.append_array([
				{
					"name": "set_by_caller_tag",
					"type": TYPE_STRING_NAME,
					"hint": PROPERTY_HINT_NONE,
				},
			])

	return list


func _property_can_revert(property: StringName) -> bool:
	return property in [
		# Scalable float.
		&"magnitude",
		&"scaling_curve",

		# Attribute based.
		&"coefficient",
		&"pre_multiply_additive_value",
		&"post_multiply_additive_value",
		&"backing_attribute",
		&"attribute_curve",
		&"attribute_based_float_calculation_type",
		# &"final_channel",
		&"source_tag_filter",
		&"target_tag_filter",

		# Set by caller.
		&"set_by_caller_tag",
	]


func _property_get_revert(property: StringName) -> Variant:
	match property:
		# Scalable float.
		&"magnitude":
			return 0.0
		&"scaling_curve":
			return null

		# Attribute based.
		&"coefficient":
			return 0.0
		&"pre_multiply_additive_value":
			return 0.0
		&"post_multiply_additive_value":
			return 0.0
		&"backing_attribute":
			return null
		&"attribute_curve":
			return null
		&"attribute_based_float_calculation_type":
			return AttributeBasedFloatCalculationType.ATTRIBUTE_BASE_VALUE
		# &"final_channel":
		# 	return GameplayModifierEvaluationChannel.CHANNEL_0
		&"source_tag_filter":
			return []
		&"target_tag_filter":
			return []

		# Set by caller.
		&"set_by_caller_tag":
			return &""
	return null


#region Math Evaluation
## Evaluates the final magnitude of this modifier based on the character's level.
func calculate_magnitude_scalable_float(level: float) -> float:
	assert(magnitude_calculation == MagnitudeCalculation.SCALABLE_FLOAT)

	if scaling_curve:
		# Godot curves evaluate between X=0.0 and X=1.0 by default, but we can sample 
		# beyond 1.0 if the curve domain is set up for it. 
		# We sample the curve, then multiply it by the base magnitude.
		var curve_value = scaling_curve.sample_baked(level)
		return curve_value * magnitude

	# If no curve, just return the flat static number
	return magnitude

func calculate_magnitude_attribute_based(
		source_asc: AbilitySystemComponent,
		target_asc: AbilitySystemComponent,
) -> float:
	assert(magnitude_calculation == MagnitudeCalculation.ATTRIBUTE_BASED)
	assert(backing_attribute != null)

	var attribute: AttributeData = null
	match backing_attribute.attribute_source:
		GameplayEffectAttributeCaptureDefinition.AttributeCaptureSource.SOURCE:
			assert(source_asc != null)
			attribute = source_asc.get_attribute(backing_attribute.attribute_to_capture)
		GameplayEffectAttributeCaptureDefinition.AttributeCaptureSource.TARGET:
			assert(target_asc != null)
			attribute = target_asc.get_attribute(backing_attribute.attribute_to_capture)
	assert(attribute != null)

	var attribute_value: float = 0.0

	match attribute_based_float_calculation_type:
		AttributeBasedFloatCalculationType.ATTRIBUTE_MAGNITUDE:
			attribute_value = attribute.current_value
		AttributeBasedFloatCalculationType.ATTRIBUTE_BASE_VALUE:
			attribute_value = attribute.base_value
		AttributeBasedFloatCalculationType.ATTRIBUTE_BONUS_MAGNITUDE:
			attribute_value = attribute.current_value - attribute.base_value

	if attribute_curve != null:
		attribute_value = attribute_curve.sample_baked(attribute_value)

	return \
		( \
			coefficient \
			* ( \
				pre_multiply_additive_value \
				+ attribute_value \
			) \
		) \
		+ post_multiply_additive_value


#endregion
