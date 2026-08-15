##
## @meta_addon: GodotGAS 1.0.5
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayEffectAttributeCaptureDefinition extends Resource

enum AttributeCaptureSource {
	SOURCE,
	TARGET,
}

@export var attribute_source: = AttributeCaptureSource.SOURCE
@export var attribute_to_capture: = ""
@export var snapshot: = false
