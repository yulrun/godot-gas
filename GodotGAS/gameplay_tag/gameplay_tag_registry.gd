## The master list of all registered gameplay tags in the project.
##
## Stored as a serialized Array of StringNames for optimized memory 
## and comparison. Auto-formats and validates tags upon entry.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayTagRegistry extends Resource

## The master list of all registered tags in the project.
## Stored as an Array of StringNames for optimized memory and comparison.
@export var tags: Array[StringName] = []


#region Tag Management
## Attempts to add a new tag. Auto-formats casing before checking validity.
## Returns the formatted tag on success, or a string starting with "Error:" on failure.
func add_tag(tag_string: String) -> String:
	var clean_tag = tag_string.strip_edges()
	
	if clean_tag.is_empty():
		return "Error: Cannot add an empty tag."
		
	# 1. Auto-formatting (e.g., test.test -> Test.Test, Test.TesTest -> Test.Testest)
	var parts = clean_tag.split(".")
	var formatted_parts: Array[String] = []
	
	for part in parts:
		if part.is_empty():
			formatted_parts.append("") # Let the Regex catch double dots
		else:
			var p = part.to_lower()
			# Capitalize only the first letter, leave the rest lowercase
			var formatted_part = p.substr(0, 1).to_upper() + p.substr(1)
			formatted_parts.append(formatted_part)
			
	var formatted_tag = ".".join(formatted_parts)
	
	# 2. Regex Enforcement
	var regex = RegEx.new()
	regex.compile("^([A-Z][a-zA-Z0-9]*)(\\.[A-Z][a-zA-Z0-9]*)*$")
	
	if not regex.search(formatted_tag):
		return "Error: Invalid format '%s'. Must use alphanumeric characters and dots." % formatted_tag
		
	var new_tag := StringName(formatted_tag)
	
	# 3. Duplicate Check (using the newly formatted string)
	if has_tag(new_tag):
		return "Error: Tag '%s' already exists." % formatted_tag
		
	tags.append(new_tag)
	tags.sort_custom(func(a, b): return String(a) < String(b))
	
	emit_changed()
	GameplayTagGenerator.generate_tags_file(tags)
	
	if not resource_path.is_empty():
		ResourceSaver.save(self, resource_path)
	
	return formatted_tag # Return the beautiful string back to the UI


## Removes an exact tag from the registry.
func remove_tag(tag_name: StringName) -> void:
	if has_tag(tag_name):
		tags.erase(tag_name)
		emit_changed()
		GameplayTagGenerator.generate_tags_file(tags)
		
		if not resource_path.is_empty():
			ResourceSaver.save(self, resource_path)
#endregion


#region Tag Queries
## Checks if the exact tag exists in the registry.
func has_tag(tag_name: StringName) -> bool:
	return tags.has(tag_name)


## Returns all tags that fall under a specific parent.
## e.g., get_child_tags("Status") might return ["Status.Stunned", "Status.Burning"].
func get_child_tags(parent_tag: StringName) -> Array[StringName]:
	var children: Array[StringName] = []
	var prefix = String(parent_tag) + "."
	
	for tag in tags:
		if String(tag).begins_with(prefix):
			children.append(tag)
			
	return children
#endregion
