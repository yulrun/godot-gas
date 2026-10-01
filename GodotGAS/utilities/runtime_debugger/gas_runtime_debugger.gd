## In-Engine Visual Runtime Debugger for GodotGAS
##
## Attach this script to a Node or CanvasLayer and assign a `target_asc`.
## It dynamically generates a UI overlay to monitor real-time tags, attributes,
## active effects, executing abilities, and recent tag activity on the target.
## Supports up to 4 concurrent debuggers with automatic clockwise collision resolution
## and responsive 50%/100% height expansion based on vertical neighbors.
##
## Toggle Visibility: CTRL+SHIFT+D (Windows/Linux) or CMD+SHIFT+D (macOS).
##
## @meta_addon: GodotGAS Version 1+
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GASRuntimeDebugger extends CanvasLayer

## Position on screen where the debugger panel docks.
enum DockPosition {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_RIGHT,
	BOTTOM_LEFT
}

## Group identifier used by all active runtime debuggers to coordinate layout.
const DEBUGGER_GROUP: StringName = &"GodotGAS.RuntimeDebuggers"

## Traversal order when resolving dock collisions.
const CLOCKWISE_DOCKS: Array[DockPosition] = [
	DockPosition.TOP_LEFT,
	DockPosition.TOP_RIGHT,
	DockPosition.BOTTOM_RIGHT,
	DockPosition.BOTTOM_LEFT
]

## Duration in seconds to retain recently added or removed tags in the activity monitor.
const RECENT_TAG_LIFETIME: float = 3.0

## Default pixel width of the docked debugger panel.
const PANEL_WIDTH: float = 360.0

## The screen corner where this debugger instance docks.
@export var dock_position: DockPosition = DockPosition.TOP_LEFT:
	set(value):
		dock_position = value
		if is_inside_tree() and _panel:
			update_all_debugger_layouts(get_tree())

## The AbilitySystemComponent this debugger will actively poll.
@export var target_asc: AbilitySystemComponent

## Root container panel for positioning and anchors.
var _panel: PanelContainer
## Reference to the main title Label.
var _lbl_title: Label
## Reference to the RichTextLabel displaying the target's attribute data.
var _lbl_attributes: RichTextLabel
## Reference to the RichTextLabel displaying the target's active tag state.
var _lbl_tags: RichTextLabel
## Reference to the RichTextLabel displaying recently added and lost tags.
var _lbl_recent_tags: RichTextLabel
## Reference to the RichTextLabel displaying the target's active gameplay effects.
var _lbl_effects: RichTextLabel
## Reference to the RichTextLabel displaying the target's granted and executing abilities.
var _lbl_abilities: RichTextLabel

## Tracks the initial unmutated base values for each attribute when first observed.
var _original_base_values: Dictionary[String, float] = {}

## Tracks recently added tags with their remaining display duration in seconds.
var _recently_added_tags: Dictionary[StringName, float] = {}

## Tracks recently removed tags with their remaining display duration in seconds.
var _recently_lost_tags: Dictionary[StringName, float] = {}

## Reference to the ASC currently bound for signal connections.
var _connected_asc: AbilitySystemComponent


#region Initialization & Lifecycle
## Initializes the debugger UI, resolves collisions, and validates the target ASC.
func _ready() -> void:
	if not is_instance_valid(target_asc):
		var parent := get_parent()
		if parent is AbilitySystemComponent:
			target_asc = parent as AbilitySystemComponent
		else:
			push_warning("GodotGAS: GASRuntimeDebugger requires a valid 'target_asc' or must be a child of an AbilitySystemComponent.")
			return

	add_to_group(DEBUGGER_GROUP)

	if not _resolve_dock_collision():
		set_process(false)
		visible = false
		queue_free()
		return

	_bind_asc_signals(target_asc)

	layer = 128
	
	_panel = PanelContainer.new()
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	add_child(_panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(margin)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(main_vbox)

	# Main Window Title
	var parent_name: String = ""
	if is_instance_valid(target_asc) and target_asc.get_parent():
		parent_name = target_asc.get_parent().name
	elif get_parent():
		parent_name = get_parent().name
	else:
		parent_name = "Entity"

	_lbl_title = Label.new()
	_lbl_title.text = "GASDebugger (%s)" % parent_name
	_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_title.add_theme_color_override("font_color", Color.YELLOW)
	main_vbox.add_child(_lbl_title)
	
	var title_separator := HSeparator.new()
	main_vbox.add_child(title_separator)

	# Viewport Scrolling
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(scroll)
	
	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_vbox)
	
	_lbl_attributes = _create_section(content_vbox, "ATTRIBUTES")
	_lbl_tags = _create_section(content_vbox, "TAGS")
	_lbl_recent_tags = _create_section(content_vbox, "RECENT TAG ACTIVITY")
	_lbl_effects = _create_section(content_vbox, "ACTIVE EFFECTS")
	_lbl_abilities = _create_section(content_vbox, "ABILITIES")

	update_all_debugger_layouts(get_tree())


## Cleans up active signal connections and informs remaining debuggers to re-evaluate height.
func _exit_tree() -> void:
	_unbind_asc_signals()
	remove_from_group(DEBUGGER_GROUP)
	var tree := get_tree()
	if tree:
		update_all_debugger_layouts.call_deferred(tree)


## Helper method to instantiate and style a labeled section within the debugger UI.
func _create_section(parent: Control, title: String) -> RichTextLabel:
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", Color.CYAN)
	parent.add_child(title_lbl)
	
	var content_lbl := RichTextLabel.new()
	content_lbl.bbcode_enabled = true
	content_lbl.fit_content = true
	content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(content_lbl)
	
	var separator := HSeparator.new()
	parent.add_child(separator)
	
	return content_lbl
#endregion


#region Input Handling
## Listens for the debugger toggle hotkey (CTRL+SHIFT+D or CMD+SHIFT+D).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D and event.shift_pressed and event.is_command_or_control_pressed():
			visible = not visible
			get_viewport().set_input_as_handled()
#endregion


#region Multi-Instance Layout Coordination
## Static coordinator instructing every active debugger in the SceneTree to recalculate anchors.
static func update_all_debugger_layouts(tree: SceneTree) -> void:
	if not tree:
		return
	var debuggers: Array[Node] = tree.get_nodes_in_group(DEBUGGER_GROUP)
	for node in debuggers:
		var dbg := node as GASRuntimeDebugger
		if is_instance_valid(dbg) and dbg._panel:
			dbg._recalculate_layout(debuggers)


## Detects if the chosen dock is occupied, seeking clockwise or failing if 4 are active.
func _resolve_dock_collision() -> bool:
	var tree := get_tree()
	if not tree:
		return true

	var occupied_positions: Dictionary[DockPosition, GASRuntimeDebugger] = {}
	for node in tree.get_nodes_in_group(DEBUGGER_GROUP):
		var dbg := node as GASRuntimeDebugger
		if dbg != self and is_instance_valid(dbg) and dbg.is_inside_tree():
			occupied_positions[dbg.dock_position] = dbg

	if not occupied_positions.has(dock_position):
		return true

	# Attempt clockwise search
	var start_idx: int = CLOCKWISE_DOCKS.find(dock_position)
	for i in range(1, CLOCKWISE_DOCKS.size()):
		var candidate: DockPosition = CLOCKWISE_DOCKS[(start_idx + i) % CLOCKWISE_DOCKS.size()]
		if not occupied_positions.has(candidate):
			push_warning("GodotGAS: Dock position '%s' is occupied. Re-routing debugger to '%s'." % [
				DockPosition.keys()[dock_position],
				DockPosition.keys()[candidate]
			])
			dock_position = candidate
			return true

	push_error("GodotGAS: Maximum limit of 4 GASRuntimeDebuggers reached. All dock quadrants are occupied.")
	return false


## Dynamically sets anchors based on quadrant and vertical neighbor presence (50% vs 100% height).
func _recalculate_layout(all_debuggers: Array[Node]) -> void:
	if not _panel:
		return

	# Scan for active positions in the scene
	var active_positions: Dictionary[DockPosition, bool] = {}
	for node in all_debuggers:
		var dbg := node as GASRuntimeDebugger
		if is_instance_valid(dbg) and dbg.is_inside_tree():
			active_positions[dbg.dock_position] = true

	var has_top_left: bool = active_positions.get(DockPosition.TOP_LEFT, false)
	var has_bottom_left: bool = active_positions.get(DockPosition.BOTTOM_LEFT, false)
	var has_top_right: bool = active_positions.get(DockPosition.TOP_RIGHT, false)
	var has_bottom_right: bool = active_positions.get(DockPosition.BOTTOM_RIGHT, false)

	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)

	match dock_position:
		DockPosition.TOP_LEFT:
			_panel.anchor_left = 0.0
			_panel.anchor_right = 0.0
			_panel.offset_left = 0.0
			_panel.offset_right = PANEL_WIDTH
			_panel.anchor_top = 0.0
			_panel.offset_top = 0.0
			_panel.offset_bottom = 0.0
			# Expand to 100% height if no neighbor below it
			_panel.anchor_bottom = 0.5 if has_bottom_left else 1.0

		DockPosition.BOTTOM_LEFT:
			_panel.anchor_left = 0.0
			_panel.anchor_right = 0.0
			_panel.offset_left = 0.0
			_panel.offset_right = PANEL_WIDTH
			_panel.anchor_bottom = 1.0
			_panel.offset_top = 0.0
			_panel.offset_bottom = 0.0
			# Expand to 100% height if no neighbor above it
			_panel.anchor_top = 0.5 if has_top_left else 0.0

		DockPosition.TOP_RIGHT:
			_panel.anchor_left = 1.0
			_panel.anchor_right = 1.0
			_panel.offset_left = -PANEL_WIDTH
			_panel.offset_right = 0.0
			_panel.anchor_top = 0.0
			_panel.offset_top = 0.0
			_panel.offset_bottom = 0.0
			# Expand to 100% height if no neighbor below it
			_panel.anchor_bottom = 0.5 if has_bottom_right else 1.0

		DockPosition.BOTTOM_RIGHT:
			_panel.anchor_left = 1.0
			_panel.anchor_right = 1.0
			_panel.offset_left = -PANEL_WIDTH
			_panel.offset_right = 0.0
			_panel.anchor_bottom = 1.0
			_panel.offset_top = 0.0
			_panel.offset_bottom = 0.0
			# Expand to 100% height if no neighbor above it
			_panel.anchor_top = 0.5 if has_top_right else 0.0
#endregion


#region Signal Management
## Binds tag signals on the target ASC to track addition and removal timelines.
func _bind_asc_signals(asc: AbilitySystemComponent) -> void:
	if _connected_asc == asc:
		return
		
	_unbind_asc_signals()
	
	if is_instance_valid(asc):
		_connected_asc = asc
		if not _connected_asc.tag_added.is_connected(_on_tag_added):
			_connected_asc.tag_added.connect(_on_tag_added)
		if not _connected_asc.tag_removed.is_connected(_on_tag_removed):
			_connected_asc.tag_removed.connect(_on_tag_removed)


## Safely disconnects bound ASC signals.
func _unbind_asc_signals() -> void:
	if is_instance_valid(_connected_asc):
		if _connected_asc.tag_added.is_connected(_on_tag_added):
			_connected_asc.tag_added.disconnect(_on_tag_added)
		if _connected_asc.tag_removed.is_connected(_on_tag_removed):
			_connected_asc.tag_removed.disconnect(_on_tag_removed)
	_connected_asc = null


## Records tag additions with a countdown timer.
func _on_tag_added(tag: StringName) -> void:
	_recently_added_tags[tag] = RECENT_TAG_LIFETIME
	if _recently_lost_tags.has(tag):
		_recently_lost_tags.erase(tag)


## Records tag removals with a countdown timer.
func _on_tag_removed(tag: StringName) -> void:
	_recently_lost_tags[tag] = RECENT_TAG_LIFETIME
	if _recently_added_tags.has(tag):
		_recently_added_tags.erase(tag)
#endregion


#region Polling & Refresh
## Actively polls the target ASC every frame and refreshes the UI data.
func _process(delta: float) -> void:
	if not is_instance_valid(target_asc):
		_unbind_asc_signals()
		if is_instance_valid(_lbl_attributes):
			_set_all_text("[color=gray]Waiting for Target ASC...[/color]")
		return
		
	if target_asc != _connected_asc:
		_bind_asc_signals(target_asc)
		
	_tick_recent_tags(delta)
	_update_attributes()
	_update_tags()
	_update_recent_tags()
	_update_effects()
	_update_abilities()


## Ticks down the display timer for recently added and removed tags.
func _tick_recent_tags(delta: float) -> void:
	for tag: StringName in _recently_added_tags.keys():
		_recently_added_tags[tag] -= delta
		if _recently_added_tags[tag] <= 0.0:
			_recently_added_tags.erase(tag)
			
	for tag: StringName in _recently_lost_tags.keys():
		_recently_lost_tags[tag] -= delta
		if _recently_lost_tags[tag] <= 0.0:
			_recently_lost_tags.erase(tag)


## Helper method to quickly overwrite all text labels.
func _set_all_text(text: String) -> void:
	_lbl_attributes.text = text
	_lbl_tags.text = text
	_lbl_recent_tags.text = text
	_lbl_effects.text = text
	_lbl_abilities.text = text


## Fetches attributes and applies contextual highlighting for modified or overridden values.
func _update_attributes() -> void:
	var bbcode: String = ""
	for set in target_asc.attribute_sets:
		if not set:
			continue
		for prop in set.get_property_list():
			if prop.class_name == &"AttributeData":
				var attr: AttributeData = set.get(prop.name)
				if attr:
					var attr_name: String = prop.name
					if not _original_base_values.has(attr_name):
						_original_base_values[attr_name] = attr.base_value
						
					var orig_base: float = _original_base_values[attr_name]
					
					# Highlight current value relative to base value
					var cur_color: String = "cyan"
					if attr.current_value > attr.base_value:
						cur_color = "green"
					elif attr.current_value < attr.base_value:
						cur_color = "red"
						
					# Determine if the base value was overridden via direct mutation or active effect
					var is_overridden: bool = not is_equal_approx(attr.base_value, orig_base)
					if not is_overridden:
						for active_effect in target_asc._active_effects:
							if active_effect.is_suppressed:
								continue
							var def := active_effect.get_effect_def()
							if not def:
								continue
							for mod in def.modifiers:
								if mod and mod.attribute_name == attr_name and mod.operation == GameplayEffectModifier.Operation.OVERRIDE:
									is_overridden = true
									break
							if is_overridden:
								break
					
					var base_text: String = ""
					if is_overridden:
						base_text = "[color=gray](Base: [/color][color=orange]%.1f[/color] [color=gray][Orig: %.1f])[/color]" % [attr.base_value, orig_base]
					else:
						base_text = "[color=gray](Base: %.1f)[/color]" % attr.base_value
						
					bbcode += "- %s: [color=%s]%.1f[/color] %s\n" % [attr_name.capitalize(), cur_color, attr.current_value, base_text]
					
	_lbl_attributes.text = bbcode if bbcode != "" else "[color=gray]No Attributes[/color]"


## Fetches and formats all active tags and their reference counts on the target ASC.
func _update_tags() -> void:
	var bbcode: String = ""
	for tag in target_asc._active_tags.keys():
		var count: int = target_asc._active_tags[tag]
		bbcode += "- %s [color=yellow]x%d[/color]\n" % [tag, count]
		
	_lbl_tags.text = bbcode if bbcode != "" else "[color=gray]No Active Tags[/color]"


## Displays recently added and removed tags during their active countdown period.
func _update_recent_tags() -> void:
	var bbcode: String = ""
	
	if not _recently_added_tags.is_empty():
		bbcode += "[b][color=green]Recently Added:[/color][/b]\n"
		for tag: StringName in _recently_added_tags.keys():
			var time_left: float = _recently_added_tags[tag]
			bbcode += "  + %s [color=gray](%.1fs)[/color]\n" % [tag, time_left]
			
	if not _recently_lost_tags.is_empty():
		if bbcode != "":
			bbcode += "\n"
		bbcode += "[b][color=red]Recently Lost:[/color][/b]\n"
		for tag: StringName in _recently_lost_tags.keys():
			var time_left: float = _recently_lost_tags[tag]
			bbcode += "  - %s [color=gray](%.1fs)[/color]\n" % [tag, time_left]
			
	_lbl_recent_tags.text = bbcode if bbcode != "" else "[color=gray]No Recent Tag Changes[/color]"


## Iterates over all active gameplay effects on the target ASC and formats their status.
func _update_effects() -> void:
	var bbcode: String = ""
	for active_effect in target_asc._active_effects:
		var def := active_effect.get_effect_def()
		if not def:
			continue
		
		var eff_name: String = def.resource_name
		if eff_name == "":
			eff_name = def.resource_path.get_file().get_basename()
		if eff_name == "":
			eff_name = "UnnamedEffect"
		
		var stacks: int = active_effect.stack_count
		var supp: String = " [color=red](Suppressed)[/color]" if active_effect.is_suppressed else ""
		
		match def.policy:
			GameplayEffect.DurationPolicy.INFINITE:
				bbcode += "- %s [color=yellow]x%d[/color] [color=gray](Infinite)[/color]%s\n" % [eff_name, stacks, supp]
			GameplayEffect.DurationPolicy.DURATION:
				bbcode += "- %s [color=yellow]x%d[/color] [color=orange](%.1fs)[/color]%s\n" % [eff_name, stacks, active_effect.time_remaining, supp]
			GameplayEffect.DurationPolicy.TURN_BASED:
				bbcode += "- %s [color=yellow]x%d[/color] [color=orange](%d turns)[/color]%s\n" % [eff_name, stacks, active_effect.spec.remaining_turns, supp]
				
	_lbl_effects.text = bbcode if bbcode != "" else "[color=gray]No Active Effects[/color]"


## Iterates over all granted abilities on the target ASC and displays their execution states.
func _update_abilities() -> void:
	var bbcode: String = ""
	for ability in target_asc._active_abilities:
		var state: String = "[color=green]Executing[/color]" if ability.is_active else "[color=gray]Idle[/color]"
		bbcode += "- %s: %s\n" % [ability.ability_tag, state]
		
	_lbl_abilities.text = bbcode if bbcode != "" else "[color=gray]No Granted Abilities[/color]"
#endregion
