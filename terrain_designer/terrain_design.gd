@tool
extends Node3D

@export var keep_seed = false
@export var seed: int
@export var max_depth = 4
@export var resolution = 32
@export var material: ShaderMaterial = preload("res://material/terrain_design.material")

var size = 200000
var altitude = 4000
var subdivision_scale = 1.5
var camera: Camera3D
var camera_last_pos: Vector3

var next_nodes = {}
var current_nodes = {}

var generation_in_progress = false

@onready var debug_node = $"../Debug"
@onready var terrain_noise_node = $"../Noise"
@onready var terrain_mesh_node = $"../Mesh"

func _ready():
	for child in get_children():
		child.queue_free()
		
	if Engine.is_editor_hint():
		camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	else:
		printerr("terrain.gd: Add in game camera")
		return
	
	update_quadtree()

func _process(delta: float) -> void:
	if camera.global_position.distance_to(camera_last_pos) > 200:
		camera_last_pos = camera.global_position
		update_quadtree()

func update_quadtree():
	if generation_in_progress:  # Block new updates if generation is in progress
		return
		
	next_nodes.clear()
	var root_rect2 = Rect2(Vector2.ZERO, Vector2.ONE * size)
	subdivide_node(root_rect2, 0)
	
	var current_keys = current_nodes.keys()
	var next_keys = next_nodes.keys()
	current_keys.sort()
	next_keys.sort()
	
	if current_keys != next_keys:
		generate_nodes()

func subdivide_node(rect2: Rect2, depth: int):
	if depth >= max_depth:
		next_nodes[rect2] = depth
		return
	
	var center_2d = rect2.get_center()
	var center_3d = Vector3(center_2d.x, 0, center_2d.y)
	center_3d.y = terrain_noise_node.get_altitude(center_3d)
	var distance = camera.global_position.distance_to(center_3d)
	if distance < rect2.size.x * subdivision_scale:
		var pos = rect2.position
		var half_size = rect2.size.x / 2
		var half_extend = Vector2.ONE * half_size
		var children = [
			Rect2(pos, half_extend),
			Rect2(pos + Vector2(half_size, 0), half_extend),
			Rect2(pos + Vector2(0, half_size), half_extend),
			Rect2(pos + Vector2(half_size, half_size), half_extend),
		]
		for child in children:
			subdivide_node(child, depth + 1)
	else:
		next_nodes[rect2] = depth

func generate_nodes():
	if generation_in_progress:
		return
	
	generation_in_progress = true
	
	# Gather nodes to generate
	var nodes_to_generate = []
	for rect2 in next_nodes:
		if not current_nodes.has(rect2):
			nodes_to_generate.append(rect2)
	
	if nodes_to_generate.is_empty():
		generation_in_progress = false
		return
		
	# Delete old nodes first
	var nodes_to_delete = []
	for rect2 in current_nodes:
		if not next_nodes.has(rect2):
			nodes_to_delete.append(rect2)
	for rect2 in nodes_to_delete:
		var mesh_instance = current_nodes[rect2]
		if is_instance_valid(mesh_instance):
			mesh_instance.queue_free()
		current_nodes.erase(rect2)
	
	for rect2 in nodes_to_generate:
		var arrays = terrain_mesh_node.generate_arrays(rect2)["arrays"]
		var array_mesh = ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var new_mesh_instance = MeshInstance3D.new()
		new_mesh_instance.mesh = array_mesh
		new_mesh_instance.set_surface_override_material(0, material)
		add_child(new_mesh_instance)
		current_nodes[rect2] = new_mesh_instance
		
	generation_in_progress = false
