@tool
extends Node

var terrain_size: float
@export var max_depth = 10
@export var lod_threshold_scale = 1.5
@export var position_jitter = 5
@export var lod_1_depth = 9

#@onready var terrain_node = $"../Terrain"
#@onready var masks_node = $"../Masks"

var terrain_noise: TerrainNoise
var forest_mask: ImageTexture
var forest_mask_image: Image
var forest_mask_res: int

var species = [
	[preload("res://meshes/vegetation/beech_0/beech_0.mesh"), preload("res://meshes/vegetation/beech_0/beech_0_billboard.res")],
	[preload("res://meshes/vegetation/spruce_0/spruce_0.mesh"), preload("res://meshes/vegetation/spruce_0/spruce_0_billboard.res")]
]

var camera: Camera3D
var camera_last_position: Vector3

var next_nodes = {}
var last_nodes = {}

var forest_multimeshes = {}

var num_lods = 2
var num_species = 2

var pattern_size = 200
var pattern_resolution = 10 # trees per row / column
@export var pattern_positions: Dictionary

# signal mask_done # Signal from manager node
@onready var manager_node = $"../Manager"

func _init() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED

func intitialize():
	process_mode = Node.PROCESS_MODE_INHERIT
	
	for child in get_children():
		child.queue_free()
		
	terrain_size = manager_node.terrain_node.terrain_size
	terrain_noise = manager_node.terrain_node.terrain_noise
	forest_mask = manager_node.masks_node.forest_mask
	forest_mask_image = forest_mask.get_image()
	forest_mask_res = forest_mask_image.get_width()
	
	if Engine.is_editor_hint():
		camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	else:
		pass # Add in game camera
		
	camera_last_position = camera.global_position
	
	# Init positions
	# if pattern_positions.size() == 0:
	pattern_positions = {}
	for specie in range(num_species):
		pattern_positions[specie] = []
	
	var step = pattern_size / float(pattern_resolution)
	var half_step = float(step) / 2.0
	for x in range(pattern_resolution):
		for y in range(pattern_resolution):
			var point = Vector2(x * step, y * step) # + Vector2.ONE * half_step # We will use the "pixel" middle position
			point.x += randf_range(-position_jitter, position_jitter)
			point.y += randf_range(-position_jitter, position_jitter)
			var specie = randi_range(0, num_species-1)
			pattern_positions[specie].append(point)
	
	for lod in range(num_lods):
		# Init multimeshes storage
		forest_multimeshes[lod] = {}
		# Init next/last nodes
		next_nodes[lod] = []
		last_nodes[lod] = []
	
	generate_quadtree()

func _process(delta: float) -> void:
	if camera.global_position.distance_to(camera_last_position) > 50:
		camera_last_position = camera.global_position
		generate_quadtree()

func generate_quadtree():
	for lod in range(num_lods):
		next_nodes[lod] = []
		
	var root_node = Rect2(Vector2.ZERO, Vector2.ONE * terrain_size)
	subdivide(root_node, 0)
	
	# Same tree
	if next_nodes == last_nodes:
		return
	# Clear last_node
	for lod in last_nodes:
		last_nodes[lod] = []
	
	update_quadtree()

func subdivide(current_node: Rect2, depth: int):
	if depth >= max_depth:
		next_nodes[0].append(current_node)
		return
		
	var center = current_node.get_center()
	var center_3d = Vector3(center.x, 0, center.y)
	center_3d.y = terrain_noise.get_altitude_at(center_3d)
	var distance = camera.global_position.distance_to(center_3d)
	var distance_threshold = current_node.size.x * lod_threshold_scale
	
	if distance < distance_threshold:
		var half = current_node.size / 2.0
		var pos = current_node.position
		var children_nodes = [
			Rect2(pos, half),
			Rect2(pos + Vector2(half.x, 0), half),
			Rect2(pos + Vector2(0, half.y), half),
			Rect2(pos + Vector2(half.x, half.y), half),
		]
		for child_node in children_nodes:
			subdivide(child_node, depth + 1)
			
	else:
		# WARNING Need to test for duplicate spawn ?
		if depth >= lod_1_depth:
			next_nodes[1].append(current_node)

func update_quadtree():
	# Delete unwanted nodes
	for lod in forest_multimeshes.keys(): # WARNING use keys
		for rect2 in forest_multimeshes[lod].keys(): # WARNING use keys
			if not next_nodes[lod].has(rect2):
				# Delete the multimesh_instances
				for instance in forest_multimeshes[lod][rect2]:
					instance.queue_free()
				# Erase the key
				forest_multimeshes[lod].erase(rect2)
	
	for lod in range(num_lods):
		for rect2 in next_nodes[lod]:
			if forest_multimeshes[lod].has(rect2):
				continue # No need to generate this multimesh
			var multimesh_instances = generate_multimeshes(rect2, lod)
			for instance in multimesh_instances:
				add_child(instance)
			forest_multimeshes[lod][rect2] = multimesh_instances
			
	last_nodes = next_nodes.duplicate()

func generate_multimeshes(rect2: Rect2, lod: int) -> Array:
	var multimesh_instances = []
	
	for specie_index in range(num_species):
		var specie_positions = []
		
		# Extract the positions from pattern for this rect2
		var specie_pattern_positions = pattern_positions[specie_index]
		# Extend search by one tile in each direction to avoid missing border tiles
		var tile_min_x = floori(rect2.position.x / pattern_size) - 1
		var tile_max_x = floori(rect2.end.x / pattern_size) + 1
		var tile_min_y = floori(rect2.position.y / pattern_size) - 1
		var tile_max_y = floori(rect2.end.y / pattern_size) + 1
		
		for tile_x in range(tile_min_x, tile_max_x + 1):
			for tile_y in range(tile_min_y, tile_max_y + 1):
				var tile_origin = Vector2(tile_x, tile_y) * pattern_size
				for pattern_position in specie_pattern_positions:
					var world_pos_2d = tile_origin + pattern_position
					if rect2.has_point(world_pos_2d):
						specie_positions.append(world_pos_2d)
		
		var valid_positions = []
		# Test forest mask
		for world_pos_2d in specie_positions:
			var uv = world_pos_2d / (Vector2.ONE * terrain_size)
			var pixel_coord = Vector2i(uv * Vector2.ONE * forest_mask_res)
			pixel_coord = pixel_coord.clamp(Vector2i.ZERO, Vector2i.ONE * forest_mask_res - Vector2i.ONE)
			
			var density = forest_mask_image.get_pixelv(pixel_coord).r
			if density > 0.5:
				valid_positions.append(world_pos_2d)
		
		if valid_positions.size() == 0:
			continue
			
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.instance_count = valid_positions.size()
		multimesh.mesh = species[specie_index][lod]
			
		for i in valid_positions.size():
			var tree_pos_2d = valid_positions[i]
			var tree_pos_3d = Vector3(tree_pos_2d.x, terrain_noise.get_altitude_at(Vector3(tree_pos_2d.x,0,tree_pos_2d.y)), tree_pos_2d.y)
			var transform = Transform3D()
			transform.origin = tree_pos_3d
			multimesh.set_instance_transform(i, transform)
		
		var multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.multimesh = multimesh
		multimesh_instances.append(multimesh_instance)
		
	return multimesh_instances
