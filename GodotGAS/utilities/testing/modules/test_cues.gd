## Self-contained exhaustive test suite for the GodotGAS Cues Subsystem.
##
## Tests dynamic scene instantiation, the auto-destroy lifecycle, object pooling 
## efficiency, sleep/wake states, ASC integration, and persistent lifecycle parity.
##
## @meta_addon: GodotGAS Version 1.1.0+
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name TestCues extends GASTestBase

var _original_scenes: Dictionary
var _original_pools: Dictionary

func _ready() -> void:
	if get_parent() == get_tree().root:
		await run_all_tests()


func run_all_tests() -> void:
	print_header("GodotGAS Subsystem Test: Gameplay Cues & Object Pooling")
	
	# Backup the global manager state to avoid polluting real project data
	_original_scenes = GameplayCueManager._cue_scenes.duplicate(true)
	_original_pools = GameplayCueManager._pool.duplicate(true)
	
	# Isolate the manager for the test suite
	GameplayCueManager._cue_scenes.clear()
	GameplayCueManager._pool.clear()
	
	await _battery_instantiation_and_playback()
	await _battery_auto_destroy_lifecycle()
	await _battery_object_pooling_recycling()
	await _battery_manual_destruction()
	await _battery_asc_integration()
	await _battery_6_persistent_cues()
	
	# Restore global manager state
	GameplayCueManager._cue_scenes = _original_scenes
	GameplayCueManager._pool = _original_pools
	
	print_summary()


# ---------------------------------------------------------
# Dynamic Scene Builder
# ---------------------------------------------------------
## Packages a mock GameplayCueNotify scene completely in memory for testing
func _create_mock_cue_scene(auto_destroy: bool, delay: float) -> PackedScene:
	var root := GameplayCueNotify.new()
	root.name = "MockCue"
	root.auto_destroy = auto_destroy
	root.destroy_delay = delay
	
	# Add a visual child to verify the Manager correctly toggles visibility to hide pooled objects
	var visual := Node2D.new()
	visual.name = "VisualChild"
	root.add_child(visual)
	visual.owner = root # Crucial for packing children
	
	var pack := PackedScene.new()
	pack.pack(root)
	
	root.queue_free()
	return pack


# ---------------------------------------------------------
# Battery 1: Instantiation & Playback
# ---------------------------------------------------------
func _battery_instantiation_and_playback() -> void:
	print_rich("\n[color=yellow]--- Battery 1: Scene Instantiation & Playback ---[/color]")
	
	var target := Node.new()
	add_child(target)
	
	var mock_scene := _create_mock_cue_scene(true, 0.1)
	GameplayCueManager._cue_scenes[&"Cue.Test.Impact"] = mock_scene
	GameplayCueManager._pool[&"Cue.Test.Impact"] = []
	
	GameplayCueManager.execute_cue(&"Cue.Test.Impact", target)
	
	var active_cue := target.get_node_or_null("MockCue")
	assert_true(active_cue != null, "1.01: execute_cue successfully instantiates and attaches scene to target")
	assert_eq(active_cue.process_mode, Node.PROCESS_MODE_INHERIT, "1.02: Instantiated cue initializes in an awake process mode")
	
	var visual_child = active_cue.get_node_or_null("VisualChild")
	assert_true(visual_child != null and visual_child.visible, "1.03: Visual children initialize actively visible")
	
	target.queue_free()


# ---------------------------------------------------------
# Battery 2: Auto-Destroy Lifecycle & Sleeping
# ---------------------------------------------------------
func _battery_auto_destroy_lifecycle() -> void:
	print_rich("\n[color=yellow]--- Battery 2: Auto-Destroy Lifecycle & Sleeping ---[/color]")
	
	var target := Node.new()
	add_child(target)
	
	var mock_scene := _create_mock_cue_scene(true, 0.1) # 0.1s lifespan
	GameplayCueManager._cue_scenes[&"Cue.Test.Auto"] = mock_scene
	GameplayCueManager._pool[&"Cue.Test.Auto"] = []
	
	GameplayCueManager.execute_cue(&"Cue.Test.Auto", target)
	
	# Yield long enough for the destroy_delay timer to expire
	await get_tree().create_timer(0.15).timeout
	
	assert_eq(target.get_child_count(), 0, "2.01: auto_destroy completely removes the cue from the target node")
	
	var pool: Array = GameplayCueManager._pool[&"Cue.Test.Auto"]
	assert_eq(pool.size(), 1, "2.02: auto_destroy successfully pushed the finished cue into the global pool")
	
	var pooled_cue: GameplayCueNotify = pool[0]
	assert_eq(pooled_cue.process_mode, Node.PROCESS_MODE_DISABLED, "2.03: Pooled cue correctly suspended processing (PROCESS_MODE_DISABLED)")
	
	var visual_child = pooled_cue.get_node_or_null("VisualChild")
	assert_false(visual_child.visible, "2.04: Manager successfully toggled visual children to invisible while pooled")
	
	target.queue_free()


# ---------------------------------------------------------
# Battery 3: Object Pooling Recycling
# ---------------------------------------------------------
func _battery_object_pooling_recycling() -> void:
	print_rich("\n[color=yellow]--- Battery 3: Object Pooling Recycling (Waking Up) ---[/color]")
	
	var target := Node.new()
	add_child(target)
	
	# Verify we still have 1 sleeping item in the pool from Battery 2
	var pool_before: Array = GameplayCueManager._pool[&"Cue.Test.Auto"]
	var original_instance_id = pool_before[0].get_instance_id()
	assert_eq(pool_before.size(), 1, "3.01: Verifying pool contains exactly 1 dormant instance")
	
	# Request the same tag again!
	GameplayCueManager.execute_cue(&"Cue.Test.Auto", target)
	
	var pool_after: Array = GameplayCueManager._pool[&"Cue.Test.Auto"]
	assert_eq(pool_after.size(), 0, "3.02: execute_cue cleanly removed the instance from the dormant pool")
	
	var active_cue := target.get_node_or_null("MockCue")
	assert_true(active_cue != null, "3.03: Cue successfully re-attached to target node")
	assert_eq(active_cue.get_instance_id(), original_instance_id, "3.04: Framework recycled exact memory instance (NO new instantiation)")
	
	assert_eq(active_cue.process_mode, Node.PROCESS_MODE_INHERIT, "3.05: Recycled cue correctly woke up processing (PROCESS_MODE_INHERIT)")
	assert_true(active_cue.get_node("VisualChild").visible, "3.06: Recycled cue correctly restored visibility to children")
	
	# Clean up before it auto-destroys again to keep the test environment sane
	active_cue.queue_free()
	target.queue_free()


# ---------------------------------------------------------
# Battery 4: Manual Destruction
# ---------------------------------------------------------
func _battery_manual_destruction() -> void:
	print_rich("\n[color=yellow]--- Battery 4: Manual Destruction Lifecycle ---[/color]")
	
	var target := Node.new()
	add_child(target)
	
	var mock_scene := _create_mock_cue_scene(false, 0.1) # auto_destroy = false
	GameplayCueManager._cue_scenes[&"Cue.Test.Manual"] = mock_scene
	GameplayCueManager._pool[&"Cue.Test.Manual"] = []
	
	GameplayCueManager.execute_cue(&"Cue.Test.Manual", target)
	
	# Yield past what the timer would be
	await get_tree().create_timer(0.15).timeout
	
	var active_cue: GameplayCueNotify = target.get_node_or_null("MockCue")
	assert_true(active_cue != null, "4.01: auto_destroy=false prevents the cue from removing itself")
	
	var pool: Array = GameplayCueManager._pool[&"Cue.Test.Manual"]
	assert_eq(pool.size(), 0, "4.02: Cue has not entered the global pool")
	
	# Force the manual completion
	active_cue.finish_cue()
	
	assert_eq(target.get_child_count(), 0, "4.03: Manual finish_cue() successfully removed cue from target")
	assert_eq(pool.size(), 1, "4.04: Manual finish_cue() successfully pushed the instance into the pool")
	
	target.queue_free()


# ---------------------------------------------------------
# Battery 5: ASC Integration Validation
# ---------------------------------------------------------
func _battery_asc_integration() -> void:
	print_rich("\n[color=yellow]--- Battery 5: ASC Integration & Visual Routing ---[/color]")
	
	var avatar := Node.new()
	avatar.name = "Avatar"
	add_child(avatar)
	
	var asc := AbilitySystemComponent.new()
	asc.name = "AbilitySystemComponent"
	avatar.add_child(asc)
	
	# Assume the cue scene is mapped
	var mock_scene := _create_mock_cue_scene(false, 1.0)
	GameplayCueManager._cue_scenes[&"Cue.Test.ASC"] = mock_scene
	GameplayCueManager._pool[&"Cue.Test.ASC"] = []
	
	# Fire the cue dynamically through the component
	asc.execute_cue(&"Cue.Test.ASC")
	
	assert_true(avatar.has_node("MockCue"), "5.01: Component correctly routed the visual cue to the Avatar (Parent)")
	assert_false(asc.has_node("MockCue"), "5.02: Visual cue was NOT attached to the invisible ASC node")
	
	# Non-existent safe catch check
	asc.execute_cue(&"Cue.Ghost.DoesNotExist")
	assert_true(true, "5.03: Executing an unmapped/ghost tag fails gracefully without crashing")
	
	avatar.queue_free()


# ---------------------------------------------------------
# Battery 6: Persistent Cues & Lifecycle Parity
# ---------------------------------------------------------
func _battery_6_persistent_cues() -> void:
	print_rich("\n[color=yellow]--- Battery 6: Persistent Cues & Lifecycle Parity ---[/color]")
	
	var target := Node.new()
	add_child(target)
	
	var mock_scene := _create_mock_cue_scene(true, 0.1) # Originally a burst cue
	GameplayCueManager._cue_scenes[&"Cue.Test.Aura"] = mock_scene
	GameplayCueManager._pool[&"Cue.Test.Aura"] = []
	
	var active_cue = GameplayCueManager.add_persistent_cue(&"Cue.Test.Aura", target)
	assert_true(active_cue != null, "6.01: add_persistent_cue successfully instantiates and returns the live node")
	assert_false(active_cue.auto_destroy, "6.02: add_persistent_cue forcefully disables the auto_destroy timer")
	
	await get_tree().create_timer(0.15).timeout
	assert_true(active_cue.is_inside_tree() and active_cue.get_parent() == target, "6.03: Persistent cue survives past its default burst lifespan")
	
	GameplayCueManager.set_cue_state(active_cue, false)
	assert_eq(active_cue.process_mode, Node.PROCESS_MODE_DISABLED, "6.04: set_cue_state successfully suspends node processing")
	assert_false(active_cue.get_node("VisualChild").visible, "6.05: set_cue_state successfully hides visual elements")
	
	GameplayCueManager.remove_persistent_cue(active_cue)
	assert_eq(target.get_child_count(), 0, "6.06: remove_persistent_cue cleanly detaches the node from the target")
	var pool: Array = GameplayCueManager._pool[&"Cue.Test.Aura"]
	assert_eq(pool.size(), 1, "6.07: remove_persistent_cue returns the node to the global object pool")
	
	target.queue_free()
