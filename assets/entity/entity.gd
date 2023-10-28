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
var texture : String = "None" : set = _set_texture
var body_tint := Color.WHITE : set = _set_body_tint

const SPEED := 250.0

var tick := 0.1
var preview : bool

var position_changed : bool
var cell_position : Vector3i
var moving_to_target : bool
var direction : Vector3

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
			
var default_permissions : Array[Game.EntityPermission]
var players_permissions : Dictionary

var light : Light


@onready var base := $Base as MeshInstance3D
@onready var body := $Body as SpriteMeshInstance
@onready var eyes := $Eyes as Camera3D
@onready var selector := $Selector as MeshInstance3D
@onready var update_timer := $UpdateTimer as Timer
@onready var info := $Info as CanvasLayer
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
	
	_set_texture('None')
	_set_label(label)
	_set_label_known(label_known)
	_set_health(health)
	_set_health_max(health_max)
	_set_health_known(health_known)
	
	_update()
	

func _process(_delta):
	label_control.position = Game.camera.eyes.unproject_position(position)
	
	var look_direction
	var current_eyes = Game.world.map.entity_eyes
	if Game.camera.eyes.current:
		look_direction = Game.camera.eyes.global_transform.basis.z
		look_direction.y = 0
		body.look_at(body.global_position + look_direction, Vector3(0, 1, 0))
	elif current_eyes != self:
		look_direction = current_eyes.position - position
		look_direction.y = 0
		body.look_at(body.global_position + look_direction, Vector3(0, 1, 0))

	if light:
		light.position = position


func _physics_process(delta):
	if moving_to_target:
		var velocity_to_target = clamp((target_position - position).length() * 10 * delta, 0.05, 10000)
		position = position.move_toward(target_position, velocity_to_target)
		if position == target_position:
			moving_to_target = false
			if self == Game.world.map.entity_eyes:
				Game.world.map.update_fov()
				
	elif Game.world.map.entity_eyes == self or eyes.current:
		_move_process(delta)
	

func _move_process(delta):
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if eyes.current:
		direction = Vector3(input_dir.x, 0, input_dir.y).normalized().rotated(Vector3.UP, eyes.rotation.y)
	else:
		direction = Vector3(input_dir.x, 0, input_dir.y).normalized().rotated(Vector3.UP, Game.camera.rotation.y)
		
	if direction:
		velocity.x = direction.x * SPEED * delta
		velocity.z = direction.z * SPEED * delta
		#body.look_at(body.global_position + direction)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta)
	
	var previous_position = position
	move_and_slide() 
	validate_position(previous_position)
	
	if position != previous_position:
		position_changed = true


func validate_position(fallback_position := Vector3(0, 0, 0)):
	var new_cell_position = Vector3i(position)
	var cell : Map.Cell = Game.world.map.cells.get(new_cell_position)
	
	if not cell:
		position = fallback_position
		return
	
	if cell.is_door and not cell.is_open and not cell.is_locked:
		cell.skin = 'door1'
		cell.is_empty = true
		cell.is_transparent = true
		cell.is_open = true
		Game.world.map.set_cell(new_cell_position, cell)
		Game.world.map.refresh_lights()
		await Commands.async_send(Commands.OpCode.SET_CELLS, {
			"cells": [Game.world.map.serialize_cell(new_cell_position, cell)]
		})

	if cell.is_empty:
		return 

	position = fallback_position


func use_entity_eyes():
	eyes.current = true
	body.visible = false
	cell_changed.emit()
	
	
func exit_entity_eyes():
	body.visible = true
	Game.world.exit_entity_eyes()


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
	
	var new_cell_position = Utils.v3_to_v3i(position)
	if new_cell_position != cell_position:
		cell_position = new_cell_position
#		if not is_instance_valid(light):  # light will update vision
#			cell_changed.emit()

		cell_changed.emit()
	
	# calculate if entity has been moved
	if position_changed and not moving_to_target:
		Commands.async_send(Commands.OpCode.SET_ENTITY_TARGET_POSITION, {
			"id": name,
			"target_position": Utils.v3_to_array(position), 
		})
		position_changed = false


func change(kwargs):
	if "label" in kwargs: 
		label = kwargs["label"]
	if "label_known" in kwargs: 
		label_known = kwargs["label_known"]
	if "texture" in kwargs: 
		texture = kwargs["texture"]
	if "base_color" in kwargs: 
		base_color = kwargs["base_color"]
	if "base_size" in kwargs: 
		base_size = kwargs["base_size"]
	if "health" in kwargs: 
		health = kwargs["health"]
	if "health_max" in kwargs: 
		health_max = kwargs["health_max"]
	if "health_known" in kwargs: 
		health_known = kwargs["health_known"]

	changed.emit()
	
	_update()


###################
# getters/setters #
###################

func _set_label(value):
	label = value
	label_label.text = value


func _set_label_known(value):
	label_known = value
	if not Game.has_entity_permissions(id, [Game.EntityPermission.GET_LABEL]):
		label_label.visible = false
		return

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
	if not Game.has_entity_permissions(id, [Game.EntityPermission.GET_HEALTH]):
		healt_bar.visible = false
		return
		
	healt_bar.visible = value


func _set_base_size(value):
	base_size = value
	var mesh : CylinderMesh = base.mesh
	mesh.top_radius = value / 2
	mesh.bottom_radius = value / 2


func _set_base_color(value):
	base_color = value
	base.mesh.surface_get_material(0).albedo_color = base_color
	
	light_fixture = Color.TRANSPARENT
	

func _set_texture(value):
	texture = value
	body.mesh_depth = 2
	body.mesh_double_sided = true
	
	if value != 'None':
		body.texture = load("res://resources/entity_textures/%s.png" % [value])
		var height = body.texture.get_height()
		body.update_sprite_mesh()
		var sprite_mesh = body.generated_sprite_mesh
		body.mesh = sprite_mesh.meshes[0]
		body.material_override = sprite_mesh.material
		body.position.y = height * 0.025 + 0.1
		
		if is_instance_valid(light):
			light.pivot.position.y = height * 0.05 + 0.3
		
	else:
		body.texture = null
		body.mesh = null
		body.material_override = null


func _set_body_tint(value):
	body_tint = value
	body.get_surface_override_material(0).albedo_color = body_tint


#########
# input #
#########

var look_sen = 2

func _unhandled_input(event: InputEvent) -> void:
	if eyes.current:
	
		if event is InputEventMouseMotion:
			var look_dir = event.relative * 0.001
			eyes.rotation.y -= look_dir.x * look_sen
			eyes.rotation.x = clamp(eyes.rotation.x - look_dir.y * look_sen, deg_to_rad(-89), deg_to_rad(89))
			
		if Input.is_action_just_pressed("ui_cancel"): 
			exit_entity_eyes()
			

###############
# Serializers #
###############

func serialize():
	var serialized_entity = {}
	serialized_entity["id"] = id
	var entity_position = target_position if moving_to_target else position
	serialized_entity["position"] = Utils.v3_to_array(entity_position)
	serialized_entity["label"] = label
	serialized_entity["label_known"] = health_known
	serialized_entity["health"] = health
	serialized_entity["health_max"] = health_max
	serialized_entity["health_known"] = health_known
	serialized_entity["base_size"] = base_size
	serialized_entity["base_color"] = Utils.color_to_string(base_color)
	serialized_entity["texture"] = texture
	return serialized_entity
	
