extends Control


var light : Light


@onready var accept_button := %AcceptButton as Button
@onready var cancel_button := %CancelButton as Button
@onready var apply_button := %ApplyButton as Button
@onready var delete_button := %DeleteButton as Button

@onready var id_edit := %IdEdit as LineEdit
@onready var intensity_edit := %IntensityEdit as SpinBox
@onready var bright_edit := %BrightEdit as SpinBox
@onready var faint_edit := %FaintEdit as SpinBox
@onready var following_edit := %FollowingEdit as LineEdit


func use_light(p_light):
	light = p_light


func _ready():
	accept_button.pressed.connect(_on_accept_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	apply_button.pressed.connect(_on_apply_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	
	$Panel/TabBar.gui_input.connect(_on_input)
	
	if light:
		id_edit.text = str(light.name)
		intensity_edit.value = light.intensity
		bright_edit.value = light.bright
		faint_edit.value = light.faint
		following_edit.text = light.parent
	else:
		id_edit.text = UUID.short()


func _on_accept_button_pressed():
	_on_apply_button_pressed()
	queue_free()
		

func _on_delete_button_pressed():
	queue_free()
	light.get_parent().remove_child(light)
	light.queue_free()
	Server.send_message(Game.world.OpCode.DELETE_LIGHT, {
		"id": str(light.name)
	})
	
	light.forget()
	Game.world.map.update_fov()
	

func _on_cancel_button_pressed():
	queue_free()


func _on_apply_button_pressed():
	var is_new_light = false
	if not light:
		is_new_light = true
		light = Game.world.light_scene.instantiate()
		Game.world.map.lights_parent.add_child(light)
		light.position = Game.world.pointer.position + Vector3(0.5, Light.DEFAULT_HEIGHT, 0.5)

	light.intensity = intensity_edit.value
	light.bright = bright_edit.value
	light.faint = faint_edit.value
	light.parent = following_edit.text
	light.name = id_edit.text
	
	if is_new_light:
		Server.send_message(Game.world.OpCode.NEW_LIGHT, {
			"position": Utils.v3_to_array(light.position),
			"id": str(light.name),
			"intensity": light.intensity,
			"bright": light.bright,
			"faint": light.faint,
			"parent": light.parent,
		})
	else:
		Server.send_message(Game.world.OpCode.CHANGE_LIGHT, {
			"id": str(light.name),
			"intensity": light.intensity,
			"bright": light.bright,
			"faint": light.faint,
			"parent": light.parent,
		})

	light.update_fov()
	Game.world.map.update_fov()
	

func _on_input(event):
	if event is InputEventMouseMotion and Input.is_action_pressed("left_click"):
		$Panel.position += event.relative
