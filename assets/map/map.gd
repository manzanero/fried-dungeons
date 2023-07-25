class_name Map
extends Node3D

signal changed


var label := 'Unlabeled'
var min_x : int = 0
var min_y : int = 0
var min_z : int = 0
var max_x : int = 0
var max_y : int = 0
var max_z : int = 0
var skin_library := {}
var floors := {}
var cells := {}
var cells_queded := {}
var cache_cells := {}
var entity_eyes : Entity
var entity_hovered : Entity
var preview_move_mode : bool
var entity_moving : Entity
var offset_moving : Vector3
var preview_entity : Entity

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


@onready var solid_map = $SolidMap as GridMap
@onready var entities_parent = $Entities as Node3D
@onready var map_theme := MapTheme.new()
@onready var cell_raycast = PhysicsRayQueryParameters3D.new()
@onready var entity_raycast = PhysicsRayQueryParameters3D.new()


func _ready():
	_load_library()


func _load_library():
	var skin_library_len = solid_map.mesh_library.get_item_list().size()
	for i in range(skin_library_len):
		skin_library[solid_map.mesh_library.get_item_name(i)] = i
	
	
func _physics_process(delta):
	_process_cell_ray_hit()
	_process_entity_ray_hit()
	_process_preview_move(delta)
	
	
func get_cell(cell_position : Vector3i) -> Cell:
	var cell = cells.get(cell_position)
	if not cell:
		return cells_queded.get(cell_position) 
	if cell.is_in_view:
		return cells_queded.get(cell_position, cell)
	return cell
		
	
func set_cell(cell_position : Vector3i, cell : Cell):
	if cell.is_in_view:
		cells[cell_position] = cell
		cell.is_explored = true
	else:
		cells_queded[cell_position] = cell
		cell = get_cell(cell_position)
	
	solid_map.set_cell_item(cell_position, cell.code(skin_library), cell.orientation)
		
	if cell_position.y == 0:
		floors[cell_position.y].set_transparent(Vector2i(cell_position.x, cell_position.z), cell.is_transparent)


func load_map(kwargs):
	solid_map.clear()
	
	if "donjon_file" in kwargs:
		_load_donjon_json_file(kwargs["donjon_file"])
		name = kwargs["id"]
	if "fried_file" in kwargs:
		_load_fried_json_file(kwargs["fried_file"])
	if "map" in kwargs:
		deserialize(kwargs["map"])
		
	if Game.is_host:
		reset_view(true)


func change_to_entity_eyes(entity):
	if entity_eyes:
		entity_eyes.cell_changed.disconnect(update_view)
	
	entity_eyes = entity
	
	if entity:
		reset_view(false)
		entity.cell_changed.connect(update_view)
		update_view()
	else:
		reset_view(true)



func reset_view(is_in_view):
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			for z in range(min_z, max_z):
				var cell_position = Vector3i(x, y, z)
				var cell = get_cell(cell_position)
				if cell:
					cell.is_in_view = is_in_view
					set_cell(cell_position, cell)


func reset_explored():
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			for z in range(min_z, max_z):
				var cell_position = Vector3i(x, y, z)
				var cell = get_cell(cell_position)
				if cell:
					cell.is_explored = false
					set_cell(cell_position, cell)


func update_view():
	var c_x = entity_eyes.cell_position.x
	var c_y = entity_eyes.cell_position.y
	var c_z = entity_eyes.cell_position.z
	
	for cell_position in cache_cells:
		if cell_position.y not in [c_y - 1, c_y] \
		or cell_position.x not in range(c_x - RANGE, c_x + RANGE + 1) \
		or cell_position.z not in range(c_z - RANGE, c_z + RANGE + 1):
			var cell = cache_cells[cell_position]
			if cell.is_in_view:
				cell.is_in_view = false
				set_cell(cell_position, cell)
		
	cache_cells.clear()
	
	floors[0].clear_field_of_view()
	floors[0].compute_field_of_view(Utils.v3i_to_v2i(entity_eyes.position), RANGE)
	
	for y in [c_y - 1, c_y]:
		for x in range(c_x - RANGE, c_x + RANGE + 1):
			for z in range(c_z - RANGE, c_z + RANGE + 1):
				var cell_position = Vector3i(x, y, z)
				var cell = get_cell(cell_position)
				if not cell:
					continue
				
				var is_in_view = floors[0].is_in_view(Vector2i(x, z))
				cell.is_in_view = is_in_view
				cache_cells[cell_position] = cell
				set_cell(cell_position, cell)


func _process_cell_ray_hit():
	var ray_length = 1000
	var mouse_pos = get_viewport().get_mouse_position()
	var space_state = get_world_3d().direct_space_state
	cell_raycast.from = Game.camera.camera.project_ray_origin(mouse_pos)
	cell_raycast.to = cell_raycast.from + Game.camera.camera.project_ray_normal(mouse_pos) * ray_length
	cell_raycast.collision_mask = Utils.get_bitmask(1)
	var hit_info = space_state.intersect_ray(cell_raycast)
	if hit_info:
		is_cell_hovered = true
		position_hovered = hit_info["position"] 
		normal_hovered = hit_info["normal"]
	else:
		is_cell_hovered = false


func _process_entity_ray_hit():
	var ray_length = 1000
	var mouse_pos = get_viewport().get_mouse_position()
	var space_state = get_world_3d().direct_space_state
	entity_raycast.from = Game.camera.camera.project_ray_origin(mouse_pos)
	entity_raycast.to = entity_raycast.from + Game.camera.camera.project_ray_normal(mouse_pos) * ray_length
	entity_raycast.collision_mask = Utils.get_bitmask(2)
	var hit_info = space_state.intersect_ray(entity_raycast)
	if hit_info:
		entity_hovered = hit_info["collider"]
	else:
		entity_hovered = null
		

func _process_preview_move(delta):
	if entity_hovered and Input.is_action_just_pressed("left_click"):
		preview_move_mode = true
		entity_moving = entity_hovered
		offset_moving = entity_moving.position - position_hovered
		preview_entity = Game.world.entity_scene.instantiate() as Entity
		Game.world.map.add_child(preview_entity)
		preview_entity.preview = true
		preview_entity.texture_path = entity_moving.texture_path
		var preview_base_color = entity_moving.base_color
		preview_base_color.a *= 0.75
		preview_entity.base_color = preview_base_color
		preview_entity.position = entity_moving.position
		var preview_body_material = preview_entity.body.get_surface_override_material(0)
		preview_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		preview_body_material.albedo_color.a *= 0.75
		preview_entity.label_control.visible = false
		
	var preview_entity_position = position_hovered
	preview_entity_position += normal_hovered * 0.1 * Vector3(1, 0, 1) + offset_moving
	
	if preview_move_mode:
		preview_entity.position = lerp(preview_entity.position, preview_entity_position, 20 * delta)
	
	if preview_move_mode and Input.is_action_just_released("left_click"):
		preview_move_mode = false
		preview_entity.queue_free()
		preview_entity = null
		var fallback_position = entity_moving.position
		entity_moving.position = position_hovered
		entity_moving.position += normal_hovered * 0.1 + offset_moving
		entity_moving.position.y = 0
		entity_moving.validate_position(fallback_position)
		Server.send_message(Game.world.OpCode.SET_ENTITY_TARGET_POSITION, {
			"id": entity_moving.name,
			"target_position": Utils.v3_to_array(entity_moving.position), 
		})


###########
# Objects #
###########

var RANGE = 10
const FILL = "Fill0"
const COVER = "Cover0"


class MapTheme:
	var floor = "Stone1"
	var wall = "Brick1"
	var door_closed = "Door0"
	var door_open = "Door1"
	

class Cell:
	var skin : String
	var donjon_code : int
	var orientation : int
	
	var is_queued : bool
	var is_in_view : bool
	var is_explored : bool
	
	var is_empty : bool
	var is_transparent : bool
	
	var is_door : bool
	var is_open : bool
	var is_locked : bool
		
	func code(skin_library : Dictionary) -> int:
		if is_in_view:
			return skin_library.get(skin, -1) 
		elif is_explored and not is_empty and Game.is_high_end:
			return skin_library.get(FILL)
		return -1
	

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
				
				var cell = Cell.new()
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


func deserialize(serialized_map : Dictionary):
	name = serialized_map['id']
	label = serialized_map['label']
	min_x = serialized_map['from'][0]
	min_y = serialized_map['from'][1]
	min_z = serialized_map['from'][2]
	max_x = serialized_map['to'][0]
	max_y = serialized_map['to'][1]
	max_z = serialized_map['to'][2]
	
	floors[0] = MRPAS.new(Vector2(max_x - min_x, max_z - min_z ))
	
	for serialized_cell in serialized_map['cells']:
		var cell_position = Vector3i(
			serialized_cell["x"], 
			serialized_cell["y"], 
			serialized_cell["z"])
		var cell = Cell.new()
		var skin = serialized_cell.get("s")
		cell.skin = solid_map.mesh_library.get_item_name(skin) if skin else ""
		cell.orientation = serialized_cell.get("o", 0)
		cell.is_empty = bool(serialized_cell.get("e", 0))
		cell.is_transparent = bool(serialized_cell.get("t", 0))
		cell.is_door = bool(serialized_cell.get("door", 0))
		cell.is_open = bool(serialized_cell.get("open", 0))
		cell.is_locked = bool(serialized_cell.get("locked", 0))
		set_cell(cell_position, cell)
	
	for serialized_entity in serialized_map['entities']:
		Game.world.new_command(Game.world.OpCode.NEW_ENTITY, serialized_entity)
	

func serialize() -> Dictionary:	
	var serialized_cells = []
	for cell_position in cells:
		var serialized_cell = {}
		var cell : Cell = cells[cell_position]
		serialized_cell["x"] = cell_position.x
		serialized_cell["y"] = cell_position.y
		serialized_cell["z"] = cell_position.z
		if cell.skin:
			serialized_cell["s"] = skin_library.get(cell.skin, -1) 
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
		serialized_cells.append(serialized_cell)
		
	var serialized_entities = []
	for entity in entities_parent.get_children():
		var serialized_entity = {}
		serialized_entity["id"] = str(entity.name)
		serialized_entity["position"] = Utils.v3_to_array(
			entity.target_position if entity.moving_to_target else entity.position)
		serialized_entity["label"] = entity.label
		serialized_entity["health"] = entity.health
		serialized_entity["health_max"] = entity.health_max
		serialized_entity["base_size"] = entity.base_size
		serialized_entity["base_color"] = Utils.color_to_string(entity.base_color)
		serialized_entity["texture_path"] = entity.texture_path
		serialized_entities.append(serialized_entity)
		
	var serialized_map = {
		"id": name,
		"label": label,
		"from": [min_x, min_y, min_z],
		"to": [max_x, max_y, max_z],
		"cells": serialized_cells,
		"entities": serialized_entities,
	}
	
	return serialized_map
