class_name Light
extends Node3D


signal cell_changed


var id : String : 
	get:
		return str(name)
	set(value):
		name = value

var intensity : int = 100 : 
	get:
		return clampi(intensity, 0, 100)
		
var bright : int = 0
var faint : int = 0
var color := Color.WHITE : set = _set_color
var follow : String = "" : set = _set_follow

var cell_position : Vector3i
var cells : Dictionary = {}
var tick := 0.1
var preview : bool

var is_selected : bool : 
	get:
		return selector.visible
	set(value):
		if selector.visible != value:
			selector.visible = value


const DEFAULT_HEIGHT := 1.1


@onready var pivot := $Pivot as Marker3D
@onready var body := %Body as MeshInstance3D
@onready var collider := %Collider as StaticBody3D
@onready var selector := %Selector as MeshInstance3D
@onready var follower := $Follower as RemoteTransform3D
@onready var update_timer := $UpdateTimer as Timer


func _ready():
	pivot.position.y = DEFAULT_HEIGHT
	selector.visible = false
	
	update_timer.wait_time = tick
	update_timer.autostart = true
	update_timer.timeout.connect(_update)

	cell_changed.connect(_on_cell_changed)
	

func change(kwargs : Dictionary):
	if "intensity" in kwargs: 
		intensity = kwargs.get("intensity", 100)
	if "bright" in kwargs: 
		bright = kwargs.get("bright", 0)
	if "faint" in kwargs: 
		faint = kwargs.get("faint", 0)
	if "follow" in kwargs: 
		follow = kwargs.get("follow", "")
	

func _set_follow(value : String):
	follow = value
	if value:
		var entity : Entity = Game.world.map.entities_parent.get_node(value)
		follower.remote_path = entity.get_path()
	else:
		follower.remote_path = NodePath("")
	
	pivot.position.y = DEFAULT_HEIGHT


func _set_color(value : Color):
	color = value
	body.mesh.surface_get_material(0).albedo_color = value


func get_intensity(target_position : Vector3) -> int:
	var d : float = ((target_position - position) * Vector3(1, 0, 1)).length()
	if d <= bright:
		return intensity
	if d >= faint:
		return 0
	return  (1 - (d - bright) / (faint - bright)) * intensity
	

func _update():
	if preview:
		return

	# calculate if selected
	is_selected = Game.world.selected_light == self
	
	var new_cell_position = Utils.v3_to_v3i(position)
	if new_cell_position != cell_position:
		cell_position = new_cell_position
		cell_changed.emit()


func forget():
	for cell_position in cells:
		var cell : Map.Cell = cells[cell_position]
		cell.lights.erase(self)
		
	cells.clear()
		
	
const RANGE = 10

	
func update_fov():
	forget()
	
	var c_x : int = position.x
	var c_y : int = position.y
	var c_z : int = position.z
	
	var map = Game.world.map
	var floors = Game.world.map.floors
	floors[0].clear_field_of_view()
	floors[0].compute_field_of_view(Utils.v3_to_v2i(position), RANGE)
	
	for y in [c_y - 1, c_y]:
		for x in range(c_x - RANGE, c_x + RANGE + 1):
			for z in range(c_z - RANGE, c_z + RANGE + 1):
				var cell_position = Vector3i(x, y, z)
				var cell = map.cells.get(cell_position)
				if not cell:
					continue
				
				var is_in_fov = floors[0].is_in_view(Vector2i(x, z))
				if is_in_fov:
					cells[cell_position] = cell
					cell.lights.append(self)
				
				
func _on_cell_changed():
	update_fov()
	Game.world.map.update_fov()
