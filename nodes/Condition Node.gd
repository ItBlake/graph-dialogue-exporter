extends GraphNode

@onready var value_line_1 = $Value1
@onready var value_line_2 = $Value2

func _on_input_1_toggled(toggled_on: bool) -> void:
	if toggled_on:
		value_line_1.placeholder_text = "Variable 1"
		value_line_1.text = ""
		value_line_1.editable = false
		set_slot(1, true, 0, Color.WHITE, false, 0, Color.WHITE)
	else:
		value_line_1.placeholder_text = "Value 1"
		value_line_1.text = ""
		value_line_1.editable = true
		set_slot(1, false, 0, Color.WHITE, false, 0, Color.WHITE)
	queue_redraw()

func _on_input_2_toggled(toggled_on: bool) -> void:
	if toggled_on:
		value_line_2.placeholder_text = "Variable 2"
		value_line_2.text = ""
		value_line_2.editable = false
		set_slot(3, true, 0, Color.WHITE, false, 0, Color.WHITE)
	else:
		value_line_2.placeholder_text = "Value 2"
		value_line_2.text = ""
		value_line_2.editable = true
		set_slot(3, false, 0, Color.WHITE, false, 0, Color.WHITE)
	queue_redraw()
