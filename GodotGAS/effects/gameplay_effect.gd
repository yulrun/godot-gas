## The core data asset that defines a buff, debuff, or instant change in the game.
##
## Game Designers create instances of this Resource to build out the game's skills.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayEffect extends Resource

## Defines the lifecycle behavior of the effect.
enum DurationPolicy { 
	INSTANT, # Applies math immediately and vanishes. Cannot grant tags. (e.g., Fireball Damage)
	DURATION, # Applies math/tags for X seconds, then undoes them. (e.g., 5-second Poison)
	INFINITE # Applies math/tags permanently until explicitly removed. (e.g., Equipped Ring) 
}

## Defines the stacking behaviour for the effect.
enum StackingPolicy { 
	FREE,             # Can have infinite overlapping instances of this effect.
	REFRESH_DURATION  # If applied again, resets the timer of the existing instance instead of adding a new one.
}

@export_category("Effect Rules")
## How this effect behaves if it is applied while already active on the target.
## FREE = multiple unique stacks, REFRESH_DURATION will refresh existing
## NOTE: Does not override or decide 'if' a effect stacks
@export var stacking_policy: StackingPolicy = StackingPolicy.FREE
## How long this effect persists on the target.
@export var policy: DurationPolicy = DurationPolicy.INSTANT
## The lifespan of the effect in seconds. Only used if policy is DURATION.
@export_range(0.0, 9999.0, 0.1, "or_greater") var duration: float = 0.0: 
	set(value): 
		duration = maxf(0.0, value)
## Periodic modifiers are permanent and do NOT reverse when the effect ends.
@export_range(0.0, 999.0, 0.1, "or_greater") var period: float = 0.0

@export_category("Application Requirements")
## The target MUST have all of these tags for this effect to apply.
## (e.g., Must have 'Status.Burning' for an 'Explode' effect to work).
@export var application_required_tags: Array[StringName] = []
## The target must NOT have any of these tags. If they do, the effect is blocked.
## (e.g., Target has 'Status.Immune.Poison', so block poison effects).
@export var application_ignore_tags: Array[StringName] = []

@export_category("Cue Management")
## Cues that play exactly once when the effect is first applied to a target.
@export var application_cue_tags: Array[StringName] = []
## Cues that play every time a periodic tick occurs.
@export var periodic_cue_tags: Array[StringName] = []

@export_category("Attribute Modifiers")
## Custom mathematical scripts that run complex logic (e.g., Damage = Attack - Defense).
@export var executions: Array[GameplayExecutionCalculation] = []
## A list of simple mathematical changes this effect applies to the target's AttributeSets.
@export var modifiers: Array[GameplayEffectModifier] = []

@export_category("State Management")
## Tags granted to the target ASC for as long as this effect is active.
## Not used for events, but state ie: 'Status.Stunned'
## NOTE: Instant effects do not grant tags.
@export var granted_tags: Array[StringName] = []

@export_category("Event Management")
## Tags broadcasted directly to the target's ASC as Gameplay Events upon application (or periodic tick).
## Ideal for waking up reactive passive abilities (e.g., 'Event.Damage.Taken').
@export var event_tags: Array[StringName] = []
