## Editor tool for mapping GameplayTags to GameplayCues.
##
## Provides a UI to associate visual/audio scenes with specific tags,
## storing these mappings in the global cue registry.
##
## @meta_addon: GodotGAS Version 1 (See plugin version for exact version)
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
extends Control

## Addon project settings.
const GodotGasProjectSettings: = preload("res://addons/GodotGAS/utilities/project_settings.gd")

## Icon used to represent gameplay tags.
const TAG_ICON = preload("res://addons/GodotGAS/icons/godot_gas_tags.svg")

## Icon used to represent packed scenes (cues).
const SCENE_ICON = preload("res://addons/GodotGAS/icons/godot_gas_cues.svg")

## Reference to the active global cue registry resource.
var _registry: GameplayCueRegistry

## Temporary storage for the tag currently being mapped.
var _draft_tag: StringName = ""

## Temporary storage for the scene currently being mapped.
var _draft_scene: PackedScene = null

## Tracks the array index of the cue currently being edited (-1 if new).
var _editing_index: int = -1

## Tracks the array index of the cue staged for deletion.
var _delete_index: int = -1

## Dialog used to select a PackedScene file.
var _scene_dialog: EditorFileDialog

## Dialog used to select a GameplayTag from the registry.
var _tag_dialog: ConfirmationDialog

## Container for the tag selection tree interface.
var _tag_tree_vbox: VBoxContainer

## Input field for filtering the tag selection tree.
var _tag_search_bar: LineEdit

## Button to toggle the expand/collapse state of the tag tree.
var _btn_tag_expand_collapse: Button

## Tree node displaying available gameplay tags.
var _tag_tree: Tree

## Dialog used to confirm the deletion of a cue mapping.
var _delete_confirm_dialog: ConfirmationDialog

## The generated system accent color for active UI elements.
var _sys_accent: String

## In-memory styles used to override panels natively to prevent dirtying .tres files
var _base_panel_style: StyleBoxFlat
var _dark_panel_style: StyleBoxFlat
var _header_panel_style: StyleBoxFlat
var _list_item_style: StyleBoxFlat

## Reference to the search filter input field.
@onready var _search_bar: LineEdit = %SearchFilter

## Reference to the vertical box containing the mapped cues.
@onready var _cue_list_vbox: VBoxContainer = %CueListVBox

## Reference to the label displaying the selected scene file name.
@onready var _lbl_selected_scene: Label = %LblSelectedScene

## Reference to the button used to trigger tag selection.
@onready var _btn_select_tag: Button = %BtnSelectTag

## Reference to the button used to browse for a scene file.
@onready var _btn_browse_scene: Button = %BtnBrowseScene

## Reference to the button used to commit a new or edited mapping.
@onready var _btn_add_mapping: Button = %BtnAddMapping

## Reference to the button used to cancel the current edit.
@onready var _btn_cancel: Button = %BtnCancel


#region Initialization
## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		_load_registry()
		_setup_ui()
		_sync_theme_colors()
		_refresh_cue_list()
		_reset_form()
		
		# Connect the Search Filter
		if _search_bar:
			_search_bar.text_changed.connect(_on_search_changed)


## Loads the cue registry from disk.
func _load_registry() -> void:
	var cue_registry_path: = GodotGasProjectSettings.get_registry_cue_path()
	if ResourceLoader.exists(cue_registry_path):
		_registry = load(cue_registry_path) as GameplayCueRegistry
	else:
		push_warning("GodotGAS: Cue Registry not found at " + cue_registry_path)


## Receives Godot Engine broadcasts, allowing us to seamlessly update colors if the user changes themes.
func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_THEME_CHANGED:
		if Engine.is_editor_hint() and is_node_ready():
			_sync_theme_colors()
			var filter_text = _search_bar.text if _search_bar else ""
			_refresh_cue_list(filter_text)


## Wires up signals and instantiates the dynamic UI dialogs.
func _setup_ui() -> void:
	# Connect Form Buttons
	_btn_browse_scene.pressed.connect(_on_browse_scene_pressed)
	_btn_select_tag.pressed.connect(_on_select_tag_pressed)
	_btn_add_mapping.pressed.connect(_on_add_mapping_pressed)
	
	_btn_cancel.pressed.connect(_reset_form)
	_btn_cancel.icon = get_theme_icon("Close", "EditorIcons")
	
	# Fetch theme colors and apply styling
	_sync_theme_colors()
	
	if _cue_list_vbox:
		_cue_list_vbox.add_theme_constant_override("separation", 8)
	
	# Build the Scene Browser Dialog
	_scene_dialog = EditorFileDialog.new()
	_scene_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_scene_dialog.add_filter("*.tscn", "Godot Scene")
	_scene_dialog.file_selected.connect(_on_scene_selected)
	add_child(_scene_dialog)
	
	# Build the Delete Confirmation Dialog
	_delete_confirm_dialog = ConfirmationDialog.new()
	_delete_confirm_dialog.confirmed.connect(_execute_delete)
	add_child(_delete_confirm_dialog)
	
	# Build the Scalable Tag Picker (Tree View with Search)
	_tag_dialog = ConfirmationDialog.new()
	_tag_dialog.title = "Select Gameplay Tag"
	_tag_dialog.confirmed.connect(_on_tag_dialog_confirmed)
	
	_tag_tree_vbox = VBoxContainer.new()
	_tag_tree_vbox.custom_minimum_size = Vector2(800, 600)
	
	# Create HBox for Search Bar + Expand/Collapse Button
	var search_hbox = HBoxContainer.new()
	_tag_tree_vbox.add_child(search_hbox)
	
	_tag_search_bar = LineEdit.new()
	_tag_search_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tag_search_bar.placeholder_text = "Filter Tags..."
	_tag_search_bar.clear_button_enabled = true
	_tag_search_bar.text_changed.connect(_on_tag_search_changed)
	search_hbox.add_child(_tag_search_bar)
	
	_btn_tag_expand_collapse = Button.new()
	_btn_tag_expand_collapse.icon = get_theme_icon("CollapseTree", "EditorIcons")
	_btn_tag_expand_collapse.tooltip_text = "Collapse Tree"
	_btn_tag_expand_collapse.pressed.connect(_on_tag_expand_collapse_pressed)
	search_hbox.add_child(_btn_tag_expand_collapse)
	
	_tag_tree = Tree.new()
	_tag_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tag_tree.hide_root = true
	_tag_tree_vbox.add_child(_tag_tree)
	
	_tag_dialog.add_child(_tag_tree_vbox)
	add_child(_tag_dialog)


## Synchronizes internal color variables and generates dynamic StyleBoxes to match the Editor Theme.
func _sync_theme_colors() -> void:
	if not Engine.is_editor_hint(): return
	var editor_theme = EditorInterface.get_editor_theme()
	if not editor_theme: return
	
	var editor_accent = editor_theme.get_color("accent_color", "Editor")
	var base_color = editor_theme.get_color("base_color", "Editor")
	var dark_color = editor_theme.get_color("dark_color_1", "Editor")
	
	var is_dark_theme = base_color.get_luminance() < 0.5
	var header_color = base_color.lightened(0.08) if is_dark_theme else base_color.darkened(0.08)
	var list_item_color = dark_color.lightened(0.05) if is_dark_theme else dark_color.darkened(0.05)
	
	# Fallback safeguard in case theme is completely unloaded during a hot-reload
	if base_color == Color(0, 0, 0, 1) and dark_color == Color(0, 0, 0, 1):
		return
		
	_sys_accent = editor_accent.to_html(false)
	
	if not _base_panel_style:
		_base_panel_style = StyleBoxFlat.new()
		_base_panel_style.set_content_margin_all(5)
		_base_panel_style.set_corner_radius_all(5)
		
	if not _dark_panel_style:
		_dark_panel_style = StyleBoxFlat.new()
		_dark_panel_style.set_content_margin_all(5)
		_dark_panel_style.set_corner_radius_all(5)
		
	if not _header_panel_style:
		_header_panel_style = StyleBoxFlat.new()
		_header_panel_style.set_content_margin_all(5)
		_header_panel_style.set_corner_radius_all(8)

	if not _list_item_style:
		_list_item_style = StyleBoxFlat.new()
		_list_item_style.set_content_margin_all(8)
		_list_item_style.set_corner_radius_all(8)
		
	_base_panel_style.bg_color = base_color
	_dark_panel_style.bg_color = dark_color
	_header_panel_style.bg_color = header_color
	_list_item_style.bg_color = list_item_color
	
	_apply_panel_colors(self)
	
	# Safely apply to the parent TabContainer (Delayed by 1 frame so parent can initialize)
	if get_parent() is TabContainer:
		get_parent().set_tab_icon.call_deferred(get_index(), GodotGasProjectSettings.get_svg_icon("res://addons/GodotGAS/icons/godot_gas_cues.svg"))


## Traverses the UI tree to identify PanelContainers by their .tres assignment and applies the local StyleBox override.
func _apply_panel_colors(node: Node) -> void:
	if node is PanelContainer:
		if not node.has_meta("panel_type"):
			var style = node.get_theme_stylebox("panel")
			if style and style.resource_path != "":
				if "editor_panel_flat_style_dark" in style.resource_path:
					node.set_meta("panel_type", "dark")
				elif "editor_panel_flat_style" in style.resource_path:
					node.set_meta("panel_type", "base")
					
		if node.has_meta("panel_type"):
			if node.get_meta("panel_type") == "base":
				node.add_theme_stylebox_override("panel", _base_panel_style)
			elif node.get_meta("panel_type") == "dark":
				node.add_theme_stylebox_override("panel", _dark_panel_style)
			elif node.get_meta("panel_type") == "header":
				node.add_theme_stylebox_override("panel", _header_panel_style)
				
	for child in node.get_children():
		_apply_panel_colors(child)
#endregion


#region Button Handlers & Search
## Called when the main search bar text is updated.
func _on_search_changed(new_text: String) -> void:
	_refresh_cue_list(new_text)


## Opens the file dialog to browse for a scene.
func _on_browse_scene_pressed() -> void:
	_scene_dialog.popup_file_dialog()


## Stores the selected scene path and updates the UI label.
func _on_scene_selected(path: String) -> void:
	_draft_scene = load(path) as PackedScene
	_lbl_selected_scene.text = path.get_file()


## Prepares and opens the dynamic tag picker dialog.
func _on_select_tag_pressed() -> void:
	_tag_search_bar.text = "" # Reset filter on open
	
	# Reset expand/collapse button state to default (Expanded)
	_btn_tag_expand_collapse.icon = get_theme_icon("CollapseTree", "EditorIcons")
	_btn_tag_expand_collapse.tooltip_text = "Collapse Tree"
	
	_build_tag_tree()
	_tag_dialog.popup_centered()


## Filters the dynamic tag tree based on search input.
func _on_tag_search_changed(new_text: String) -> void:
	_build_tag_tree(new_text)


## Toggles the expand/collapse state of all top-level tag tree items.
func _on_tag_expand_collapse_pressed() -> void:
	var root = _tag_tree.get_root()
	if not root or not root.get_first_child(): 
		return
	
	# Determine the new state based on the first child folder
	var new_collapsed_state = !root.get_first_child().collapsed
	
	# Apply to all top-level children
	for child in root.get_children():
		child.collapsed = new_collapsed_state
		
	# Update Button UI
	if new_collapsed_state:
		_btn_tag_expand_collapse.icon = get_theme_icon("ExpandTree", "EditorIcons")
		_btn_tag_expand_collapse.tooltip_text = "Expand Tree"
	else:
		_btn_tag_expand_collapse.icon = get_theme_icon("CollapseTree", "EditorIcons")
		_btn_tag_expand_collapse.tooltip_text = "Collapse Tree"


## Constructs the tag tree representation from the global tag registry.
func _build_tag_tree(filter: String = "") -> void:
	_tag_tree.clear()
	var root = _tag_tree.create_item()
	
	var tag_registry_path: = GodotGasProjectSettings.get_registry_tag_path()
	if not ResourceLoader.exists(tag_registry_path):
		push_error("GodotGAS: Tag Registry not found at " + tag_registry_path)
		return
		
	var tag_registry = load(tag_registry_path)
	var editor_theme = EditorInterface.get_editor_theme()
	var disabled_color = editor_theme.get_color("disabled_font_color", "Editor")
	
	# Create a list of currently mapped tags to grey them out
	var taken_tags = []
	if _registry:
		for entry in _registry.entries:
			taken_tags.append(entry.tag)

	# Build Tree from your Tag Registry data
	for tag_name in tag_registry.tags:
		var tag_str = String(tag_name)
		
		# Skip building this branch entirely if it doesn't match the filter
		if filter != "" and not filter.to_lower() in tag_str.to_lower():
			continue
			
		var parts = tag_str.split(".")
		var current = root
		
		for part in parts:
			var found_item: TreeItem = null
			var children: Array[TreeItem] = current.get_children()
			
			# Look for an existing folder/node
			for child in children:
				if child.get_text(0) == part:
					found_item = child
					break
			
			if found_item:
				current = found_item
			else:
				current = _tag_tree.create_item(current)
				current.set_text(0, part)
				# Auto-expand folders if the user is actively searching
				if filter != "":
					current.collapsed = false
		
		# Now 'current' is the leaf node. Disable it if already mapped.
		if tag_name in taken_tags:
			current.set_selectable(0, false)
			current.set_custom_color(0, disabled_color)
			current.set_tooltip_text(0, "Tag already mapped to a Cue")
		else:
			# Store the full tag string so we can retrieve it easily
			current.set_icon(0, TAG_ICON)
			current.set_custom_color(0, Color(_sys_accent))
			var part: String = current.get_text(0)
			current.set_text(0, part + " (" + tag_name + ")")
			current.set_metadata(0, tag_name)


## Validates and stores the tag selected from the picker dialog.
func _on_tag_dialog_confirmed() -> void:
	var selected = _tag_tree.get_selected()
	if selected:
		# If it's a folder, metadata is null. If it's a leaf, we get the tag string.
		var tag_val = selected.get_metadata(0)
		if tag_val != null:
			_draft_tag = tag_val
			_btn_select_tag.text = str(_draft_tag)
#endregion


#region CRUD Logic
## Commits the drafted mapping (tag + scene) into the cue registry.
func _on_add_mapping_pressed() -> void:
	if _draft_tag == "" or _draft_scene == null:
		push_warning("GodotGAS: Must select both a Tag and a Scene.")
		return
		
	# DUPLICATE CHECK: Prevent 1 tag having multiple scenes
	for i in range(_registry.entries.size()):
		if i != _editing_index and _registry.entries[i].tag == _draft_tag:
			push_error("GodotGAS: A cue is already mapped to '%s'. Only 1 Scene per Tag is allowed." % str(_draft_tag))
			return
		
	if _editing_index >= 0:
		var entry = _registry.entries[_editing_index]
		entry.tag = _draft_tag
		entry.scene = _draft_scene
	else:
		var new_entry = GameplayCueEntry.new()
		new_entry.tag = _draft_tag
		new_entry.scene = _draft_scene
		_registry.entries.append(new_entry)
		
	ResourceSaver.save(_registry, GodotGasProjectSettings.get_registry_cue_path())
	_reset_form()
	
	# Refresh using the current search bar text so the list doesn't visually reset
	var filter_text = _search_bar.text if _search_bar else ""
	_refresh_cue_list(filter_text)


## Sets up the form fields to edit an existing cue mapping.
func _on_edit_pressed(index: int) -> void:
	_editing_index = index
	var entry = _registry.entries[index]
	
	_draft_tag = entry.tag
	_draft_scene = entry.scene
	
	_btn_select_tag.text = str(entry.tag) if entry.tag else "Select Tag..."
	_lbl_selected_scene.text = entry.scene.resource_path.get_file() if entry.scene else "No Scene Selected"
	
	_btn_add_mapping.text = "Save Changes"
	_btn_add_mapping.icon = get_theme_icon("Save", "EditorIcons")
	_btn_cancel.show()


## Prepares the deletion confirmation dialog for a specific row.
func _on_delete_pressed(index: int) -> void:
	_delete_index = index
	var entry = _registry.entries[index]
	
	# Contextual popup showing what is being deleted
	_delete_confirm_dialog.dialog_text = "Delete Mapping?\nTag: %s\nScene: %s" % [str(entry.tag), entry.scene.resource_path.get_file() if entry.scene else "None"]
	_delete_confirm_dialog.popup_centered()


## Global routing function that fires after the delete confirm dialog is accepted.
func _execute_delete() -> void:
	if _delete_index < 0 or _delete_index >= _registry.entries.size():
		return
		
	_registry.entries.remove_at(_delete_index)
	ResourceSaver.save(_registry,  GodotGasProjectSettings.get_registry_cue_path())
	
	if _delete_index == _editing_index:
		_reset_form()
		
	_delete_index = -1
	
	var filter_text = _search_bar.text if _search_bar else ""
	_refresh_cue_list(filter_text)


## Resets the data entry form back to its default state.
func _reset_form() -> void:
	_editing_index = -1
	_draft_tag = ""
	_draft_scene = null
	
	_btn_select_tag.text = "Select Tag..."
	_lbl_selected_scene.text = "No Scene Selected"
	
	_btn_add_mapping.text = "Add Mapping"
	_btn_add_mapping.icon = get_theme_icon("Add", "EditorIcons")
	_btn_cancel.hide()


## Rebuilds the visual list of configured cue mappings.
func _refresh_cue_list(filter: String = "") -> void:
	for child in _cue_list_vbox.get_children():
		child.queue_free()

	if not _registry: 
		return

	# 1. Gather all entries that match the search filter
	var entries_to_show = []
	for entry in _registry.entries:
		var tag_str = str(entry.tag) if entry.tag else "No Tag Assigned"
		if filter == "" or filter.to_lower() in tag_str.to_lower():
			entries_to_show.append(entry)

	# 2. Build rows only for the filtered entries
	for i in range(entries_to_show.size()):
		var entry = entries_to_show[i]
		
		# Grab the original index so Edit/Delete affect the actual array, not the filtered position
		var original_index = _registry.entries.find(entry)
		
		# --- NEW: Beautiful Card Background ---
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", _list_item_style)
		
		var row = HBoxContainer.new()
		card.add_child(row)
		
		# --- NEW: VBox Wrapper to force perfect vertical centering ---
		var lbl_vbox = VBoxContainer.new()
		lbl_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var lbl = RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lbl.add_theme_stylebox_override("normal", StyleBoxEmpty.new()) # Destroys the faint editor background
		
		var tag_name = entry.tag if entry.tag else "No Tag Assigned"
		var scene_name = entry.scene.resource_path.get_file() if entry.scene else "No Scene Assigned"
		var scene_path = entry.scene.resource_path if entry.scene else "No Scene Assigned"
		
		# Fetch the exact hex string of Godot's native font color
		var editor_theme = EditorInterface.get_editor_theme()
		var icon_color_hex = editor_theme.get_color("font_color", "Editor").to_html(false)
		
		# Multiply Godot's standard 16px icon size by the user's monitor UI scale
		var icon_size = int(16 * EditorInterface.get_editor_scale())
		
		# Use the strict Godot 4 BBCode syntax (width=X height=Y color=#HEX)
		var tag_icon: String = "[img width=%d height=%d color=#%s]%s[/img]" % [icon_size, icon_size, icon_color_hex, TAG_ICON.resource_path]
		var scene_icon: String = "[img width=%d height=%d color=#%s]%s[/img]" % [icon_size, icon_size, icon_color_hex, SCENE_ICON.resource_path]
		
		lbl.text = tag_icon + " [color=" + _sys_accent + "][b]" + str(tag_name) + "[/b][/color] [i]executes [b]→[/b][/i] " + scene_icon + " [color=" + _sys_accent + "][b]" + scene_name + "[/b][/color] [i](" + scene_path + ")[/i]"
		
		# Parent everything up
		lbl_vbox.add_child(lbl)
		row.add_child(lbl_vbox)
		
		var edit_btn = Button.new()
		edit_btn.icon = get_theme_icon("Edit", "EditorIcons")
		edit_btn.pressed.connect(_on_edit_pressed.bind(original_index))
		
		var del_btn = Button.new()
		del_btn.icon = get_theme_icon("Remove", "EditorIcons")
		del_btn.pressed.connect(_on_delete_pressed.bind(original_index))
		
		row.add_child(edit_btn)
		row.add_child(del_btn)
		
		_cue_list_vbox.add_child(card)
#endregion
