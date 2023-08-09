extends Panel

var floor_index : int = 0
var cell_model : int = 0
var is_targeting_cell_position := false
var is_building := false
var target_cell_position := Vector3i.ZERO
var last_targeting_cell_position := Vector3i.UP * 1000

var cells_rollback := {}
var cells_rollout := {}

@onready var floor_button := %FloorButton as Button
@onready var wall_button := %WallButton as Button
@onready var door_closed := %DoorClosedButton as Button
@onready var door_open := %DoorOpenButton as Button
@onready var empty_button := %EmptyButton as Button

@onready var draw_wall_button := %CellWallButton as Button
@onready var draw_floor_button := %CellFloorButton as Button

@onready var submit_button := %CellSubmitButton as Button
@onready var cancel_button := %CellCancelButton as Button

@onready var map_theme := Map.MapTheme.new()
@onready var target_raycast = PhysicsRayQueryParameters3D.new()


func _ready():
	empty_button.pressed.connect(_on_empty_button_pressed)
	floor_button.pressed.connect(_on_floor_button_pressed)
	wall_button.pressed.connect(_on_wall_button_pressed)
	door_closed.pressed.connect(_on_door_closed_button_pressed)
	door_open.pressed.connect(_on_door_open_button_pressed)
	
	draw_wall_button.pressed.connect(_on_draw_wall_button_pressed)
	draw_floor_button.pressed.connect(_on_draw_floor_button_pressed)
	
	submit_button.pressed.connect(_on_submit_button_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_button_pressed)


func _on_empty_button_pressed():
	cell_model = 0
func _on_floor_button_pressed():
	cell_model = 1
func _on_wall_button_pressed():
	cell_model = 2
func _on_door_closed_button_pressed():
	cell_model = 3
func _on_door_open_button_pressed():
	cell_model = 4
func _on_draw_wall_button_pressed():
	floor_index = 0
func _on_draw_floor_button_pressed():
	floor_index = -1


func _on_submit_button_button_pressed():
	var serialized_cells = []
	for cell_position in cells_rollout:
		var cell_rollout : Map.Cell = cells_rollout[cell_position]
		cell_rollout.is_preview = false
		Game.world.map.set_cell(cell_position, cell_rollout)
		serialized_cells.append(Game.world.map.serialize_cell(cell_position, cell_rollout))
		
	visible = false
	Game.world.map.refresh_lights()
	Game.world.map.update_fov()
		
	Server.send_message(Game.world.OpCode.SET_CELLS, {
		"cells": serialized_cells
	})


func _on_cancel_button_button_pressed():
	for cell_position in cells_rollback:
		Game.world.map.set_cell(cell_position, cells_rollback[cell_position])
		
	visible = false
	Game.world.map.refresh_lights()
	Game.world.map.update_fov()


func get_new_cell():
	var cell = Map.Cell.new(Game.world.map)
	match cell_model:
		0:
			cell.is_empty = true
			cell.is_transparent = true
			cell.orientation = Data.orientations.pick_random()
		1:
			cell.skin = map_theme.floor
			cell.orientation = Data.orientations.pick_random()
		2:
			cell.skin = map_theme.wall
			cell.orientation = Data.yp_orientations.pick_random()
		3:
			cell.skin = map_theme.door_closed
			cell.orientation = Data.yp_orientations[0]
			cell.is_door = true
		4:
			cell.skin = map_theme.door_open
			cell.orientation = Data.yp_orientations[0]
			cell.is_door = true
			cell.is_open = true
			
	cell.is_preview = true
	return cell


func _process_target_ray_hit():
	var ray_length = 1000
	var mouse_pos = get_viewport().get_mouse_position()
	var space_state = Game.world.get_world_3d().direct_space_state
	target_raycast.from = Game.camera.camera.project_ray_origin(mouse_pos)
	target_raycast.to = target_raycast.from + Game.camera.camera.project_ray_normal(mouse_pos) * ray_length
	target_raycast.collision_mask = Utils.get_bitmask(4)
	var hit_info = space_state.intersect_ray(target_raycast)
	if hit_info:
		is_targeting_cell_position = true
		target_cell_position = Utils.v3_to_v3i(hit_info["position"] + Vector3.UP * (floor_index + 0.1) )
	else:
		is_targeting_cell_position = false


func _process(delta):
	_process_target_ray_hit()
	
	if is_building and is_targeting_cell_position and visible:
		if target_cell_position == last_targeting_cell_position:
			return
		
		last_targeting_cell_position = target_cell_position
		
		if not cells_rollback.has(target_cell_position):
			var cell_rollback = Game.world.map.cells.get(target_cell_position)
			cells_rollback[target_cell_position] = cell_rollback
		
		var cell_rollout = get_new_cell()
		
		# door case
		if cell_rollout.is_door:
			var next_cell = cells_rollout.get(target_cell_position + Vector3i(0, 0, -1), 
					Game.world.map.cells.get(target_cell_position + Vector3i(0, 0, -1)))
				
			if next_cell and next_cell.is_empty:
				cell_rollout.orientation = Data.yp_orientations[1]
		
		Game.world.map.set_cell(target_cell_position, cell_rollout)
		cells_rollout[target_cell_position] = cell_rollout


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				is_building = true


func _input(event):
	if event is InputEventMouseButton:
		if event.is_released():
			if event.button_index == MOUSE_BUTTON_LEFT:
				is_building = false
				last_targeting_cell_position = Vector3i.UP * 1000
