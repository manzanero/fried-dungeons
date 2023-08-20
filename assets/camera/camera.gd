class_name Camera
extends Marker3D

@export var init_x: float = 15
@export var init_z: float = 25
@export var init_rot_x: float = -60
@export var init_rot_y: float = 0
@export var init_zoom: float = 20

@export var move_speed: float = 0.075
@export var rot_x_speed: float = 0.0025
@export var rot_y_speed: float = 0.0075
@export var zoom_step: float = 0.1
@export var zoom_speed: float = 10

@export var min_x: float = -100
@export var max_x: float = 10000
@export var min_z: float = -100
@export var max_z: float = 10000
@export var min_rot_x: float = -90
@export var max_rot_x: float = 90
@export var min_zoom: float = 0
@export var max_zoom: float = 10

var is_action: bool
var is_move: bool
var is_rotate: bool
var new_rotation: Vector3
var new_position: Vector3
var offset_move: Vector2
var offset_wheel: int
var zoom: float = 1

var is_operated : bool

@onready var camera = $Camera3D


func _ready():
	new_position = Vector3(init_x, transform.origin.y, init_z)
	new_rotation.x = clamp(deg_to_rad(init_rot_x), deg_to_rad(min_rot_x), deg_to_rad(max_rot_x))
	new_rotation.y = deg_to_rad(init_rot_y)
	new_rotation.z = 0
	zoom = clamp(init_zoom, min_zoom, max_zoom)


func _process(delta):
	if is_rotate:
		new_rotation += Vector3(-offset_move.y * rot_y_speed, offset_move.x * rot_x_speed, 0)
		new_rotation.x = clamp(new_rotation.x, deg_to_rad(min_rot_x), deg_to_rad(max_rot_x))

	if is_move:
		var transform_forward = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
		var transform_left = Vector3.LEFT.rotated(Vector3.UP, rotation.y)
		offset_move = offset_move * 0.015 * (zoom + 0.5)
		new_position += move_speed * (offset_move.y * transform_forward + offset_move.x * transform_left)
		new_position.x = clamp(new_position.x, min_x, max_x)
		new_position.z = clamp(new_position.z, min_z, max_z)
		
	offset_move = Vector2.ZERO

	if not position == new_position:
		position = lerp(position, new_position, zoom_speed * delta)

	if not rotation == new_rotation:
		rotation = lerp(rotation, new_rotation, zoom_speed * delta)

	if not camera.position.z == zoom:
		camera.position.z = lerp(camera.position.z, zoom, zoom_speed * delta)


func _input(event):

	# Mouse
	if event is InputEventMouseMotion:
		if is_rotate or is_move:
			offset_move += event.relative

	elif event is InputEventMouseButton:
		if event.is_released():
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				is_rotate = false
			if event.button_index == MOUSE_BUTTON_RIGHT:
				is_move = false
				
			if not is_rotate and not is_move:
				is_operated = false


func _unhandled_input(event):
	
	# Touch
	if event is InputEventSingleScreenDrag:
		var mobile_offset_move = event.relative * 0.001 * (zoom + 1)
		var transform_forward = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
		var transform_left = Vector3.LEFT.rotated(Vector3.UP, rotation.y)
		new_position += mobile_offset_move.y * transform_forward + mobile_offset_move.x * transform_left
		new_position.x = clamp(new_position.x, min_x, max_x)
		new_position.z = clamp(new_position.z, min_z, max_z)

	elif event is InputEventMultiScreenDrag:
		var offset_rotation = event.relative * 0.002
		new_rotation += Vector3(-offset_rotation.y, offset_rotation.x, 0)
		new_rotation.x = clamp(new_rotation.x, deg_to_rad(min_rot_x), deg_to_rad(max_rot_x))

	elif event is InputEventScreenPinch:
		var offset_zoom = -event.relative * 0.0025 * (zoom + 0.25)
		zoom += offset_zoom
		zoom = clamp(zoom, min_zoom, max_zoom)
	
	elif event is InputEventMouseButton:
		
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				is_operated = true
				is_rotate = true
				is_move = false
			if event.button_index == MOUSE_BUTTON_RIGHT:
				is_operated = true
				is_rotate = false
				is_move = true
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom -= zoom_step * (zoom + 0.25)
				zoom = clamp(zoom, min_zoom, max_zoom)
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom += zoom_step * (zoom + 0.25)
				zoom = clamp(zoom, min_zoom, max_zoom)
