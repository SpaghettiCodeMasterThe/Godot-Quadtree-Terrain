@tool
extends Node3D

var noise_continent: FastNoiseLite
var noise_mountain: FastNoiseLite
var camera: Camera3D
var max_depth = 6
var terrain_size = 200000
var altitude = 4000
var lod_distance_factor = 2.0
var resolution = 32
var camera_last_position: Vector3
var material = preload("res://material/terrain.material")
@onready var debug_node = $"../Debug"

@export var keep_terrain_seed = false
@export var terrain_seed : float
@export var keep_forest_mask = false
@export var forest_mask : ImageTexture

var root_node: QuadtreeNode

class QuadtreeNode:
	var bounds: Rect2
	var depth: int
	var children: Array[QuadtreeNode] = []
	var mesh_instance: MeshInstance3D = null
	var parent_script: Node # To get the variables at the top of this script ( noise, camera, resolution, etc)
	
	func _init(_bounds: Rect2, _depth: int, _parent_script: Node) -> void:
		bounds = _bounds
		depth = _depth
		parent_script = _parent_script
		
	func update(camera_position: Vector3):
		var center = Vector3(bounds.position.x + bounds.size.x / 2, 0, bounds.position.y + bounds.size.y / 2)
		center.y = parent_script.get_altitude(center)
		var distance = center.distance_to(camera_position)
		var should_split = distance < (bounds.size.x * parent_script.lod_distance_factor) and depth < parent_script.max_depth
		
		if should_split:
			if children.is_empty():
				split()
			for child in children:
				child.update(camera_position)
			
			# Always remove our own mesh when we have children (more aggressive)
			if mesh_instance:
				mesh_instance.queue_free()
				mesh_instance = null
				
		else:
			# === MERGE: We should NOT split → collapse everything below ===
			# Clean up ALL descendants aggressively
			if not children.is_empty():
				for child in children:
					child.cleanup()  # This already recurses to max depth
				children.clear()
			
			# Now, create mesh only if we don't have one
			if mesh_instance == null:
				create_mesh()
		
	func split():
		var half = bounds.size / 2
		var pos = bounds.position
		children.append(QuadtreeNode.new(Rect2(pos, half), depth + 1, parent_script))
		children.append(QuadtreeNode.new(Rect2(pos + Vector2(half.x, 0), half), depth + 1, parent_script))
		children.append(QuadtreeNode.new(Rect2(pos + Vector2(0, half.y), half), depth + 1, parent_script))
		children.append(QuadtreeNode.new(Rect2(pos + half, half), depth + 1, parent_script))
		
	func create_mesh():
		var surface_tool = SurfaceTool.new()
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		var res = parent_script.resolution
		var step = bounds.size.x / (res - 1)
		
		# Generate vertices and normals
		var vertices = []
		for z in range(res):
			for x in range(res):
				var local_pos = Vector2(x * step, z * step)
				var world_pos = Vector3(bounds.position.x + local_pos.x, 0, bounds.position.y + local_pos.y)
				var height = parent_script.get_altitude(world_pos)
				# height = max(height, 0)  # Optional: clamp negative
				var vertex = Vector3(world_pos.x, height, world_pos.z)
				vertices.append(vertex)
				#surface_tool.set_normal(Vector3.UP)  # Simple flat normal (improve with noise gradient if needed)
				surface_tool.add_vertex(vertex)
		
		# Indices for triangles
		for z in range(res - 1):
			for x in range(res - 1):
				var i = z * res + x
				var a = i
				var b = i + 1
				var c = i + res
				var d = i + res + 1
				
				surface_tool.add_index(a)
				surface_tool.add_index(b)
				surface_tool.add_index(c)
				
				surface_tool.add_index(b)
				surface_tool.add_index(d)
				surface_tool.add_index(c)
		
		surface_tool.generate_normals()
		var array_mesh = surface_tool.commit()
		
		array_mesh.surface_set_material(0, parent_script.material)
		
		mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = array_mesh
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		
		# Optional: add collision
		var static_body = StaticBody3D.new()
		var collision_shape = CollisionShape3D.new()
		
		# This creates the trimesh (concave) shape from the mesh
		collision_shape.shape = array_mesh.create_trimesh_shape()
		
		static_body.add_child(collision_shape)
		mesh_instance.add_child(static_body)
		
		parent_script.add_child(mesh_instance)
	
	func cleanup():
		if mesh_instance:
			mesh_instance.queue_free()
			mesh_instance = null
		for child in children:
			child.cleanup()
		children.clear()

func _ready() -> void:
	for child in get_children():
		child.queue_free()
		
	setup_noise()
	if keep_forest_mask and forest_mask != null:
		print("Reusing existing forest mask.")
	else:
		generate_forest_mask()
	
	material.set_shader_parameter("forest_mask", forest_mask)
	material.set_shader_parameter("terrain_size", float(terrain_size))

	if Engine.is_editor_hint():
		camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	camera_last_position = camera.global_position
	
	var root_bounds = Rect2(Vector2.ZERO, Vector2.ONE * terrain_size)
	root_node = QuadtreeNode.new(root_bounds, 0, self)
	root_node.update(camera.global_position)

func _process(delta: float) -> void:
	if camera.global_position.distance_to(camera_last_position) > 200.0:
		camera_last_position = camera.global_position
		root_node.update(camera.global_position)

func find_valid_seed():
	var grid_resolution = 8
	var total_points = grid_resolution * grid_resolution
	var min_valid_points = total_points / 2
	var max_try = 100
	
	while max_try > 0:
		max_try -= 1
		if max_try == 0:
			print("no seed found")
		noise_continent.seed = randi()
		var valid_points_count = 0
		# We create a square half the sizte of terrain in center
		var start_pos = Vector3(terrain_size / 4, 0, terrain_size / 4)
		var steps = ( terrain_size / 2 ) / float(grid_resolution - 1)
		
		for z in range(grid_resolution):
			for x in range(grid_resolution):
				var point = Vector3(x * steps, 0, z * steps) + start_pos
				point.y = get_altitude(point)
				# debug_node.draw_cube(point)
				if point.y > 0.0 and point.y < 2000.0:
					valid_points_count += 1
				
		if valid_points_count > min_valid_points:
			return

func get_altitude(point: Vector3) -> float:
		var continent_value = noise_continent.get_noise_2d(point.x, point.z)
		continent_value = remap(continent_value, -1.0, 1.0, -1.0, 1.0)
		
		var mountain_value = noise_mountain.get_noise_2d(point.x, point.z)
		mountain_value = remap(mountain_value, -1.0, 1.0, 0.0, 1.0)
		
		var blend_value = clamp(continent_value * 1.0, 0.0, 1.0)
		
		var final_value = lerp(continent_value, mountain_value, blend_value)
		final_value = clamp(final_value, -1.0, 1.0)
		
		return final_value * altitude

func setup_noise():
	noise_mountain = FastNoiseLite.new()
	noise_mountain.seed = 1
	noise_mountain.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_mountain.frequency = 0.0001
	noise_mountain.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise_mountain.fractal_octaves = 6
	noise_mountain.fractal_gain = 0.5
	noise_mountain.fractal_lacunarity = 2.0
	
	noise_continent = FastNoiseLite.new()
	noise_continent.noise_type = FastNoiseLite.TYPE_VALUE
	noise_continent.frequency = 0.00001
	noise_continent.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_continent.fractal_octaves = 6
	noise_continent.fractal_gain = 0.5
	noise_continent.fractal_lacunarity = 2.0
	if keep_terrain_seed and terrain_seed != null:
		noise_continent.seed = terrain_seed
	else:
		find_valid_seed()
		terrain_seed = noise_continent.seed

func generate_forest_mask():
	const forest_min_height = 15
	const forest_max_height = 2200
	const forest_min_slope = 0.1
	const mask_resolution = 256
	
	var img := Image.create(mask_resolution, mask_resolution, false, Image.FORMAT_L8)
	var steps = terrain_size / float(mask_resolution - 1)
	var sample_delta = steps * 1.5
	
	for x in range(mask_resolution):
		for z in range(mask_resolution):
			var world_x = x * steps
			var world_z = z * steps
			var h_center = get_altitude(Vector3(world_x, 0, world_z))
			
			# Sample neighbors for slope
			var h_left = get_altitude(Vector3(world_x - sample_delta, 0, world_z))
			var h_right = get_altitude(Vector3(world_x + sample_delta, 0, world_z))
			var h_down = get_altitude(Vector3(world_x, 0, world_z - sample_delta))
			var h_up = get_altitude(Vector3(world_x, 0, world_z + sample_delta))
			
			var dx = (h_right - h_left) / (2.0 * sample_delta)
			var dz = (h_up - h_down) / (2.0 * sample_delta)
			var slope = sqrt(dx*dx + dz*dz)
			
			# Forest strength
			var strength = 0.0
			if h_center > forest_min_height and slope > forest_min_slope:
				if h_center < forest_max_height:
					strength = 1.0
			
			img.set_pixel(x, z, Color(strength,strength,strength))
	
	var texture = ImageTexture.new()
	texture = ImageTexture.create_from_image(img)
	forest_mask = texture
	print(img.get_height())
	print(img.get_width())
	img.save_png("res://debug_forest_mask.png")
