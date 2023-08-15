extends Node


signal message(op_code, kwargs)


const KEY := "defaultkey"
const HOST := "nakama.alejmans.dev"
const PORT := 7350
const SCHEMA := "https"
const GAME := "fried-dungeons"

var client : NakamaClient
var session : NakamaSession
var socket : NakamaSocket
var multiplayer_bridge
var match_id

var user_id := "local" :
	get:
		return session.user_id if session else user_id


func _ready():
	client = get_node("/root/Nakama").create_client(KEY, HOST, PORT, SCHEMA)


func authenticate_async(email, password) -> Error:
	var result := OK
	
	var new_session = await client.authenticate_email_async(email, password) as NakamaSession
	
	if not new_session.is_exception():
		session = new_session
	else:
		result = new_session.get_exception().status_code as Error

	return result


func connect_to_server_async() -> Error:
	socket = get_node("/root/Nakama").create_socket_from(client)
	socket.connected.connect(_on_socket_connected)
	socket.closed.connect(_on_socket_closed)
	socket.received_error.connect(_on_socket_error)
	socket.received_match_state.connect(_on_match_state)
	
	var result := await socket.connect_async(session) as NakamaAsyncResult
	if not result.is_exception():
		return OK
	
	return ERR_CANT_CONNECT


func _on_socket_connected():
	print("Socket connected.")


func _on_socket_closed():
	socket = null


func _on_socket_error(err):
	printerr("Socket error %s" % err)
	

func join_match_async(is_host, match_name=null):
	multiplayer_bridge = NakamaMultiplayerBridge.new(socket)
	multiplayer_bridge.match_join_error.connect(_on_match_join_error)
	multiplayer_bridge.match_joined.connect(_on_match_join)
	
	if is_host:
		var result := await socket.create_match_async(match_name) as NakamaRTAPI.Match
		if result.is_exception():
			var exception: NakamaException = result.get_exception()
			printerr("Errror joining the match: %s - %s" % [exception.status_code, exception.message])
			
		match_id = result.match_id
		
	else:
		await multiplayer_bridge.join_named_match(match_name)
		match_id = multiplayer_bridge.match_id
	
		if multiplayer_bridge._users.size() == 1:
			socket.leave_match_async(match_id)
			return false
			
	if multiplayer_bridge._users.size() == 3:
		socket.leave_match_async(match_id)
		return false
	
	return true
	

func _on_match_join_error(error):
	print ("Unable to join match: ", error.message)


func _on_match_join() -> void:
	print ("Joined match with id: ", multiplayer_bridge.match_id)


func _on_network_peer_connected(peer_id):
	print ("Peer joined match: ", peer_id)


func _on_network_peer_disconnected(peer_id):
	print ("Peer left match: ", peer_id)


func _on_match_state(match_state : NakamaRTAPI.MatchData):
	var kwargs = JSON.parse_string(match_state.data)
	message.emit(match_state.op_code, kwargs)


func save_object(key : String, data):
	var acks : NakamaAPI.ApiStorageObjectAcks = await client.write_storage_objects_async(session, [
		NakamaWriteStorageObject.new(GAME, key, 1, 1, Utils.dumps_json(data), "")
	])
	if acks.exception:
		printerr(acks.exception)
		
		
func load_object(key: String):
	var read_object_id := NakamaStorageObjectId.new(GAME, key, session.user_id, "")
	var result : NakamaAPI.ApiStorageObjects = await client.read_storage_objects_async(session, [read_object_id])
	var objects := await result.objects
	return Utils.loads_json(objects[0].value)


func load_objects(keys: Array[String]) -> Array:
	var ids := []
	for key in keys:
		ids.append(NakamaStorageObjectId.new(GAME, key, session.user_id, ""))
	var result : NakamaAPI.ApiStorageObjects = await client.read_storage_objects_async(session, ids)
	var objects := await result.objects
	var values := []
	for object in objects:
		values.append(Utils.loads_json(object.value))
	return values
