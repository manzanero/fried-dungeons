class_name Light
extends Node3D

var intensity : int = 100 : 
	get:
		return clampi(intensity, 0, 100)
		
var bright : int = 0
var faint : int = 0

var cells : Dictionary = {}

var parent : Node3D = null : set = _set_parent


const DEFAULT_HEIGHT := 1.1


@onready var pivot := $Pivot as Marker3D
@onready var body := %Body as MeshInstance3D
@onready var collider := %Collider as StaticBody3D
@onready var selector := %Selector as MeshInstance3D
@onready var follower := $Follower as RemoteTransform3D


func _ready():
	pivot.position.y = DEFAULT_HEIGHT


func _set_parent(value : Node3D):
	if value:
		parent = value
		follower.remote_path = parent.get_path()
		pivot.position.y = 0
	else:
		parent = value
		follower.remote_path = NodePath("")
		pivot.position.y = DEFAULT_HEIGHT


func get_intensity(target_position : Vector3) -> int:
	var d : float= (target_position - position).length()
	if d <= bright:
		return 100
	if d >= faint:
		return 0
	return  (1 - (d - bright) / (faint - bright)) * intensity
	

func update_view():
	pass
