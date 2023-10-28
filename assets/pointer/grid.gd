class_name Grid
extends Node3D


var is_mouse_tile_hover : bool
var mouse_position : Vector3
var mouse_tile_position : Vector3i

var floor_level : int :
	set(value):
		floor_level = value
		var up_shape : WorldBoundaryShape3D = %Up.shape
		var down_shape : WorldBoundaryShape3D = %Down.shape
		up_shape.plane.d = value
		down_shape.plane.d = -value
		
var active : bool :
	set(value):
		active = value
		grid_pivot.visible = value


@onready var grid_pivot = $GridPivot as Marker3D
@onready var material : Material = grid_pivot.get_child(0).get_surface_override_material(0)

@onready var raycast = PhysicsRayQueryParameters3D.new()


func _ready():
	floor_level = 0
	active = true
	

func _process(_delta):
	if show and is_mouse_tile_hover:
		grid_pivot.position = mouse_tile_position
		material.set_shader_parameter("mouse_position", mouse_position)
	

func _physics_process(_delta):
	var hit_info = Utils.get_raycast_hit(self, Game.camera.eyes, raycast, Utils.get_bitmask(4))
	if hit_info:
		is_mouse_tile_hover = true
		mouse_position = hit_info["position"]
		mouse_tile_position = Vector3i(floori(mouse_position.x), snappedi(mouse_position.y, 1), floori(mouse_position.z))
	else:
		is_mouse_tile_hover = false
