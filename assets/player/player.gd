class_name Player
extends CharacterBody2D


const SPEED = 150


enum {
	MOVE,
	ROLL,
	ATTACK,
}

var state = MOVE


@onready var pivot = $Pivot as Marker2D
@onready var left_joystick = $CanvasLayer/Left/Joystick
@onready var right_joystick = $CanvasLayer/Right/Joystick


func _physics_process(delta):
	match state:
		MOVE:
			_move_process(delta)
			

func _move_process(delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if left_joystick.held:
		direction = left_joystick.direction * left_joystick.strength
	
	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

#	var world_position = get_global_mouse_position()
#	if right_joystick.held:
#		world_position = position + right_joystick.direction
		
	var world_position = position + right_joystick.direction
	
	pivot.look_at(world_position)

	move_and_slide()


#func _input(event):
#	# Mouse in viewport coordinates.
#	if event is InputEventMouseButton:
#		print("Mouse Click/Unclick at: ", event.position)
#	elif event is InputEventMouseMotion:
#		print("Mouse Motion at: ", event.position)
