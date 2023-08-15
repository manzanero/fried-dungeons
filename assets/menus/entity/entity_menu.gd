extends Control


var entity : Entity


@onready var accept_button := %AcceptButton as Button
@onready var cancel_button := %CancelButton as Button
@onready var apply_button := %ApplyButton as Button
@onready var delete_button := %DeleteButton as Button
@onready var token_texture_tree := %TokenTextureTree as Tree

@onready var id_edit := %IdEdit as LineEdit
@onready var label_edit := %LabelEdit as LineEdit
@onready var label_public_check := %LabelPublicCheckBox as CheckBox
@onready var health_edit := %HelathEdit as SpinBox
@onready var health_max_edit := %HelathMaxEdit as SpinBox
@onready var health_public_check := %HealtPublicCheckBox as CheckBox
@onready var base_check := %BaseCheckBox as CheckBox
@onready var base_size_spin := %BaseSizeSpinBox as SpinBox
@onready var base_color_picker := %BaseColorColorPickerButton as ColorPickerButton
@onready var token_check := %TokenCheckBox as CheckBox
@onready var token_texture_label := %TokenTextureLabel as LineEdit
@onready var token_scale_spin := %TokenScaleSpinBox as SpinBox
@onready var token_tint_picker := %TokenTintColorPickerButton as ColorPickerButton

func use_entity(p_entity):
	entity = p_entity


func _ready():
	token_texture_tree.item_selected.connect(_set_token_texture_edit)
	accept_button.pressed.connect(_on_accept_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	apply_button.pressed.connect(_on_apply_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	
	$Panel/TabBar.gui_input.connect(_on_input)
	
	if entity:
		id_edit.text = str(entity.name)
		label_edit.text = entity.label
		label_public_check.button_pressed = entity.label_known
		health_edit.value = entity.health
		health_max_edit.value = entity.health_max
		health_public_check.button_pressed = entity.health_known
		base_check.button_pressed = true
		base_size_spin.value = entity.base_size
		base_color_picker.color = entity.base_color
		token_check.button_pressed = true
		token_scale_spin.value = 1
		token_tint_picker.color = Color.WHITE
		
		if entity.texture_path == "None":
			populate_texture_tree("None")
		else:
			populate_texture_tree(entity.texture_path.split("res://resources/entity_textures/")[1])
	else:
		id_edit.text = UUID.short()
		populate_texture_tree()


func populate_texture_tree(selection : String = "None"):
	token_texture_tree.clear()
	var root = token_texture_tree.create_item()
	token_texture_tree.hide_root = true
	
	var dir = DirAccess.open("res://resources/entity_textures/")
	for cat in dir.get_directories():
		var cat_child = token_texture_tree.create_item(root)
		cat_child.set_text(0, cat)
		cat_child.set_tooltip_text(0, " ")
		cat_child.collapsed = selection == "None" or selection.split("/")[0] != cat
		cat_child.set_selectable(0, false)
		
		for sub_cat in DirAccess.get_directories_at("res://resources/entity_textures/" + cat):
			var sub_cat_child = token_texture_tree.create_item(cat_child)
			sub_cat_child.set_text(0, sub_cat)
			sub_cat_child.set_tooltip_text(0, " ")
			sub_cat_child.collapsed = selection == "None" or selection.split("/")[1] != sub_cat
			sub_cat_child.set_selectable(0, false)
			
			for texture in DirAccess.get_files_at("res://resources/entity_textures/" + cat + "/" + sub_cat):
				if texture.contains(".png.import"):
					if FileAccess.file_exists("res://resources/entity_textures/" + cat + "/" + sub_cat + "/" + texture.split(".import")[0]):  # when export, .png goes to png.im
						texture = texture.split(".import")[0]
						
					var texture_child = token_texture_tree.create_item(sub_cat_child)
					var texture_basename = texture.split(".png")[0]
					texture_child.set_text(0, texture_basename)
					texture_child.set_tooltip_text(0, " ")

					if selection != "None" and selection.split("/")[2] == texture:
						texture_child.select(0)
						token_texture_tree.scroll_to_item(texture_child)
						
	var none_child = token_texture_tree.create_item(root)
	none_child.set_text(0, "None")
	
	if selection == "None":
		none_child.select(0)
		token_texture_tree.scroll_to_item(none_child)
	

func _set_token_texture_edit():
	var selected = token_texture_tree.get_selected()
	var text = selected.get_text(0)
	if text != "None":
		var sub_cat = selected.get_parent().get_text(0)
		var cat = selected.get_parent().get_parent().get_text(0)
		var path = "%s/%s/%s" % [cat, sub_cat, text]
		token_texture_label.text = path
	else:
		token_texture_label.text = "None"
		

func _on_accept_button_pressed():
	_on_apply_button_pressed()
	queue_free()
		

func _on_delete_button_pressed():
	queue_free()
	entity.get_parent().remove_child(entity)
	entity.queue_free()
	Game.world.send_command(Game.world.OpCode.DELETE_ENTITY, {
		"id": str(entity.name)
	})

	Game.world.populate_tokens_tree()

func _on_cancel_button_pressed():
	queue_free()


func _on_apply_button_pressed():
	var is_new_entity = false	
	if not entity:
		is_new_entity = true
		var world: World = Game.world
		entity = world.entity_scene.instantiate()
		world.map.entities_parent.add_child(entity)
		entity.position = world.pointer.position + Vector3(0.5, 1, 0.5)

	entity.label = label_edit.text
	entity.label_known = label_public_check.button_pressed
	entity.health = health_edit.value
	entity.health_max = health_max_edit.value
	entity.health_known = health_public_check.button_pressed
#	base_check.button_pressed = true
	entity.base_size = base_size_spin.value
	entity.base_color = base_color_picker.color
#	token_check.button_pressed = true
#	token_scale_spin.value = 1
#	token_tint_picker.color = Color.WHITE
	entity.name = id_edit.text
	if token_texture_label.text == "None":
		entity.texture_path = "None"
	else:
		entity.texture_path = "res://resources/entity_textures/" + token_texture_label.text + ".png"
	
	if is_new_entity:
		Game.world.send_command(Game.world.OpCode.NEW_ENTITY, {
			"id": str(entity.name),
			"position": Utils.v3_to_array(entity.position),
			"label": entity.label,
			"health": entity.health,
			"health_max": entity.health_max,
			"base_size": entity.base_size,
			"base_color": Utils.color_to_string(entity.base_color),
			"texture_path": entity.texture_path,
		})
	else:
		Game.world.send_command(Game.world.OpCode.CHANGE_ENTITY, {
			"id": str(entity.name),
			"label": entity.label,
			"health": entity.health,
			"health_max": entity.health_max,
			"base_size": entity.base_size,
			"base_color": Utils.color_to_string(entity.base_color),
			"texture_path": entity.texture_path,
		})
	
	Game.world.populate_tokens_tree()


func _on_input(event):
	if event is InputEventMouseMotion and Input.is_action_pressed("left_click"):
		$Panel.position += event.relative
