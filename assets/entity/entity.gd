class_name Entity
extends CharacterBody3D

signal cell_changed
signal changed

var id : String : 
	get:
		return str(name)
	set(value):
		name = value

var label := 'Unlabeled' : set = _set_label
var label_known := false : set = _set_label_known
var health := 50.0 : set = _set_health
var health_max := 100.0 : set = _set_health_max
var health_known := false : set = _set_health_known

var base_size := 0.5 : set = _set_base_size
var base_color := Color.WHITE : set = _set_base_color
var texture_path : String = "None" : set = _set_texture
var body_tint := Color.WHITE : set = _set_body_tint

const SPEED := 250.0

var tick := 0.1
var preview : bool

var position_changed : bool
var cell_position : Vector3i
var moving_to_target : bool

var target_position : Vector3 :
	set(value):
		target_position = value
		moving_to_target = true

var is_in_view : bool
var light_fixture : Color
var is_selected : bool : 
	get:
		return selector.visible
	set(value):
		if selector.visible != value:
			selector.visible = value


@onready var base := $Base as MeshInstance3D
@onready var body := $Body as SpriteMeshInstance
@onready var selector := $Selector as MeshInstance3D
@onready var update_timer := $UpdateTimer as Timer
@onready var label_control := $Info/Label as Control
@onready var label_label := %LabelLabel as Label
@onready var healt_bar := %HealthBar as ProgressBar
@onready var healt_bar_label := %HealthBar/Label as Label


func _ready():
	update_timer.wait_time = tick
	update_timer.autostart = true
	update_timer.timeout.connect(_update)

	body.position += Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		randf_range(-1, 1)).normalized() * 0.01

	selector.visible = false

	_set_label(label)
	_set_label_known(label_known)
	_set_health(health)
	_set_health_max(health_max)
	_set_health_known(health_known)
	

func _process(delta):
	label_control.position = Game.camera.camera.unproject_position(position)


func _physics_process(delta):
	if moving_to_target:
		var velocity_to_target = clamp((target_position - position).length() * 10 * delta, 0.05, 10000)
		position = position.move_toward(target_position, velocity_to_target)
		if position == target_position:
			moving_to_target = false
			if self == Game.world.map.entity_eyes:
				Game.world.map.update_fov()
				
	elif Game.world.map and Game.world.map.entity_eyes == self:
		_move_process(delta)
	

func _move_process(delta):
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED * delta
		velocity.z = direction.z * SPEED * delta
		body.look_at(position + direction)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta)
	
	var previous_position = position
	move_and_slide() 
	validate_position(previous_position)
	
	if position != previous_position:
		position_changed = true


func validate_position(fallback_position := Vector3(0, 0, 0)):
	var cell_position = Vector3i(position)
	var cell : Map.Cell = Game.world.map.cells.get(cell_position)
	
	if not cell:
		position = fallback_position
		return
	
	if cell.is_door and not cell.is_open and not cell.is_locked:
		cell.skin = 'Door1'
		cell.is_empty = true
		cell.is_transparent = true
		cell.is_open = true
		Game.world.map.set_cell(cell_position, cell)
		Game.world.map.refresh_lights()
		Game.world.send_command(Game.world.OpCode.SET_CELLS, {
			"cells": [Game.world.map.serialize_cell(cell_position, cell)]
		})
		
		
	if cell.is_empty:
		return 

	position = fallback_position


func get_cell() -> Map.Cell:
	return Game.world.map.cells.get(cell_position)
	

func _update():
	if preview:
		return

	# calculate if selected
	is_selected = Game.world.selected_entity == self

	# calculate if entity is visible
	var cell := get_cell()
	if cell and cell.get_light_intensity(cell_position):
		if cell.is_in_view != is_in_view:
			is_in_view = cell.is_in_view
			visible = is_in_view
			label_control.visible = is_in_view
		
		var cell_light_fixture := cell.get_light_fixture(cell_position)
		if cell_light_fixture != light_fixture:
			light_fixture = cell_light_fixture
			base.mesh.surface_get_material(0).albedo_color = base_color * light_fixture
			body.get_surface_override_material(0).albedo_color = body_tint * light_fixture
	
	else:
		is_in_view = false
		visible = false
		label_control.visible = false
		
	if moving_to_target:
		return
	
	# calculate if entity has been moved
	if position_changed:
		Game.world.send_command(Game.world.OpCode.SET_ENTITY_TARGET_POSITION, {
			"id": name,
			"target_position": Utils.v3_to_array(position), 
		})
		position_changed = false
	
	var new_cell_position = Utils.v3_to_v3i(position)
	if new_cell_position != cell_position:
		cell_position = new_cell_position
		cell_changed.emit()


func change(kwargs):
	
	# TODO: remove this
#	if kwargs["id"] in Game.public_entities:
#		label_known = true
#		health_known = true
#		Game.world.map.change_to_entity_eyes(self)
		
	if "label" in kwargs: 
		label = kwargs["label"]
	if "texture_path" in kwargs: 
		texture_path = kwargs["texture_path"]
	if "base_color" in kwargs: 
		base_color = kwargs["base_color"]
	if "base_size" in kwargs: 
		base_size = kwargs["base_size"]
	if "health" in kwargs: 
		health = kwargs["health"]
	if "health_max" in kwargs: 
		health_max = kwargs["health_max"]
	if "health_max" in kwargs: 
		health_max = kwargs["health_max"]

	changed.emit()


###################
# getters/setters #
###################

func _set_label(value):
	label = value
	label_label.text = value


func _set_label_known(value):
	label_known = value
	label_label.visible = value


func _set_health(value):
	health = value
	healt_bar.value = value
	healt_bar_label.text = "%s/%s" % [health, health_max]


func _set_health_max(value):
	health_max = value
	healt_bar.max_value = value
	healt_bar_label.text = "%s/%s" % [health, health_max]


func _set_health_known(value):
	health_known = value
	healt_bar.visible = value


func _set_base_size(value):
	base_size = value
	var mesh : CylinderMesh = base.mesh
	mesh.top_radius = value / 2
	mesh.bottom_radius = value / 2


func _set_base_color(value):
	base_color = value
	base.mesh.surface_get_material(0).albedo_color = base_color
	

func _set_texture(value):
	texture_path = value
	body.mesh_depth = 2
	body.mesh_double_sided = true
	
	if value != 'None':
		body.texture = load(value)
		body.update_sprite_mesh()
		var sprite_mesh = body.generated_sprite_mesh
		body.mesh = sprite_mesh.meshes[0]
		body.material_override = sprite_mesh.material
		
	else:
		body.texture = null
		body.mesh = null
		body.material_override = null


func _set_body_tint(value):
	body_tint = value
	body.get_surface_override_material(0).albedo_color = body_tint
