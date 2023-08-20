class_name World
extends Node3D

var map_scene = preload("res://assets/map/map.tscn")
var light_scene = preload("res://assets/light/light.tscn")
var entity_scene = preload("res://assets/entity/entity.tscn")
var light_menu_scene = preload("res://assets/menus/light/light_menu.tscn")
var entity_menu_scene = preload("res://assets/menus/entity/entity_menu.tscn")

var tick := 0.1
var selected_light : Light
var selected_entity : Entity

@onready var maps_parent := $Maps as Node3D
@onready var pointer := $Pointer as Pointer
@onready var update_timer := $UpdateTimer as Timer
@onready var save_timer := $SaveTimer as Timer

@onready var player_name_tab := %PlayerNameTab as TabBar

@onready var tokens_panel := %TokensPanel as Panel
@onready var tokens_tree := %TokensTree as Tree

@onready var commands_panel := %CommandsPanel as Panel
@onready var new_entity_button := %NewEntity as Button
@onready var new_light_button := %NewLight as Button
@onready var total_vision_button := %TotalVision as Button
@onready var forget_explored_button := %ForgetExplored as Button
@onready var save_exit_button := %SaveExit as Button

@onready var cell_contextual_menu := %CellContextualMenu as Panel
@onready var cell_edit_button := %CellEditButton as Button
@onready var cell_edit_panel := %CellEditPanel as Panel

@onready var light_contextual_menu := %LightContextualMenu as Panel
@onready var light_edit_button := %LightEditButton as Button

@onready var entity_contextual_menu := %EntityContextualMenu as Panel
@onready var entity_edit_button := %EntityEditButton as Button
@onready var entity_vision_button := %EntityVisionButton as Button
@onready var map : Map = null


func _ready():
	Game.camera = $CameraPivot
	
	for child in maps_parent.get_children():
		child.queue_free()
		
	commands_panel.visible = Game.is_host
	
#	if Game.is_host:
#		save_timer.timeout.connect(enqueue.bind(OpCode.SAVE_MAP))
	
	pointer.is_pointing = false
	
	update_timer.wait_time = tick
	update_timer.autostart = true
	update_timer.timeout.connect(_update)
	
	new_entity_button.pressed.connect(_on_new_entity_button_pressed)
	new_light_button.pressed.connect(_on_new_light_button_pressed)
	total_vision_button.pressed.connect(_on_total_vision_button_pressed)
	forget_explored_button.pressed.connect(_on_forget_explored_button_pressed)
	save_exit_button.pressed.connect(_on_save_exit_button_button_pressed)
	
	cell_contextual_menu.visible = false
	cell_edit_panel.visible = false
	cell_edit_button.pressed.connect(_on_cell_edit_button_pressed)
	
	light_contextual_menu.visible = false
	light_edit_button.pressed.connect(_on_light_edit_button_pressed)
	
	entity_contextual_menu.visible = false
	entity_edit_button.pressed.connect(_on_entity_edit_button_pressed)
	entity_vision_button.pressed.connect(_on_entity_vision_button_pressed)

	tokens_tree.item_selected.connect(_select_tokens_tree)
	tokens_tree.item_activated.connect(_activate_tokens_tree)

	if Game.is_host:
		var current_map = Game.player.map
		var map_id = current_map if current_map and current_map != 'None' else Game.campaign.maps[0]
		
		Commands.enqueue(Commands.OpCode.SET_MAP, {
			"id": map_id,
		})
	else:
		Commands.send(Commands.OpCode.SEND_CAMPAIGN, {
			"player_id": Game.player_id
		})

#	test_commands()
#	test_fried_commands()
	

func populate_tokens_tree():
	tokens_tree.clear()
	var root = tokens_tree.create_item()
	tokens_tree.hide_root = true
	
	var entities = map.entities_parent.get_children()
	entities.sort_custom(func(a, b): return a.label.naturalnocasecmp_to(b.label) < 0)
	
	var to_draw_entities := []
	if Game.is_host:
		to_draw_entities = entities
	else:
		for entity in entities:
			if not Game.has_entity_permissions(entity.id, [Game.EntityPermission.GET_LABEL]):
				continue
			to_draw_entities.append(entity)
	
	for entity in to_draw_entities:
		var entity_child = tokens_tree.create_item(root)
		entity_child.set_text(0, entity.label)
		entity_child.set_tooltip_text(0, " ")
		entity_child.set_metadata(0, str(entity.name))


func _select_tokens_tree():
	var entity_child = tokens_tree.get_selected()
	var entity_id = entity_child.get_metadata(0)
	var entity : Entity = map.entities_parent.get_node(entity_id)
	selected_entity = entity
		
		
func _activate_tokens_tree():
	_select_tokens_tree()
	entity_contextual_menu.position = get_viewport().get_mouse_position()
	entity_contextual_menu.visible = true


func _update():
	%MapValue.text = map.id if map else "None"
	%SelectedCellValue.text = Utils.v3i_to_str(pointer.cell_position) if pointer.is_pointing else "None"
	%HoveredCellValue.text = Utils.v3i_to_str(map.cell_hovered_position) if map and map.is_cell_hovered else "None"
	%SelectedEntiyValue.text = selected_entity.id if selected_entity else "None"
	
	# Server connection
	if Commands.queue:
		Commands.execute(Commands.queue.pop_front())
		if Commands.queue.is_empty():
			Commands.empty_queue.emit()
			
	Server.async_update_authentication()


func _on_cell_edit_button_pressed():
	cell_edit_panel.cells_rollback.clear()
	cell_edit_panel.cells_rollout.clear()
	cell_edit_panel.visible = true
	cell_contextual_menu.visible = false


func _on_light_edit_button_pressed():
	var light_menu = light_menu_scene.instantiate()
	light_menu.use_light(selected_light)
	$HUDCanvas/HUD/Midde.add_child(light_menu)
	light_contextual_menu.visible = false


func _on_entity_edit_button_pressed():
	var entity_menu = entity_menu_scene.instantiate()
	entity_menu.use_entity(selected_entity)
	$HUDCanvas/HUD/Midde.add_child(entity_menu)
	entity_contextual_menu.visible = false


func _on_entity_vision_button_pressed():
	map.change_to_entity_eyes(selected_entity)
	selected_entity.cell_changed.emit()
	entity_contextual_menu.visible = false

		
func _on_new_entity_button_pressed():
	var entity_menu = entity_menu_scene.instantiate()
	$HUDCanvas/HUD/Midde.add_child(entity_menu)
	entity_menu.id_edit.text = UUID.short()
	entity_menu.position = Vector2(0, -entity_menu.size.y / 2)

		
func _on_new_light_button_pressed():
	var light_menu = light_menu_scene.instantiate()
	$HUDCanvas/HUD/Midde.add_child(light_menu)
	light_menu.id_edit.text = UUID.short()
	light_menu.position = Vector2(0, -light_menu.size.y / 2)
	
	
func _on_total_vision_button_pressed():
	map.change_to_entity_eyes(null)
	
	
func _on_forget_explored_button_pressed():
	map.reset_explored()
	
	
func _on_save_exit_button_button_pressed():
	Commands.enqueue(Commands.OpCode.SAVE_MAP)
	await Commands.empty_queue
	Server.disconnected.emit()
	

#########
# input #
#########

func _unhandled_input(event):
	if event is InputEventMouseButton:
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				
				cell_contextual_menu.visible = false
				light_contextual_menu.visible = false
				entity_contextual_menu.visible = false
					
				# cell selection
				if map and map.is_cell_hovered and not map.entity_hovered and not map.light_hovered:
					pointer.is_pointing = true
					pointer.move_to(map.cell_pointed_position)
					selected_light = null
					selected_entity = null
					
					if event.double_click:
						cell_contextual_menu.visible = true
						cell_contextual_menu.position = event.position
					
				else:
					pointer.is_pointing = false
						
				# light selection
				if map and map.light_hovered and not map.entity_hovered:
					pointer.is_pointing = false
					selected_light = map.light_hovered
					selected_entity = null
					
					if event.double_click:
						light_contextual_menu.visible = true
						light_contextual_menu.position = event.position
						
				else:
					selected_light = null
						
				# entity selection
				if map and map.entity_hovered and not map.light_hovered:
					pointer.is_pointing = false
					selected_light = null
					selected_entity = map.entity_hovered
					
					if event.double_click:
						entity_contextual_menu.visible = true
						entity_contextual_menu.position = event.position
						
				else:
					selected_entity = null


########
# test #
########

func test_fried_commands():
#	enqueue(Commands.OpCode.SAVE_MAP)
	if Game.is_host:
		Commands.enqueue(Commands.OpCode.SET_MAP, {
			"file": "user://maps/0.json",
		})
#	enqueue(OpCode.NEW_LIGHT, {
#		"id": "0",
#		"position": Utils.v3_to_array(Vector3(14, 0, 24.5)),
#		"bright": 5,
#		"faint": 10,
#	})


func test_commands():
	Commands.enqueue(Commands.OpCode.MESSAGE, {
		"message": "hello",
	})
	Commands.enqueue(Commands.OpCode.SET_MAP, {
		"id": "0",
		"donjon_file": "res://resources/maps/donjon/large_rooms.json",
	})
	Commands.enqueue(Commands.OpCode.NEW_ENTITY, {
		"id": "0",
		"label": "0",
		"texture_path": "res://resources/entity_textures/monsters/undead/undead_101.png",
		"position": Utils.v3_to_array(Vector3(14, 0, 24.5)),
		"base_color": Utils.color_to_string(Color.BLUE),
	})
	

func test_populate_grid():
	for x in range(5):
		for z in range(25):
			map.solid_map.set_cell_item(Vector3i(x, -1, z), [0,1,3].pick_random(), Data.orientations.pick_random())
