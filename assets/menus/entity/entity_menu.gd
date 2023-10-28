class_name EntityMenu
extends Control


var entity : Entity
var is_new_entity : bool

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


func use_entity(p_entity, p_is_new_entity=false):
	entity = p_entity
	is_new_entity = p_is_new_entity


func _ready():
	token_texture_tree.item_selected.connect(_set_token_texture_edit)
	accept_button.pressed.connect(_on_accept_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	apply_button.pressed.connect(_on_apply_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	
	%TabBar.gui_input.connect(_on_input)
	
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
	
	if entity.texture == "None":
		populate_texture_tree("None")
	else:
		populate_texture_tree(entity.texture)


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
			
			for basename in DirAccess.get_files_at("res://resources/entity_textures/" + cat + "/" + sub_cat):
				if basename.contains(".png.import"):
					var icon_path = "res://resources/entity_textures/" + cat + "/" + sub_cat + "/" + basename
					if FileAccess.file_exists(icon_path.split(".import")[0]):  # when export, .png goes to png.im
						basename = basename.split(".import")[0]
						
					var texture_child = token_texture_tree.create_item(sub_cat_child)
					var texture_basename = basename.split(".png")[0]
					texture_child.set_text(0, texture_basename)
					texture_child.set_tooltip_text(0, " ")
					texture_child.set_icon(0, load(icon_path.split(".import")[0]))

					if selection != "None" and selection.split("/")[2] + ".png" == basename:
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
	
	if not is_new_entity:
		Commands.async_send(Commands.OpCode.DELETE_ENTITY, {
			"id": str(entity.name)
		})

	Game.world.populate_tokens_tree()
	
	Game.world.map.update_fov()


func _on_cancel_button_pressed():
	if is_new_entity:
		entity.get_parent().remove_child(entity)
		entity.queue_free()
		
	queue_free()


func _on_apply_button_pressed():
	entity.name = id_edit.text
	
	entity.change({
		"label": label_edit.text,
		"label_known": label_public_check.button_pressed,
		"texture": token_texture_label.text,
		"base_color": base_color_picker.color,
		"base_size": base_size_spin.value,
		"health": health_edit.value,
		"health_max": health_max_edit.value,
		"health_known": health_public_check.button_pressed,
	})
	
	if is_new_entity:
		Commands.async_send(Commands.OpCode.NEW_ENTITY, {
			"id": entity.id,
			"position": Utils.v3_to_array(entity.position),
			"label": entity.label,
			"health": entity.health,
			"health_max": entity.health_max,
			"base_size": entity.base_size,
			"base_color": Utils.color_to_string(entity.base_color),
			"texture": entity.texture,
		})
	else:
		Commands.async_send(Commands.OpCode.CHANGE_ENTITY, {
			"id": str(entity.name),
			"label": entity.label,
			"health": entity.health,
			"health_max": entity.health_max,
			"base_size": entity.base_size,
			"base_color": Utils.color_to_string(entity.base_color),
			"texture": entity.texture,
		})
	
	Game.world.populate_tokens_tree()


func _on_input(event):
	if event is InputEventMouseMotion and Input.is_action_pressed("left_click"):
		$Panel.position += event.relative
