extends Node


func v3i_to_v2i(v3i : Vector3i) -> Vector2i:
	return Vector2i(floor(v3i.x), floor(v3i.z))


func v3_to_v3i(v3 : Vector3) -> Vector3i:
	return Vector3i(v3.floor())


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
	return pow(2, x - 1)


func read_json(json_file_path : String) -> Dictionary:
	var file = FileAccess.open(json_file_path, FileAccess.READ)
	var text = file.get_as_text()
	var dict = JSON.parse_string(text)
	return dict


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
