extends Node

var world : World
var camera : Camera
var is_high_end : bool = true
var is_pc : bool = true

var is_host : bool = true
var match_name : String = "frierd_dungeons__" + OS.get_environment("USERNAME")

var campaign_id : String
var campaign_label : String
var campaign : Campaign
var group_users := {}
var presences := {}

var master_id : String
var player_id : String : 
	get: 
		return Server.session.user_id
var player_label : String : 
	get: 
		return group_users[Server.session.user_id]
var player : Player
var master_permission : bool
var entity_permissions := {}


###########
# Objects #
###########

class Campaign:
	var players := {}
	var maps := {}


	func async_load() -> Error:
		var group_name = "fried-dungeons-" + Game.campaign_id
		var result : NakamaAPI.ApiGroupList = await Server.client.list_groups_async(Server.session, group_name, 20)
		if not result.groups:
			printerr("Cannot find groups")
			return ERR_CONNECTION_ERROR
			
		var group = result.groups[0] as NakamaAPI.ApiGroup
		
		var member_list : NakamaAPI.ApiGroupUserList = await Server.client.list_group_users_async(Server.session, group.id)
		Game.group_users.clear()
		for group_user in member_list.group_users:
			var user = group_user.user as NakamaAPI.ApiUser
			Game.group_users[user.id] = user.username
			if group_user.state == 0:
				Game.master_id = user.id
				
		if Server.session.user_id not in Game.group_users:
			printerr('User "%s" not in group "%s"' % [Server.session.username, group.description])
			return ERR_CONNECTION_ERROR
			
		Game.campaign_label = group.description
		var data = await Server.async_load_object("fried-dungeons-campaigns", Game.campaign_id)
		if not data:
			printerr('User "%s" not in group "%s"' % [Server.session.username, group.description])
			return ERR_CONNECTION_ERROR
		
		deserialize(data)
		
		return OK
	
	
	func async_save():
		var serialized_data = serialize()
		await Server.async_save_object("fried-dungeons-campaigns", Game.campaign_id, serialized_data)
	

	func deserialize(data):
		for player_id in data['players']:
			players[player_id] = Player.new().deserialize(data['players'][player_id])
		maps = data['maps']
		return self
	
	
	func serialize():
		var serialized_players := {}
		for player in players:
			serialized_players[player] = players[player].serialize()
		return {
			"players": serialized_players,
			"maps": maps,
		}
		

class Player:
	var master_permission: bool
	var entity_permissions : Dictionary
	var map : String


	func deserialize(data) -> Player:
		master_permission = data.get('master_permission', false)
		entity_permissions = data.get('entity_permissions', {})
		map = data.get('map', 'None')
		return self
		
		
	func serialize():
		return {
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
