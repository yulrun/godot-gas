## An extended class for the attribute module: ExampleAttributeSet 
##
## @meta_addon: GodotGAS 1.0
## @meta_author: YulRun (https://YulRun.Dev) & 'Your Name Here'
## @meta_license: MIT (Default)

@tool
class_name ExampleAttributeSet extends AttributeSet

var health: AttributeData = AttributeData.new(100.0)
var max_health: AttributeData = AttributeData.new(100.0)
var mana: AttributeData = AttributeData.new(100.0)
var max_mana: AttributeData = AttributeData.new(100.0)
var mana_regen: AttributeData = AttributeData.new(5.0)
var attack: AttributeData = AttributeData.new(50.0)
var defence: AttributeData = AttributeData.new(25.0)
var critical_rate: AttributeData = AttributeData.new(20.0)
var evasion: AttributeData = AttributeData.new(15.0)


## The safety pipeline: Clamps stats before they are officially changed.
func pre_attribute_change(attribute_name: String, proposed_value: float) -> float:
	match attribute_name:
		"health":
			return clamp(proposed_value, 0.0, max_health.current_value)
		"mana":
			return clamp(proposed_value, 0.0, max_mana.current_value)

	return proposed_value
