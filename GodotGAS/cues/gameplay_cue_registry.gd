## A registry resource that holds mappings of gameplay tags to visual/audio cues.
##
## Used by the global GameplayCueManager to look up which PackedScene 
## should be instantiated or pooled when a specific cue tag is executed.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayCueRegistry extends Resource

## The list of all registered gameplay cues.
@export var entries: Array[GameplayCueEntry]


#region Registry Queries
## Helper to find a PackedScene by its mapped gameplay tag quickly.
func get_scene_for_tag(tag: StringName) -> PackedScene:
	for entry in entries:
		if entry.tag == tag:
			return entry.scene
			
	return null
#endregion
