extends Node

@onready var dialogue_ui = preload("res://addons/Fuck It I'll Dialogue System/DialogBox.tscn").instantiate()

signal dialogue_finished
signal dialogue_started
signal var_updated(variable, value)

var dialogue_active := false
var dialogue_data: Array = []
var dialogue_map := {}
var current_index := 0
var picked_option := ""
var dialogue_vars := {}

var portraits := {}

func _ready():
	if dialogue_ui.get_parent() == null:
		add_child(dialogue_ui)
		if "build_portraits_map" in dialogue_ui:
			dialogue_ui.build_portraits_map()
		if "portraits_map" in dialogue_ui:
			portraits = dialogue_ui.portraits_map.duplicate(true)

	dialogue_ui.hide()

	for conn in dialogue_ui.option_chosen.get_connections():
		dialogue_ui.option_chosen.disconnect(conn.callable)
	for conn in dialogue_ui.next_pressed.get_connections():
		dialogue_ui.next_pressed.disconnect(conn.callable)

	dialogue_ui.option_chosen.connect(_on_option_chosen)
	dialogue_ui.next_pressed.connect(_on_next_pressed)

func start(path: String):
	if dialogue_active:
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Dialogue file not found: " + path)
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("Failed to parse dialogue JSON: " + path)
		return

	dialogue_data = parsed
	dialogue_map.clear()
	for i in range(dialogue_data.size()):
		var entry = dialogue_data[i]
		if entry.has("id"):
			dialogue_map[entry["id"]] = i

	current_index = 0
	picked_option = ""
	dialogue_active = true
	
	# --- START FIX: Initialize local dialogue_vars from Global State ---
	dialogue_vars.clear()
	
	# Check the very first line for 'jump_if' to see which variables need loading
	if dialogue_data.size() > 0 and dialogue_data[0].has("jump_if"):
		var jump_if_dict: Dictionary = dialogue_data[0]["jump_if"]
		
		# Load all variables mentioned in the jump_if from QuestManager (Global)
		if QuestManager.has_method("get_global"):
			for var_name in jump_if_dict.keys():
				if var_name == "default": continue
				# Load the global state of the variable into the local dialogue_vars
				dialogue_vars[var_name] = QuestManager.get_global(var_name, false)
		else:
			push_warning("QuestManager missing get_global() method. Conditional jumps will not work.")
	# --- END FIX ---
	
	dialogue_ui.show()
	emit_signal("dialogue_started")
	_show_line()

func _apply_quest_actions(actions: Dictionary) -> void:
	if actions.has("give"):
		for q in actions["give"]:
			if QuestManager.has_method("start_quest"):
				QuestManager.start_quest(q)
			else:
				push_warning("QuestManager missing start_quest for '%s'" % q)

	if actions.has("complete"):
		for q in actions["complete"]:
			if QuestManager.has_method("complete_quest"):
				QuestManager.complete_quest(q)
			else:
				push_warning("QuestManager missing complete_quest for '%s'" % q)

	if actions.has("update_step"):
		for q in actions["update_step"].keys():
			var step = actions["update_step"][q]
			if QuestManager.has_method("update_quest_step"):
				QuestManager.update_quest_step(q, step)
			else:
				push_warning("QuestManager missing update_quest_step for '%s'" % q)

	if actions.has("set_quest_var"):
		for key in actions["set_quest_var"].keys():
			var value = actions["set_quest_var"][key]
			if QuestManager.has_method("set_global"):
				QuestManager.set_global(key, value)
			else:
				push_warning("QuestManager missing set_global_var for '%s'" % key)

func _show_line():
	if not dialogue_active:
		return

	if current_index >= dialogue_data.size():
		_end_dialogue()
		return

	var line: Dictionary = dialogue_data[current_index]

	# String replace for picked_option
	for key in line.keys():
		if typeof(line[key]) == TYPE_STRING:
			line[key] = line[key].replace("{picked_option}", picked_option)

	# Execute commands even if no speaker
	if line.has("set_var"):
		for key in line["set_var"].keys():
			dialogue_vars[key] = line["set_var"][key]
			emit_signal("var_updated", key, line["set_var"][key])

	if line.has("quest_update"):
		for quest_id in line["quest_update"].keys():
			var update_type = line["quest_update"][quest_id]
			if QuestManager.has_method("change_quest_state"):
				QuestManager.change_quest_state(quest_id, update_type)
			else:
				push_warning("QuestManager missing change_quest_state() for '%s'" % quest_id)

	if line.has("quest"):
		_apply_quest_actions(line["quest"])

	# Handle conditional and direct jumps BEFORE showing UI
	if line.has("jump_if"):
		var jump_target = line["jump_if"].get("default", null)
		for var_name in line["jump_if"].keys():
			if var_name == "default":
				continue
			if dialogue_vars.get(var_name, false) == true:
				jump_target = line["jump_if"][var_name]
				break
		line["_conditional_jump"] = jump_target

	if line.has("jump") and typeof(line["jump"]) == TYPE_STRING:
		var target = line["jump"]
		if target == "end":
			line["_end_after_read"] = true
		elif dialogue_map.has(target):
			line["_direct_jump"] = target
			
	# --- START FIX FOR COMMAND-ONLY LINES ---
	var has_speaker = line.has("speaker") and line["speaker"] != ""
	
	if not has_speaker:
		# Check for immediate jumps/ends on command-only lines
		if line.has("_conditional_jump"):
			var target = line["_conditional_jump"]
			if target == "end":
				_end_dialogue()
				return
			elif dialogue_map.has(target):
				current_index = dialogue_map[target]
				_show_line()
				return

		if line.has("_direct_jump"):
			current_index = dialogue_map[line["_direct_jump"]]
			_show_line()
			return

		if line.has("_end_after_read") and line["_end_after_read"] == true:
			_end_dialogue()
			return
			
		# If it's a command line with no jump, auto-advance
		current_index += 1
		_show_line()
		return
	# --- END FIX ---
	

	# Only show HUD if the line has a speaker
	if has_speaker:
		var portrait_texture: Texture2D = null
		if portraits.has(line["speaker"]):
			portrait_texture = portraits[line["speaker"]]
		print("DM: Switching camera for speaker: ", line["speaker"])
		_camera_switch_for_speaker(line["speaker"])

		dialogue_ui.show()
		dialogue_ui.load_dialogue(line, portrait_texture)

func _on_next_pressed() -> void:
	if not dialogue_active:
		return

	if dialogue_ui.is_typing():
		dialogue_ui.skip_typing()
		return

	var line: Dictionary = dialogue_data[current_index]

	if line.has("_conditional_jump"):
		var target = line["_conditional_jump"]
		if target == "end":
			_end_dialogue()
			return
		elif dialogue_map.has(target):
			current_index = dialogue_map[target]
			_show_line()
			return

	if line.has("_direct_jump"):
		var target = line["_direct_jump"]
		if dialogue_map.has(target):
			current_index = dialogue_map[target]
			_show_line()
			return

	if line.has("_end_after_read") and line["_end_after_read"] == true:
		_end_dialogue()
		return

	current_index += 1
	_show_line()

func _on_option_chosen(option_data) -> void:
	var opt_text := ""
	var opt_jump = null
	if typeof(option_data) == TYPE_DICTIONARY:
		opt_text = option_data.get("text", "")
		opt_jump = option_data.get("jump", null)
	else:
		opt_text = str(option_data)

	picked_option = opt_text

	if opt_jump == "end":
		_end_dialogue()
		return

	if opt_jump != null and dialogue_map.has(opt_jump):
		current_index = dialogue_map[opt_jump]
		_show_line()
		return

	current_index += 1
	_show_line()

func _end_dialogue():
	dialogue_active = false
	dialogue_ui.hide()
	emit_signal("dialogue_finished")

func get_var(name: String, default_value = false):
	return dialogue_vars.get(name, default_value)

func set_var(name: String, value):
	dialogue_vars[name] = value
	emit_signal("var_updated", name, value)

func _camera_switch_for_speaker(speaker_name: String) -> void:
	print("DM: Searching for camera for speaker: ", speaker_name)

	if speaker_name.to_lower() == "player" or speaker_name.to_lower() == "dipper":
		# Use the player's dialogue cam if it's set
		if CameraManager.player_dialogue_cam != null:
			print("DM: Switching to player dialogue camera: ", CameraManager.player_dialogue_cam)
			CameraManager.set_player_dialogue_cam(CameraManager.player_dialogue_cam, true)
			return
		else:
			print("DM: Player dialogue camera not set!")
			return

	# Otherwise, search NPC cameras
	var cameras = get_tree().get_nodes_in_group("npc_cam")
	print("DM: Cameras in npc_cam group: ", cameras.size())

	for cam in cameras:
		print("DM: Checking camera: ", cam, " owner: ", cam.get_owner())

		var owner = cam.get_owner()
		if owner == null:
			print("DM: Camera has no owner, skipping.")
			continue

		if owner.name.to_lower() == speaker_name.to_lower():
			print("DM: Match found! Switching to cam: ", cam)
			CameraManager.set_npc_cam(cam, true)
			return

	print("DM: No matching camera found for speaker: ", speaker_name)
