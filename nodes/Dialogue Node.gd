extends GraphNode

# Ensure you have a reference to the small dialogue box (TextEdit/LineEdit)
@onready var dialogue = $DialogueContainer/Dialogue
@onready var dialogue_panel = $DialogueContainer/DialoguePanel
@onready var dialogue_expanded = $DialogueContainer/DialoguePanel/VBoxContainer/DialogueExpanded
@onready var OptionsToggle = $OptionsToggle
@onready var optionA = $OptionA
@onready var optionB = $OptionB
@onready var optionC = $OptionC


func _ready():
	# It's better to set visibility in _ready without the print("")
	optionA.visible = false
	optionB.visible = false
	optionC.visible = false

func _on_expand_button_pressed():
	# 1. Sync the small text to the large text BEFORE opening
	if dialogue_expanded and dialogue:
		dialogue_expanded.text = dialogue.text
		
	# 2. Open the expanded panel
	dialogue_panel.popup_centered()
	dialogue_expanded.grab_focus()

func _on_close_button_pressed():
	# 1. Sync the large text back to the small text BEFORE closing
	if dialogue and dialogue_expanded:
		dialogue.text = dialogue_expanded.text
		
	# 2. Close the expanded panel
	dialogue_panel.hide()

func _on_dialogue_expanded_text_changed():
	if dialogue and dialogue_expanded:
		dialogue.text = dialogue_expanded.text

func _on_options_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		optionA.visible = true
		optionB.visible = true
		optionC.visible = true
		set_slot(3, false, 0, Color.WHITE, false, 0, Color.WHITE)
	else:
		optionA.visible = false
		optionB.visible = false
		optionC.visible = false
		set_slot(3, false, 0, Color.WHITE, true, 0, Color.WHITE)
