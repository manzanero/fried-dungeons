extends Node

signal empty_queue
signal map_saved

var map_scene = preload("res://assets/map/map.tscn")
var light_scene = preload("res://assets/light/light.tscn")
var entity_scene = preload("res://assets/entity/entity.tscn")


var queue : Array[Command] = [] 


enum OpCode {
	MESSAGE,
	SET_CAMPAIGN,
	SEND_CAMPAIGN,
	SET_MAP,
	SEND_MAP,
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
		OpCode.MESSAGE: _command_message(command.kwargs)
		OpCode.SEND_CAMPAIGN: _command_send_campaign(command.kwargs)
		OpCode.SET_CAMPAIGN: _command_set_campaign(command.kwargs)
		OpCode.SEND_MAP: _command_send_map(command.kwargs)
		OpCode.SET_MAP: _command_set_map(command.kwargs)
		OpCode.SAVE_MAP: _command_save_map(command.kwargs)
		OpCode.NEW_ENTITY: _command_new_entity(command.kwargs)
		OpCode.CHANGE_ENTITY: _command_change_entity(command.kwargs)
		OpCode.DELETE_ENTITY: _command_delete_entity(command.kwargs)
		OpCode.SET_ENTITY_POSITION: _command_set_entity_position(command.kwargs)
		OpCode.SET_ENTITY_TARGET_POSITION: _command_set_entity_target_position(command.kwargs)
		OpCode.SET_CELLS: _command_set_cells(command.kwargs)
		OpCode.NEW_LIGHT: _command_new_light(command.kwargs)
		OpCode.CHANGE_LIGHT: _command_change_light(command.kwargs)
		OpCode.DELETE_LIGHT: _command_delete_light(command.kwargs)
		OpCode.SET_LIGHT_POSITION: _command_set_light_position(command.kwargs)


func _command_message(kwargs : Dictionary):
	print(kwargs.get("message"))


func _command_send_campaign(kwargs : Dictionary):
	if not Game.is_host:
		return
	
	send(OpCode.SET_CAMPAIGN, {
		"campaign": Game.campaign.serialize(),
		"player_ids": [kwargs["player_id"]],
	})


func _command_set_campaign(kwargs : Dictionary):
	Game.campaign.deserialize(kwargs["campaign"])
	
	send(OpCode.SEND_MAP, {
		"player_id": Game.player_id,
	})
	
	Game.world.player_name_tab.set_tab_title(0, Game.player.username)


func _command_send_map(kwargs : Dictionary):
	if not Game.is_host:
		return
		
	await Server.async_save_object("map-" + Game.world.map.id, Game.world.map.serialize())

	send(OpCode.SET_MAP, {
		"id": Game.world.map.id,
		"player_ids": [kwargs["player_id"]],
	})


func _command_set_map(kwargs : Dictionary):
	if Game.world.map:
		Game.world.maps_parent.remove_child(Game.world.map)
		Game.world.map.queue_free()
		
	Game.world.map = map_scene.instantiate() as Map
	Game.world.maps_parent.add_child(Game.world.map)
	
	Game.world.map.load_map(kwargs)


func _command_save_map(_kwargs := {}):
	await Server.async_save_object("map-" + Game.world.map.id, Game.world.map.serialize())
	map_saved.emit()


func _command_new_entity(kwargs : Dictionary):
	var entity := entity_scene.instantiate() as Entity
	entity.name = kwargs["id"]
	Game.world.map.entities_parent.add_child(entity)
	_command_set_entity_position(kwargs)
	_command_change_entity(kwargs)
	
	Game.world.populate_tokens_tree()


func _command_change_entity(kwargs : Dictionary):
	var entity : Entity = Game.world.map.entities_parent.get_node(kwargs["id"])
	entity.change(kwargs)
	
	if entity == Game.world.map.entity_eyes:
		Game.world.map.update_fov()
	
	Game.world.populate_tokens_tree()


func _command_delete_entity(kwargs):
	var entity : Entity = Game.world.map.entities_parent.get_node(kwargs["id"])
	if entity:
		entity.get_parent().remove_child(entity)
		entity.queue_free()
	
	Game.world.populate_tokens_tree()


func _command_set_entity_position(kwargs):
	var entity : Entity = Game.world.map.entities_parent.get_node(kwargs["id"])
	entity.position = Utils.array_to_v3(kwargs["position"])
	
	if entity == Game.world.map.entity_eyes:
		Game.world.map.update_fov()


func _command_set_entity_target_position(kwargs):
	var entity : Entity = Game.world.map.entities_parent.get_node(kwargs["id"])
	entity.target_position = Utils.array_to_v3(kwargs["target_position"])
	
	
func _command_set_cells(kwargs):
	var serialized_cells = kwargs["cells"]
	for serialized_cell in serialized_cells:
		var cell_position = Vector3i(
			serialized_cell["x"], 
			serialized_cell["y"], 
			serialized_cell["z"])
		var cell = Game.world.map.deserialize_cell(serialized_cell)
		Game.world.map.set_cell(cell_position, cell)
		
	Game.world.map.refresh_lights()
	Game.world.map.update_fov()
	
	
func _command_new_light(kwargs):
	var light := light_scene.instantiate() as Light
	light.id = kwargs["id"]
	Game.world.map.lights_parent.add_child(light)
	_command_set_light_position(kwargs)
	_command_change_light(kwargs)
	
	Game.world.map.update_fov()


func _command_change_light(kwargs):
	var light : Light = Game.world.map.lights_parent.get_node(kwargs["id"])
	light.change(kwargs)
	
	Game.world.map.update_fov()


func _command_delete_light(kwargs):
	var light : Light = Game.world.map.lights_parent.get_node(kwargs["id"])
	if light:
		light.get_parent().remove_child(light)
		light.queue_free()
	
	Game.world.map.update_fov()
	
	
func _command_set_light_position(kwargs):
	var light : Light = Game.world.map.lights_parent.get_node(kwargs["id"])
	light.position = Utils.v3_to_v3i(Utils.array_to_v3(kwargs["position"]))
	
	Game.world.map.update_fov()


###########
# objects #
###########

class Command:
	var op_code : OpCode
	var kwargs : Dictionary
	
	func _init(p_op_code, p_kwargs):
		op_code = p_op_code
		kwargs = p_kwargs


func enqueue(op_code : OpCode, kwargs : Dictionary = {}):
	var player_ids = kwargs.get('player_ids', [])
	if player_ids and Game.player_id not in player_ids:
		return
		
	queue.append(Command.new(op_code, kwargs))
	print("Player %s <-- queued command: %s" % [Game.player_id, OpCode.keys()[op_code]])


func send(op_code : OpCode, kwargs : Dictionary, player_ids : Array[String] = []):
	if player_ids:
		kwargs["player_ids"] = player_ids
		
	Server.async_send_room_message(op_code, kwargs)
	print("Player %s --> sended command: %s" % [Game.player_id, OpCode.keys()[op_code]])
