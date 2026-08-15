## The core data asset that defines a buff, debuff, or instant change in the game.
##
## Game Designers create instances of this Resource to build out the game's skills.
##
## @meta_addon: GodotGAS 1.0.5
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayEffect extends Resource

## Defines the lifecycle behavior of the effect.
enum DurationPolicy { 
	INSTANT, # Applies math immediately and vanishes. Cannot grant tags. (e.g., Fireball Damage)
	DURATION, # Applies math/tags for X seconds, then undoes them. (e.g., 5-second Poison)
	INFINITE, # Applies math/tags permanently until explicitly removed. (e.g., Equipped Ring) 
	TURN_BASED # Applies math/tags for X turns, handled discretely by an external Turn Manager.
}

## Defines the stacking behaviour for the effect.
enum StackingPolicy { 
	FREE,             # Can have infinite overlapping instances of this effect.
	REFRESH_DURATION  # If applied again, resets the timer of the existing instance instead of adding a new one.
}

# "Effect Rules"
## How this effect behaves if it is applied while already active on the target.
## FREE = multiple unique stacks, REFRESH_DURATION will refresh existing
## NOTE: Does not override or decide 'if' a effect stacks
var stacking_policy: StackingPolicy = StackingPolicy.FREE
## How long this effect persists on the target.
var policy: DurationPolicy = DurationPolicy.INSTANT:
	set(value):
		policy = value
		notify_property_list_changed()
	get:
		return policy
## The lifespan of the effect in seconds. Only used if policy is DURATION.
var duration: = 0.0: 
	set(value): 
		duration = maxf(0.0, value)
	get:
		return duration
## Periodic modifiers are permanent and do NOT reverse when the effect ends.
## Note: For Turn-Based effects, set this to 1.0 to tell the system it is a DoT, not a Buff.
var period: = 0.0

# "Turn Based Settings"
## How many turns this effect lasts.
var duration_turns: = 1
## If true, periodic effects (period > 0) trigger their math and cues when the turn advances.
var tick_on_turn_start: = true

# "Application Requirements"
## The target MUST have all of these tags for this effect to apply.
## (e.g., Must have 'Status.Burning' for an 'Explode' effect to work).
var application_required_tags: Array[StringName] = []
## The target must NOT have any of these tags. If they do, the effect is blocked.
## (e.g., Target has 'Status.Immune.Poison', so block poison effects).
var application_ignore_tags: Array[StringName] = []

# "Cue Management"
## Cues that play exactly once when the effect is first applied to a target.
var application_cue_tags: Array[StringName] = []
## Cues that play every time a periodic tick occurs.
var periodic_cue_tags: Array[StringName] = []

# "Attribute Modifiers"
## Custom mathematical scripts that run complex logic (e.g., Damage = Attack - Defense).
var executions: Array[GameplayExecutionCalculation] = []
## A list of simple mathematical changes this effect applies to the target's AttributeSets.
var modifiers: Array[GameplayEffectModifier] = []

# "State Management"
## Tags granted to the target ASC for as long as this effect is active.
## Not used for events, but state ie: 'Status.Stunned'
## NOTE: Instant effects do not grant tags.
var granted_tags: Array[StringName] = []

# "Event Management"
## Tags broadcasted directly to the target's ASC as Gameplay Events upon application (or periodic tick).
## Ideal for waking up reactive passive abilities (e.g., 'Event.Damage.Taken').
var event_tags: Array[StringName] = []


func _get_property_list() -> Array[Dictionary]:
	var property_list: Array[Dictionary] = [
		{
			"name": "Effect Rules",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
		},
		{
			"name": "stacking_policy",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(
				[
					"Free",
					"Refresh duration",
				]
			)
		},
		{
			"name": "policy",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(
				[
					"Instant",
					"Duration",
					"Infinite",
					"Turn based",
				]
			)
		},
		{
			"name": "duration",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,9999.0,0.1,or_greater",
		},
		{
			"name": "period",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,999.0,0.1,or_greater",
		},
	]

	if policy == DurationPolicy.TURN_BASED:
		property_list.append_array(
			[
				{
					"name": "Turn Based Settings",
					"type": TYPE_NIL,
					"usage": PROPERTY_USAGE_GROUP,
				},
				{
					"name": "duration_turns",
					"type": TYPE_INT,
					"hint": PROPERTY_HINT_RANGE,
					"hint_string": "0,999,1,or_greater",
				},
				{
					"name": "tick_on_turn_start",
					"type": TYPE_BOOL,
				},
			]
		)

	property_list.append_array(
		[
			{
				"name": "Application Requirements",
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_GROUP,
			},
			{
				"name": "application_required_tags",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_ARRAY_TYPE,
				"hint_string": "StringName,gas::tag",
			},
			{
				"name": "application_ignore_tags",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_ARRAY_TYPE,
				"hint_string": "StringName,gas::tag",
			},

			{
				"name": "Cue Management",
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_GROUP,
			},
			{
				"name": "application_cue_tags",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_ARRAY_TYPE,
				"hint_string": "StringName,gas::tag",
			},
			{
				"name": "periodic_cue_tags",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_ARRAY_TYPE,
				"hint_string": "StringName,gas::tag",
			},

			{
				"name": "Attribute Modifiers",
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_GROUP,
			},
			{
				"name": "executions",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_ARRAY_TYPE,
				"hint_string": "GameplayExecutionCalculation",
			},
			{
				"name": "modifiers",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_ARRAY_TYPE,
				"hint_string": "GameplayEffectModifier",
			},

			{
				"name": "State Management",
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_GROUP,
			},
			{
				"name": "granted_tags",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_ARRAY_TYPE,
				"hint_string": "StringName,gas::tag",
			},

			{
				"name": "Event Management",
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_GROUP,
			},
			{
				"name": "event_tags",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_ARRAY_TYPE,
				"hint_string": "StringName,gas::tag",
			},
		]
	)

	return property_list


func _property_can_revert(property: StringName) -> bool:
	return property in [
		# "Effect Rules"
		&"stacking_policy",
		&"policy",
		&"duration",
		&"period",

		# "Turn Based Settings"
		&"duration_turns",
		&"tick_on_turn_start",

		# "Application Requirements"
		&"application_required_tags",
		&"application_ignore_tags",

		# "Cue Management"
		&"application_cue_tags",
		&"periodic_cue_tags",

		# "Attribute Modifiers"
		&"executions",
		&"modifiers",

		# "State Management"
		&"granted_tags",

		# "Event Management"
		&"event_tags",
	]


func _property_get_revert(property: StringName) -> Variant:
	match property:
		# "Effect Rules"
		&"stacking_policy":
			return StackingPolicy.FREE
		&"policy":
			return DurationPolicy.INSTANT
		&"duration":
			return 0.0
		&"period":
			return 0.0

		# "Turn Based Settings"
		&"duration_turns":
			return 1
		&"tick_on_turn_start":
			return true

		# "Application Requirements"
		&"application_required_tags":
			return []
		&"application_ignore_tags":
			return []

		# "Cue Management"
		&"application_cue_tags":
			return []
		&"periodic_cue_tags":
			return []

		# "Attribute Modifiers"
		&"executions":
			return []
		&"modifiers":
			return []

		# "State Management"
		&"granted_tags":
			return []

		# "Event Management"
		&"event_tags":
			return []
		_:
			return null
