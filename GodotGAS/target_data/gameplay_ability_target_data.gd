## Encapsulates target information gathered during an ability's execution.
##
## Stores hit results and unique target nodes, providing a standardized
## payload that can be passed safely to GameplayEffects.
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayAbilityTargetData extends RefCounted

## Array of strictly unique target nodes captured by the ability.
var _target_nodes: Array[Node] = []

## Array of all raw hit dictionaries, allowing for multi-hit tracking.
var _hit_results: Array[Dictionary] = []


#region Appenders
## Directly appends a raw Godot physics query dictionary (from raycasts or intersect_shape).
func append_physics_hit(hit_dict: Dictionary) -> void:
	_hit_results.append(hit_dict)
	
	var collider: Node = hit_dict.get("collider")
	if collider and not _target_nodes.has(collider):
		_target_nodes.append(collider)


## Appends a direct node reference. Excellent for ShapeCast nodes, UI targeting, or auto-aim.
## Safely generates a mock hit dictionary to maintain data structure.
func append_node(node: Node, hit_position: Variant = null) -> void:
	if not node:
		return
		
	if not _target_nodes.has(node):
		_target_nodes.append(node)
		
	var pos_to_use: Variant = hit_position
	if pos_to_use == null and "global_position" in node:
		pos_to_use = node.global_position
	elif pos_to_use == null:
		pos_to_use = Vector3.ZERO # Fallback for non-spatial/canvas nodes
		
	var mock_hit: Dictionary = {
		"collider": node,
		"position": pos_to_use,
		"normal": Vector3.ZERO
	}
	_hit_results.append(mock_hit)


## Convenience method for Area overlaps. Automatically processes an array of nodes.
func append_overlap(nodes: Array) -> void:
	for node in nodes:
		append_node(node)
#endregion


#region Getters
## Returns the array of strictly unique target nodes.
func get_target_nodes() -> Array[Node]:
	return _target_nodes


## Returns every registered hit, allowing for multi-hit/AoE processing.
func get_all_hits() -> Array[Dictionary]:
	return _hit_results


## Returns only the physics dictionaries associated with a specific node.
## Useful for precision calculations (e.g., 'Did this specific bullet hit the head shape?').
func get_hits_for_node(node: Node) -> Array[Dictionary]:
	var specific_hits: Array[Dictionary] = []
	for hit in _hit_results:
		if hit.get("collider") == node:
			specific_hits.append(hit)
			
	return specific_hits


## Clears all payload data.
func clear() -> void:
	_target_nodes.clear()
	_hit_results.clear()
#endregion
