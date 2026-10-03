# GodotGAS v1.1.2 - "Core Concepts" Demo

## Preface: Installation & Setup
Before opening the demo scenes, you must configure your project data. 
1. Ensure your Godot project has the **GodotGAS Addon (v1.1.2 or higher)** installed and enabled.
2. Drag and drop the attached `godot_gas` folder directly into the root (`res://`) of your project. 
3. This folder contains the pre-configured `DemoAttributeSet`, the `GameplayTags` registry, and the generated GDScript references required for the demo scenes to function.

## Core Concepts
This demo provides a sterile, UI-driven environment. By binding buttons directly to the `AbilitySystemComponent` (ASC) and docking the visual `GASRuntimeDebugger` on-screen, these scenes isolate complex mathematical and state-driven mechanics so you can watch exactly how the framework responds in real-time.

---

### Scene 1: The Basics (Costs & Cooldowns)
**Purpose:** Understand how to grant abilities, deduct resources, apply cooldowns, and handle gatekeeper rejections.
* **What it Does:** Instantiates an ASC and grants it two code-first abilities: a Damage Spell and a Heal Spell. When cast, the system deducts Mana and applies a Cooldown tag. If the player lacks Mana or is on Cooldown, the ASC's Gatekeeper intercepts the cast and emits a failure signal.
* **How to Learn From It:** Click the spells and watch the debugger. Observe how the Cooldown effect counts down in real-time under "Active Effects." Try to cast while on cooldown or with low Mana, and watch the event log catch the specific `ActivationError` enum (e.g., `ON_COOLDOWN`). Open the script to see how `commit_ability()` is used to cleanly separate the cost/cooldown from the actual payload logic.

### Scene 2: Stacking & Overflow Engine
**Purpose:** Master stack limits, duration refreshing, overflow payloads, and the Cleanser pattern.
* **What it Does:** Allows you to apply a "Chill" debuff (-50 Speed) that stacks up to 3 times, refreshing its 4-second duration on every application. If a 4th stack is applied, the framework purges the Chill stacks and triggers the "Frozen" overflow effect—an infinite debuff that overrides Speed to 0.0. A "Thaw" cleanser button purges the Frozen effect.
* **How to Learn From It:** Spam the Chill button and watch the stack count increment in the debugger while the timer resets. Trigger the overflow and notice how the `OVERRIDE` modifier highlights the Speed attribute in orange. Attempt to apply Chill while Frozen to see how the `application_query` securely blocks conflicting effects.

### Scene 3: Dynamic Math (SetByCaller & Attribute-Based)
**Purpose:** Break away from static, hardcoded numbers by injecting variables at runtime or scaling off live attributes.
* **What it Does:** Features a UI slider to determine incoming damage. Instead of a hardcoded damage modifier, the Damage effect uses `SET_BY_CALLER` to wait for the slider's value injected via a `GameplayEffectSpec`. The Heal effect uses `ATTRIBUTE_BASED` scaling to automatically heal the player for exactly 50% of their current buffed Armor value.
* **How to Learn From It:** Move the slider and click "Apply Slider Damage." Look at the script to see how `GameplayEffectSpec.set_set_by_caller_magnitude()` passes UI data into the engine. Then, click the Armor Heal and notice how the system dynamically checks the ASC's `armor` attribute at the exact moment of execution to calculate the 50% scaling.

### Scene 4: Inhibition & Cleansers
**Purpose:** Learn how to temporarily suspend active effects (Inhibition) and permanently destroy them (Cleansers).
* **What it Does:** You cast an infinite "Shield Aura" (+50 Armor). You then apply a "Silence" debuff. The Shield Aura has an `ongoing_suppression_query` listening for Silence; the moment Silence is applied, the Aura's +50 Armor vanishes, and its granted tags drop. A "Purge" button permanently destroys the Silence, instantly reactivating the Aura.
* **How to Learn From It:** Cast the Aura and apply Silence. Look at the debugger: the Aura effect remains in memory under "Active Effects," but is flagged in red as `(Suppressed)`. Purge the Silence and watch the math and tags seamlessly re-aggregate without having to recast the Aura.

### Scene 5: Execution Calculations (ExecCalcs)
**Purpose:** Write complex custom GDScript combat formulas that go beyond basic addition and multiplication.
* **What it Does:** Simulates an RPG combat swing: `Damage = Max(1.0, AttackPower - Armor)`. The user sets the Attack Power via a slider, and can infinitely stack a +5 Armor buff on the defender. The framework passes the `GameplayEffectSpec` and Target ASC into a custom `GameplayExecutionCalculation` script to evaluate the final math.
* **How to Learn From It:** Set the Attack Power to 30. Click the +5 Armor buff until the defender has 40+ Armor. Execute the attack. Watch the event log report that exactly `1.0` damage was dealt, proving that the custom GDScript `maxf()` floor calculation in the ExecCalc successfully overrode the standard modifiers. 

### Scene 6: Event-Driven Passives
**Purpose:** Decouple abilities from player inputs using event listeners and asynchronous task routing.
* **What it Does:** Grants a "Reactive Heal" passive ability that sits completely dormant. You apply an infinite "Burning" DoT that ticks every 3 seconds. Every time the DoT ticks, it globally broadcasts the `Event.Combat.Hit` tag. The passive ability intercepts this tag, wakes up, waits asynchronously for 1 second, and then applies a minor heal.
* **How to Learn From It:** Apply the Burn and do nothing. Watch the visual rhythm in the log: the DoT deals damage, 1 second passes, and the passive heals. Open the script and inspect `trigger_event_tag` to see how abilities automatically wake up, and how `await task_wait_delay()` is utilized inside an executing ability without freezing the main game thread.
