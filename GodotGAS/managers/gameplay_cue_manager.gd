## Global Autoload for managing and spawning visual/audio cues.
##
## Utilizes an object pooling system to efficiently reuse GameplayCueNotify 
## nodes, preventing performance hitches during rapid cue instantiation.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
extends Node

## File path to the default cue registry resource.
const REGISTRY_PATH = "res://addons/GodotGAS/data/default_cue_registry.tres"

## Internal dictionary holding the object pool. Format: { "tag": [GameplayCueNotify, ...] }
var _pool: Dictionary = {}

## Internal dictionary holding the cached PackedScenes. Format: { "tag": PackedScene }
var _cue_scenes: Dictionary = {}


#region Initialization
## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_load_registry()


## Loads the cue registry from disk and prepares the object pool.
func _load_registry() -> void:
	if not ResourceLoader.exists(REGISTRY_PATH):
		push_warning("GodotGAS: No cue registry found at " + REGISTRY_PATH)
		return
		
	var registry = load(REGISTRY_PATH) as GameplayCueRegistry
	if not registry:
		return
		
	# Register everything found in the resource
	for entry in registry.entries:
		if entry.tag and entry.scene:
			_cue_scenes[entry.tag] = entry.scene
			_pool[entry.tag] = []
#endregion


#region Cue Execution
## The main public API called by the ASC to spawn an effect.
func execute_cue(tag: StringName, target: Node, payload: Dictionary = {}) -> void:
	if not _cue_scenes.has(tag):
		return
		
	var cue_instance: GameplayCueNotify = _get_or_create_cue(tag)
	
	# Ensures the cue_instance was correctly loaded and bypasses nullpoint errors
	if not cue_instance:
		return
	
	if cue_instance.get_parent():
		cue_instance.get_parent().remove_child(cue_instance)
		
	target.add_child(cue_instance)
	
	cue_instance.execute_cue(target, payload)
#endregion


#region Object Pooling
## Internal pooling logic to retrieve an inactive cue or instantiate a new one.
func _get_or_create_cue(tag: StringName) -> GameplayCueNotify:
	# 1. Try to grab an existing dormant cue from the pool
	if _pool.has(tag) and _pool[tag].size() > 0:
		return _pool[tag].pop_back()
		
	# 2. If the pool is empty, instance a brand new one
	var raw_instance = _cue_scenes[tag].instantiate()
	
	# TYPE CHECK: Is this scene actually a GameplayCueNotify?
	if not raw_instance is GameplayCueNotify:
		push_error("GodotGAS: Failed to load cue '%s'. The root node of this scene must extend 'GameplayCueNotify'." % tag)
		raw_instance.free() # Clean up the invalid node
		return null
	
	var new_cue: GameplayCueNotify = raw_instance
	new_cue.gameplay_cue_tag = tag
	new_cue.cue_finished.connect(_on_cue_finished)
	
	_set_cue_state(new_cue, true) # Initialize as Active
	return new_cue


## Called automatically when a cue calls finish_cue().
func _on_cue_finished(cue_node: GameplayCueNotify, tag: StringName) -> void:
	if cue_node.get_parent():
		cue_node.get_parent().remove_child(cue_node)
	
	_set_cue_state(cue_node, false) # Put to sleep
	add_child(cue_node)
	
	if not _pool.has(tag):
		_pool[tag] = []
		
	_pool[tag].append(cue_node)


## Centralized lifecycle state manager.
## Handles enabling/disabling logic and visual toggling for any node structure.
func _set_cue_state(cue: GameplayCueNotify, active: bool) -> void:
	# 1. Toggle Logic
	cue.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	
	# 2. Toggle Visuals
	# We loop immediate children. If they are visual nodes, they are toggled.
	# Because visibility propagates, hiding children effectively hides the whole subtree.
	for child in cue.get_children():
		if "visible" in child:
			child.visible = active
#endregion
