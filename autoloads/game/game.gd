extends Node

var world : World
var camera : Camera
var is_high_end : bool = true
var is_pc : bool = true

var is_host : bool = true
var match_name : String = "frierd_dungeons__" + OS.get_environment("USERNAME")
var player_name : String = "Master"

var public_entities = [
	"DFCFD0B0",
	"DFCFD0B1",
	"DFCFD0B2",
	"DFCFD0B3",
	"DFCFD0B4",
	"DFCFD0B5",
	"DFCFD0B6",
	"DFCFD0B7",
] 
