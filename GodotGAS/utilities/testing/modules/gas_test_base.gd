## Base class for GodotGAS modular test suites.
## Provides standardized assertion helpers, rich colored reporting, and metric tracking.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

class_name GASTestBase extends Node

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var suite_name: String = "Test Suite"


func assert_true(condition: bool, test_name: String, failure_context: String = "") -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print_rich("  [color=green][PASS][/color] %s" % test_name)
	else:
		failed_tests += 1
		var ctx: String = (" | Context: " + failure_context) if failure_context != "" else ""
		print_rich("  [color=red][FAIL][/color] %s (Expected: true, Got: false)%s" % [test_name, ctx])


func assert_false(condition: bool, test_name: String, failure_context: String = "") -> void:
	total_tests += 1
	if not condition:
		passed_tests += 1
		print_rich("  [color=green][PASS][/color] %s" % test_name)
	else:
		failed_tests += 1
		var ctx: String = (" | Context: " + failure_context) if failure_context != "" else ""
		print_rich("  [color=red][FAIL][/color] %s (Expected: false, Got: true)%s" % [test_name, ctx])


func assert_eq(actual: Variant, expected: Variant, test_name: String, failure_context: String = "") -> void:
	total_tests += 1
	if actual == expected:
		passed_tests += 1
		print_rich("  [color=green][PASS][/color] %s" % test_name)
	else:
		failed_tests += 1
		var ctx: String = (" | Context: " + failure_context) if failure_context != "" else ""
		print_rich("  [color=red][FAIL][/color] %s (Expected: %s, Got: %s)%s" % [test_name, str(expected), str(actual), ctx])


func assert_approx(actual: float, expected: float, tolerance: float, test_name: String, failure_context: String = "") -> void:
	total_tests += 1
	if is_equal_approx(actual, expected) or absf(actual - expected) <= tolerance:
		passed_tests += 1
		print_rich("  [color=green][PASS][/color] %s" % test_name)
	else:
		failed_tests += 1
		var ctx: String = (" | Context: " + failure_context) if failure_context != "" else ""
		print_rich("  [color=red][FAIL][/color] %s (Expected: %f ± %f, Got: %f)%s" % [test_name, expected, tolerance, actual, ctx])


func print_header(title: String) -> void:
	suite_name = title
	print_rich("\n[b][color=cyan]==================================================[/color][/b]")
	print_rich("[b][color=cyan]   %s[/color][/b]" % title)
	print_rich("[b][color=cyan]==================================================[/color][/b]")


func print_summary() -> void:
	print_rich("\n[b][color=cyan]--------------------------------------------------[/color][/b]")
	if failed_tests == 0 and total_tests > 0:
		print_rich("[b][color=green]   %s: ALL %d TESTS PASSED.[/color][/b]" % [suite_name, total_tests])
	elif total_tests > 0:
		print_rich("[b][color=red]   %s: %d / %d TESTS PASSED (%d FAILED).[/color][/b]" % [suite_name, passed_tests, total_tests, failed_tests])
	else:
		print_rich("[b][color=gray]   %s: NO TESTS EXECUTED.[/color][/b]" % suite_name)
	print_rich("[b][color=cyan]==================================================[/color][/b]\n")
