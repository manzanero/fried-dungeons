class_name Light
extends Node3D


signal cell_changed


const DEFAULT_HEIGHT := 1.1
const RANGE = 10


var id : String : 
	get:
		return str(name)
	set(value):
		name = value

var intensity : int = 100 : 
	get:
		return clampi(intensity, 0, 100)
		
var bright : int = 0
var faint : int = 1
var color := Color.WHITE : set = _set_color
var follow : String = "" : set = _set_follow

var cell_position : Vector3i
var cells : Dictionary = {}
var tick := 0.1
var followed_position : Vector3
var followed_entity : Entity
var preview : bool

var is_selected : bool : 
	get:
		return selector.visible
	set(value):
		if selector.visible != value:
			selector.visible = value


@onready var pivot := $Pivot as Marker3D
@onready var body := %Body as MeshInstance3D
@onready var collider := %Collider as StaticBody3D
@onready var selector := %Selector as MeshInstance3D
@onready var update_timer := $UpdateTimer as Timer


func _ready():
	pivot.position.y = DEFAULT_HEIGHT
	selector.visible = false
	
	update_timer.wait_time = tick
	update_timer.autostart = true
	update_timer.timeout.connect(_update)
	
	if followed_entity:
		followed_position = followed_entity.position

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
	
	if followed_entity:
		followed_entity.light = null
		followed_entity = null
	
	if value:
		followed_entity = Game.world.map.entities_parent.get_node(value)
		followed_entity.light = self
		var height = followed_entity.body.texture.get_height()
		pivot.position.y = height * 0.05 + 0.3
	else:
		pivot.position.y = DEFAULT_HEIGHT
	


func _set_color(value : Color):
	color = value
	body.mesh.surface_get_material(0).albedo_color = value


func get_intensity(target_position : Vector3i) -> float:
	var d : float = ((target_position - cell_position) * Vector3i(1, 0, 1)).length()
	if d <= bright:
		return intensity
	if d >= faint:
		return 0
	return (1 - (d - bright) / (faint - bright)) * intensity
	

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
	for lights_cell_position in cells:
		var cell : Map.Cell = cells[lights_cell_position]
		cell.lights.erase(self)
		
	cells.clear()
	
	
func update_fov():
	forget()
	
	cells = fov(Utils.v3_to_v3i(position))
	for cell in cells.values():
		cell.lights.append(self)


func fov(viewer_position : Vector3i) -> Dictionary:
	var fov_cells := {}

	var c_x := viewer_position.x
	var c_y := viewer_position.y
	var c_z := viewer_position.z
	
	var map = Game.world.map
	var floors = map.floors
	
	for y in [c_y, c_y - 1] + range(c_y + 1, map.max_y + 1):
		floors[y].clear_field_of_view()
		floors[y].compute_field_of_view(Utils.v3_to_v2i(position), RANGE)
		
		var effective_floor_level = c_y if y <= c_y else y - 1
		
		for x in range(c_x - RANGE, c_x + RANGE + 1):
			for z in range(c_z - RANGE, c_z + RANGE + 1):
				var candidate_cell_position := Vector3i(x, y, z)
				var candidate_cell = map.cells.get(candidate_cell_position)
				if not candidate_cell:
					continue
					
				var is_in_fov = floors[effective_floor_level].is_in_view(Vector2i(x, z))
				if not is_in_fov:
					continue
					
				fov_cells[candidate_cell_position] = candidate_cell
		
		if y <= 0:
			continue
			
		var vertical_cell_position := Vector3i(c_x, y, c_z)
		var vertical_cell = map.cells.get(vertical_cell_position)
		if vertical_cell and not vertical_cell.is_empty:
			break
				
	return fov_cells


func _on_cell_changed():
	update_fov()
	Game.world.map.update_fov()


###############
# Serializers #
###############

func serialize():
	var serialized_light := {}
	serialized_light["id"] = id
	serialized_light["position"] = Utils.v3_to_array(position)
	serialized_light["intensity"] = intensity
	serialized_light["bright"] = bright
	serialized_light["faint"] = faint
	serialized_light["follow"] = follow
	return serialized_light
