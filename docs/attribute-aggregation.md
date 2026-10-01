# Attribute and effect math

GodotGAS stores two values in each `AttributeData`: `base_value` is the
permanent value, and `current_value` is the value used while effects are active.
The `AbilitySystemComponent` (ASC) derives the current value from the base and
the active effects whenever that set changes.

## Active, non-periodic effects

For each attribute, the ASC collects modifiers from all unsuppressed active
stacks. It evaluates them by operation, regardless of application order:

```text
current = pre_attribute_change(
    (base + sum(ADD magnitudes) + sum(execution deltas))
    * product(MULTIPLY magnitudes)
    / product(DIVIDE magnitudes)
)
```

An empty product is `1`. A divisor that is approximately zero is ignored.
`pre_attribute_change` belongs to the attribute set and can clamp the final
value. `OVERRIDE` takes precedence over this formula: the active override with
the highest `override_priority` supplies the value passed to
`pre_attribute_change`. If priorities are equal, the highest numeric magnitude
wins. Give coexisting overrides distinct priorities when one should reliably
win by design.

For example, base `10`, `ADD +2`, and `MULTIPLY 0.5` produce `6`, whichever
effect is applied first. Removing the addition leaves `5`; removing the
multiplier leaves `12`; removing both restores `10`. Two multipliers `0.8` and
`0.7` compound to `0.56`. Floating-point arithmetic can produce small rounding
differences, so compare results with an appropriate tolerance.

The ASC recalculates after effect application, removal, expiration, stack
changes, suppression, and unsuppression. Each active stack contributes its own
captured magnitudes. An effect suppressed by an ongoing tag query contributes
neither modifiers nor granted tags until it becomes active again. Cleansing an
effect removes its contribution; it does not reverse an old numeric delta.

Modifier magnitudes, including SetByCaller and attribute-based values, and
execution deltas are captured when each active stack is applied. Later changes
to the attributes used to calculate those magnitudes do not change that stack's
contribution. Apply another stack or effect to capture new values.

## Instant and periodic effects

Instant effects change `base_value` immediately. Periodic effects change the
base on each tick; their tick math is evaluated again at that time. Removing a
periodic effect does not undo ticks that have already occurred. After each base
change, the ASC clamps the new base through `pre_attribute_change` and
recalculates `current_value` with the active effects.

Instant and periodic changes occur in time order. For example, an instant
multiply followed by an instant addition can produce a different base from the
reverse order. The order independence above applies to the **same final set of
active, non-periodic modifiers with the same base and captured magnitudes**.

Do not assign `AttributeData.base_value` or `current_value` directly during
gameplay. Direct writes bypass ASC aggregation, and a later recalculation can
replace a manually assigned current value. Use an instant `GameplayEffect` for
a permanent change, or `initialize_attribute_overrides()` for initial values.

## Shared attributes and events

With `share_attributes = true`, ASCs that reference the same `AttributeData`
resource combine their active modifiers when deriving its current value. The
ASC performing the recalculation emits `attribute_changed` when the final
current value changes; other ASCs sharing the resource do not emit that signal
for the same transition. This path scans the ASCs sharing the resource on each
recalculation, which may matter if many actors share one resource.

The ASC also uses the aggregation rules when previewing ability costs. For
instant costs, it checks the prospective base as well as the resulting current
value. If an `AttributeSet` has clamping or custom cost rules, verify those
rules against the intended resource semantics.

## Testing

The existing native test scene is
`GodotGAS/utilities/testing/master_gas_tester.tscn`. Mount the addon at
`res://addons/GodotGAS`, then run the scene in Godot. Aggregation regressions
are in `GodotGAS/utilities/testing/modules/test_effects.gd` and the other
modules in that directory.
