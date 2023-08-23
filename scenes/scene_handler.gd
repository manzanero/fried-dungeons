extends Node

var world_scene = preload("res://scenes/world/world.tscn")
var touch_demo = preload("res://scenes/demo_touch/Demo.tscn")

@onready var canvas := $CanvasLayer as CanvasLayer
@onready var main_menu := $CanvasLayer/MainMenu as Control
@onready var current_scene := $CurrentScene as Node


func _ready():
	%StartMaster.pressed.connect(start_player.bind(true, "master@fried-dungeons.magno", "password"))
	%StartPlayer1.pressed.connect(start_player.bind(false, "player1@fried-dungeons.magno", "password"))
	%StartPlayer2.pressed.connect(start_player.bind(false, "player2@fried-dungeons.magno", "password"))
	%StartPlayer3.pressed.connect(start_player.bind(false, "player3@fried-dungeons.magno", "password"))
	%TouchButton.pressed.connect(touch_demo_world.bind())
	
	Game.is_high_end = "Windows" == Utils.get_os_name()
	Server.message.connect(Commands.enqueue)
	Server.disconnected.connect(leave_world)
	
	# show fps
	var debug_menu = get_node("/root/DebugMenu/DebugMenu")
	debug_menu.style = debug_menu.Style.HIDDEN
#	debug_menu.style = debug_menu.Style.VISIBLE_COMPACT
#	debug_menu.style = debug_menu.Style.VISIBLE_DETAILED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
#	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 3000
	
#	var voices = DisplayServer.tts_get_voices_for_language("es")
#	var voice_id = voices[0]
#	DisplayServer.tts_speak("¿Ustedes piensan antes de hablar o hablan tras pensar?", voice_id)
#	DisplayServer.tts_stop()


func start_player(is_mastrer, email, password): 
	Game.is_host = is_mastrer
	if await Server.async_authenticate(email, password): 
		return
	if await Server.async_connect_to_server(): 
		return
	if await Server.async_get_or_create_match(Game.match_name): 
		return
	
	Game.campaign_id = "CAM000"
	Game.campaign = Game.Campaign.new()
	if await Game.campaign.async_load():
		return
	
	Game.player = Game.campaign.players[Game.player_id]
	Game.master_permission = Game.player.master_permission
	Game.entity_permissions = Game.player.entity_permissions
			
	var world : World = world_scene.instantiate()
	Game.world = world
	current_scene.add_child(world)
	
	main_menu.visible = false
	

func leave_world():
	if Game.world:
		Game.world.queue_free()
		current_scene.remove_child(Game.world)
	
	main_menu.visible = true


func touch_demo_world():
	current_scene.add_child(touch_demo.instantiate())
	
	main_menu.visible = false


#########
# input #
#########

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
