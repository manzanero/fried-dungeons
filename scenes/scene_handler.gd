extends Node

var world_scene = preload("res://scenes/world/world.tscn")
var touch_demo = preload("res://scenes/demo_touch/Demo.tscn")

@onready var canvas := $CanvasLayer as CanvasLayer
@onready var main_menu := $CanvasLayer/MainMenu as Control
@onready var current_scene := $CurrentScene as Node


func _ready():
	%StartMaster.pressed.connect(start_master.bind())
	%StartPlayer1.pressed.connect(start_player1.bind())
	%StartPlayer2.pressed.connect(start_player2.bind())
	%StartPlayer3.pressed.connect(start_player3.bind())
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
	
	Server.message.connect(Commands.enqueue)
	Server.disconnected.connect(leave_world)
	

func start_master():
	Game.is_host = true
	Game.campaign_id = "CAM000"
	Game.player_id = "MAS000"
	start_world()


func start_player1():
	Game.is_host = false
	Game.campaign_id = "CAM000"
	Game.player_id = "PLA001"
	start_world()


func start_player2():
	Game.is_host = false
	Game.campaign_id = "CAM000"
	Game.player_id = "PLA002"
	start_world()


func start_player3():
	Game.is_host = false
	Game.campaign_id = "CAM000"
	Game.player_id = "PLA003"
	start_world()
	

func start_world():
	var email = "guest@magno.default"
	var password = "password"
	if await Server.async_authenticate(email, password): 
		return
	if await Server.async_connect_to_server(): 
		return
	if await Server.async_get_or_create_match(Game.match_name): 
		return
	
	Game.campaign = await Game.Campaign.new("CAM000").async_load()
	Game.player = Game.campaign.players[Game.player_id]
	Game.master_permission = Game.player.master_permission
	Game.entity_permissions = Game.player.entity_permissions
	for player_id in Game.campaign.players:
		var player : Game.Player = Game.campaign.players[player_id]
		if player.master_permission:
			Game.master_id = player_id
			
	var world : World = world_scene.instantiate()
	current_scene.add_child(world)
	Game.world = world
	
	main_menu.visible = false
	

func leave_world():
	Game.world.queue_free()
	
	main_menu.visible = true


func touch_demo_world():
	current_scene.add_child(touch_demo.instantiate())
	
	main_menu.visible = false
	
	
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
