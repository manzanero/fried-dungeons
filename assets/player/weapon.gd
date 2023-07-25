class_name Weapon
extends Area2D


var damage := 10.0


func _ready():
	body_entered.connect(_on_body_entered)


func _process(delta):
	pass


func _on_body_entered(body):
	body.health -= damage
	body.knockback = (body.position - position) * 120
