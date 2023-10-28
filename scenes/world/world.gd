class_name World
extends Node3D

signal floor_level_changed(new_level)
signal eyes_changed()

var map_scene : PackedScene = preload("res://assets/map/map.tscn")
var light_scene : PackedScene = preload("res://assets/light/light.tscn")
var entity_scene : PackedScene = preload("res://assets/entity/entity.tscn")
var light_menu_scene : PackedScene = preload("res://assets/menus/light/light_menu.tscn")
var entity_menu_scene : PackedScene = preload("res://assets/menus/entity/entity_menu.tscn")
var entity_permissions_menu_scene : PackedScene = preload("res://assets/menus/entity/entity_permissions_menu.tscn")

var tick := 0.1
var selected_light : Light
var selected_entity : Entity
var map : Map

var floor_level : int : 
	get:
		return int(floor_level_label.text)
	set(value):
		floor_level_label.text = str(value)
		floor_level_changed.emit(value)

	
@onready var map_library := $MapLibrary as MapLibrary
@onready var maps_parent := $Maps as Node3D
@onready var pointer := $Pointer as Pointer
@onready var update_timer := $UpdateTimer as Timer
@onready var save_timer := $SaveTimer as Timer

@onready var player_name_tab := %PlayerNameTab as TabBar

@onready var cell_contextual_menu := %CellContextualMenu as Panel
@onready var cell_edit_button := %CellEditButton as Button
@onready var cell_new_entity_button := %CellNewEntityButton as Button
@onready var cell_new_light_button := %CellNewLightButton as Button
@onready var cell_edit_panel := %CellEditPanel as CellEditMenu
@onready var grid := %Grid as Grid

@onready var light_contextual_menu := %LightContextualMenu as Panel
@onready var light_edit_button := %LightEditButton as Button

@onready var entity_contextual_menu := %EntityContextualMenu as Panel
@onready var entity_edit_button := %EntityEditButton as Button
@onready var entity_permissions_button := %EntityPermissionsButton as Button
@onready var entity_vision_button := %EntityVisionButton as Button
@onready var entity_eyes_button := %EntityEyesButton as Button

@onready var tokens_panel := %TokensPanel as Panel
@onready var tokens_tree := %TokensTree as Tree

@onready var commands_panel := %CommandsPanel as Panel
@onready var total_vision_button := %TotalVision as Button
@onready var forget_explored_button := %ForgetExplored as Button

@onready var floor_level_label := %FloorLevelLabel as Label
@onready var next_floor_button := %NextFloorButton as Button
@onready var previous_floor_button := %PreviousFloorButton as Button

@onready var save_exit_button := %SaveExit as Button


func _ready():
	map_library.load_library()
	Game.camera = $CameraPivot
		
	commands_panel.visible = Game.is_host
	player_name_tab.set_tab_title(0, Game.player_label)
	
	# Saver
#	save_timer.timeout.connect(Commands.enqueue.bind(Game.player_id, Commands.OpCode.SAVE_MAP))
	
	pointer.is_pointing = false
	grid.active = false 
	
	update_timer.wait_time = tick
	update_timer.autostart = true
	update_timer.timeout.connect(_update)
	
	cell_contextual_menu.visible = false
	cell_edit_panel.visible = false
	cell_edit_button.pressed.connect(_on_cell_edit_button_pressed)
	cell_new_entity_button.pressed.connect(_on_cell_new_entity_button_pressed)
	cell_new_light_button.pressed.connect(_on_cell_new_light_button_pressed)
	
	light_contextual_menu.visible = false
	light_edit_button.pressed.connect(_on_light_edit_button_pressed)
	
	entity_contextual_menu.visible = false
	entity_edit_button.pressed.connect(_on_entity_edit_button_pressed)
	entity_permissions_button.pressed.connect(_on_entity_permissions_button_pressed)
	entity_vision_button.pressed.connect(_on_entity_vision_button_pressed)
	entity_eyes_button.pressed.connect(_on_entity_eyes_button_pressed)
	
	tokens_tree.item_selected.connect(_select_tokens_tree)
	tokens_tree.item_activated.connect(_activate_tokens_tree)
	
	total_vision_button.pressed.connect(_on_total_vision_button_pressed)
	forget_explored_button.pressed.connect(_on_forget_explored_button_pressed)
	save_exit_button.pressed.connect(_on_save_exit_button_button_pressed)
	
	next_floor_button.pressed.connect(func(): floor_level += 1)
	previous_floor_button.pressed.connect(func(): floor_level -= 1)

	var current_map = Game.player.map
	var is_valid_map = current_map and current_map != 'None' and current_map in Game.campaign.maps.keys()
	var map_id = current_map if is_valid_map else Game.campaign.maps.keys()[0]
	
	Commands.queue.clear()
	if Game.is_host:
		Commands.enqueue(Game.player_id, Commands.OpCode.SET_MAP, {
			"id": map_id,
		})
	else:
		Commands.async_send(Commands.OpCode.SEND_MAP, {
			"id": map_id,
		}, [
			Game.master_id,
		])

#	test_commands()
	

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
	%SelectedEntiyValue.text = selected_entity.id if is_instance_valid(selected_entity) else "None"
	
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
	grid.active = true


func _on_cell_new_entity_button_pressed():
	var entity : Entity = entity_scene.instantiate()
	entity.id = UUID.short()
	map.entities_parent.add_child(entity)
	entity.position = pointer.position + Vector3(0.5, 1, 0.5)
	
	var entity_menu : EntityMenu = entity_menu_scene.instantiate()
	entity_menu.use_entity(entity, true)
	%Middle.add_child(entity_menu)
	entity_menu.position = Vector2(0, -entity_menu.size.y / 2)
	
	cell_contextual_menu.visible = false

		
func _on_cell_new_light_button_pressed():
	var light : Light = light_scene.instantiate()
	light.id = UUID.short()
	map.lights_parent.add_child(light)
	light.position = pointer.position + Vector3(0.5, 1, 0.5)
	
	var light_menu : LightMenu = light_menu_scene.instantiate()
	light_menu.use_light(light, true)
	%Middle.add_child(light_menu)
	light_menu.position = Vector2(0, -light_menu.size.y / 2)
	
	cell_contextual_menu.visible = false


func _on_light_edit_button_pressed():
	var light_menu = light_menu_scene.instantiate()
	light_menu.use_light(selected_light)
	%Middle.add_child(light_menu)
	light_contextual_menu.visible = false


func _on_entity_edit_button_pressed():
	var entity_menu = entity_menu_scene.instantiate()
	entity_menu.use_entity(selected_entity)
	%Middle.add_child(entity_menu)
	entity_contextual_menu.visible = false


func _on_entity_permissions_button_pressed():
	var entity_permissions_menu := entity_permissions_menu_scene.instantiate() as EntityPermissionsMenu
	entity_permissions_menu.use_entity(selected_entity)
	%Middle.add_child(entity_permissions_menu)
	entity_contextual_menu.visible = false


func _on_entity_vision_button_pressed():
	map.change_to_entity_vision(selected_entity)
	selected_entity.cell_changed.emit()
	entity_contextual_menu.visible = false


func _on_entity_eyes_button_pressed():
	for entity in map.entities_parent.get_children():
		entity.info.visible = false
		
	map.change_to_entity_vision(selected_entity)
	selected_entity.use_entity_eyes()
	entity_contextual_menu.visible = false
	$HUDCanvas/UI.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	eyes_changed.emit()


func exit_entity_eyes():
	Game.camera.eyes.current = true
	$HUDCanvas/UI.visible = true
	floor_level_changed.emit(floor_level)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	
func _on_total_vision_button_pressed():
	map.change_to_entity_vision(null)
	
	
func _on_forget_explored_button_pressed():
	map.reset_explored()
	
	
func _on_save_exit_button_button_pressed():
	Commands.enqueue(Game.player_id, Commands.OpCode.SAVE_MAP)
	await Commands.empty_queue
	Server.disconnected.emit()
	

#########
# input #
#########

func _unhandled_input(event):
	if event is InputEventMouseButton:
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				
#				print("unhandled world click")
				
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
	if Game.is_host:
		Commands.enqueue(Game.player_id, Commands.OpCode.SET_MAP, {
			"file": "user://maps/0.json",
		})


func test_commands():
	Commands.enqueue(Game.player_id, Commands.OpCode.MESSAGE, {
		"message": "hello",
	})
	Commands.enqueue(Game.player_id, Commands.OpCode.SET_MAP, {
		"id": "0",
		"donjon_file": "res://resources/maps/donjon/large_rooms.json",
	})
	Commands.enqueue(Game.player_id, Commands.OpCode.NEW_ENTITY, {
		"id": "0",
		"label": "0",
		"texture": "monsters/undead/undead_101",
		"position": Utils.v3_to_array(Vector3(14, 0, 24.5)),
		"base_color": Utils.color_to_string(Color.BLUE),
	})
