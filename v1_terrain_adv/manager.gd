@tool
extends Node

@onready var debug_node: Node3D = $"../Debug"
@onready var terrain_node: Node3D = $"../Terrain"
@onready var road_node: Node3D = $"../Road"
@onready var masks_node: Node3D = $"../Masks"
@onready var cities_node: Node3D = $"../Cities"
@onready var forest_node: Node3D = $"../Forest"


func _init() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED

func masks_done() -> void:
	forest_node.intitialize()
