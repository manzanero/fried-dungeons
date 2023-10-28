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
	
	%LabelEdit.text = entity.label
	
	%TabBar.gui_input.connect(_on_input)

	populate_permissions_tree()

	
func populate_permissions_tree():
	player_permissions_tree.clear()
	var root : TreeItem = player_permissions_tree.create_item()
	player_permissions_tree.hide_root = true
	player_permissions_tree.columns = 11
	for i in range(1, player_permissions_tree.columns):
		player_permissions_tree.set_column_expand(i, false)
		
	var get_position_icon := AtlasTexture.new()
	get_position_icon.set_atlas(permission_icons)
	get_position_icon.set_region(Rect2(0, 0, 16, 16))
	var get_label_icon := AtlasTexture.new()
	get_label_icon.set_atlas(permission_icons)
	get_label_icon.set_region(Rect2(16, 0, 16, 16))
	var get_health_icon := AtlasTexture.new()
	get_health_icon.set_atlas(permission_icons)
	get_health_icon.set_region(Rect2(32, 0, 16, 16))
	var get_vision_icon := AtlasTexture.new()
	get_vision_icon.set_atlas(permission_icons)
	get_vision_icon.set_region(Rect2(48, 0, 16, 16))
	var get_move_icon := AtlasTexture.new()
	get_move_icon.set_atlas(permission_icons)
	get_move_icon.set_region(Rect2(64, 0, 16, 16))
	
	var default_item : TreeItem = player_permissions_tree.create_item(root)
	default_item.set_text(0, "Default")
	default_item.set_tooltip_text(0, " ")
	default_item.set_expand_right(0, true)
	default_item.set_metadata(0, "None")
	
	default_item.set_cell_mode(1, TreeItem.CELL_MODE_ICON)
	default_item.set_icon(1, get_position_icon)
	default_item.set_cell_mode(2, TreeItem.CELL_MODE_CHECK)
	default_item.set_editable(2, true)
	default_item.propagate_check(2, true)
	
	default_item.set_cell_mode(3, TreeItem.CELL_MODE_ICON)
	default_item.set_icon(3, get_label_icon)
	default_item.set_cell_mode(4, TreeItem.CELL_MODE_CHECK)
	default_item.set_editable(4, true)
	default_item.propagate_check(4, true)
	
	default_item.set_cell_mode(5, TreeItem.CELL_MODE_ICON)
	default_item.set_icon(5, get_health_icon)
	default_item.set_cell_mode(6, TreeItem.CELL_MODE_CHECK)
	default_item.set_editable(6, true)
	default_item.propagate_check(6, true)
	
	default_item.set_cell_mode(7, TreeItem.CELL_MODE_ICON)
	default_item.set_icon(7, get_vision_icon)
	default_item.set_cell_mode(8, TreeItem.CELL_MODE_CHECK)
	default_item.set_editable(8, true)
	default_item.propagate_check(8, true)
	
	default_item.set_cell_mode(9, TreeItem.CELL_MODE_ICON)
	default_item.set_icon(9, get_move_icon)
	default_item.set_cell_mode(10, TreeItem.CELL_MODE_CHECK)
	default_item.set_editable(10, true)
	default_item.propagate_check(10, true)
	
	var players = Game.campaign.players
	for player_id in players:
		var player_item : TreeItem = player_permissions_tree.create_item(root)

		var player : Game.Player = players[player_id]
		player_item.set_text(0, player.label)
		player_item.set_tooltip_text(0, " ")
		player_item.set_expand_right(0, true)
		player_item.set_metadata(0, player_id)
		
		player_item.set_cell_mode(1, TreeItem.CELL_MODE_ICON)
		player_item.set_icon(1, get_position_icon)
		player_item.set_cell_mode(2, TreeItem.CELL_MODE_CHECK)
		player_item.set_editable(2, true)
		player_item.propagate_check(2, true)
		
		player_item.set_cell_mode(3, TreeItem.CELL_MODE_ICON)
		player_item.set_icon(3, get_label_icon)
		player_item.set_cell_mode(4, TreeItem.CELL_MODE_CHECK)
		player_item.set_editable(4, true)
		player_item.propagate_check(4, true)
		
		player_item.set_cell_mode(5, TreeItem.CELL_MODE_ICON)
		player_item.set_icon(5, get_health_icon)
		player_item.set_cell_mode(6, TreeItem.CELL_MODE_CHECK)
		player_item.set_editable(6, true)
		player_item.propagate_check(6, true)
		
		player_item.set_cell_mode(7, TreeItem.CELL_MODE_ICON)
		player_item.set_icon(7, get_vision_icon)
		player_item.set_cell_mode(8, TreeItem.CELL_MODE_CHECK)
		player_item.set_editable(8, true)
		player_item.propagate_check(8, true)
		
		player_item.set_cell_mode(9, TreeItem.CELL_MODE_ICON)
		player_item.set_icon(9, get_move_icon)
		player_item.set_cell_mode(10, TreeItem.CELL_MODE_CHECK)
		player_item.set_editable(10, true)
		player_item.propagate_check(10, true)


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
