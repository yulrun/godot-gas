## The Master Test Runner for GodotGAS v1.1.0+
##
## Orchestrates the modular test suites, allowing developers to execute
## all tests or isolate specific subsystems via Inspector toggles.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

extends Node

@export_category("Master Test Configuration")
@export var run_all_tests: bool = true

@export_group("Individual Suites")
@export var test_1_tags: bool = false
@export var test_2_attributes: bool = false
@export var test_3_cues: bool = false
@export var test_4_effects: bool = false
@export var test_5_abilities: bool = false
@export var test_6_full_system: bool = false

var _grand_total: int = 0
var _grand_passed: int = 0


func _ready() -> void:
	print_rich("\n[b][color=magenta]==================================================[/color][/b]")
	print_rich("[b][color=magenta]   GodotGAS v1.1.0 Master Suite Initialization[/color][/b]")
	print_rich("[b][color=magenta]==================================================[/color][/b]")
	
	if run_all_tests or test_1_tags:
		var suite := TestTags.new()
		add_child(suite)
		await suite.run_all_tests()
		_tally(suite)
		suite.queue_free()
		
	if run_all_tests or test_2_attributes:
		var suite := TestAttributes.new()
		add_child(suite)
		await suite.run_all_tests()
		_tally(suite)
		suite.queue_free()
		
	if run_all_tests or test_3_cues:
		var suite := TestCues.new()
		add_child(suite)
		await suite.run_all_tests()
		_tally(suite)
		suite.queue_free()
		
	if run_all_tests or test_4_effects:
		var suite := TestEffects.new()
		add_child(suite)
		await suite.run_all_tests()
		_tally(suite)
		suite.queue_free()
		
	if run_all_tests or test_5_abilities:
		var suite := TestAbilities.new()
		add_child(suite)
		await suite.run_all_tests()
		_tally(suite)
		suite.queue_free()
		
	if run_all_tests or test_6_full_system:
		var suite := TestFullSystem.new()
		add_child(suite)
		await suite.run_all_tests()
		_tally(suite)
		suite.queue_free()

	_print_master_summary()


func _tally(suite: GASTestBase) -> void:
	_grand_total += suite.total_tests
	_grand_passed += suite.passed_tests


func _print_master_summary() -> void:
	print_rich("\n[b][color=magenta]==================================================[/color][/b]")
	print_rich("[b][color=magenta]   MASTER REGRESSION SUITE RESULTS[/color][/b]")
	print_rich("[b][color=magenta]==================================================[/color][/b]")
	
	if _grand_total == 0:
		print_rich("[color=gray]No tests were executed. Check your @export toggles.[/color]")
	elif _grand_total == _grand_passed:
		print_rich("[color=green]SUCCESS: All %d out of %d tests passed. The GodotGAS framework is stable.[/color]" % [_grand_passed, _grand_total])
	else:
		var failed = _grand_total - _grand_passed
		print_rich("[color=red]FAILURE: %d out of %d tests failed! Degradation detected.[/color]" % [failed, _grand_total])
		
	print_rich("[b][color=magenta]==================================================[/color][/b]\n")
