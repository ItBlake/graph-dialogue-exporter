extends Control 

# --- Signal Definition ---
signal node_spawn_requested(node_type_name, position) 

# --- Configuration (UPDATE THESE PATHS) ---
@onready var visual_menu_panel: Control = $VBoxContainer 
@onready var menu_button: MenuButton = $VBoxContainer/AddMenu 

var target_global_position: Vector2 = Vector2.ZERO
var initial_right_click_handled: bool = false 

# --- Initialization and Dynamic Menu Building ---

func initialize_menu(pos: Vector2, node_map: Dictionary) -> void:
	target_global_position = pos
	var screen_size = get_viewport().size
	var menu_size = visual_menu_panel.size
	
	var final_x = min(target_global_position.x, screen_size.x - menu_size.x)
	var final_y = min(target_global_position.y, screen_size.y - menu_size.y)
	
	visual_menu_panel.global_position = Vector2(final_x, final_y)
	
	var popup_menu = menu_button.get_popup()
	popup_menu.clear()
	
	var id_counter = 0
	
	var sorted_names = node_map.keys()
	sorted_names.sort()
	
	for node_name in sorted_names:
		popup_menu.add_item(node_name, id_counter)
		popup_menu.set_item_metadata(id_counter, node_name)
		id_counter += 1

	popup_menu.id_pressed.connect(_on_menu_item_selected)

func _ready():
	mouse_filter = MOUSE_FILTER_STOP
	
# --- Custom Input Handling (Auto-Dismissal) ---

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed and not initial_right_click_handled:
			initial_right_click_handled = true
			get_viewport().set_input_as_handled()
			return

		if mouse_event.pressed:
			var click_missed_panel = not visual_menu_panel.get_global_rect().has_point(mouse_event.global_position)
			
			if click_missed_panel:
				if mouse_event.button_index == MOUSE_BUTTON_LEFT or mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
					print("Left/Middle click outside menu, closing.")
					queue_free()
					get_viewport().set_input_as_handled()
				
				elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
					print("Right click outside menu, closing this instance.")
					queue_free()

# --- Menu Action Handler ---

func _on_menu_item_selected(id: int) -> void:
	var popup_menu = menu_button.get_popup()
	var node_type_name = popup_menu.get_item_metadata(id)
	
	emit_signal("node_spawn_requested", node_type_name, visual_menu_panel.global_position)
	
	print("Node action selected: " + node_type_name + ". Closing menu.")
	queue_free()
	get_viewport().set_input_as_handled()
