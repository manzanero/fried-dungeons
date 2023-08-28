extends Node


func v3_to_v2i(v3 : Vector3) -> Vector2i:
	return Vector2i(floor(v3.x), floor(v3.z))


func v3_to_v3i(v3 : Vector3) -> Vector3i:
	return Vector3i(v3.floor())
	
	
func v3_to_str(v3 : Vector3) -> String:
	return "(%s, %s, %s)" % [v3.x, v3.y, v3.z]
	
	
func v3i_to_str(v3i : Vector3i) -> String:
	return "(%s, %s, %s)" % [v3i.x, v3i.y, v3i.z]


func array_to_v3(array : Array) -> Vector3:
	return Vector3(array[0], array[1], array[2])


func array_to_v3i(array : Array) -> Vector3i:
	return Vector3i(array[0], array[1], array[2])


func v3_to_array(v3 : Vector3) -> Array:
	return [snappedf(v3.x, 0.001), snappedf(v3.y, 0.001), snappedf(v3.z, 0.001)]


func v3i_to_array(v3i : Vector3) -> Array:
	return [v3i.x, v3i.y, v3i.z]


func color_to_string(color : Color) -> String:
	return color.to_html()
	
	
func string_to_color(string : String) -> Color:
	return Color.html(string)
	

func get_bitmask(x : int) -> int:
	return int(pow(2, x - 1))


func get_raycast_hit(space : Node3D, camera : Camera3D, raycast : PhysicsRayQueryParameters3D, collision_mask : int):
	var ray_length = 1000
	var mouse_pos = get_viewport().get_mouse_position()
	var space_state = space.get_world_3d().direct_space_state
	raycast.from = camera.project_ray_origin(mouse_pos)
	raycast.to = raycast.from + camera.project_ray_normal(mouse_pos) * ray_length
	raycast.collision_mask = collision_mask
	return space_state.intersect_ray(raycast)


func loads_json(data):
	var json = JSON.new()
	json.parse(data)
	var result = json.data
	if result == null:
		printerr("JSON load failed on line %s: %s" % [json.get_error_line(), json.get_error_message()])
	return result


func load_json(path : String):
	var file = FileAccess.open(path, FileAccess.READ)
	var open_error := FileAccess.get_open_error()
	if open_error:
		printerr("error reading json: %s" % error_string(open_error))
	var text = file.get_as_text()
	var dict = loads_json(text)
	return dict


func dumps_json(data) -> String:
	return JSON.stringify(data, "", false)


func dump_json(path : String, data):
	var json_string := dumps_json(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	var open_error := FileAccess.get_open_error()
	if open_error:
		printerr("error writing json: %s" % error_string(open_error))
	file.store_line(json_string)


func make_dirs(path : String):
	DirAccess.make_dir_recursive_absolute(path)


func generate_match_name():
	var word := "" 
	var characters = '0123456789'
	var n_char = len(characters)
	for i in range(4):
		word += characters[randi()% n_char]
	Data.match_name = "fried_dungeons__" + word
	
	
func get_os_name():
	match OS.get_name():
		"Windows", "UWP":
			return "Windows"
		"macOS":
			return "macOS"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return "Linux/BSD"
		"Android":
			return "Android"
		"iOS":
			return "iOS"
		"Web":
			return "Web"
	return "Unknown"
