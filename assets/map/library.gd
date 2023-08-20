class_name MapLibrary
extends Node


@export var meshes : MeshLibrary
@export var shader = preload("res://resources/mesh_libraries/solids.gdshader")


func load_library():
	var meshes_len = 16
	var meshes_len_10 = meshes_len
	var meshes_len_9 = meshes_len * 2
	var meshes_len_8 = meshes_len * 3
	var meshes_len_7 = meshes_len * 4
	var meshes_len_6 = meshes_len * 5
	var meshes_len_5 = meshes_len * 6
	var meshes_len_4 = meshes_len * 7
	
	# clear previous generated meshes
	for i in meshes.get_item_list().size():
		if i >= meshes_len:
			meshes.remove_item(i)
			
	
	var shape = meshes.get_item_shapes(0)[0].duplicate(true) as Shape3D
	var material = ShaderMaterial.new()
	material.shader = shader
	
	var material_10 = material.duplicate(true) as ShaderMaterial
	var material_9 = material.duplicate(true) as ShaderMaterial
	var material_8 = material.duplicate(true) as ShaderMaterial
	var material_7 = material.duplicate(true) as ShaderMaterial
	var material_6 = material.duplicate(true) as ShaderMaterial
	var material_5 = material.duplicate(true) as ShaderMaterial
	var material_4 = material.duplicate(true) as ShaderMaterial
	material_10.set_shader_parameter("is_in_view", true)
	material_10.set_shader_parameter("intensity", 1)
	material_9.set_shader_parameter("is_in_view", true)
	material_9.set_shader_parameter("intensity", 0.8)
	material_8.set_shader_parameter("is_in_view", true)
	material_8.set_shader_parameter("intensity", 0.6)
	material_7.set_shader_parameter("is_in_view", true)
	material_7.set_shader_parameter("intensity", 0.4)
	material_6.set_shader_parameter("is_in_view", true)
	material_6.set_shader_parameter("intensity", 0.2)
	material_5.set_shader_parameter("is_in_view", true)
	material_5.set_shader_parameter("intensity", 0.0)
	material_4.set_shader_parameter("is_in_view", false)
	material_4.set_shader_parameter("intensity", 1)

	for i in range(meshes_len):
		var mesh_name = meshes.get_item_name(i)
		
		var mesh_10 = meshes.get_item_mesh(i).duplicate(true) as Mesh
		mesh_10.surface_set_material(0, material_10)
		meshes.create_item(i + meshes_len_10)
		meshes.set_item_mesh(i + meshes_len_10, mesh_10)
		meshes.set_item_name(i + meshes_len_10, "100" + mesh_name)
		meshes.set_item_shapes(i + meshes_len_10, [shape])
		
		var mesh_9 = meshes.get_item_mesh(i).duplicate(true) as Mesh
		mesh_9.surface_set_material(0, material_9)
		meshes.create_item(i + meshes_len_9)
		meshes.set_item_mesh(i + meshes_len_9, mesh_9)
		meshes.set_item_name(i + meshes_len_9, "80" + mesh_name)
		meshes.set_item_shapes(i + meshes_len_9, [shape])
		
		var mesh_8 = meshes.get_item_mesh(i).duplicate(true) as Mesh
		mesh_8.surface_set_material(0, material_8)
		meshes.create_item(i + meshes_len_8)
		meshes.set_item_mesh(i + meshes_len_8, mesh_8)
		meshes.set_item_name(i + meshes_len_8, "60" + mesh_name)
		meshes.set_item_shapes(i + meshes_len_8, [shape])
		
		var mesh_7 = meshes.get_item_mesh(i).duplicate(true) as Mesh
		mesh_7.surface_set_material(0, material_7)
		meshes.create_item(i + meshes_len_7)
		meshes.set_item_mesh(i + meshes_len_7, mesh_7)
		meshes.set_item_name(i + meshes_len_7, "40" + mesh_name)
		meshes.set_item_shapes(i + meshes_len_7, [shape])
		
		var mesh_6 = meshes.get_item_mesh(i).duplicate(true) as Mesh
		mesh_6.surface_set_material(0, material_6)
		meshes.create_item(i + meshes_len_6)
		meshes.set_item_mesh(i + meshes_len_6, mesh_6)
		meshes.set_item_name(i + meshes_len_6, "20" + mesh_name)
		meshes.set_item_shapes(i + meshes_len_6, [shape])
		
		var mesh_5 = meshes.get_item_mesh(i).duplicate(true) as Mesh
		mesh_5.surface_set_material(0, material_5)
		meshes.create_item(i + meshes_len_5)
		meshes.set_item_mesh(i + meshes_len_5, mesh_5)
		meshes.set_item_name(i + meshes_len_5, "0" + mesh_name)
		meshes.set_item_shapes(i + meshes_len_5, [shape])
		
		var mesh_4 = meshes.get_item_mesh(i).duplicate(true) as Mesh
		mesh_4.surface_set_material(0, material_4)
		meshes.create_item(i + meshes_len_4)
		meshes.set_item_mesh(i + meshes_len_4, mesh_4)
		meshes.set_item_name(i + meshes_len_4, "x" + mesh_name)
		meshes.set_item_shapes(i + meshes_len_4, [shape])
