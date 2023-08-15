extends Node

var world : World
var camera : Camera
var is_high_end : bool = true
var is_pc : bool = true

var is_host : bool = true
var match_name : String = "frierd_dungeons__" + OS.get_environment("USERNAME")

var campaign : Campaign = Campaign.new()
var player_id : String
var player : Player :
	get:
		return campaign.players[player_id]


###########
# Objects #
###########

class Campaign:
	var id : String
	var label : String
	var players := {}
	var maps : Array[String] = []


	func read(p_id : String):
		var data = Utils.read_json("user://campaigns/%s.json" % p_id)
		id = p_id
		deserialize(data)
	

	func deserialize(data):
		label = data['label']
		for player_id in data['players']:
			players[player_id] = Player.new().deserialize(data['players'][player_id])
		for map in data['maps']:
			maps.append(map)
	
	
	func serialize():
		var serialized_players = {}
		for player in players:
			serialized_players[player] = players[player].serialize()
		
		return {
			"label": label,
			"players": serialized_players,
			"maps": maps,
		}
	
	
	func save():
		Utils.write_json("user://campaings/%s.json" % id, serialize())
		

class Player:
	var username : String
	var entity_permissions : Dictionary
	var map : String
	var is_master: bool
	
	
	func has_entity_permissions(entity_id : String, permission_codes : Array[int]) -> bool:
		var permissions = entity_permissions.get(entity_id)
		if not permissions:
			return false
		for code in permission_codes:
			if code not in permissions:
				return false
		return true


	func deserialize(serialized_player) -> Player:
		username = serialized_player['username']
		entity_permissions = serialized_player.get('entity_permissions', {})
		map = serialized_player.get('map', 'None')
		is_master = serialized_player.get('is_master', false)
		return self
		
		
	func serialize():
		return {
			"username": username,
			"entity_permissions": entity_permissions,
			"map": map,
			"is_master": is_master,
		}


enum EntityPermission {
	GET_POSITION,
	GET_LABEL,
	GET_HEALTH,
	GET_VISION,
	SET_POSITION,
}
