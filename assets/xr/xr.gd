class_name XR
extends Node3D

var xr_interface: XRInterface

func _ready():
	
	# https://docs.godotengine.org/en/4.1/classes/class_mobilevrinterface.html
	xr_interface = XRServer.find_interface("Native mobile")


func activate():
	if xr_interface and xr_interface.initialize():
		get_viewport().use_xr = true
		
		
func deactivate():
	if xr_interface and xr_interface.initialize():
		get_viewport().use_xr = false
		
		
func toggle():
	if xr_interface and xr_interface.initialize():
		get_viewport().use_xr = not get_viewport().use_xr


#########
# input #
#########

func _input(event):
	if event is InputEventKey:
		if event.is_pressed():
			if event.keycode == KEY_F2:
				toggle()
