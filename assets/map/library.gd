class_name MapLibrary
extends Node

const VoxImporterCommon = preload("res://addons/MagicaVoxel_Importer_with_Extensions/vox-importer-common.gd");

const SHADES = 6
const SHADES_STEP = int(100.0 / (SHADES - 1))

var meshes : MeshLibrary
var meshes_len : int
var shape : BoxShape3D
var shader := preload("res://resources/mesh_libraries/solids.gdshader") as Shader
var solids_path = "res://resources/mesh_libraries/solids"

# transparency
var meshes_50 : MeshLibrary
var shader_50 := preload("res://resources/mesh_libraries/solids_transparent_50.gdshader") as Shader

# empty
#var meshes_empty : MeshLibrary

var DEBUG : bool = false
#var DEBUG : bool = true


func load_library():
	var start_time = Time.get_ticks_msec()
	
	if not DEBUG:
		meshes = load("res://resources/mesh_libraries/solids.tres")
		meshes_len = meshes.get_item_list().size()
		meshes_50 = load("res://resources/mesh_libraries/solids_50.tres")
		return
	
	meshes = MeshLibrary.new()
	shape = BoxShape3D.new()
	
	# transparency
	meshes_50 = MeshLibrary.new()
	
	var category_tapbar := Game.world.cell_edit_panel.category_tapbar
	category_tapbar.clear_tabs()
	var category_itemlist := Game.world.cell_edit_panel.category_itemlist
	category_itemlist.clear()
	
	for cat in DirAccess.get_directories_at(solids_path):
		
		# builder tabs
		category_tapbar.add_tab(cat)
		
		# import base meshes
		for sub_cat in DirAccess.get_directories_at(solids_path + "/" + cat):
			var mesh_name = cat + sub_cat
			var source_path = solids_path + "/" + cat + "/" + sub_cat + "/mesh.vox"
			load_solid(source_path, mesh_name)
	
	category_tapbar.tab_selected.connect(_on_tab_selected)
	category_tapbar.current_tab = 0
	
	meshes_len = meshes.get_item_list().size()
	
	# materials
	var shade_materials := []
	var shade_materials_50 := []
	for i in range(SHADES):
		var material = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("is_in_view", true)
		material.set_shader_parameter("intensity", clampi(SHADES_STEP * i, 0, 100) * 0.01)
		shade_materials.append(material)
		
		# transparency
		var material_50 = ShaderMaterial.new()
		material_50.shader = shader_50
		material_50.set_shader_parameter("is_in_view", true)
		material_50.set_shader_parameter("intensity", clampi(SHADES_STEP * i, 0, 100) * 0.01)
		shade_materials_50.append(material_50)
	
	var sepia_material = ShaderMaterial.new()
	sepia_material.shader = shader
	sepia_material.set_shader_parameter("is_in_view", false)
	sepia_material.set_shader_parameter("intensity", 1)
	
	# transparency
	var sepia_material_50 = ShaderMaterial.new()
	sepia_material_50.shader = shader_50
	sepia_material_50.set_shader_parameter("is_in_view", false)
	sepia_material_50.set_shader_parameter("intensity", 1)

	for i in range(meshes_len):
		var mesh_name = meshes.get_item_name(i)
		
		for j in range(SHADES):
			var library_index = meshes_len * (j + 1) + i
			var library_name = "%s%s" % [clampi(SHADES_STEP * j, 0, 100), mesh_name]
			var library_mesh = meshes.get_item_mesh(i).duplicate(true) as Mesh
			library_mesh.surface_set_material(0, shade_materials[j])
			new_library_item(meshes, library_index, library_name, library_mesh, [shape])
#			print("Created skin %s at index %s" % [library_name, library_index])

			# transparency
			var library_mesh_50 = meshes.get_item_mesh(i).duplicate(true) as Mesh
			library_mesh_50.surface_set_material(0, shade_materials_50[j])
			new_library_item(meshes_50, library_index, library_name, library_mesh_50, [shape])
		
		var sepia_index = meshes_len * (SHADES + 1) + i
		var sepia_name = "x" + mesh_name
		var sepia_mesh = meshes.get_item_mesh(i).duplicate(true) as Mesh
		sepia_mesh.surface_set_material(0, sepia_material)
		new_library_item(meshes, sepia_index, sepia_name, sepia_mesh, [shape])
#		print("Created skin %s at index %s" % [sepia_name, sepia_index])

		# transparency
		var sepia_mesh_50 = meshes.get_item_mesh(i).duplicate(true) as Mesh
		sepia_mesh_50.surface_set_material(0, sepia_material_50)
		new_library_item(meshes_50, sepia_index, sepia_name, sepia_mesh_50, [shape])

	var elapsed_time = (Time.get_ticks_msec() - start_time) * 0.001
	print("Skin library took %s s to load" % [elapsed_time])
	
	ResourceSaver.save(meshes, "res://resources/mesh_libraries/solids.tres")
	ResourceSaver.save(meshes_50, "res://resources/mesh_libraries/solids_50.tres")


func load_solid(source_path, mesh_name):
	var mesh : Mesh = VoxImporterCommon.new().import(source_path, null, {Scale=null}, null, null)[0]
	var size = meshes.get_item_list().size()
	new_library_item(meshes, size, mesh_name, mesh, [shape])
	
	# transparency
	new_library_item(meshes_50, size, mesh_name, mesh, [shape])
	
	
func new_library_item(library, index, item_name, mesh, shapes):
	library.create_item(index)
	library.set_item_mesh(index, mesh)
	library.set_item_name(index, item_name)
	library.set_item_shapes(index, shapes)


func _on_tab_selected(tab_index):
	var category_tapbar := Game.world.cell_edit_panel.category_tapbar
	var category_itemlist := Game.world.cell_edit_panel.category_itemlist
	category_itemlist.clear()
	
	var cat = category_tapbar.get_tab_title(tab_index)
	for sub_cat in DirAccess.get_directories_at(solids_path + "/" + cat):
		var icon_path = solids_path + "/" + cat + "/" + sub_cat + "/icon.png"
		var icon := load(icon_path) as Texture2D
		var metadata := {"skin": cat + sub_cat}
		if cat == "door":
			metadata["is_door"] = true
		category_itemlist.set_item_metadata(category_itemlist.add_item("", icon), metadata)
	
	
func serialize():
	var serialized_library := {}
	for i in range(meshes_len):
		serialized_library[meshes.get_item_name(i)] = i
#
#	print("Serialized Library: %s" % [serialized_library])
	
#	for i in range(meshes.get_item_list().size()):
#		print(i, ": ", meshes.get_item_name(i))
	
	return serialized_library
	
		
