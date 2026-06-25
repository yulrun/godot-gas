## Custom editor property for selecting and managing gameplay tags.
##
## Displays a button in the inspector that opens a dedicated tag editor 
## popup window, allowing users to assign, create, or delete tags.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
extends EditorProperty

## File path to the default tag registry resource.
const REGISTRY_PATH = "res://addons/GodotGAS/data/default_tag_registry.tres"

## The main button displayed in the inspector row.
var _button := Button.new()

## The transient popup window containing the tag tree.
var _popup: Window

## Input field for filtering the tag tree.
var _search_bar: LineEdit

## Tree node displaying the hierarchical tag list.
var _tree: Tree

## Input field for defining a new gameplay tag.
var _new_tag_input: LineEdit

## Button used to submit the new tag to the registry.
var _add_tag_button: Button

## Label providing feedback on user actions (e.g., success or error).
var _status_label: Label

## Reference to the active global tag registry resource.
var _registry: GameplayTagRegistry

## Array tracking the currently selected tags for the inspected object.
var _current_tags: Array = []

## Flag to prevent recursive updates when modifying tags from within the tree.
var _is_updating_from_tree: bool = false


#region Initialization & Lifecycle
func _init() -> void:
	_registry = load(REGISTRY_PATH) as GameplayTagRegistry
	
	_button.text = "Edit Tags..."
	_button.clip_text = true
	add_child(_button)
	add_focusable(_button)
	_button.pressed.connect(_on_button_pressed)


## Connects to the registry signal when the property enters the inspector.
func _enter_tree() -> void:
	if _registry and not _registry.changed.is_connected(_on_registry_changed):
		_registry.changed.connect(_on_registry_changed)


## Cleans up the connection to prevent memory leaks.
func _exit_tree() -> void:
	if _registry and _registry.changed.is_connected(_on_registry_changed):
		_registry.changed.disconnect(_on_registry_changed)
#endregion



#region Virtual Overrides
## Automatically validates this property if a tag is deleted globally.
func _on_registry_changed() -> void:
	var object = get_edited_object()
	if not is_instance_valid(object) or not _registry: 
		return
	
	var prop_name = get_edited_property()
	var val = object.get(prop_name)
	var did_change = false
	
	if val is Array:
		# Duplicate the array to preserve Godot's strict typing
		var new_val = val.duplicate()
		var original_size = new_val.size()
		
		# Iterate backwards when removing items from an array
		for i in range(new_val.size() - 1, -1, -1):
			if not _registry.has_tag(StringName(new_val[i])):
				new_val.remove_at(i)
				
		if new_val.size() != original_size:
			_current_tags = new_val.duplicate()
			emit_changed(prop_name, _current_tags)
			did_change = true
			
	elif val is StringName or val is String:
		var t_str = String(val)
		if not t_str.is_empty() and not _registry.has_tag(StringName(t_str)):
			_current_tags.clear()
			emit_changed(prop_name, StringName(""))
			did_change = true
			
	# If this specific inspector row lost a tag, update its text instantly
	if did_change:
		_button.text = "Tags (%d selected)" % _current_tags.size()


## Synchronizes the UI with the inspected object's data.
func _update_property() -> void:
	var val = get_edited_object().get(get_edited_property())
	if val is Array:
		_current_tags = val.duplicate()
	elif val is StringName or val is String:
		_current_tags = [val] if not String(val).is_empty() else []
	
	_button.text = "Tags (%d selected)" % _current_tags.size()
	
	if is_instance_valid(_popup) and _popup.visible and not _is_updating_from_tree:
		_refresh_tree()
#endregion


#region UI Handlers
func _on_button_pressed() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()
		
	_popup = Window.new()
	_popup.title = "Gameplay Tag Editor"
	_popup.size = Vector2i(900, 750)
	_popup.transient = true
	_popup.exclusive = true
	_popup.close_requested.connect(func(): _popup.queue_free.call_deferred())
	
	EditorInterface.get_base_control().add_child(_popup)
	_popup.popup_centered()
	
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	_popup.add_child(main_vbox)
	
	_search_bar = LineEdit.new()
	_search_bar.placeholder_text = "Search tags..."
	_search_bar.text_changed.connect(func(_new_text): _refresh_tree())
	main_vbox.add_child(_search_bar)
	
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.item_edited.connect(_on_tree_item_edited)
	_tree.button_clicked.connect(_on_tree_button_clicked)
	main_vbox.add_child(_tree)
	
	var h_split := HBoxContainer.new()
	main_vbox.add_child(h_split)
	
	_new_tag_input = LineEdit.new()
	_new_tag_input.placeholder_text = "New.Tag.Hierarchy"
	_new_tag_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_split.add_child(_new_tag_input)
	
	_add_tag_button = Button.new()
	_add_tag_button.text = "Add Tag"
	_add_tag_button.pressed.connect(_on_add_custom_tag)
	h_split.add_child(_add_tag_button)
	
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_status_label)
	
	_refresh_tree()


func _refresh_tree() -> void:
	if not is_instance_valid(_tree) or not _registry: 
		return
	
	_tree.clear()
	var root = _tree.create_item()
	var filter = _search_bar.text.to_lower()
	var created_nodes: Dictionary = {}
	var trash_icon = EditorInterface.get_editor_theme().get_icon("Remove", "EditorIcons")
	
	for tag in _registry.tags:
		var tag_str = String(tag).strip_edges()
		if tag_str.is_empty(): 
			continue
		
		if not filter.is_empty() and not filter in tag_str.to_lower():
			continue
			
		var parts = tag_str.split(".")
		var current_path = ""
		var parent_item = root
		
		for i in range(parts.size()):
			var part_name = parts[i].strip_edges()
			if part_name.is_empty(): 
				continue
			
			current_path = part_name if current_path.is_empty() else current_path + "." + part_name
			
			if created_nodes.has(current_path):
				parent_item = created_nodes[current_path]
			else:
				var item = _tree.create_item(parent_item)
				item.set_metadata(0, current_path)
				
				if current_path == tag_str:
					item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
					item.set_text(0, part_name)
					item.set_checked(0, _current_tags.has(StringName(current_path)))
					item.set_editable(0, true)
					item.add_button(0, trash_icon, 1, false, "Delete from Registry")
				else:
					item.set_text(0, part_name)
					
				created_nodes[current_path] = item
				parent_item = item


func _on_tree_item_edited() -> void:
	var item = _tree.get_edited()
	if not item: 
		return
	
	var tag_path = StringName(item.get_metadata(0))
	var is_checked = item.is_checked(0)
	
	_is_updating_from_tree = true
	
	var prop_type = get_edited_object().get(get_edited_property())
	if prop_type is Array:
		if is_checked and not _current_tags.has(tag_path):
			_current_tags.append(tag_path)
		elif not is_checked and _current_tags.has(tag_path):
			_current_tags.erase(tag_path)
		emit_changed(get_edited_property(), _current_tags)
	else:
		if is_checked:
			emit_changed(get_edited_property(), tag_path)
		else:
			emit_changed(get_edited_property(), StringName(""))
			
		if is_instance_valid(_popup):
			_popup.hide()
			_popup.queue_free.call_deferred()
			
	_is_updating_from_tree = false


func _on_tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	if id == 1: 
		var tag_to_remove = StringName(item.get_metadata(0))
		
		var prop_type = get_edited_object().get(get_edited_property())
		if prop_type is Array and _current_tags.has(tag_to_remove):
			_current_tags.erase(tag_to_remove)
			emit_changed(get_edited_property(), _current_tags)
		elif not prop_type is Array and _current_tags.size() > 0 and _current_tags[0] == tag_to_remove:
			_current_tags.clear() 
			emit_changed(get_edited_property(), StringName(""))
		
		_button.text = "Tags (%d selected)" % _current_tags.size()
		
		_registry.remove_tag(tag_to_remove)
		_set_status("Deleted tag: " + tag_to_remove, true)
		_refresh_tree()


func _on_add_custom_tag() -> void:
	var text = _new_tag_input.text.strip_edges()
	if text.is_empty(): 
		return
	
	if not _registry:
		_set_status("Error: Tag Registry not found.", false)
		return
		
	var result_message = _registry.add_tag(text)
	
	if not result_message.begins_with("Error:"):
		_set_status("Successfully added: " + result_message, true)
		_new_tag_input.text = ""
		_refresh_tree()
	else:
		_set_status(result_message.replace("Error: ", ""), false)


func _set_status(message: String, is_success: bool) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message
		if is_success:
			_status_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
		else:
			_status_label.add_theme_color_override("font_color", Color.LIGHT_CORAL)
#endregion
