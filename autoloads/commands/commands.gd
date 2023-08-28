extends Node

signal executed_command(command)
signal empty_queue()
signal map_saved()

var map_scene = preload("res://assets/map/map.tscn")
var light_scene = preload("res://assets/light/light.tscn")
var entity_scene = preload("res://assets/entity/entity.tscn")


var queue : Array[Command] = [] 


enum OpCode {
	MESSAGE,
	SEND_MAP,
	SET_MAP,
	SAVE_MAP,
	NEW_ENTITY,
	CHANGE_ENTITY,
	DELETE_ENTITY,
	SET_ENTITY_POSITION,
	SET_ENTITY_TARGET_POSITION,
	SET_CELLS,
	NEW_LIGHT,
	CHANGE_LIGHT,
	DELETE_LIGHT,
	SET_LIGHT_POSITION,
}


func execute(command : Command):
	match command.op_code:
		OpCode.MESSAGE: _command_message(command)
		OpCode.SEND_MAP: _command_send_map(command)
		OpCode.SET_MAP: _command_set_map(command)
		OpCode.SAVE_MAP: _command_save_map(command)
		OpCode.NEW_ENTITY: _command_new_entity(command)
		OpCode.CHANGE_ENTITY: _command_change_entity(command)
		OpCode.DELETE_ENTITY: _command_delete_entity(command)
		OpCode.SET_ENTITY_POSITION: _command_set_entity_position(command)
		OpCode.SET_ENTITY_TARGET_POSITION: _command_set_entity_target_position(command)
		OpCode.SET_CELLS: _command_set_cells(command)
		OpCode.NEW_LIGHT: _command_new_light(command)
		OpCode.CHANGE_LIGHT: _command_change_light(command)
		OpCode.DELETE_LIGHT: _command_delete_light(command)
		OpCode.SET_LIGHT_POSITION: _command_set_light_position(command)
	
	executed_command.emit(command)


func _command_message(command : Command):
	print(command.kwargs.get("message"))


func _command_send_map(command : Command):
	await Server.async_save_object("fried-dungeons-maps", Game.world.map.id, Game.world.map.serialize())

	await async_send(OpCode.SET_MAP, {
		"id": command.kwargs["id"]
	}, [
		command.player_id
	])


func _command_set_map(command : Command):
	if Game.world.map:
		Game.world.maps_parent.remove_child(Game.world.map)
		Game.world.map.queue_free()
		
	Game.world.map = map_scene.instantiate() as Map
	Game.world.maps_parent.add_child(Game.world.map)
	
	Game.world.map.load_map(command.kwargs)


func _command_save_map(_command : Command):
	if not is_instance_valid(Game.world.map):
		printerr("Cannot save map")
		return
	
	if Game.is_host:
		Server.async_save_object("fried-dungeons-maps", Game.world.map.id, Game.world.map.serialize())
	else:
		Server.async_save_object("fried-dungeons-explored", Game.world.map.id, Game.world.map.serialize_explored())
	map_saved.emit()


func _command_new_entity(command : Command):
	var entity := entity_scene.instantiate() as Entity
	entity.name = command.kwargs["id"]
	Game.world.map.entities_parent.add_child(entity)
	_command_set_entity_position(command)
	_command_change_entity(command)
	
	Game.world.populate_tokens_tree()


func _command_change_entity(command : Command):
	var entity : Entity = Game.world.map.entities_parent.get_node(command.kwargs["id"])
	entity.change(command.kwargs)
	
	if entity == Game.world.map.entity_eyes:
		Game.world.map.update_fov()
	
	Game.world.populate_tokens_tree()


func _command_delete_entity(command : Command):
	var entity : Entity = Game.world.map.entities_parent.get_node(command.kwargs["id"])
	if entity:
		entity.get_parent().remove_child(entity)
		entity.queue_free()
	
	Game.world.populate_tokens_tree()


func _command_set_entity_position(command : Command):
	var entity : Entity = Game.world.map.entities_parent.get_node(command.kwargs["id"])
	entity.position = Utils.array_to_v3(command.kwargs["position"])
	
	if entity == Game.world.map.entity_eyes:
		Game.world.map.update_fov()


func _command_set_entity_target_position(command : Command):
	var entity : Entity = Game.world.map.entities_parent.get_node(command.kwargs["id"])
	entity.target_position = Utils.array_to_v3(command.kwargs["target_position"])
	
	
func _command_set_cells(command : Command):
	var serialized_cells = command.kwargs["cells"]
	for serialized_cell in serialized_cells:
		var cell_position = Vector3i(
			serialized_cell["x"], 
			serialized_cell["y"], 
			serialized_cell["z"])
		var cell = Game.world.map.deserialize_cell(serialized_cell)
		Game.world.map.set_cell(cell_position, cell)
		
	Game.world.map.refresh_lights()
	Game.world.map.update_fov()
	
	
func _command_new_light(command : Command):
	var light := light_scene.instantiate() as Light
	light.id = command.kwargs["id"]
	Game.world.map.lights_parent.add_child(light)
	_command_set_light_position(command)
	_command_change_light(command)
	
	Game.world.map.update_fov()


func _command_change_light(command : Command):
	var light : Light = Game.world.map.lights_parent.get_node(command.kwargs["id"])
	light.change(command.kwargs)
	
	Game.world.map.update_fov()


func _command_delete_light(command : Command):
	var light : Light = Game.world.map.lights_parent.get_node(command.kwargs["id"])
	if light:
		light.get_parent().remove_child(light)
		light.queue_free()
	
	Game.world.map.update_fov()
	
	
func _command_set_light_position(command : Command):
	var light : Light = Game.world.map.lights_parent.get_node(command.kwargs["id"])
	light.position = Utils.array_to_v3(command.kwargs["position"])
	
	Game.world.map.update_fov()


###########
# objects #
###########

class Command:
	var player_id : String
	var op_code : OpCode
	var kwargs : Dictionary
	
	func _init(p_player_id : String, p_op_code : OpCode, p_kwargs : Dictionary):
		player_id = p_player_id
		op_code = p_op_code
		kwargs = p_kwargs


func enqueue(player_id : String, op_code : OpCode, kwargs : Dictionary = {}):
	if kwargs.has("recipient_users_ids") and Game.player_id not in kwargs["recipient_users_ids"]:
		return
	
	queue.append(Command.new(player_id, op_code, kwargs))
	print("Queued command: [%s] <-- [%s]: %s" % [Game.player_label, Game.group_users[player_id], OpCode.keys()[op_code]])


func async_send(op_code : OpCode, kwargs : Dictionary, player_ids = null):
	if player_ids is Array:
		kwargs["recipient_users_ids"] = player_ids
		
	await Server.async_send_room_message(op_code, kwargs)
	var player_labels := "All"
	if player_ids:
		player_labels = "[" + Game.group_users[player_ids.pop_front()]
		for player_id in player_ids:
			player_labels += ", " + Game.group_users[player_id]
		player_labels += "]"
	print("Sended command: [%s] --> %s: %s" % [Game.player_label, player_labels, OpCode.keys()[op_code]])
