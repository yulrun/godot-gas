## Core editor plugin script for the GodotGAS framework.
##
## Handles the initialization of the GodotGAS editor dashboard, registers the 
## GameplayTag inspector plugin, and manages autoload singletons for the framework.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
extends EditorPlugin

## Name of the global cue manager singleton.
const CUE_MANAGER_NAME = "GameplayCueManager"

## File path to the global cue manager singleton script.
const CUE_MANAGER_PATH = "res://addons/GodotGAS/managers/gameplay_cue_manager.gd"

## Preloaded packed scene for the editor dashboard.
const DASHBOARD_SCENE = preload("res://addons/GodotGAS/editor/godot_gas_dashboard.tscn")

## Preloaded script for the tag inspector plugin.
const GameplayTagInspectorPlugin = preload("res://addons/GodotGAS/gameplay_tag/gameplay_tag_inspector_plugin.gd")

## Reference to the active dashboard control node in the editor.
var _dashboard_instance: Control

## Reference to the active tag inspector plugin instance.
var _tag_inspector: EditorInspectorPlugin


#region Plugin Lifecycle
## Called when the plugin is activated or enters the editor tree.
func _enter_tree() -> void:
	_tag_inspector = GameplayTagInspectorPlugin.new()
	add_inspector_plugin(_tag_inspector)
	
	# Auto-register the Singleton so the user doesn't have to
	add_autoload_singleton(CUE_MANAGER_NAME, CUE_MANAGER_PATH)
	
	_dashboard_instance = DASHBOARD_SCENE.instantiate()
	_dashboard_instance.visible = false
	get_editor_interface().get_editor_main_screen().add_child(_dashboard_instance)
	_make_visible(false)
	
	print("GodotGAS: Framework Initialized.")


## Called when the plugin is deactivated or leaves the editor tree.
func _exit_tree() -> void:
	if _tag_inspector:
		remove_inspector_plugin(_tag_inspector)
		
	# Clean up the Singleton when the plugin is disabled
	remove_autoload_singleton(CUE_MANAGER_NAME)
	
	if _dashboard_instance:
		_dashboard_instance.queue_free()
	
	print("GodotGAS: Framework Disabled.")
#endregion


#region Main Screen Integration
## Notifies the editor that this plugin has a main screen workspace.
func _has_main_screen() -> bool:
	return true


## Returns the name displayed on the top center tab in the Godot Editor.
func _get_plugin_name() -> String:
	return "GodotGAS"


## Returns the icon displayed next to the plugin name on the main screen tab.
func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/GodotGAS/icons/godot_gas.svg")


## Called when the user toggles the main screen tab visibility.
func _make_visible(visible: bool) -> void:
	if _dashboard_instance:
		_dashboard_instance.visible = visible
#endregion
