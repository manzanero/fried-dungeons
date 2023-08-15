extends Node

var world_scene = preload("res://scenes/world/world.tscn")
var touch_demo = preload("res://scenes/demo_touch/Demo.tscn")

@onready var canvas := $CanvasLayer as CanvasLayer
@onready var main_menu := $CanvasLayer/MainMenu as Control
@onready var current_scene := $CurrentScene as Node


func _ready():
	%StartMaster.pressed.connect(start_master.bind())
	%StartPlayer.pressed.connect(start_player.bind())
	%TouchButton.pressed.connect(touch_demo_world.bind())
	
	Game.is_high_end = "Windows" == Utils.get_os_name()
	
	# show fps
	var debug_menu = get_node("/root/DebugMenu/DebugMenu")
	debug_menu.style = debug_menu.Style.HIDDEN
#	debug_menu.style = debug_menu.Style.VISIBLE_COMPACT
#	debug_menu.style = debug_menu.Style.VISIBLE_DETAILED
#	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 3000
	
#	var voices = DisplayServer.tts_get_voices_for_language("es")
#	var voice_id = voices[0]
#	DisplayServer.tts_speak("¿Ustedes piensan antes de hablar o hablan tras pensar?", voice_id)
#	DisplayServer.tts_stop()


func start_world():
	var email = "guest@magno.default"
	var password = "password"
	await request_authentication(email, password)
	await connect_to_server()
	
	if not await join_match():
		print("not joined")
		return
		
	print("joined")
	main_menu.visible = false
	var world : World = world_scene.instantiate()
	current_scene.add_child(world)
	Game.world = world
	
	print("Loaded world")


func start_master():
	Game.is_host = true
	Game.campaign.read("CAM000")
	Game.player_id = "MAS000"
	
	start_world()


func start_player():
	Game.is_host = false
	Game.player_id = "PLA001"
	start_world()


func touch_demo_world():
	main_menu.visible = false
	current_scene.add_child(touch_demo.instantiate())


func request_authentication(email, password):
	print("authenticating user %s" % email)
	var result: int = await Server.authenticate_async(email, password)
	if result == OK:
		print("authenticated user %s" % email)
	else:
		print("Cannot authenticate user %s" % email)


func connect_to_server():
	print("connecting to server")
	var result: int = await Server.connect_to_server_async()
	if result == OK:
		print("connected user to server")
	elif result == ERR_CANT_CONNECT:
		print("Cannot connect user to server")


func join_match():
	print("joining to server")
	return await Server.join_match_async(Game.is_host, Game.match_name)
	print("joined to server")
	
	
func _input(event):
	if event is InputEventKey:
		if event.is_pressed():
			if event.keycode == KEY_F4:
				if DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED:
					DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
				else:
					DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
					
			if event.keycode == KEY_F5:
				get_tree().reload_current_scene()
