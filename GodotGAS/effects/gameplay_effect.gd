## The core data asset that defines a buff, debuff, or instant change in the game.
##
## Game Designers create instances of this Resource to build out the game's skills.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayEffect extends Resource

## Defines the lifecycle behavior of the effect.
enum DurationPolicy { 
	INSTANT, # Applies math immediately and vanishes. Cannot grant tags. (e.g., Fireball Damage)
	DURATION, # Active math/tags persist for X seconds, then are removed. (e.g., 5-second Buff)
	INFINITE, # Active math/tags persist until explicitly removed. (e.g., Equipped Ring)
	TURN_BASED # Applies math/tags for X turns, handled discretely by an external Turn Manager.
}

## Defines the stacking behaviour for the effect.
enum StackingPolicy { 
	FREE,             # Can have infinite overlapping instances of this effect.
	REFRESH_DURATION  # If applied again, resets the timer of the existing instance instead of adding a new one.
}

## Defines how stacks are handled when multiple instigators apply the same effect.
enum InstigatorStackingPolicy { 
	SHARED_POOL,              # All applications merge into a single effect wrapper.
	INDEPENDENT_BY_INSTIGATOR # Applications from different instigators track independently.
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
## Note: For Turn-Based effects, set this to 1.0 to tell the system it is a DoT, not a Buff.
@export_range(0.0, 999.0, 0.1, "or_greater") var period: float = 0.0

@export_category("Stacking & Overflows")
## How this effect merges stacks from multiple different attackers.
@export var instigator_stacking_policy: InstigatorStackingPolicy = InstigatorStackingPolicy.SHARED_POOL
## The maximum number of stacks this effect can accumulate. 0 means infinite.
@export var max_stacks: int = 0
## Effects to apply to the target when the stack limit is reached and a new stack is attempted.
@export var overflow_effects: Array[GameplayEffect] = []
## If true, hitting the stack cap and attempting to add another stack will completely purge this effect.
@export var clear_stack_on_overflow: bool = false

@export_category("Turn Based Settings")
## How many turns this effect lasts (only used if policy is TURN_BASED).
@export_range(1, 999) var duration_turns: int = 1
## If true, periodic effects (period > 0) trigger their math and cues when the turn advances.
@export var tick_on_turn_start: bool = true

@export_category("Application Requirements")
## The query evaluated against the target's ASC to determine if this effect can be applied.
@export var application_query: GameplayTagQuery

@export_category("Cue Management")
## Cues that play exactly once when the effect is first applied to a target.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var application_cue_tags: Array[StringName] = []
## Cues that persistently loop while the effect is active, pausing during suppression.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var persistent_cue_tags: Array[StringName] = []
## Cues that play every time a periodic tick occurs.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var periodic_cue_tags: Array[StringName] = []
## Cues that play exactly once when the effect expires or is forcefully removed.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var removal_cue_tags: Array[StringName] = []

@export_category("Attribute Modifiers")
## Custom mathematical scripts that run complex logic (e.g., Damage = Attack - Defense).
@export var executions: Array[GameplayExecutionCalculation] = []
## A list of simple mathematical changes this effect applies to the target's AttributeSets.
@export var modifiers: Array[GameplayEffectModifier] = []

@export_category("State Management")
## If this effect is successfully applied, it will immediately purge any active effects on the target that grant these tags.
## (e.g., A 'Cure' potion would list 'Status.Poison' here).
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var remove_effects_with_tags: Array[StringName] = []
## Tags granted to the target ASC for as long as this effect is active.
## Not used for events, but state ie: 'Status.Stunned'
## NOTE: Instant effects do not grant tags.
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var granted_tags: Array[StringName] = []
## If the target matches this query while the effect is active, the effect's math and tags are temporarily suspended.
@export var ongoing_suppression_query: GameplayTagQuery

@export_category("Event Management")
## Tags broadcasted directly to the target's ASC as Gameplay Events upon application (or periodic tick).
## Ideal for waking up reactive passive abilities (e.g., 'Event.Damage.Taken').
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var event_tags: Array[StringName] = []
