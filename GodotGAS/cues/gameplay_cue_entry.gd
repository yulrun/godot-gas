## Maps a specific gameplay tag to a visual/audio cue scene.
##
## Used by the GameplayCueRegistry to define which PackedScene should be
## instantiated or pooled when a specific cue tag is executed.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayCueEntry extends Resource

## The gameplay tag associated with this cue. 
## Note: The GameplayTag inspector plugin automatically detects the variable name "tag".
@export var tag: StringName

## The PackedScene containing the visual or audio effects to trigger.
@export var scene: PackedScene
