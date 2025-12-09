extends GraphEdit

# --- Configuration ---
@onready var context_menu_scene: PackedScene = preload("res://right_click_context_menu.tscn")
@export var graph_node_directory: String = "res://nodes/" 
var loaded_node_scenes: Dictionary = {}                 
var current_menu: Control = null                        

func _ready():
	_load_all_graph_nodes()
	
	if context_menu_scene == null:
		push_warning("Context Menu Scene is null. Check path 'res://right_click_context_menu.tscn'!")
	if loaded_node_scenes.is_empty():
		push_warning("No graph node scenes were loaded from %s. Check folder and file extensions." % graph_node_directory)

# --- Node Deletion Logic ---

# Replace the existing func _unhandled_input(event: InputEvent) -> void:
# with the following:

func _input(event: InputEvent) -> void:
	# Check if the event is a key press (or an action)
	if event.is_action_pressed("graph_delete_node") and not event.is_echo():
		
		var nodes_to_delete = []
		var delete_performed = false

		# Iterate through all children of the GraphEdit
		for child in get_children():
			# 1. Ensure the child is a GraphNode
			if child is GraphNode:
				# 2. Check the built-in 'selected' property
				if child.selected and not child.title == "Start Node":
					nodes_to_delete.append(child)

		# 3. Delete the collected nodes outside the main loop
		if not nodes_to_delete.is_empty():
			for node in nodes_to_delete:
				node.queue_free()
				print("Deleted node: " + node.title)
			
			delete_performed = true
		
		# 4. If a node was deleted, consume the input immediately
		if delete_performed:
			get_viewport().set_input_as_handled()

# --- Function to Scan and Load Scenes ---
func _load_all_graph_nodes():
	loaded_node_scenes.clear()
	
	var dir = DirAccess.open(graph_node_directory)
	if dir == null:
		push_error("Could not open directory: " + graph_node_directory)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			var full_path = graph_node_directory + file_name
			
			var scene = load(full_path)
			
			if scene is PackedScene:
				var node_type = file_name.get_basename()
				loaded_node_scenes[node_type] = scene
				print("Loaded graph node type: " + node_type)
			else:
				push_warning("File %s is not a PackedScene, ignoring." % file_name)
				
		file_name = dir.get_next()
	
	dir.list_dir_end()

# --- Input Handling for Context Menu ---
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			
			if is_instance_valid(current_menu):
				current_menu.queue_free()
				current_menu = null
			
			if context_menu_scene != null:
				
				var menu_instance = context_menu_scene.instantiate() as Control
				current_menu = menu_instance
				get_tree().root.add_child(current_menu)
				
				if menu_instance.has_signal("node_spawn_requested"):
					menu_instance.node_spawn_requested.connect(_on_node_spawn_requested)
				
				if current_menu.has_method("initialize_menu"):
					current_menu.initialize_menu(mouse_event.global_position, loaded_node_scenes)
				
				get_viewport().set_input_as_handled()

# --- Signal Handler Function: SPWANING THE NODE ---
@warning_ignore("shadowed_variable_base_class")
func _on_node_spawn_requested(node_type_name: String, global_position: Vector2) -> void:
	var scene_to_spawn = loaded_node_scenes.get(node_type_name)
	
	if scene_to_spawn == null:
		push_error("Cannot spawn node: Scene for type '" + node_type_name + "' not found.")
		return

	var new_node = scene_to_spawn.instantiate() as GraphNode
	
	if new_node == null:
		push_error("Spawned scene is not a GraphNode. Check the scene root.")
		return
		
	var spawn_pos_on_canvas = (global_position / zoom) - get_scroll_offset() 
	new_node.position_offset = spawn_pos_on_canvas
	
	new_node.title = node_type_name
			
	add_child(new_node)
	
	print("Spawned " + new_node.title + " at " + str(new_node.position_offset))
