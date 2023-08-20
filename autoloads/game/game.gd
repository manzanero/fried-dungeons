extends Node

var world : World
var camera : Camera
var is_high_end : bool = true
var is_pc : bool = true

var is_host : bool = true
var match_name : String = "frierd_dungeons__" + OS.get_environment("USERNAME")

var campaign_id : String
var player_id : String
var master_id : String
var campaign : Campaign
var player : Player
var master_permission : bool
var entity_permissions := {}


###########
# Objects #
###########

class Campaign:
	var id : String
	var label : String
	var players := {}
	var maps : Array[String] = []
	
	
	func _init(p_id):
		id = p_id


	func async_load():
		var data = await Server.async_load_object("campaign-" + id)
		return deserialize(data)
	
	
	func async_save():
		var serialized_data = serialize()
		await Server.async_save_object("campaign-" + id, serialized_data)
	

	func deserialize(data):
		label = data['label']
		for player_id in data['players']:
			players[player_id] = Player.new(player_id).deserialize(data['players'][player_id])
		for map in data['maps']:
			maps.append(map)
		return self
	
	
	func serialize():
		var serialized_players := {}
		for player in players:
			serialized_players[player] = players[player].serialize()
		return {
			"label": label,
			"players": serialized_players,
			"maps": maps,
		}
		

class Player:
	var id : String
	var username : String
	var master_permission: bool
	var entity_permissions : Dictionary
	var map : String
	
	
	func _init(p_id):
		id = p_id


	func deserialize(data) -> Player:
		username = data['username']
		master_permission = data.get('master_permission', false)
		entity_permissions = data.get('entity_permissions', {})
		map = data.get('map', 'None')
		return self
		
		
	func serialize():
		return {
			"username": username,
			"master_permission": master_permission,
			"entity_permissions": entity_permissions,
			"map": map,
		}


func has_entity_permissions(entity_id : String, permission_codes : Array[int]) -> bool:
	if master_permission:
		return true
	
	var permissions = entity_permissions.get(entity_id)
	if not permissions:
		return false
	
	for code in permission_codes:
		if float(code) not in permissions:
			return false
			
	return true


enum EntityPermission {
	GET_POSITION,
	GET_LABEL,
	GET_HEALTH,
	GET_VISION,
	SET_POSITION,
}
