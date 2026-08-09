## Custom editor property for selecting and managing gameplay tags.
##
## Displays a button in the inspector that opens a dedicated tag editor 
## popup window, allowing users to assign, create, or delete tags.
##
## @meta_addon: GodotGAS 1.0.5
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
extends EditorProperty

enum TreeItemButtonId {
	STRICT = 1,
	DELETE = 2,
}

## Addon project settings.
const GodotGasProjectSettings: = preload("res://addons/GodotGAS/utilities/project_settings.gd")

## Property type.
var property_type: = TYPE_STRING
## Only permit selection of strict types. (tree leaves)
var strict_only: = false


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
func _init(property_type: = TYPE_STRING, strict_only: = false) -> void:
	assert(
		property_type == TYPE_ARRAY
		or property_type == TYPE_PACKED_STRING_ARRAY
		or property_type == TYPE_STRING
		or property_type == TYPE_STRING_NAME,
		"Unsupported variant property type.",
	)
	self.property_type = property_type
	self.strict_only = strict_only

	_registry = load(GodotGasProjectSettings.get_registry_tag_path()) as GameplayTagRegistry
	
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
	
	if val is Array or val is PackedStringArray:
		# Enforce strict typing during validation purges
		var new_typed_array: Array[StringName] = []
		if val != null:
			new_typed_array.assign(val)
			
		var original_size = new_typed_array.size()
		
		# Iterate backwards when removing items from an array
		for i in range(new_typed_array.size() - 1, -1, -1):
			if not _registry.has_tag(StringName(new_typed_array[i])):
				new_typed_array.remove_at(i)
				
		if new_typed_array.size() != original_size:
			_current_tags = Array(new_typed_array)
			emit_changed(prop_name, new_typed_array if val is Array else PackedStringArray(new_typed_array))
			did_change = true
			
	elif val is StringName or val is String:
		var t_str = String(val)
		if not t_str.is_empty() and not _registry.has_tag(StringName(t_str)):
			_current_tags.clear()
			emit_changed(prop_name, StringName(""))
			did_change = true
			
	# If this specific inspector row lost a tag, update its text instantly
	if did_change:
		_update_button_text()


## Synchronizes the UI with the inspected object's data.
func _update_property() -> void:
	var val = get_edited_object().get(get_edited_property())
	
	if val is Array or val is PackedStringArray:
		_current_tags = Array(val) # Safely cast to standard Array for internal UI tracking
	elif val is StringName or val is String:
		_current_tags = [val] if not String(val).is_empty() else []
	
	_update_button_text()
	
	if is_instance_valid(_popup) and _popup.visible and not _is_updating_from_tree:
		_refresh_tree()


func _update_button_text() -> void:
	var tooltip_text: = ""
	var current_tags: = _current_tags.duplicate()
	current_tags.sort_custom(
		func(a: String, b: String):
			return a.casecmp_to(b) < 0
	)

	match property_type:
		TYPE_STRING, \
		TYPE_STRING_NAME:
			if current_tags.is_empty():
				_button.text = "No tag"
				tooltip_text = "No tag selected."
			else:
				_button.text = current_tags[0]
				tooltip_text = "Selected tag:"
				tooltip_text += "\n  - %s" % current_tags[0]
		TYPE_ARRAY, \
		TYPE_PACKED_STRING_ARRAY:
			if current_tags.is_empty():
				_button.text = "No tags"
				tooltip_text = "No tags selected."
			else:
				_button.text = "Tags (%d selected)" % current_tags.size()
				var plural: = ""
				if current_tags.size() >= 2:
					plural = "s"
				tooltip_text = "Selected tag%s:" % plural
				for current_tag in current_tags:
					tooltip_text += "\n  - %s" % current_tag

	_button.tooltip_text = tooltip_text

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
	var root: = _tree.create_item()
	var filter: = _search_bar.text.to_lower()
	var created_nodes: Dictionary = {}
	var icon_trash: = EditorInterface.get_editor_theme().get_icon("Remove", "EditorIcons")
	var icon_strict: = EditorInterface.get_editor_theme().get_icon("MatchCase", "EditorIcons")
	var accent_color: Color = EditorInterface.get_editor_theme().get_color("accent_color", "Editor")
	
	for tag in _registry.tags:
		var tag_str: = String(tag).strip_edges()
		if tag_str.is_empty(): 
			continue

		if not filter.is_empty() and not filter in tag_str.to_lower():
			continue
	
		var parts: = tag_str.split(".")
		var current_path: = StringName()
		var parent_item: = root
		
		for i in range(parts.size()):
			var part_name: = parts[i].strip_edges()
			if part_name.is_empty(): 
				continue
			
			current_path = StringName(
				part_name \
					if current_path.is_empty() \
					else current_path + "." + part_name,
			)

			if created_nodes.has(current_path):
				parent_item = created_nodes[current_path]
			else:
				var item: = _tree.create_item(parent_item)
				var item_checked: = false
				var tag_is_strict: = strict_only

				if current_path in _current_tags:
					item_checked = true
				elif GameplayTagUtilities.to_strict(current_path) in _current_tags:
					item_checked = true
					tag_is_strict = true

				item.set_metadata(0, {
					"tag": current_path,
					"is_strict": tag_is_strict,
				})
				item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
				item.set_text(0, part_name)
				item.set_tooltip_text(
					0, 
					GameplayTagUtilities.to_strict(current_path) \
						if tag_is_strict \
						else current_path,
				)
				item.set_checked(0, item_checked)
				item.set_editable(0, true)

				if current_path == tag_str:
					var icon_strict_index: = 0

					if not strict_only:
						item.add_button(0, icon_strict, TreeItemButtonId.STRICT, not item_checked, "Strict Match")
						icon_strict_index = item.get_button_count(0) - 1
						if tag_is_strict:
							item.set_button_color(0, icon_strict_index, accent_color)

					item.add_button(0, icon_trash, TreeItemButtonId.DELETE, false, "Delete from Registry")

				created_nodes[current_path] = item
				parent_item = item


func _on_tree_item_edited() -> void:
	var item = _tree.get_edited()
	if not item:
		return
	
	var metadata: Dictionary = item.get_metadata(0)
	var tag: StringName = metadata["tag"]
	var tag_is_strict: bool = metadata["is_strict"]
	var is_checked = item.is_checked(0)

	if tag_is_strict:
		tag = GameplayTagUtilities.to_strict(tag)
	
	_is_updating_from_tree = true
	
	var prop_val = get_edited_object().get(get_edited_property())
	if prop_val is Array or prop_val is PackedStringArray:
		# 1. CREATE STRICTLY TYPED ARRAY (Breaks memory link & fixes save bug!)
		var new_typed_array: Array[StringName] = []
		
		# 2. Copy the existing data safely
		if prop_val != null:
			new_typed_array.assign(prop_val)
			
		# 3. Apply the changes
		if is_checked and not new_typed_array.has(tag):
			new_typed_array.append(tag)
		elif not is_checked and new_typed_array.has(tag):
			new_typed_array.erase(tag)
			
		# 4. Sync UI tracking and emit the perfectly typed data
		_current_tags = Array(new_typed_array)
		emit_changed(get_edited_property(), new_typed_array if prop_val is Array else PackedStringArray(new_typed_array))
	else:
		if is_checked:
			emit_changed(get_edited_property(), tag)
		else:
			emit_changed(get_edited_property(), StringName(""))
			
		if is_instance_valid(_popup):
			_popup.hide()
			_popup.queue_free.call_deferred()
			
	_is_updating_from_tree = false


func _on_tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	match id:
		TreeItemButtonId.STRICT:
			_on_tree_button_strict(item, column, id, mouse_button_index)
		TreeItemButtonId.DELETE:
			_on_tree_button_delete(item, column, id, mouse_button_index)


func _on_tree_button_strict(item: TreeItem, column: int, _id: int, mouse_button_index: int) -> void:
	var metadata: Dictionary = item.get_metadata(0)
	var tag: StringName = metadata["tag"]
	var tag_is_strict: bool = metadata["is_strict"]
	var old_tag: = tag
	var new_tag: = tag
	var old_tag_is_strict: = tag_is_strict
	# The intent by clicking is to switch the current value.
	var new_tag_is_strict: = not tag_is_strict  

	if old_tag_is_strict:
		old_tag = GameplayTagUtilities.to_strict(tag)
	if new_tag_is_strict:
		new_tag = GameplayTagUtilities.to_strict(tag)

	var prop_val = get_edited_object().get(get_edited_property())
	var is_array_type = prop_val is Array or prop_val is PackedStringArray
	
	if is_array_type:
		# Break memory link with strictly typed array
		var new_typed_array: Array[StringName] = []
		if prop_val != null:
			new_typed_array.assign(prop_val)

		var tag_index: = new_typed_array.find(old_tag)
		if tag_index > -1:
			new_typed_array.set(tag_index, new_tag)

		_current_tags = Array(new_typed_array)
		emit_changed(get_edited_property(), new_typed_array if prop_val is Array else PackedStringArray(new_typed_array))
		
	elif not is_array_type and _current_tags.size() > 0 and _current_tags[0] == old_tag:
		_current_tags.set(0, new_tag)
		emit_changed(get_edited_property(), StringName(new_tag))
	
	_update_button_text()
	_refresh_tree()


func _on_tree_button_delete(item: TreeItem, column: int, _id: int, mouse_button_index: int) -> void:
	var metadata: Dictionary = item.get_metadata(0)
	var tag: StringName = metadata["tag"]
	var tag_is_strict: bool = metadata["is_strict"]
	var prop_val = get_edited_object().get(get_edited_property())
	var is_array_type = prop_val is Array or prop_val is PackedStringArray

	if tag_is_strict:
		tag = GameplayTagUtilities.to_strict(tag)

	if is_array_type:
		# Break memory link with strictly typed array
		var new_typed_array: Array[StringName] = []
		if prop_val != null:
			new_typed_array.assign(prop_val)
			
		if new_typed_array.has(tag):
			new_typed_array.erase(tag)
			
		_current_tags = Array(new_typed_array)
		emit_changed(get_edited_property(), new_typed_array if prop_val is Array else PackedStringArray(new_typed_array))
		
	elif not is_array_type and _current_tags.size() > 0 and _current_tags[0] == tag:
		_current_tags.clear()
		emit_changed(get_edited_property(), StringName(""))
	
	_update_button_text()
	
	_registry.remove_tag(tag)
	_set_status("Deleted tag: " + tag, true)
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
		var editor_theme = EditorInterface.get_editor_theme()
		if is_success:
			_status_label.add_theme_color_override("font_color", editor_theme.get_color("success_color", "Editor"))
		else:
			_status_label.add_theme_color_override("font_color", editor_theme.get_color("error_color", "Editor"))
#endregion
