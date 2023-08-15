class_name Map
extends Node3D

signal changed


var id : String : 
	get:
		return str(name)
	set(value):
		name = value

var label := 'Unlabeled'
var min_x : int = 0
var min_y : int = 0
var min_z : int = 0
var max_x : int = 0
var max_y : int = 0
var max_z : int = 0
var ambient_light : int = 0
var floors := {}
var cells := {}
var cells_explored := {}
var cache_cells := {}
var entity_eyes : Entity

var entity_hovered : Entity
var preview_entity_move_mode : bool
var entity_moving : Entity
var offset_entity_moving : Vector3
var preview_entity : Entity

var light_hovered : Light
var preview_light_move_mode : bool
var light_moving : Light
var offset_light_moving : Vector3
var preview_light : Light

var is_cell_hovered : bool
var position_hovered : Vector3
var normal_hovered : Vector3

var cell_hovered_position : Vector3i : 
	get: 
		return Utils.v3_to_v3i(position_hovered + normal_hovered / 2)
		
var cell_hovered : Cell : 
	get: 
		return cells.get(cell_hovered_position)
		
var cell_pointed_position : Vector3i : 
	get: 
		return Utils.v3_to_v3i(position_hovered - normal_hovered / 2)
		
var cell_pointed : Cell : 
	get: 
		return cells.get(cell_pointed_position)


@onready var library := $MapLibrary as MapLibrary
@onready var solid_map := $SolidMap as GridMap
@onready var entities_parent := $Entities as Node3D
@onready var lights_parent := $Lights as Node3D
@onready var map_theme := MapTheme.new()
@onready var cell_raycast := PhysicsRayQueryParameters3D.new()
@onready var entity_raycast := PhysicsRayQueryParameters3D.new()
@onready var light_raycast := PhysicsRayQueryParameters3D.new()


func _ready():
	library.load_library()
	solid_map.mesh_library = library.meshes
	
	
func _physics_process(delta):
	_process_cell_ray_hit()
	_process_light_ray_hit()
	_process_entity_ray_hit()
	_process_preview_entity_move(delta)
	_process_preview_light_move(delta)
		

func get_cell_code(cell_position : Vector3i, cell : Cell, cell_light_intensity : int) -> int:
		
	# buil mode
	if cell.is_preview:
		return solid_map.mesh_library.find_item_by_name(cell.skin)
	
	if cell.is_in_view and cell_light_intensity:
		var light_str = str(snappedi(cell_light_intensity - 10, 20))
		return solid_map.mesh_library.find_item_by_name(light_str + cell.skin)

	var cell_explored = cells_explored.get(cell_position)
	if cell_explored and Game.is_high_end:
		return solid_map.mesh_library.find_item_by_name('x' + cell_explored.skin)

	return -1


func set_cell(cell_position : Vector3i, cell : Cell):
	cells[cell_position] = cell
	
	var cell_light_intensity = 0
	if cell.is_in_view:
		cell_light_intensity = cell.get_light_intensity(cell_position)
		
		if cell_light_intensity >= 20:
			cells_explored[cell_position] = cell

	if cell:
		solid_map.set_cell_item(cell_position, get_cell_code(cell_position, cell, cell_light_intensity), cell.orientation)
		if cell_position.y == 0:
			floors[0].set_transparent(Vector2i(cell_position.x, cell_position.z), cell.is_transparent)
	else:
		solid_map.set_cell_item(cell_position, -1)
		if cell_position.y == 0:
			floors[0].set_transparent(Vector2i(cell_position.x, cell_position.z), true)


func load_map(kwargs):
	solid_map.clear()
	
	id = kwargs["id"]
	if "file" in kwargs:
		_load_fried_json_file(kwargs["file"])
	elif "donjon_file" in kwargs:
		_load_donjon_json_file(kwargs["donjon_file"])
	elif "id" in kwargs:
		var map = await Server.load_object("map-" + id)
		deserialize(map)
		
	if Game.is_host:
		reset_cells(true)


func change_to_entity_eyes(entity):
	if entity_eyes:
		entity_eyes.cell_changed.disconnect(update_fov)
	
	entity_eyes = entity
	
	if entity:
		reset_cells(false)
		entity.cell_changed.connect(update_fov)
		update_fov()
	else:
		reset_cells(true)


func reset_cells(is_in_view):
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			for z in range(min_z, max_z):
				var cell_position = Vector3i(x, y, z)
				var cell = cells.get(cell_position)
				if cell:
					cell.is_in_view = is_in_view
					set_cell(cell_position, cell)


func refresh_lights():
	for light in lights_parent.get_children():
		light.update_fov()


func reset_explored():
	cells_explored.clear()
	
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			for z in range(min_z, max_z):
				var cell_position = Vector3i(x, y, z)
				var cell = cells.get(cell_position)
				if cell:
					set_cell(cell_position, cell)


func update_fov():
	if not entity_eyes:
		reset_cells(true)
		return
	
	var c_x := entity_eyes.cell_position.x
	var c_y := entity_eyes.cell_position.y
	var c_z := entity_eyes.cell_position.z
	
	# unview cached cells
	for cell_position in cache_cells:
		if cell_position.y not in [c_y - 1, c_y] \
				or cell_position.x not in range(c_x - RANGE, c_x + RANGE + 1) \
				or cell_position.z not in range(c_z - RANGE, c_z + RANGE + 1):
			var cell : Cell = cache_cells[cell_position]
			if cell.is_in_view:
				cell.is_in_view = false
				set_cell(cell_position, cell)
		
	cache_cells.clear()
	
	floors[0].clear_field_of_view()
	floors[0].compute_field_of_view(Utils.v3_to_v2i(entity_eyes.position), RANGE)
	
	for y in [c_y - 1, c_y]:
		for x in range(c_x - RANGE, c_x + RANGE + 1):
			for z in range(c_z - RANGE, c_z + RANGE + 1):
				var cell_position = Vector3i(x, y, z)
				var cell = cells.get(cell_position)
				if not cell:
					continue
				
				var is_in_view = floors[0].is_in_view(Vector2i(x, z))
				cell.is_in_view = is_in_view
				cache_cells[cell_position] = cell
				set_cell(cell_position, cell)


func _get_hit_info(raycast : PhysicsRayQueryParameters3D, collision_mask : int):
	var ray_length = 1000
	var mouse_pos = get_viewport().get_mouse_position()
	var space_state = get_world_3d().direct_space_state
	raycast.from = Game.camera.camera.project_ray_origin(mouse_pos)
	raycast.to = raycast.from + Game.camera.camera.project_ray_normal(mouse_pos) * ray_length
	raycast.collision_mask = collision_mask
	return space_state.intersect_ray(raycast)


func _process_cell_ray_hit():
	var hit_info = _get_hit_info(cell_raycast, Utils.get_bitmask(1))
	if hit_info:
		is_cell_hovered = true
		position_hovered = hit_info["position"] 
		normal_hovered = hit_info["normal"]
	else:
		is_cell_hovered = false


func _process_entity_ray_hit():
	var hit_info = _get_hit_info(cell_raycast, Utils.get_bitmask(2))
	if hit_info:
		entity_hovered = hit_info["collider"]
	else:
		entity_hovered = null


func _process_light_ray_hit():
	var hit_info = _get_hit_info(light_raycast, Utils.get_bitmask(3))
	if hit_info:
#		print(hit_info["collider"].get_path())
		light_hovered = hit_info["collider"].get_parent().get_parent()
	else:
		light_hovered = null
		

func _process_preview_entity_move(delta):
	if entity_hovered and not light_hovered and Input.is_action_just_pressed("left_click"):
		preview_entity_move_mode = true
		entity_moving = entity_hovered
		offset_entity_moving = entity_moving.position - position_hovered
		preview_entity = Game.world.entity_scene.instantiate() as Entity
		Game.world.map.add_child(preview_entity)
		preview_entity.preview = true
		preview_entity.texture_path = entity_moving.texture_path
		var preview_base_color = entity_moving.base_color
		preview_base_color.a *= 0.5
		preview_entity.base_color = preview_base_color
		preview_entity.position = entity_moving.position
		var preview_body_material = preview_entity.body.get_surface_override_material(0)
		preview_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		preview_body_material.albedo_color.a *= 0.75
		preview_entity.label_control.visible = false
		preview_entity.selector.visible = true
		
	var preview_entity_position = position_hovered
	preview_entity_position += normal_hovered * 0.1 * Vector3(1, 0, 1) + offset_entity_moving
	
	if preview_entity_move_mode:
		preview_entity.position = lerp(preview_entity.position, preview_entity_position, 20 * delta)
	
	if preview_entity_move_mode and Input.is_action_just_released("left_click"):
		preview_entity_move_mode = false
		preview_entity.queue_free()
		preview_entity = null
		var fallback_position = entity_moving.position
		entity_moving.position = position_hovered
		entity_moving.position += normal_hovered * 0.1 + offset_entity_moving
		entity_moving.position.y = 0
		entity_moving.validate_position(fallback_position)
		Game.world.send_command(Game.world.OpCode.SET_ENTITY_TARGET_POSITION, {
			"id": entity_moving.id,
			"target_position": Utils.v3_to_array(entity_moving.position), 
		})

		
func _process_preview_light_move(delta):
	if light_hovered and Input.is_action_just_pressed("left_click"):
		preview_light_move_mode = true
		light_moving = light_hovered
		offset_light_moving = light_moving.position - position_hovered
		preview_light = Game.world.light_scene.instantiate() as Light
		Game.world.map.add_child(preview_light)
		preview_light.preview = true
		var preview_color = light_moving.color
		preview_color.a *= 0.5
		preview_light.color = preview_color
		preview_light.position = light_moving.position
		preview_light.selector.visible = true
		
	var preview_light_position := position_hovered
	preview_light_position += normal_hovered * 0.1 * Vector3(1, 0, 1) + offset_light_moving
	
	if preview_light_move_mode:
		preview_light.position = lerp(preview_light.position, preview_light_position, 20 * delta)
	
	if preview_light_move_mode and Input.is_action_just_released("left_click"):
		preview_light_move_mode = false
		preview_light.queue_free()
		preview_light = null
		light_moving.position = position_hovered
		light_moving.position += normal_hovered * 0.1 + offset_light_moving
		light_moving.position.y = 0
		Game.world.send_command(Game.world.OpCode.SET_LIGHT_POSITION, {
			"id": light_moving.id,
			"position": Utils.v3_to_array(light_moving.position), 
		})


###########
# Objects #
###########

var RANGE := 10
const FILL := "Fill0"
const COVER := "Cover0"


class MapTheme:
	var floor := "Stone0"
	var wall := "Brick1"
	var door_closed := "Door0"
	var door_open := "Door1"
	

class Cell:
	var map : Map
	var skin : String
	var donjon_code : int
	var orientation : int
	var emission : int
	var is_empty : bool
	var is_transparent : bool
	var is_door : bool
	var is_open : bool
	var is_locked : bool
	
	var is_preview : bool
	var is_in_view : bool
	var lights : Array[Light] = []
	
	
	func _init(p_map):
		map = p_map


	func get_light_intensity(cell_position : Vector3i) -> int:
		var light_intensity = 0
		for light in lights:
			light_intensity += light.get_intensity(cell_position)
			
		var is_master_ambient_light_enabled := Game.is_host and not map.entity_eyes
		var master_ambient_light := 20 if is_master_ambient_light_enabled else 0
		return clamp(max(map.ambient_light, emission, light_intensity), master_ambient_light, 100)
	
	
	func get_light_fixture(cell_position : Vector3i) -> Color:
		var value = Color.WHITE * get_light_intensity(cell_position) / 100
		value.a = 1
		return value
	

func serialize_cell(cell_position : Vector3i, cell : Cell) -> Dictionary:
	var serialized_cell = {}
	serialized_cell["x"] = cell_position.x
	serialized_cell["y"] = cell_position.y
	serialized_cell["z"] = cell_position.z
	if cell.skin:
		serialized_cell["s"] = solid_map.mesh_library.find_item_by_name(cell.skin) 
	if cell.orientation:
		serialized_cell["o"] = cell.orientation
	if cell.is_empty:
		serialized_cell["e"] = 1
	if cell.is_transparent:
		serialized_cell["t"] = 1
	if cell.is_door:
		serialized_cell["door"] = 1
	if cell.is_open:
		serialized_cell["open"] = 1
	if cell.is_locked:
		serialized_cell["locked"] = 1
	return serialized_cell
		
	
func deserialize_cell(serialized_cell : Dictionary) -> Cell:
	var cell = Cell.new(self)
	var skin = serialized_cell.get("s")
	cell.skin = solid_map.mesh_library.get_item_name(skin) if skin else ""
	cell.orientation = serialized_cell.get("o", 0)
	cell.is_empty = bool(serialized_cell.get("e", 0))
	cell.is_transparent = bool(serialized_cell.get("t", 0))
	cell.is_door = bool(serialized_cell.get("door", 0))
	cell.is_open = bool(serialized_cell.get("open", 0))
	cell.is_locked = bool(serialized_cell.get("locked", 0))
	return cell


#########
# Utils #
#########

func _load_donjon_json_file(json_file_path):
	print("Loading donjon map: " + json_file_path)

	var map_data = Utils.read_json(json_file_path)
	label = map_data["settings"]["name"]
	var cells_data = map_data["cells"]
	
	var len_x = cells_data[0].size()
	var len_y = 2
	var len_z = cells_data.size()
	min_x = 0
	min_y = -1
	min_z = 0
	max_x = min_x + len_x
	max_y = min_y + len_y
	max_z = min_z + len_z
	
	floors[0] = MRPAS.new(Vector2(len_x, len_z))

	for y in range(min_y, max_y):
		for x in range(len_x):
			for z in range(len_z): 
				var donjon_code = cells_data[z][x]
				var cell_is_wall = int(donjon_code) in [0, 16]
				var cell_is_door = int(donjon_code) in [131076]
				
				var cell = Cell.new(self)
				cell.donjon_code = donjon_code
				match y:
					-1:
						cell.skin = map_theme.floor
						cell.orientation = Data.orientations.pick_random()
					0:
						if cell_is_wall:
							cell.skin = map_theme.wall
							cell.orientation = Data.yp_orientations.pick_random()
						elif cell_is_door:
							cell.skin = map_theme.door_closed
							var next_cell_is_wall = int(cells_data[z + 1][x]) in [0, 16]
							cell.orientation = Data.yp_orientations[0 if next_cell_is_wall else 1]
							cell.is_door = true
						else:
							cell.is_empty = true
							cell.is_transparent = true

				set_cell(Vector3i(x, y, z), cell)


func _load_fried_json_file(json_file_path):
	var serialized_map = Utils.read_json(json_file_path)
	deserialize(serialized_map)
	

func serialize() -> Dictionary:
	var serialized_cells = []
	for cell_position in cells:
		var cell : Cell = cells[cell_position]
		serialized_cells.append(serialize_cell(cell_position, cell))
	
	var serialized_lights = []
	for light in lights_parent.get_children():
		var serialized_light := {}
		serialized_light["id"] = light.id
		serialized_light["position"] = Utils.v3_to_array(light.position)
		serialized_light["intensity"] = light.intensity
		serialized_light["bright"] = light.bright
		serialized_light["faint"] = light.faint
		serialized_light["follow"] = light.follow
		serialized_lights.append(serialized_light)
		
	var serialized_entities = []
	for entity in entities_parent.get_children():
		var serialized_entity = {}
		serialized_entity["id"] = entity.id
		var entity_position = entity.target_position if entity.moving_to_target else entity.position
		serialized_entity["position"] = Utils.v3_to_array(entity_position)
		serialized_entity["label"] = entity.label
		serialized_entity["health"] = entity.health
		serialized_entity["health_max"] = entity.health_max
		serialized_entity["base_size"] = entity.base_size
		serialized_entity["base_color"] = Utils.color_to_string(entity.base_color)
		serialized_entity["texture_path"] = entity.texture_path
		serialized_entities.append(serialized_entity)
		
	var serialized_map = {
		"id": id,
		"label": label,
		"from": [min_x, min_y, min_z],
		"to": [max_x, max_y, max_z],
		"cells": serialized_cells,
		"entities": serialized_entities,
		"lights": serialized_lights,
	}
	
	return serialized_map


func deserialize(serialized_map : Dictionary):
	label = serialized_map['label']
	min_x = serialized_map['from'][0]
	min_y = serialized_map['from'][1]
	min_z = serialized_map['from'][2]
	max_x = serialized_map['to'][0]
	max_y = serialized_map['to'][1]
	max_z = serialized_map['to'][2]
	
	for y in range(min_y + 1, max_y):
		floors[y] = MRPAS.new(Vector2(max_x - min_x, max_z - min_z ))
	
	for serialized_cell in serialized_map.get('cells', {}):
		var cell_position = Vector3i(
			serialized_cell["x"], 
			serialized_cell["y"], 
			serialized_cell["z"])
		var cell = deserialize_cell(serialized_cell)
		set_cell(cell_position, cell)
	
	for serialized_light in serialized_map.get('lights', {}):
		Game.world.enqueue_command(Game.world.OpCode.NEW_LIGHT, serialized_light)
	
	for serialized_entity in serialized_map.get('entities', {}):
		Game.world.enqueue_command(Game.world.OpCode.NEW_ENTITY, serialized_entity)
