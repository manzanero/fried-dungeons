class_name EntityPermissionsMenu
extends Control


var permission_icons := preload("res://resources/icons/permission_icons.png")


var entity : Entity


@onready var accept_button := %AcceptButton as Button
@onready var cancel_button := %CancelButton as Button
@onready var apply_button := %ApplyButton as Button

@onready var player_permissions_tree := %PlayerPermissionsTree as Tree


func use_entity(p_entity):
	entity = p_entity
	

func _ready():
	accept_button.pressed.connect(_on_accept_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	apply_button.pressed.connect(_on_apply_button_pressed)
	
	%TabBar.gui_input.connect(_on_input)

	populate_permissions_tree()

	
func populate_permissions_tree():
	player_permissions_tree.clear()
	var root : TreeItem = player_permissions_tree.create_item()
	player_permissions_tree.hide_root = true
	player_permissions_tree.columns = 4
	player_permissions_tree.set_column_clip_content(1, false)
	var get_position_icon := AtlasTexture.new()
	get_position_icon.set_atlas(permission_icons)
	get_position_icon.set_region(Rect2(0, 0, 16, 16))
	
	var players = Game.campaign.players
	for player_id in players:
		var player_item : TreeItem = player_permissions_tree.create_item(root)

		var player : Game.Player = players[player_id]
		player_item.set_text(0, player.label)
		player_item.set_tooltip_text(0, " ")
		player_item.collapsed = false
		player_item.set_selectable(0, false)
		player_item.set_expand_right(0, true)
		
		player_item.set_cell_mode(1, TreeItem.CELL_MODE_ICON)
		player_item.set_icon(1, get_position_icon)
		#player_item.set_selectable(1, false)
		#player_item.set_expand_right(1, false)
		
		player_item.set_cell_mode(2, TreeItem.CELL_MODE_CHECK)
		#player_item.set_selectable(2, false)
		#player_item.set_expand_right(2, false)


func _on_accept_button_pressed():
	_on_apply_button_pressed()
	queue_free()


func _on_apply_button_pressed():
	pass


func _on_cancel_button_pressed():
	queue_free()



func _on_input(event):
	if event is InputEventMouseMotion and Input.is_action_pressed("left_click"):
		$Panel.position += event.relative
