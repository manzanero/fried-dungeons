extends CharacterBody2D


@export var max_health := 1.0 : set = set_max_health
@export var health := max_health : set = set_health
@export var acceleration := 300.0
@export var max_speed := 50.0
@export var friction := 200.0


enum {
	IDLE,
	WANDER,
	CHASE,
}

var state := IDLE
var knockback := Vector2.ZERO
var wander_range := 32.0
var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var target_player: Player = null


@onready var wander_timer := $WanderTimer as Timer
@onready var soft_collision := $SoftCollision as Area2D
@onready var player_detector := $PlayerDetector as Area2D
@onready var hitbox := $Hitbox as Area2D
@onready var hurtbox := $Hurtbox as Area2D


func _ready():
	start_position = global_position
	wander_timer.timeout.connect(update_target_position)
	player_detector.body_entered.connect(func(body): target_player = body)
	player_detector.body_exited.connect(func(body): target_player = null)


func _physics_process(delta):
	match state:
		IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			seek_player()

			if wander_timer.time_left == 0:
				update_wander()

		WANDER:
			seek_player()

			if wander_timer.time_left == 0:
				update_wander()

			accelerate_towards_point(target_position, delta)

			if target_player and global_position.distance_to(target_player.position) <= 2 * max_speed * delta:
				update_wander()

		CHASE:
			if target_player:
				accelerate_towards_point(target_player.position, delta)
			else:
				change_state(IDLE)

	knockback = knockback.move_toward(Vector2.ZERO, friction * delta)
	velocity += knockback
	
	if is_colliding():
		velocity += get_push_vector() * delta * 400

	move_and_slide()
	

func change_state(new_state):
	print("%s: change state from %s to %s" % [name, state, new_state])
	state = new_state


func accelerate_towards_point(point, delta):
	var direction = global_position.direction_to(point)
	velocity = velocity.move_toward(direction * max_speed, acceleration * delta)
	
	
func seek_player():
	if target_player:
		change_state(CHASE)


func update_wander():
	change_state(shuffle([IDLE, WANDER]))
	wander_timer.start(randf_range(1, 3))
	

func shuffle(list):
	list.shuffle()
	return list.pop_front()


func update_target_position():
	var target_vector = Vector2(randf_range(-wander_range, wander_range), randf_range(-wander_range, wander_range))
	target_position = start_position + target_vector


func is_colliding():
	return soft_collision.has_overlapping_areas()


func get_push_vector():
	var areas = soft_collision.get_overlapping_areas()
	var push_vector = Vector2.ZERO

	if is_colliding():
		var area = areas[0]
		push_vector = area.global_position.direction_to(global_position).normalized()

	return push_vector


func set_max_health(value):
	max_health = value
	self.health = min(health, max_health)


func set_health(value):
	health = value
	if health <= 0:
		queue_free()
