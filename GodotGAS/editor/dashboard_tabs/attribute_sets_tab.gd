## Editor tool for managing, configuring, and generating GodotGAS AttributeSets.
##
## Provides a UI for creating attribute categories, defining default values,
## assigning icons, and compiling the configuration into GDScript files.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
extends Control

## The file path where attribute drafts are saved.
const DRAFTS_PATH = "res://addons/GodotGAS/data/attribute_drafts.cfg"

## The default directory for generated attribute scripts.
const DEFAULT_OUTPUT_DIR = "res://gas_attributes"

## Icon for Attribute Set categories.
const SET_ICON = preload("res://addons/GodotGAS/icons/godot_gas_attributes.svg")

## Default icon for an individual attribute.
const DEFAULT_ATTR_ICON = preload("res://addons/GodotGAS/icons/godot_gas_icon_star.svg")

## Icon used for the inline edit action.
const EDIT_ICON_ICON = preload("res://addons/GodotGAS/icons/godot_gas_icon_edit.svg")

## A dictionary mapping available attribute icon names to their resource paths.
const ATTR_ICONS = {
	"Star": preload("res://addons/GodotGAS/icons/godot_gas_icon_star.svg"),
	"Heart": preload("res://addons/GodotGAS/icons/godot_gas_icon_heart.svg"),
	"Bolt": preload("res://addons/GodotGAS/icons/godot_gas_icon_bolt.svg"),
	"Shield": preload("res://addons/GodotGAS/icons/godot_gas_icon_shield.svg"),
	"Sword": preload("res://addons/GodotGAS/icons/godot_gas_icon_sword.svg"),
}

## Enum representing the available inline tree action buttons.
enum TreeBtn { EDIT, DUPLICATE, DELETE, CHANGE_ICON }

## Configuration file resource holding the current uncompiled drafts.
var _drafts: ConfigFile = ConfigFile.new()

## The name of the currently selected Attribute Set.
var _current_set: String = ""

## The directory path where the generated script will be saved.
var _output_dir: String = DEFAULT_OUTPUT_DIR

## The popup dialog used for configuring generation settings.
var _settings_dialog: ConfirmationDialog

## The dialog used to browse for output directories.
var _dir_dialog: EditorFileDialog

## The UI text field displaying the current output directory.
var _dir_label: LineEdit

## The dialog used to confirm deletion of sets or attributes.
var _delete_confirm_dialog: ConfirmationDialog

## The dialog used to display warning and error messages.
var _error_dialog: AcceptDialog

## The dynamic inline popup menu for selecting attribute icons.
var _icon_popup: PopupMenu

## A mapped array of icon names matching the index in the popup menu.
var _icon_names_map: Array[String] = []

## Tracks the name of the attribute currently having its icon changed.
var _editing_icon_attr: String = ""

## Tracks whether a 'set' or 'attribute' is currently staged for deletion.
var _delete_target_type: String = ""

## Tracks the specific name of the item staged for deletion.
var _delete_target_name: String = ""

## The generated system accent color for active UI elements.
var _sys_accent: String

## The generated stylebox used for selected items in the trees.
var _selected_box: StyleBoxFlat

## The generated accent color used for text highlighting.
var _text_accent: Color

## Reference to the tree node displaying Attribute Sets.
@onready var _set_tree: Tree = %SetTree

## Reference to the line edit for new set names.
@onready var _new_set_input: LineEdit = %NewSetInput

## Reference to the button to create a new set.
@onready var _btn_create_set: Button = %BtnCreateSet

## Reference to the label displaying the currently selected set.
@onready var _lbl_selected_set: Label = %LblSelectedSet

## Reference to the settings button.
@onready var _btn_settings: Button = %BtnSettings

## Reference to the tree node displaying attributes for the selected set.
@onready var _attribute_tree: Tree = %AttributeTree

## Reference to the line edit for new attribute names.
@onready var _new_attribute_input: LineEdit = %NewAttributeInput

## Reference to the option button for selecting an attribute icon.
@onready var _btn_icon: OptionButton = %BtnIcon

## Reference to the spinbox for the new attribute value.
@onready var _new_attribute_value: SpinBox = %NewAttributeValue

## Reference to the button to add a new attribute.
@onready var _btn_add_attribute: Button = %BtnAddAttribute

## Reference to the button to generate the final GDScript.
@onready var _btn_generate_script: Button = %BtnGenerateScript


#region Initialization
## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		_load_drafts()
		_setup_ui()
		_refresh_set_tree()
		_refresh_attribute_tree()


## Loads the saved draft data and settings.
func _load_drafts() -> void:
	if _drafts.load(DRAFTS_PATH) == OK:
		# Load custom directory if it exists, otherwise use default
		_output_dir = _drafts.get_value("Settings", "output_dir", DEFAULT_OUTPUT_DIR)


## Binds all signals and constructs the dynamic dialogs.
func _setup_ui() -> void:
	# General Buttons
	_btn_create_set.pressed.connect(_on_create_set_pressed)
	_btn_add_attribute.pressed.connect(_on_add_attribute_pressed)
	_btn_generate_script.pressed.connect(_on_generate_script_pressed)
	_btn_settings.pressed.connect(_on_settings_pressed)
	
	_new_attribute_input.text_submitted.connect(func(_t): _on_add_attribute_pressed())
	_new_set_input.text_submitted.connect(func(_t): _on_create_set_pressed())

	# Populate Icon Dropdowns & Popup Menus
	if _btn_icon:
		_btn_icon.clear()
		for icon_name in ATTR_ICONS.keys():
			_btn_icon.add_icon_item(ATTR_ICONS[icon_name], icon_name)
			
	# Build the dynamic PopupMenu for inline editing
	_icon_popup = PopupMenu.new()
	var idx = 0
	for icon_name in ATTR_ICONS.keys():
		_icon_popup.add_icon_item(ATTR_ICONS[icon_name], icon_name, idx)
		_icon_names_map.append(icon_name)
		idx += 1
	_icon_popup.id_pressed.connect(_on_icon_popup_id_pressed)
	add_child(_icon_popup)

	# Coloring & Styling
	_text_accent = DisplayServer.get_accent_color() + (Color.WHITE * 0.25)
	_sys_accent = _text_accent.darkened(0.75).to_html(false)
	_selected_box = StyleBoxFlat.new()
	_selected_box.bg_color = Color(_sys_accent)
	_selected_box.set_content_margin_all(15)
	_selected_box.set_corner_radius_all(5)

	# Setup Set Tree
	_set_tree.hide_root = true
	_set_tree.columns = 1
	_set_tree.button_clicked.connect(_on_set_tree_button_clicked)
	_set_tree.item_edited.connect(_on_set_tree_item_edited)
	_set_tree.item_selected.connect(_on_set_tree_item_selected)
	
	_set_tree.add_theme_stylebox_override("selected", _selected_box)
	_set_tree.add_theme_stylebox_override("selected_focus", _selected_box)
	_set_tree.add_theme_color_override("guide_color", Color(1, 1, 1, 0.15))
	
	# Setup Attribute Tree
	_attribute_tree.hide_root = true
	_attribute_tree.columns = 2
	_attribute_tree.set_column_title(0, "Attribute Name")
	_attribute_tree.set_column_title(1, "Base Value")
	_attribute_tree.set_column_titles_visible(true)
	
	# Set the Column Ratios (75% / 25%)
	_attribute_tree.set_column_expand(0, true)
	_attribute_tree.set_column_expand_ratio(0, 3) 
	_attribute_tree.set_column_expand(1, true)
	_attribute_tree.set_column_expand_ratio(1, 1)
	
	_attribute_tree.button_clicked.connect(_on_attribute_tree_button_clicked)
	_attribute_tree.item_edited.connect(_on_attribute_tree_item_edited)
	
	_attribute_tree.add_theme_stylebox_override("selected", _selected_box)
	_attribute_tree.add_theme_stylebox_override("selected_focus", _selected_box)
	_attribute_tree.add_theme_color_override("guide_color", Color(1, 1, 1, 0.15))

	# Build Shared Dialogs
	_delete_confirm_dialog = ConfirmationDialog.new()
	_delete_confirm_dialog.confirmed.connect(_execute_delete)
	add_child(_delete_confirm_dialog)
	
	_error_dialog = AcceptDialog.new()
	_error_dialog.title = "Action Failed"
	add_child(_error_dialog)

	# Build Settings Dialog
	_btn_settings.icon = get_theme_icon("Tools", "EditorIcons")
	
	_settings_dialog = ConfirmationDialog.new()
	_settings_dialog.title = "Attribute Set Settings"
	_settings_dialog.confirmed.connect(_on_settings_saved)

	var vbox = VBoxContainer.new()
	var hbox = HBoxContainer.new()
	
	_dir_label = LineEdit.new()
	_dir_label.editable = false
	_dir_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn_browse = Button.new()
	btn_browse.text = "Browse..."
	btn_browse.pressed.connect(func(): _dir_dialog.popup_file_dialog())
	btn_browse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn_reset = Button.new()
	btn_reset.text = "Reset Default"
	btn_reset.pressed.connect(func(): _dir_label.text = DEFAULT_OUTPUT_DIR)
	btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	hbox.add_child(btn_browse)
	hbox.add_child(btn_reset)
	var label = Label.new()
	label.text = "Script Output Directory: "
	vbox.add_child(label)
	vbox.add_child(_dir_label)
	vbox.add_child(hbox)
	_settings_dialog.add_child(vbox)
	add_child(_settings_dialog)
	
	_dir_dialog = EditorFileDialog.new()
	_dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_dir_dialog.dir_selected.connect(func(dir): _dir_label.text = dir)
	add_child(_dir_dialog)
	
	_update_right_panel_state()
#endregion


#region Settings Logic
## Triggered when the settings icon is clicked.
func _on_settings_pressed() -> void:
	_dir_label.text = _output_dir
	_settings_dialog.popup_centered(Vector2i(450, 0))


## Triggered when the user confirms changes in the settings dialog.
func _on_settings_saved() -> void:
	_output_dir = _dir_label.text
	_drafts.set_value("Settings", "output_dir", _output_dir)
	_drafts.save(DRAFTS_PATH)
	print("GodotGAS: Output directory updated to ", _output_dir)
#endregion


#region Set Manager Logic
## Rebuilds the UI tree displaying all Attribute Sets.
func _refresh_set_tree() -> void:
	_set_tree.clear()
	var root = _set_tree.create_item()
	
	for set_name in _drafts.get_sections():
		if set_name == "Settings": 
			continue
		
		var item = _set_tree.create_item(root)
		item.set_text(0, set_name)
		item.set_icon(0, SET_ICON)
		item.set_metadata(0, set_name)
		item.set_editable(0, false)
		
		item.add_button(0, get_theme_icon("Edit", "EditorIcons"), TreeBtn.EDIT, false, "Rename Set")
		item.add_button(0, get_theme_icon("ActionCopy", "EditorIcons"), TreeBtn.DUPLICATE, false, "Duplicate Set")
		item.add_button(0, get_theme_icon("Remove", "EditorIcons"), TreeBtn.DELETE, false, "Delete Set")
		
		if set_name == _current_set:
			item.select(0)


## Triggered when an action button on a set tree item is clicked.
func _on_set_tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	var set_name = item.get_metadata(0)
	
	if id == TreeBtn.EDIT:
		item.set_editable(0, true) # Temporarily unlock for editing
		item.select(0)
		_set_tree.edit_selected(true)
		
	elif id == TreeBtn.DUPLICATE:
		var new_name = set_name + "Copy"
		var counter = 2
		while _drafts.has_section(new_name):
			new_name = set_name + "Copy" + str(counter)
			counter += 1
			
		for key in _drafts.get_section_keys(set_name):
			_drafts.set_value(new_name, key, _drafts.get_value(set_name, key))
			
		_drafts.save(DRAFTS_PATH)
		_refresh_set_tree()
		
	elif id == TreeBtn.DELETE:
		_delete_target_type = "set"
		_delete_target_name = set_name
		_delete_confirm_dialog.dialog_text = "Delete Attribute Set?\nThis will permanently destroy '%s' and all its contents." % set_name
		_delete_confirm_dialog.popup_centered()


## Triggered when the user finishes renaming a set in the tree.
func _on_set_tree_item_edited() -> void:
	var item = _set_tree.get_edited()
	if not item: 
		return
	
	item.set_editable(0, false) # Immediately lock it back after editing
	
	var old_name = item.get_metadata(0)
	var new_name = item.get_text(0).strip_edges().to_pascal_case()
	
	# Validate rename
	if new_name == "" or new_name == "Settings" or new_name == old_name:
		item.set_text(0, old_name) # Revert visually
		return
		
	if _drafts.has_section(new_name):
		_error_dialog.dialog_text = "An Attribute Set named '%s' already exists." % new_name
		_error_dialog.popup_centered()
		item.set_text(0, old_name)
		return
		
	# Copy keys to new section, delete old
	for key in _drafts.get_section_keys(old_name):
		_drafts.set_value(new_name, key, _drafts.get_value(old_name, key))
	_drafts.erase_section(old_name)
	_drafts.save(DRAFTS_PATH)
	
	item.set_metadata(0, new_name)
	item.set_text(0, new_name) # Ensure pascal_case reflects
	if _current_set == old_name:
		_current_set = new_name
		_update_right_panel_state()


## Triggered when a set is selected to display its attributes.
func _on_set_tree_item_selected() -> void:
	var item = _set_tree.get_selected()
	if item:
		_current_set = item.get_metadata(0)
		_refresh_attribute_tree()


## Triggered to create a new empty attribute set.
func _on_create_set_pressed() -> void:
	var set_name = _new_set_input.text.strip_edges()
	if set_name == "": 
		return
	
	set_name = set_name.to_pascal_case()
	if set_name == "Settings":
		_error_dialog.dialog_text = "Cannot name an Attribute Set 'Settings' as it is a reserved keyword."
		_error_dialog.popup_centered()
		return
		
	if not _drafts.has_section(set_name):
		_drafts.set_value(set_name, "_initialized", true) 
		_drafts.save(DRAFTS_PATH)
		_new_set_input.text = ""
		_current_set = set_name
		_refresh_set_tree()
		_refresh_attribute_tree()
	else:
		_error_dialog.dialog_text = "An Attribute Set named '%s' already exists." % set_name
		_error_dialog.popup_centered()
#endregion


#region Attribute Manager Logic
## Toggles the disabled state of the attribute editor panel based on selection.
func _update_right_panel_state() -> void:
	var has_set = _current_set != ""
	_new_attribute_input.editable = has_set
	_new_attribute_value.editable = has_set
	_btn_icon.disabled = not has_set
	_btn_add_attribute.disabled = not has_set
	_btn_generate_script.disabled = not has_set
	_lbl_selected_set.text = ("%s Attributes" % _current_set) if has_set else "No Set Selected"


## Rebuilds the UI tree displaying the selected set's attributes.
func _refresh_attribute_tree() -> void:
	_attribute_tree.clear()
	_update_right_panel_state()
	
	if _current_set == "" or not _drafts.has_section(_current_set): 
		return
		
	var root = _attribute_tree.create_item()
		
	for key in _drafts.get_section_keys(_current_set):
		if key == "_initialized": 
			continue 
		
		# Handle old float data vs new dictionary data
		var raw_val = _drafts.get_value(_current_set, key)
		var val: float = 0.0
		var icon_key: String = "Attribute"
		
		if typeof(raw_val) == TYPE_DICTIONARY:
			val = raw_val.get("value", 0.0)
			icon_key = raw_val.get("icon", "Attribute")
		else:
			val = float(raw_val)
			_drafts.set_value(_current_set, key, {"value": val, "icon": icon_key}) # Auto-migrate old data
		
		var item = _attribute_tree.create_item(root)
		
		# Name Column (0)
		item.set_text(0, key)
		item.set_metadata(0, key)
		item.set_editable(0, true)
		
		# Resolving Icon
		if ATTR_ICONS.has(icon_key):
			item.set_icon(0, ATTR_ICONS[icon_key])
		else:
			item.set_icon(0, DEFAULT_ATTR_ICON) # Safely catches legacy "Attribute" references
		
		# Value Column (1)
		item.set_text(1, str(val))
		item.set_editable(1, true)
		item.set_custom_color(1, _text_accent)
		
		item.add_button(1, EDIT_ICON_ICON, TreeBtn.CHANGE_ICON, false, "Change Icon")
		item.add_button(1, get_theme_icon("ActionCopy", "EditorIcons"), TreeBtn.DUPLICATE, false, "Duplicate Attribute")
		item.add_button(1, get_theme_icon("Remove", "EditorIcons"), TreeBtn.DELETE, false, "Delete Attribute")


## Triggered when an action button on an attribute tree item is clicked.
func _on_attribute_tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	var attr_name = item.get_metadata(0)
		
	if id == TreeBtn.CHANGE_ICON:
		_editing_icon_attr = attr_name
		# Spawn the popup precisely where the mouse is
		_icon_popup.popup(Rect2(DisplayServer.mouse_get_position(), Vector2.ZERO))
		
	elif id == TreeBtn.DUPLICATE:
		var new_name = attr_name + "_copy"
		var counter = 2
		while _drafts.has_section_key(_current_set, new_name):
			new_name = attr_name + "_copy" + str(counter)
			counter += 1
			
		var data_dict = _drafts.get_value(_current_set, attr_name)
		_drafts.set_value(_current_set, new_name, data_dict)
		_drafts.save(DRAFTS_PATH)
		_refresh_attribute_tree()
		
	elif id == TreeBtn.DELETE:
		_delete_target_type = "attribute"
		_delete_target_name = attr_name
		_delete_confirm_dialog.dialog_text = "Delete Attribute '%s' from '%s'?" % [attr_name, _current_set]
		_delete_confirm_dialog.popup_centered()


## Triggered when the user selects a new icon from the inline PopupMenu.
func _on_icon_popup_id_pressed(id: int) -> void:
	if _editing_icon_attr == "" or _current_set == "": 
		return
	
	var chosen_icon_name = _icon_names_map[id]
	var data_dict = _drafts.get_value(_current_set, _editing_icon_attr)
	
	# Safety net
	if typeof(data_dict) != TYPE_DICTIONARY:
		data_dict = {"value": float(data_dict), "icon": "Attribute"}
		
	data_dict["icon"] = chosen_icon_name
	_drafts.set_value(_current_set, _editing_icon_attr, data_dict)
	_drafts.save(DRAFTS_PATH)
	
	_editing_icon_attr = "" # Clear state
	_refresh_attribute_tree()


## Triggered when the user finishes editing an attribute's name or value.
func _on_attribute_tree_item_edited() -> void:
	var item = _attribute_tree.get_edited()
	var col = _attribute_tree.get_edited_column()
	if not item: 
		return
	
	var old_name = item.get_metadata(0)
	var data_dict = _drafts.get_value(_current_set, old_name)
	
	# Safety catch in case it hasn't been migrated yet
	if typeof(data_dict) != TYPE_DICTIONARY:
		data_dict = {"value": float(data_dict), "icon": "Attribute"}
	
	if col == 0: # Renamed the attribute
		var new_name = item.get_text(0).strip_edges().to_snake_case()
		if new_name == "" or new_name == old_name:
			item.set_text(0, old_name)
			return
			
		if _drafts.has_section_key(_current_set, new_name):
			_error_dialog.dialog_text = "An attribute named '%s' already exists in this set." % new_name
			_error_dialog.popup_centered()
			item.set_text(0, old_name)
			return
			
		_drafts.erase_section_key(_current_set, old_name)
		_drafts.set_value(_current_set, new_name, data_dict)
		item.set_metadata(0, new_name)
		item.set_text(0, new_name) # Ensure snake_case reflects
		_drafts.save(DRAFTS_PATH)
		
	elif col == 1: # Changed the default value
		var new_val = item.get_text(1).to_float()
		item.set_text(1, str(new_val)) # Visually clean formatting
		data_dict["value"] = new_val
		_drafts.set_value(_current_set, old_name, data_dict)
		_drafts.save(DRAFTS_PATH)


## Triggered when adding a brand new attribute to the set.
func _on_add_attribute_pressed() -> void:
	var attr_name = _new_attribute_input.text.strip_edges()
	if attr_name == "" or _current_set == "": 
		return
	
	attr_name = attr_name.to_snake_case()
	if _drafts.has_section_key(_current_set, attr_name): 
		_error_dialog.dialog_text = "An attribute named '%s' already exists in this set." % attr_name
		_error_dialog.popup_centered()
		return
		
	var val = _new_attribute_value.value
	var icon_idx = _btn_icon.selected
	var icon_name = _btn_icon.get_item_text(icon_idx) if icon_idx >= 0 else "Attribute"
	
	var data_dict = {"value": val, "icon": icon_name}
	
	_drafts.set_value(_current_set, attr_name, data_dict)
	_drafts.save(DRAFTS_PATH)
	
	_new_attribute_input.text = ""
	_new_attribute_value.value = 0.0
	_refresh_attribute_tree()
#endregion


#region Deletion Routing
## Global routing function that fires after the confirm dialog is accepted.
func _execute_delete() -> void:
	if _delete_target_type == "set":
		_drafts.erase_section(_delete_target_name)
		if _current_set == _delete_target_name:
			_current_set = ""
		_drafts.save(DRAFTS_PATH)
		_refresh_set_tree()
		_refresh_attribute_tree()
		
	elif _delete_target_type == "attribute":
		_drafts.erase_section_key(_current_set, _delete_target_name)
		_drafts.save(DRAFTS_PATH)
		_refresh_attribute_tree()
		
	_delete_target_type = ""
	_delete_target_name = ""
#endregion


#region Script Generation
## Compiles the selected draft into a live GDScript resource.
func _on_generate_script_pressed() -> void:
	if _current_set == "": 
		return
	
	var file_name = _current_set.to_snake_case() + "_attribute_set.gd"
	var file_path = _output_dir + "/" + file_name
	
	# SAFEGUARD: Check if the script is open in the Editor
	var script_editor = EditorInterface.get_script_editor()
	for script in script_editor.get_open_scripts():
		if script.resource_path == file_path:
			var warning = AcceptDialog.new()
			warning.title = "Cannot Generate Script"
			warning.dialog_text = "The script '" + file_name + "' is currently open in your Script workspace.\n\nPlease close the script tab before regenerating to prevent data corruption."
			add_child(warning)
			warning.popup_centered()
			return

	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(_output_dir):
		var err = DirAccess.make_dir_recursive_absolute(_output_dir)
		if err != OK:
			push_error("GodotGAS: Failed to create output directory. Error: ", err)
			return

	# Build GDScript String
	var script_text = "## An extended class for the attribute module: %s \n" %_current_set
	script_text += "##\n"
	script_text += "## @meta_addon: GodotGAS 1.0\n"
	script_text += "## @meta_author: YulRun (https://YulRun.Dev) & 'Your Name Here'\n"
	script_text += "## @meta_license: MIT (Default)\n\n"
	script_text += "@tool\nclass_name " + _current_set + "AttributeSet extends AttributeSet\n\n"
	
	var keys = _drafts.get_section_keys(_current_set)
	var valid_attributes = []
	
	for key in keys:
		if key == "_initialized": 
			continue
			
		valid_attributes.append(key)
		
		# Safely extract ONLY the numerical value from the Drafts data
		var raw_val = _drafts.get_value(_current_set, key)
		var val: float = 0.0
		if typeof(raw_val) == TYPE_DICTIONARY:
			val = raw_val.get("value", 0.0)
		else:
			val = float(raw_val)
			
		script_text += "var %s: AttributeData = AttributeData.new(%s)\n" % [key, str(val)]
	
	script_text += "\n\n"
	
	# Boilerplate Pipeline Block (with max_ stat auto-matching)
	script_text += "## The safety pipeline: Clamps stats before they are officially changed.\n"
	script_text += "func pre_attribute_change(attribute_name: String, proposed_value: float) -> float:\n"
	script_text += "\tmatch attribute_name:\n"
	
	var has_match = false
	for key in valid_attributes:
		# Auto-generate clamp boilerplate if a generic stat has a matching 'max_' equivalent
		if not "max_" in key.to_lower() and not "min_" in key.to_lower():
			var max_k = "max_" + key
			if max_k in valid_attributes:
				# Check for a matching min_ attribute, default to 0.0 if missing
				var min_k = "min_" + key
				var min_val = min_k + ".current_value" if min_k in valid_attributes else "0.0"
				
				script_text += "\t\t\"%s\":\n" % key
				script_text += "\t\t\treturn clamp(proposed_value, %s, %s.current_value)\n" % [min_val, max_k]
				has_match = true
	
	if not has_match:
		script_text += "\t\t_:\n"
		script_text += "\t\t\tpass\n"
	
	script_text += "\n\treturn proposed_value\n"

	# Write to Disk
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(script_text)
		file.close()
		EditorInterface.get_resource_filesystem().scan()
		
		var success = AcceptDialog.new()
		success.title = "Success"
		success.dialog_text = "%s was successfully generated at:\n\"%s\"" % [file_name, file_path]
		add_child(success)
		success.popup_centered()
	else:
		var err_dialog = AcceptDialog.new()
		err_dialog.title = "Write Error"
		err_dialog.dialog_text = "Failed to write script file at:\n" + file_path
		add_child(err_dialog)
		err_dialog.popup_centered()
#endregion
