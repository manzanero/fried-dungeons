extends Node

const VoxImporterCommon = preload("res://addons/MagicaVoxel_Importer_with_Extensions/vox-importer-common.gd");

@onready var grid_map : GridMap = $Node3D/GridMap
@onready var mesh_library : MeshLibrary = grid_map.mesh_library


func _ready():
	var source_path = "res://resources/mesh_libraries/solids/brick/0/mesh.vox"
	var meshes = VoxImporterCommon.new().import(source_path, null, {Scale=null}, null, null)
	var mesh = meshes[0]
	mesh_library.create_item(0)
	mesh_library.set_item_mesh(0, mesh)
	
	grid_map.set_cell_item(Vector3i(0, 0, 0), 0, 0)
	
	mesh = load("res://resources/meshes/pointer0.obj");
	mesh_library.create_item(1)
	mesh_library.set_item_mesh(1, mesh)
	
	
	var material = ShaderMaterial.new()
	material.shader = load("res://resources/mesh_libraries/solids.gdshader")
	material.set_shader_parameter("is_in_view", false)
	material.set_shader_parameter("intensity", 1)
	
	mesh.surface_set_material(0, material)
	
	grid_map.set_cell_item(Vector3i(2, 0, 0), 1, 0)
	
