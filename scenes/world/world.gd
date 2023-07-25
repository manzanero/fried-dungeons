class_name World
extends Node3D

var map_scene = preload("res://assets/map/map.tscn")
var entity_scene = preload("res://assets/entity/entity.tscn")
var entity_menu_scene = preload("res://assets/menus/entity/entity_menu.tscn")

var tick := 0.1
var is_mouse_left_button_holded : bool
var selected_entity : Entity

@onready var maps_parent := $Maps as Node3D
@onready var pointer = $Pointer as Pointer
@onready var update_timer := $UpdateTimer as Timer
@onready var save_timer := $SaveTimer as Timer
@onready var new_entity_button := %NewEntity as Button
@onready var total_vision_button := %TotalVision as Button
@onready var forget_explored_button := %ForgetExplored as Button
@onready var cell_contextual_menu := %CellContextualMenu as Panel
@onready var entity_contextual_menu := %EntityContextualMenu as Panel
@onready var entity_edit_button := %EditButton as Button
@onready var entity_vision_button := %VisionButton as Button
@onready var command_queue : Array[Command] = [] 
@onready var map : Map = null


func _ready():
	print("Loading world")
	Game.world = self
	Game.camera = $CameraPivot
	
	for child in maps_parent.get_children():
		child.queue_free()
		
	$HUDCanvas/HUD/Left.visible = Game.is_host
	%PlayerNameTab.set_tab_title(0, Game.player_name)
	update_timer.wait_time = tick
	update_timer.autostart = true
	update_timer.timeout.connect(_update)
	
	if Game.is_host:
		save_timer.timeout.connect(new_command.bind(OpCode.SAVE_MAP))
	
	Server.message.connect(new_command)
	
	pointer.visible = false
	new_entity_button.pressed.connect(_on_new_entity_button_pressed)
	total_vision_button.pressed.connect(_on_total_vision_button_pressed)
	forget_explored_button.pressed.connect(_on_forget_explored_button_pressed)
	cell_contextual_menu.visible = false
	entity_contextual_menu.visible = false
	entity_edit_button.pressed.connect(_on_entity_edit_button_pressed)
	entity_vision_button.pressed.connect(_on_entity_vision_button_pressed)
	
	_close_all_menus()
	
	seed(2)
	
#	test_commands()
	test_fried_commands()
	
	
	
func _close_all_menus():
	pass
	
	
func _on_new_entity_button_pressed():
	var entity_menu = entity_menu_scene.instantiate()
	$HUDCanvas/HUD/Midde.add_child(entity_menu)
	entity_menu.id_edit.text = UUID.short()
	entity_menu.position = Vector2(0, -entity_menu.size.y / 2)
	
	
func _on_total_vision_button_pressed():
	map.change_to_entity_eyes(null)
	
	
func _on_forget_explored_button_pressed():
	map.reset_explored()
	

func _update():
	if command_queue:
		execute_command(command_queue.pop_front())


func _process(delta):
	pass
#	if Input.is_action_just_pressed("right_click"):
#		var message = "hello from " + ("host" if Game.is_host else "not host")
#		Server.send_message(OpCode.MESSAGE, {
#			"message": message,
#		})


func _on_entity_edit_button_pressed():
	var entity_menu = entity_menu_scene.instantiate()
	entity_menu.use_entity(selected_entity)
	$HUDCanvas/HUD/Midde.add_child(entity_menu)
	entity_contextual_menu.visible = false


func _on_entity_vision_button_pressed():
	map.change_to_entity_eyes(selected_entity)
	selected_entity.cell_changed.emit()
	entity_contextual_menu.visible = false


#########
# input #
#########

func _unhandled_input(event):
	if event is InputEventMouseButton:
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
					
				# cell selection
				if map.is_cell_hovered and not map.entity_hovered:
					pointer.pointing = true
					pointer.move_to(map.cell_pointed_position)
					selected_entity = null
					
					if event.double_click:
						entity_contextual_menu.visible = false
						cell_contextual_menu.visible = true
						cell_contextual_menu.position = event.position
					else:
						cell_contextual_menu.visible = false
						entity_contextual_menu.visible = false
					
				else:
					pointer.pointing = false
						
				# entity selection
				if map.entity_hovered:
					pointer.pointing = false
					selected_entity = map.entity_hovered
					
					if event.double_click:
						cell_contextual_menu.visible = false
						entity_contextual_menu.visible = true
						entity_contextual_menu.position = event.position
					else:
						cell_contextual_menu.visible = false
						entity_contextual_menu.visible = false
						
				else:
					selected_entity = null


############
# commands #
############

func execute_command(command):
	match command.op_code:
		OpCode.MESSAGE: 
			_command_message(command.kwargs)
		OpCode.NEW_MAP: 
			_command_new_map(command.kwargs)
		OpCode.SAVE_MAP: 
			_command_save_map(command.kwargs)
		OpCode.NEW_ENTITY: 
			_command_new_entity(command.kwargs)
		OpCode.CHANGE_ENTITY: 
			_command_change_entity(command.kwargs)
		OpCode.DELETE_ENTITY: 
			_command_delete_entity(command.kwargs)
		OpCode.SET_ENTITY_POSITION: 
			_command_set_entity_position(command.kwargs)
		OpCode.SET_ENTITY_TARGET_POSITION: 
			_command_set_entity_target_position(command.kwargs)


func _command_message(kwargs):
	print(kwargs.get("message"))


func _command_new_map(kwargs):
	if map:
		map.queue_free()
		
	map = map_scene.instantiate() as Map
	maps_parent.add_child(map)
	
	map.load_map(kwargs)


func _command_save_map(kwargs):
	var serialized_map = map.serialize()
	var json_string = JSON.stringify(serialized_map, "", false)
	var save_map = FileAccess.open("user://maps/%s.json" % map.name, FileAccess.WRITE)
	var open_error = FileAccess.get_open_error()
	if open_error:
		if open_error == ERR_FILE_NOT_FOUND:
			DirAccess.make_dir_recursive_absolute("user://maps")
			save_map = FileAccess.open("user://maps/%s.json" % map.name, FileAccess.WRITE)
		else:
			print("error saving map: " + open_error)
	save_map.store_line(json_string)
	print("map saved")


func _command_new_entity(kwargs):
	var entity := entity_scene.instantiate() as Entity
	map.entities_parent.add_child(entity)
	entity.name = kwargs["id"]
	_command_set_entity_position(kwargs)
	_command_change_entity(kwargs)


func _command_change_entity(kwargs):
	var entity : Entity = map.entities_parent.get_node(kwargs["id"])
	entity.change(kwargs)


func _command_delete_entity(kwargs):
	var entity : Entity = map.entities_parent.get_node(kwargs["id"])
	if entity:
		entity.queue_free()


func _command_set_entity_position(kwargs):
	var entity : Entity = map.entities_parent.get_node(kwargs["id"])
	entity.position = Utils.array_to_v3(kwargs["position"])


func _command_set_entity_target_position(kwargs):
	var entity : Entity = map.entities_parent.get_node(kwargs["id"])
	entity.target_position = Utils.array_to_v3(kwargs["target_position"])


###########
# objects #
###########

enum OpCode {
	MESSAGE,
	NEW_MAP,
	SAVE_MAP,
	NEW_ENTITY,
	CHANGE_ENTITY,
	DELETE_ENTITY,
	SET_ENTITY_POSITION,
	SET_ENTITY_TARGET_POSITION,
}


class Command:
	var op_code : OpCode
	var kwargs : Dictionary
	
	func _init(p_op_code, p_kwargs):
		op_code = p_op_code
		kwargs = p_kwargs


func new_command(p_op_code : OpCode, p_kwargs : Dictionary = {}):
	command_queue.append(Command.new(p_op_code, p_kwargs))


########
# test #
########

func test_fried_commands():
#	new_command(OpCode.SAVE_MAP)
	new_command(OpCode.NEW_MAP, {
		"fried_file": "user://maps/0.json",
	})


func test_commands():
	new_command(OpCode.MESSAGE, {
		"message": "hello",
	})
	new_command(OpCode.NEW_MAP, {
		"id": "0",
		"donjon_file": "res://resources/maps/donjon/large_rooms.json",
	})
	new_command(OpCode.NEW_ENTITY, {
		"id": "0",
		"label": "0",
		"texture_path": "res://resources/entity_textures/monsters/undead/undead_101.png",
		"position": Utils.v3_to_array(Vector3(14, 0, 24.5)),
		"base_color": Utils.color_to_string(Color.BLUE),
	})
	new_command(OpCode.NEW_ENTITY, {
		"id": "1",
		"label": "1",
		"texture_path": "res://resources/entity_textures/monsters/undead/undead_102.png",
		"position": Utils.v3_to_array(Vector3(14.5, 0, 24)),
		"base_color": Utils.color_to_string(Color.RED),
	})
	new_command(OpCode.NEW_ENTITY, {
		"id": "2",
		"label": "2",
		"texture_path": "res://resources/entity_textures/monsters/undead/undead_103.png",
		"position": Utils.v3_to_array(Vector3(14.5, 0, 24.5)),
		"base_color": Utils.color_to_string(Color.YELLOW),
	})
	new_command(OpCode.NEW_ENTITY, {
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
