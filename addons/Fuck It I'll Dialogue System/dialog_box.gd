extends Control

signal option_chosen(option_data)
signal next_pressed

@onready var SpeakerText: Label = $MessagePanel/SpeakerLabel
@onready var SpeakerPic: Sprite2D = $MessagePanel/SpeakerPic
@onready var Dialog: TypeWriterLabel = $MessagePanel/DialogueText # Assuming 'TypeWriterLabel' is your custom node
@onready var OptionA: Button = $Options/A
@onready var OptionB: Button = $Options/B
@onready var OptionC: Button = $Options/C

# Assuming PortraitResource is a custom resource type
@export var portrait_resources: Array = [] 
var portraits_map: Dictionary = {}

var has_options := false

func _ready() -> void:
	build_portraits_map()
	hide()
	for btn in [OptionA, OptionB, OptionC]:
		btn.pressed.connect(func(): _on_option_pressed(btn))

func _unhandled_input(event):
	if not DialogueManager.dialogue_active:
		return
	if has_options:
		return
	if event.is_action_pressed("skip_dialogue"):
		emit_signal("next_pressed")

func build_portraits_map() -> void:
	portraits_map.clear()
	for pr in portrait_resources:
		# Assuming PortraitResource has 'name' and 'texture' properties
		if pr and pr.name != "":
			portraits_map[pr.name] = pr.texture

func load_dialogue(line: Dictionary, portrait_texture: Texture2D = null):
	show()

	var raw_speaker := line.get("speaker", "")
	var display_name := ""
	if raw_speaker != "":
		# Auto capitalize first letter
		display_name = raw_speaker.substr(0, 1).to_upper() + raw_speaker.substr(1).to_lower()
	SpeakerText.text = display_name

	# Reset TypeWriterLabel and start typing
	Dialog.typewrite(line.get("text", ""))

	if portrait_texture:
		SpeakerPic.texture = portrait_texture

	# Reset and hide options
	for btn in [OptionA, OptionB, OptionC]:
		btn.hide()
		btn.disabled = false
		btn.set_meta("option_data", null)

	has_options = false

	# Setup options if they exist
	if line.has("optionA"):
		_setup_option(OptionA, line["optionA"])
		has_options = true
	if line.has("optionB"):
		_setup_option(OptionB, line["optionB"])
		has_options = true
	if line.has("optionC"):
		_setup_option(OptionC, line["optionC"])
		has_options = true

func _setup_option(button: Button, data):
	var text = ""
	if typeof(data) == TYPE_DICTIONARY:
		text = data.get("text", "")
	else:
		text = str(data)
	button.text = text
	button.show()
	button.set_meta("option_data", data)

func _on_option_pressed(button: Button) -> void:
	var data = button.get_meta("option_data")
	if data == null:
		return
	# Disable all options once one is chosen
	for btn in [OptionA, OptionB, OptionC]:
		btn.disabled = true
	has_options = false
	emit_signal("option_chosen", data)

func is_typing() -> bool:
	return Dialog.is_typing()

func skip_typing() -> void:
	Dialog.skip_typing()
