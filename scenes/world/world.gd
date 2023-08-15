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
@onready var pointer = $Pointer as Pointer
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
@onready var command_queue : Array[Command] = [] 
@onready var map : Map = null


func _ready():
	Game.camera = $CameraPivot
	
	for child in maps_parent.get_children():
		child.queue_free()
		
	commands_panel.visible = Game.is_host
	
#	if Game.is_host:
#		save_timer.timeout.connect(enqueue_command.bind(OpCode.SAVE_MAP))
	
	Server.message.connect(enqueue_command)
	
	pointer.pointing = false
	
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
		
		enqueue_command(OpCode.SET_MAP, {
			"id": "MAP000",
			"file": "user://maps/MAP000.json",
		})
#
#		enqueue_command(OpCode.SET_MAP, {
#			"id": map_id,
#		})
	else:
		send_command(OpCode.SEND_CAMPAIGN, {
			"player": Game.player_id
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
			if not Game.player.has_entity_permissions(entity.id, [Game.EntityPermission.GET_LABEL]):
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


func _process(delta):
	pass
#	if Input.is_action_just_pressed("right_click"):
#		var message = "hello from " + ("host" if Game.is_host else "not host")
#		Game.world.send_command(OpCode.MESSAGE, {
#			"message": message,
#		})


func _update():
	if command_queue:
		execute_command(command_queue.pop_front())


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
	_command_save_map()
	get_tree().quit()
	

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
					pointer.pointing = true
					pointer.move_to(map.cell_pointed_position)
					selected_light = null
					selected_entity = null
					
					if event.double_click:
						cell_contextual_menu.visible = true
						cell_contextual_menu.position = event.position
					
				else:
					pointer.pointing = false
						
				# light selection
				if map and map.light_hovered and not map.entity_hovered:
					pointer.pointing = false
					selected_light = map.light_hovered
					selected_entity = null
					
					if event.double_click:
						light_contextual_menu.visible = true
						light_contextual_menu.position = event.position
						
				else:
					selected_light = null
						
				# entity selection
				if map and map.entity_hovered and not map.light_hovered:
					pointer.pointing = false
					selected_light = null
					selected_entity = map.entity_hovered
					
					if event.double_click:
						entity_contextual_menu.visible = true
						entity_contextual_menu.position = event.position
						
				else:
					selected_entity = null


############
# commands #
############


enum OpCode {
	MESSAGE,
	SET_CAMPAIGN,
	SEND_CAMPAIGN,
	SET_MAP,
	SEND_MAP,
	SAVE_MAP,
	NEW_ENTITY,
	CHANGE_ENTITY,
	DELETE_ENTITY,
	SET_ENTITY_POSITION,
	SET_ENTITY_TARGET_POSITION,
	SET_CELLS,
	NEW_LIGHT,
	CHANGE_LIGHT,
	DELETE_LIGHT,
	SET_LIGHT_POSITION,
}


func execute_command(command : Command):
	print("Player %s - Command: %s" % [Game.player_id, OpCode.keys()[command.op_code]])
	match command.op_code:
		OpCode.MESSAGE: _command_message(command.kwargs)
		OpCode.SET_CAMPAIGN: _command_set_campaign(command.kwargs)
		OpCode.SEND_CAMPAIGN: _command_send_campaign(command.kwargs)
		OpCode.SET_MAP: _command_set_map(command.kwargs)
		OpCode.SEND_MAP: _command_send_map(command.kwargs)
		OpCode.SAVE_MAP: _command_save_map(command.kwargs)
		OpCode.NEW_ENTITY: _command_new_entity(command.kwargs)
		OpCode.CHANGE_ENTITY: _command_change_entity(command.kwargs)
		OpCode.DELETE_ENTITY: _command_delete_entity(command.kwargs)
		OpCode.SET_ENTITY_POSITION: _command_set_entity_position(command.kwargs)
		OpCode.SET_ENTITY_TARGET_POSITION: _command_set_entity_target_position(command.kwargs)
		OpCode.SET_CELLS: _command_set_cells(command.kwargs)
		OpCode.NEW_LIGHT: _command_new_light(command.kwargs)
		OpCode.CHANGE_LIGHT: _command_change_light(command.kwargs)
		OpCode.DELETE_LIGHT: _command_delete_light(command.kwargs)
		OpCode.SET_LIGHT_POSITION: _command_set_light_position(command.kwargs)


func _command_message(kwargs : Dictionary):
	print(kwargs.get("message"))


func _command_set_campaign(kwargs : Dictionary):
	Game.campaign.deserialize(kwargs["campaign"])
	var current_map = Game.player.map
	var file = current_map if current_map and current_map != 'None' else Game.campaign.maps[0]
	send_command(OpCode.SEND_MAP, {
		"player": Game.player_id
	})
	
	player_name_tab.set_tab_title(0, Game.player.username)


func _command_send_campaign(kwargs : Dictionary):
	send_command(OpCode.SET_CAMPAIGN, {
		"campaign": Game.campaign.serialize(),
	},
	[
		kwargs["player"]
	])


func _command_set_map(kwargs : Dictionary):
	if map:
		map.queue_free()
		
	map = map_scene.instantiate() as Map
	maps_parent.add_child(map)
	
	map.load_map(kwargs)


func _command_send_map(kwargs : Dictionary):
	Server.save_object("map-" + map.id, map.serialize())

	send_command(OpCode.SET_MAP, {
		"id": map.id,
	},
	[
		kwargs["player"]
	])


func _command_save_map(kwargs := {}):
	Utils.write_json("user://maps/%s.json" % map.name, map.serialize())


func _command_new_entity(kwargs : Dictionary):
	var entity := entity_scene.instantiate() as Entity
	entity.name = kwargs["id"]
	map.entities_parent.add_child(entity)
	_command_set_entity_position(kwargs)
	_command_change_entity(kwargs)
	
	populate_tokens_tree()


func _command_change_entity(kwargs : Dictionary):
	var entity : Entity = map.entities_parent.get_node(kwargs["id"])
	entity.change(kwargs)
	
	if entity == map.entity_eyes:
		map.update_fov()
	
	populate_tokens_tree()


func _command_delete_entity(kwargs):
	var entity : Entity = map.entities_parent.get_node(kwargs["id"])
	if entity:
		entity.get_parent().remove_child(entity)
		entity.queue_free()
	
	populate_tokens_tree()


func _command_set_entity_position(kwargs):
	var entity : Entity = map.entities_parent.get_node(kwargs["id"])
	entity.position = Utils.array_to_v3(kwargs["position"])
	
	if entity == map.entity_eyes:
		map.update_fov()


func _command_set_entity_target_position(kwargs):
	var entity : Entity = map.entities_parent.get_node(kwargs["id"])
	entity.target_position = Utils.array_to_v3(kwargs["target_position"])
	
	
func _command_set_cells(kwargs):
	var serialized_cells = kwargs["cells"]
	for serialized_cell in serialized_cells:
		var cell_position = Vector3i(
			serialized_cell["x"], 
			serialized_cell["y"], 
			serialized_cell["z"])
		var cell = map.deserialize_cell(serialized_cell)
		map.set_cell(cell_position, cell)
		
	map.refresh_lights()
	map.update_fov()
	
	
func _command_new_light(kwargs):
	var light := light_scene.instantiate() as Light
	light.id = kwargs["id"]
	map.lights_parent.add_child(light)
	_command_set_light_position(kwargs)
	_command_change_light(kwargs)
	
	map.update_fov()


func _command_change_light(kwargs):
	var light : Light = map.lights_parent.get_node(kwargs["id"])
	light.change(kwargs)
	
	map.update_fov()


func _command_delete_light(kwargs):
	var light : Light = map.lights_parent.get_node(kwargs["id"])
	if light:
		light.get_parent().remove_child(light)
		light.queue_free()
	
	map.update_fov()
	
	
func _command_set_light_position(kwargs):
	var light : Light = map.lights_parent.get_node(kwargs["id"])
	light.position = Utils.v3_to_v3i(Utils.array_to_v3(kwargs["position"]))
	
	map.update_fov()


###########
# objects #
###########


class Command:
	var op_code : OpCode
	var kwargs : Dictionary
	
	func _init(p_op_code, p_kwargs):
		op_code = p_op_code
		kwargs = p_kwargs


func enqueue_command(op_code : OpCode, kwargs : Dictionary = {}):
	command_queue.append(Command.new(op_code, kwargs))


func send_command(op_code: OpCode, kwargs: Dictionary, players : Array[String] = []):
	Server.socket.send_match_state_async(Server.match_id, op_code, JSON.stringify(kwargs))


########
# test #
########

func test_fried_commands():
#	enqueue_command(OpCode.SAVE_MAP)
	if Game.is_host:
		enqueue_command(OpCode.SET_MAP, {
			"file": "user://maps/0.json",
		})
#	enqueue_command(OpCode.NEW_LIGHT, {
#		"id": "0",
#		"position": Utils.v3_to_array(Vector3(14, 0, 24.5)),
#		"bright": 5,
#		"faint": 10,
#	})


func test_commands():
	enqueue_command(OpCode.MESSAGE, {
		"message": "hello",
	})
	enqueue_command(OpCode.SET_MAP, {
		"id": "0",
		"donjon_file": "res://resources/maps/donjon/large_rooms.json",
	})
	enqueue_command(OpCode.NEW_ENTITY, {
		"id": "0",
		"label": "0",
		"texture_path": "res://resources/entity_textures/monsters/undead/undead_101.png",
		"position": Utils.v3_to_array(Vector3(14, 0, 24.5)),
		"base_color": Utils.color_to_string(Color.BLUE),
	})
	enqueue_command(OpCode.NEW_ENTITY, {
		"id": "1",
		"label": "1",
		"texture_path": "res://resources/entity_textures/monsters/undead/undead_102.png",
		"position": Utils.v3_to_array(Vector3(14.5, 0, 24)),
		"base_color": Utils.color_to_string(Color.RED),
	})
	enqueue_command(OpCode.NEW_ENTITY, {
		"id": "2",
		"label": "2",
		"texture_path": "res://resources/entity_textures/monsters/undead/undead_103.png",
		"position": Utils.v3_to_array(Vector3(14.5, 0, 24.5)),
		"base_color": Utils.color_to_string(Color.YELLOW),
	})
	enqueue_command(OpCode.NEW_ENTITY, {
		"id": "3",
		"label": "3",
		"texture_path": "res://resources/entity_textures/monsters/undead/undead_104.png",
		"position": Utils.v3_to_array(Vector3(14, 0, 24)),
		"base_color": Utils.color_to_string(Color.GREEN),
	})
	

func test_populate_grid():
	for x in range(5):
		for z in range(25):
			map.solid_map.set_cell_item(Vector3i(x, -1, z), [0,1,3].pick_random(), Data.orientations.pick_random())
