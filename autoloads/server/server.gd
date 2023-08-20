extends Node


signal message(op_code, kwargs)
signal disconnected()

const KEY := "defaultkey"
const HOST := "nakama.alejmans.dev"
const PORT := 7350
const SCHEMA := "https"
const TIMEOUT = 60
const LOG_LEVEL = NakamaLogger.LOG_LEVEL.WARNING
#const LOG_LEVEL = NakamaLogger.LOG_LEVEL.DEBUG
const GAME := "fried-dungeons"

var cache_email : String
var cache_password : String
var session : NakamaSession
var socket : NakamaSocket
var room : NakamaRTAPI.Match
var multiplayer_bridge
var user_id : String


@onready var client : NakamaClient = Nakama.create_client(KEY, HOST, PORT, SCHEMA, TIMEOUT, LOG_LEVEL)


func async_authenticate(email, password, vars=null) -> Error:
	cache_email = email
	cache_password = password
	session = await client.authenticate_email_async(email, password, null, false, vars) as NakamaSession
	if session.is_exception():
		printerr("Nakama error on client.authenticate_email_async: %s" % [session.exception])
		return session.exception.status_code as Error
	
	user_id = session.user_id
	return OK


func async_connect_to_server() -> Error:
	socket = Nakama.create_socket_from(client)
	
	socket.received_error.connect(func(err): printerr("Nakama socket error: %s" % err))
	socket.received_match_state.connect(_on_room_message)
	socket.closed.connect(_on_socket_closed)

	var result := await socket.connect_async(session) as NakamaAsyncResult
	if result.is_exception():
		printerr("Nakama error on socket.connect_async: %s" % [result.exception])
		return ERR_CANT_CONNECT
	
	return OK


func _on_socket_closed():
	printerr("Nakama socket closed")
	disconnected.emit()


func async_update_authentication() -> Error:
	if session.expired or session.would_expire_in(60):
		session = await client.session_refresh_async(session)
		if session.is_exception():
			return await async_authenticate(cache_email, cache_password)

	return OK
	

func async_get_or_create_match(match_name):
	room = await socket.create_match_async(match_name) as NakamaRTAPI.Match
	if room.is_exception():
		var exception: NakamaException = room.get_exception()
		printerr("Error joining the match: %s - %s" % [exception.status_code, exception.message])
		return ERR_CANT_CONNECT
		
	return OK


func _on_room_message(match_state : NakamaRTAPI.MatchData):
	var kwargs = JSON.parse_string(match_state.data)
	message.emit(match_state.op_code, kwargs)


func async_send_room_message(op_code, kwargs, presences = []):
	var result := await Server.socket.send_match_state_async(room.match_id, op_code, JSON.stringify(kwargs), presences) as NakamaAsyncResult
	if not result or result.is_exception():
		printerr("Nakama error on socket.send_match_state_async: %s" % [result.exception])
		return ERR_CANT_CONNECT
	
	
	return OK


func async_save_object(key : String, data):
	var acks : NakamaAPI.ApiStorageObjectAcks = await client.write_storage_objects_async(session, [
		NakamaWriteStorageObject.new(GAME, key, 1, 1, Utils.dumps_json(data), "")
	])
	if acks.exception:
		printerr(acks.exception)
		
		
func async_load_object(key: String):
	var read_object_id := NakamaStorageObjectId.new(GAME, key, session.user_id, "")
	var result : NakamaAPI.ApiStorageObjects = await client.read_storage_objects_async(session, [read_object_id])
	var objects := result.objects
	if not result.objects:
		printerr("Object %s does not exist" % key)
	return Utils.loads_json(objects[0].value)


func async_load_objects(keys: Array[String]) -> Array:
	var ids := []
	for key in keys:
		ids.append(NakamaStorageObjectId.new(GAME, key, session.user_id, ""))
	var result : NakamaAPI.ApiStorageObjects = await client.read_storage_objects_async(session, ids)
	var values := []
	for object in result.objects:
		values.append(Utils.loads_json(object.value))
	return values
