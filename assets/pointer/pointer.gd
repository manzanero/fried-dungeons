class_name Pointer
extends Node3D


var cell_position : Vector3i
var pointing : bool :
	get:
		return visible
	set(value):
		visible = value

var cell : Map.Cell : get = get_cell


@onready var shape := $Shape as MeshInstance3D
@onready var timer := $Timer as Timer


func _ready():
	timer.timeout.connect(func(): shape.visible = not shape.visible)
	timer.wait_time = WAIT_TIME


func move_to(p_cell_position : Vector3i):
	cell_position = p_cell_position
	position = p_cell_position
	shape.visible = true
	timer.start()
	

func get_cell():
	return Game.world.map.get_cell(cell_position) if pointing else null


###########
# Objects #
###########

const WAIT_TIME = 0.5
