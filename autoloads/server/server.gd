extends Node


signal message(user_id, op_code, kwargs)
signal joined(user_id)
signal leaved(user_id)
signal disconnected()

const KEY := "defaultkey"
const HOST := "nakama.alejmans.dev"
const PORT := 7350
const SCHEMA := "https"
const TIMEOUT = 60
const LOG_LEVEL = NakamaLogger.LOG_LEVEL.WARNING  # DEBUG | WARNING

var cache_email : String
var cache_password : String
var pending_authentication : bool = true
var session : NakamaSession
var socket : NakamaSocket
var room : NakamaRTAPI.Match


@onready var client : NakamaClient = Nakama.create_client(KEY, HOST, PORT, SCHEMA, TIMEOUT, LOG_LEVEL)


func async_authenticate(email, password, vars=null) -> Error:
	print("Authenticating")
	cache_email = email
	cache_password = password
	session = await client.authenticate_email_async(email, password, null, false, vars) as NakamaSession
	if session.is_exception():
		printerr("Nakama error on client.authenticate_email_async: %s" % [session.exception])
		return session.exception.status_code as Error

	pending_authentication = false
	return OK


func async_connect_to_server() -> Error:
	print("Creating Socket")
	socket = Nakama.create_socket_from(client)
	
	socket.received_error.connect(_on_socket_error)
	socket.received_match_state.connect(_on_room_message)
	socket.received_match_presence.connect(_on_match_presence)
	socket.closed.connect(_on_socket_closed)

	var result := await socket.connect_async(session) as NakamaAsyncResult
	if result.is_exception():
		printerr("Nakama error on socket.connect_async: %s" % [result.exception])
		return ERR_CANT_CONNECT
	
	return OK


func _on_socket_error(err):
	pending_authentication = true
	disconnected.emit()
	printerr("Nakama socket error: %s" % err)


func _on_socket_closed():
	pending_authentication = true
	disconnected.emit()
	printerr("Nakama socket closed")


func async_update_authentication() -> Error:
	if not pending_authentication and (session.expired or session.would_expire_in(3)):
		print("Updating authentication")
		pending_authentication = true
		session = await client.session_refresh_async(session)
		if session.is_exception():
			return await async_authenticate(cache_email, cache_password)
		
	return OK
	

func async_get_or_create_match(match_name):
	print("Joining the match: %s" % [match_name])
	room = await socket.create_match_async(match_name) as NakamaRTAPI.Match
	if room.is_exception():
		var exception: NakamaException = room.get_exception()
		printerr("Error joining the match: %s - %s" % [exception.status_code, exception.message])
		return ERR_CANT_CONNECT
		
	return OK
	

func _on_match_presence(match_presence_event : NakamaRTAPI.MatchPresenceEvent):
	for presence in match_presence_event.joins:
		if presence.user_id != session.user_id:
			print("Presence %s joins" % [presence.username])
			joined.emit(presence.user_id)
			
	for presence in match_presence_event.leaves:
		if presence.user_id != session.user_id:
			print("Presence %s leaves" % [presence.username])
			leaved.emit(presence.user_id)


func _on_room_message(match_state : NakamaRTAPI.MatchData):
	var kwargs = JSON.parse_string(match_state.data)
	message.emit(match_state.presence.user_id, match_state.op_code, kwargs)


func async_send_room_message(op_code : Commands.OpCode, kwargs : Dictionary, player_ids = null):
	var result := await Server.socket.send_match_state_async(
			room.match_id, op_code, JSON.stringify(kwargs), player_ids) as NakamaAsyncResult
	if not result or result.is_exception():
		printerr("Nakama error on socket.send_match_state_async: %s" % [result.exception])
		return ERR_CANT_CONNECT

	return OK


func async_save_object(collection : String, key : String, data) -> Error:
	var acks : NakamaAPI.ApiStorageObjectAcks = await client.write_storage_objects_async(session, [
		NakamaWriteStorageObject.new(collection, key, 2, 1, Utils.dumps_json(data), "")
	])
	
	if acks.exception:
		printerr(acks.exception)
		return ERR_CONNECTION_ERROR
	
	return OK


func async_load_object(collection : String, key : String, from_master : bool = false):
	var values := await async_load_objects(collection, [key], from_master)
	if not values:
		printerr("Object %s does not exist" % key)
		return
		
	return values[0]


func async_load_objects(collection : String, keys : Array[String], from_master : bool = false) -> Array:
	var user_id = Game.master_id if from_master else session.user_id
	
	var ids := []
	for key in keys:
		ids.append(NakamaStorageObjectId.new(collection, key, user_id, ""))
		
	var result := await client.read_storage_objects_async(session, ids) as NakamaAPI.ApiStorageObjects
	var values := []
	for object in result.objects:
		values.append(Utils.loads_json(object.value))
		
	return values
