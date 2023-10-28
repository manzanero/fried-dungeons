class_name CellEditMenu
extends Panel

var build_dir := Vector3.UP
var cell_data : = {}
var is_targeting_cell_position := false
var is_building := false
var target_cell_position := Vector3i.ZERO
var last_targeting_cell_position := Vector3i.UP * 1000

var cells_rollback := {}
var cells_rollout := {}

@onready var draw_wall_button := %CellWallButton as Button
@onready var draw_floor_button := %CellFloorButton as Button

@onready var category_tapbar := %CategoryTabBar as TabBar
@onready var category_itemlist := %CategoryItemList as ItemList

@onready var submit_button := %CellSubmitButton as Button
@onready var cancel_button := %CellCancelButton as Button

@onready var map_theme := Map.MapTheme.new()
@onready var target_raycast = PhysicsRayQueryParameters3D.new()


func _ready():
	draw_wall_button.pressed.connect(_on_draw_wall_button_pressed)
	draw_floor_button.pressed.connect(_on_draw_floor_button_pressed)
	category_itemlist.item_selected.connect(_on_item_selected)
	category_itemlist.empty_clicked.connect(_on_empty_clicked)
	submit_button.pressed.connect(_on_submit_button_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_button_pressed)


func _on_draw_wall_button_pressed():
	build_dir = Vector3.UP
	
	
func _on_draw_floor_button_pressed():
	build_dir = Vector3.DOWN


func _on_item_selected(index):
	cell_data = category_itemlist.get_item_metadata(index)


func _on_empty_clicked(_at_position, _mouse_button_index):
	category_itemlist.deselect_all()
	cell_data = {}


func _on_submit_button_button_pressed():
	var serialized_cells = []
	for cell_position in cells_rollout:
		var cell_rollout : Map.Cell = cells_rollout[cell_position]
		cell_rollout.is_preview = false
		Game.world.map.set_cell(cell_position, cell_rollout)
		serialized_cells.append(Game.world.map.serialize_cell(cell_position, cell_rollout))
		
	visible = false
	Game.world.grid.active = false
	Game.world.map.refresh_lights()
	Game.world.map.update_fov()
		
	Commands.async_send(Commands.OpCode.SET_CELLS, {
		"cells": serialized_cells
	})


func _on_cancel_button_button_pressed():
	for cell_position in cells_rollback:
		Game.world.map.set_cell(cell_position, cells_rollback[cell_position])
		
	visible = false
	Game.world.grid.active = false
	Game.world.map.refresh_lights()
	Game.world.map.update_fov()


func get_new_cell():
	var cell = Map.Cell.new(Game.world.map)
	cell.is_preview = true
	
	if not cell_data:
		cell.is_empty = true
		cell.is_transparent = true
		return cell
	
	cell.skin = cell_data["skin"]
	cell.orientation = Data.yp_orientations.pick_random()
	
	if "is_door" in cell_data:
		cell.is_door = cell_data["is_door"]
	
	if "is_open" in cell_data:
		cell.is_empty = true
		cell.is_open = cell_data["is_open"]

	return cell


func _process_target_ray_hit():
	var hit_info = Utils.get_raycast_hit(Game.world, Game.camera.eyes, target_raycast, Utils.get_bitmask(4))
	if hit_info:
		is_targeting_cell_position = true
		target_cell_position = Utils.v3_to_v3i(hit_info["position"] + build_dir * 0.1)
	else:
		is_targeting_cell_position = false


func _process(_delta):
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
			var up_cell = cells_rollout.get(target_cell_position + Vector3i(0, 0, -1), 
					Game.world.map.cells.get(target_cell_position + Vector3i(0, 0, -1)))
			var left_cell = cells_rollout.get(target_cell_position + Vector3i(-1, 0, 0), 
					Game.world.map.cells.get(target_cell_position + Vector3i(-1, 0, 0)))
				
			if up_cell and up_cell.is_empty:
				cell_rollout.orientation = Data.yp_orientations[1]
			elif left_cell and left_cell.is_empty:
				cell_rollout.orientation = Data.yp_orientations[0]
		
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
			
#				print(cells_rollout)
