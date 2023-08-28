extends Node3D


var is_mouse_tile_hover : bool
var mouse_position : Vector3
var mouse_tile_position : Vector3i

var bellow : bool : 
	set(value):
		bellow = value
		mesh.position.y = 0.05 if value else (1.05)
		mesh.scale = Vector3(1, -1 if value else 1, 1)

var ground : int :
	set(value):
		ground = value
		var up_shape : WorldBoundaryShape3D = %Up.shape
		var down_shape : WorldBoundaryShape3D = %Down.shape
		up_shape.plane.d = ground
		down_shape.plane.d = -ground
		
var active : bool :
	set(value):
		active = value
		grid_pivot.visible = value


@onready var grid_pivot = $GridPivot as Marker3D
@onready var mesh = $GridPivot/MeshInstance3D as MeshInstance3D
@onready var material := mesh.get_surface_override_material(0)

@onready var raycast = PhysicsRayQueryParameters3D.new()


func _ready():
	bellow = true
	ground = 0
	active = true
	

func _process(delta):
	if show and is_mouse_tile_hover:
		grid_pivot.position = mouse_tile_position
		material.set_shader_parameter("mouse_position", mouse_position)
	

func _physics_process(delta):
	var hit_info = Utils.get_raycast_hit(self, Game.camera.camera, raycast, Utils.get_bitmask(4))
	if hit_info:
		is_mouse_tile_hover = true
		mouse_position = hit_info["position"]
		mouse_tile_position = Vector3i(floori(mouse_position.x), snappedi(mouse_position.y, 1), floori(mouse_position.z))
	else:
		is_mouse_tile_hover = false
