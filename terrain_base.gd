@tool
extends Node3D

var altitude = 4000
var size = 200000
var material = preload("res://material/terrain.material")

@export var keep_terrain = false
@export var seed = 0

@export_category("Performance")
@export var resolution = 32
@export var max_depth = 3
@export var scale_distance = 1.5

@export_category("Live Update (Heavy)")
@export var live_update = false
var wait_time = 1.0
var elapsed = 0.0
@export_category("Noise")
var noise_scale = 100000.0
@export var continent: FastNoiseLite
@export var continent_frequency = 1.0
@export var mountain: FastNoiseLite
@export var mountain_frequency = 2.0
@export var hill: FastNoiseLite
@export var hill_frequency = 10.0
@export_range(0.01, 1.0, 0.01) var flatten_terrain = 0.9

@export_category("Debug")
@export var show_continent = false
@export var show_continent_mask = false
@export var show_mountain = false
@export var show_mountain_mask = false

@export_category("Color Map")
var plain_texture: NoiseTexture2D
@export var plain_noise: FastNoiseLite
var plain_gradient: Gradient
var plain_color = [Color("8FB569FF"), Color("D8C97AFF"), Color("A8D281FF"), Color("5E8C31FF"), Color("F0E6C7FF")]

var hill_texture: NoiseTexture2D
@export var hill_noise: FastNoiseLite
var hill_gradient: Gradient
var hill_color = [Color("6B9A5EFF"), Color("8A7F4EFF"), Color("5A7F4CFF"), Color("B8A37AFF"), Color("4A6B42FF")]

var mountain_texture: NoiseTexture2D
@export var mountain_noise: FastNoiseLite
var mountain_gradient: Gradient
var mountain_color = [Color("4A7C59FF"), Color("6E8F6EFF"), Color("3E5F47FF"), Color("9CA892FF"), Color("8B7E5BFF")]

var high_mountain_texture: NoiseTexture2D
@export var high_mountain_noise: FastNoiseLite
var high_mountain_gradient: Gradient
var high_mountain_color = [Color("5D6D64FF"), Color("7A8B8CFF"), Color("A3B4A5FF"), Color("4B5A56FF"), Color("C2C9C0FF")]

# To do
#var peak_color = [Color("5D6D64FF"), Color("7A8B8CFF"), Color("A3B4A5FF"), Color("4B5A56FF"), Color("C2C9C0FF")]

@export_category("ambient occlusion")
@export var ao_res = 256
var ao_img: Image

@onready var debug_node = $"../Debug"

var next_quadtree = []
var current_quadtree = []
var current_mesh_instances = {}
var camera: Camera3D
var camera_last_position: Vector3

func _ready() -> void:
	for child in get_children():
		child.queue_free()

	if Engine.is_editor_hint():
		camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	else:
		printerr("need to add ingame camera")
		
	setup_noise()
	setup_colormap()
	setup_ao()

	material.set_shader_parameter("plain_mask", plain_texture)
	material.set_shader_parameter("hill_mask", hill_texture)
	material.set_shader_parameter("mountain_mask", mountain_texture)
	material.set_shader_parameter("high_mountain_mask", high_mountain_texture)
	
	if not keep_terrain:
		find_seed()
		
	update_quadtree()

func _process(delta: float) -> void:
	if camera.global_position.distance_to(camera_last_position) > 200.0:
		camera_last_position = camera.global_position
		update_quadtree()
		
	if live_update:
		elapsed += delta
		if elapsed >= wait_time:
			elapsed = 0.0
			for child in get_children():
				child.queue_free()
			current_mesh_instances.clear()
			current_quadtree.clear()
			next_quadtree.clear()
			setup_noise()
			update_quadtree()

func update_quadtree():
	var root_rect2 = Rect2(Vector2.ZERO, Vector2.ONE * size)
	
	next_quadtree.clear()
	subdivide_rect2(root_rect2, 0)
	
	if next_quadtree == current_quadtree:
		#print("same quadtree")
		return
	
	generate_quadtree()

func subdivide_rect2(parent_rect2: Rect2, depth: int):
	if depth >= max_depth:
		next_quadtree.append(parent_rect2)
		return
	
	var center = parent_rect2.get_center()
	var center_3d = Vector3(center.x, 0, center.y)
	center_3d.y = get_altitude_at(center_3d)
	
	var half_size = parent_rect2.size.x / 2
	var half_extend = Vector2(half_size, half_size)
	var parent_pos = parent_rect2.position
	var children_rect2 = [
		Rect2(parent_pos, half_extend),
		Rect2(parent_pos + Vector2(half_size, 0), half_extend),
		Rect2(parent_pos + Vector2(0, half_size), half_extend),
		Rect2(parent_pos + Vector2(half_size, half_size), half_extend),
		]
		
	if camera.global_position.distance_to(center_3d) < parent_rect2.size.x * scale_distance:
		for child_rect2 in children_rect2:
			subdivide_rect2(child_rect2, depth + 1)
	else:
		next_quadtree.append(parent_rect2)

func generate_quadtree():
	# Quick optimization
	for rect2 in current_quadtree:
		if not next_quadtree.has(rect2):
			var mesh_instance = current_mesh_instances[rect2]
			mesh_instance.queue_free()
			current_mesh_instances.erase(rect2)
	
	for rect2: Rect2 in next_quadtree:
		# Quick optimization
		if current_quadtree.has(rect2):
			continue
			
		var array_mesh = generate_mesh(rect2)
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = array_mesh
		add_child(mesh_instance)
		mesh_instance.position = Vector3(rect2.position.x, 0, rect2.position.y)
		# mesh_instance.owner = get_tree().edited_scene_root
		
		current_mesh_instances[rect2] = mesh_instance
	
	current_quadtree.clear()
	current_quadtree = next_quadtree.duplicate()

func setup_noise():
	if continent == null:
		continent = FastNoiseLite.new()
	continent.seed = seed
	continent.frequency = continent_frequency / noise_scale
	
	if mountain == null:
		mountain = FastNoiseLite.new()
	mountain.seed = seed + 2
	mountain.frequency = mountain_frequency / noise_scale
	
	if hill == null:
		hill = FastNoiseLite.new()
	hill.seed = seed + 3
	hill.frequency = hill_frequency / noise_scale

func setup_colormap():
	plain_texture = NoiseTexture2D.new()
	if plain_noise == null:
		plain_noise = FastNoiseLite.new()
	plain_gradient = Gradient.new()
	plain_gradient.set_color(0, plain_color[0])
	plain_gradient.set_color(1, plain_color[4])
	plain_gradient.add_point(0.25, plain_color[1])
	plain_gradient.add_point(0.5, plain_color[2])
	plain_gradient.add_point(0.75, plain_color[3])
	plain_texture.noise = plain_noise
	plain_texture.color_ramp = plain_gradient
	
	hill_texture = NoiseTexture2D.new()
	if hill_noise == null:
		hill_noise = FastNoiseLite.new()
	hill_gradient = Gradient.new()
	hill_gradient.set_color(0, hill_color[0])
	hill_gradient.set_color(1, hill_color[4])
	hill_gradient.add_point(0.25, hill_color[1])
	hill_gradient.add_point(0.5, hill_color[2])
	hill_gradient.add_point(0.75, hill_color[3])
	hill_texture.noise = hill_noise
	hill_texture.color_ramp = hill_gradient
	
	mountain_texture = NoiseTexture2D.new()
	if mountain_noise == null:
		mountain_noise = FastNoiseLite.new()
	mountain_gradient = Gradient.new()
	mountain_gradient.set_color(0, mountain_color[0])
	mountain_gradient.set_color(1, mountain_color[4])
	mountain_gradient.add_point(0.25, mountain_color[1])
	mountain_gradient.add_point(0.5, mountain_color[2])
	mountain_gradient.add_point(0.75, mountain_color[3])
	mountain_texture.noise = mountain_noise
	mountain_texture.color_ramp = mountain_gradient
	
	high_mountain_texture = NoiseTexture2D.new()
	if high_mountain_noise == null:
		high_mountain_noise = FastNoiseLite.new()
	high_mountain_gradient = Gradient.new()
	high_mountain_gradient.set_color(0, high_mountain_color[0])
	high_mountain_gradient.set_color(1, high_mountain_color[4])
	high_mountain_gradient.add_point(0.25, high_mountain_color[1])
	high_mountain_gradient.add_point(0.5, high_mountain_color[2])
	high_mountain_gradient.add_point(0.75, high_mountain_color[3])
	high_mountain_texture.noise = high_mountain_noise
	high_mountain_texture.color_ramp = high_mountain_gradient

func setup_ao():
	var pixel_size = size / ao_res  # assuming 'size' is world size, 'ao_res' is texture resolution
	ao_img = Image.create(ao_res, ao_res, false, Image.FORMAT_L8) # grayscale 8-bit
	ao_img.fill(Color.WHITE)
	
	# Initialize height map
	var height_map = []
	for y in range(ao_res):
		var row = []
		for x in range(ao_res):
			var point = Vector3((x + 0.5) * pixel_size, 0, (y + 0.5) * pixel_size)
			row.append((get_altitude_at(point) / altitude) / 2.0 + 0.5) # normalize to [0,1]
		height_map.append(row)

	# === Key: set sample distance ===
	var step = 4  # AO feature size
	var strength = 2.0  # amplification
	var bias = 0.5

	for y in range(ao_res):
		for x in range(ao_res):
			var center = height_map[y][x]
			
			# Skip underwater
			if center < 0.5:
				continue

			# Sample neighbors at 'step' distance
			var left   = height_map[y][max(0, x - step)]
			var right  = height_map[y][min(ao_res - 1, x + step)]
			var top    = height_map[max(0, y - step)][x]
			var bottom = height_map[min(ao_res - 1, y + step)][x]

			# Laplacian over larger area
			var laplacian = (left + right + top + bottom - 4.0 * center)
			var ao_value = -laplacian * strength + bias

			ao_value = clamp(ao_value, 0.0, 1.0)
			ao_img.set_pixel(x, y, Color(ao_value, ao_value, ao_value))

	var texture = ImageTexture.create_from_image(ao_img)
	material.set_shader_parameter("ao_mask", texture)

func find_seed():
	var max_try = 500
	var grid_resolution = 8
	var half_size = float(size / 2)
	var quarter_size = float(size / 4)
	
	var min_valid_points = pow(grid_resolution, 2) / 2
	var grid_step = float(half_size / grid_resolution)
	
	while max_try > 0:
		max_try -= 1
		if max_try <= 0:
			printerr("no seed found")
			return
		
		seed = randi()
		setup_noise()
		
		var valid_points = 0
		
		for z in range(grid_resolution):
			for x in range(grid_resolution):
				var point = Vector3(x + 0.5, 0, z + 0.5) * grid_step + Vector3.ONE * quarter_size
				point.y = get_altitude_at(point)
				if point.y > 100 and point.y < 1000:
					valid_points += 1
					
		if valid_points >= min_valid_points:
			return

func generate_mesh(bounds: Rect2) -> ArrayMesh:
	var vertices = PackedVector3Array([])
	var normals = PackedVector3Array([])
	var uvs = PackedVector2Array([])
	var indices = PackedInt32Array([])
	
	var step = float(bounds.size.x / (resolution - 1))
	var offset = Vector3(bounds.position.x, 0, bounds.position.y)
	
	for z in range(resolution):
		for x in range(resolution):
			var point = Vector3(x, 0, z) * step
			var point_world = point + offset
			point.y = get_altitude_at(point_world)
			vertices.append(point)
			uvs.append(Vector2(point_world.x / size, point_world.z / size))
			
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO
		
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var i0 = z * (resolution) + x
			var i1 = i0 + 1
			var i2 = (z + 1) * resolution + x
			var i3 = i2 + 1
			
			indices.append(i0)
			indices.append(i1)
			indices.append(i2)
			indices.append(i1)
			indices.append(i3)
			indices.append(i2)
			
			# Compute face normals
			var v0 = vertices[i0]
			var v1 = vertices[i1]
			var v2 = vertices[i2]
			var v3 = vertices[i3]
			
			var n1 = (v2 - v0).cross(v1 - v0).normalized()
			var n2 = (v2 - v1).cross(v3 - v1).normalized()
			
			normals[i0] += n1
			normals[i1] += n1 + n2
			normals[i2] += n1 + n2
			normals[i3] += n2
			
	# Normalize accumulated normalrs
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
		
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	array_mesh.surface_set_material(0, material)
	
	return array_mesh

func get_altitude_at(point: Vector3) -> float:
	var continent_value = continent.get_noise_2d(point.x, point.z)
	var continent_mask = smoothstep(-0.1, 0.1, continent_value)
	continent_value = remap(continent_value, -1.0, 1.0, -2.0, 2.0)
	
	var mountain_value = mountain.get_noise_2d(point.x, point.z)
	mountain_value = remap(mountain_value, -1.0, 1.0, -2.0, 2.0)
	var mountain_mask = smoothstep(-0.1, 0.1, mountain_value)
	mountain_mask *= continent_mask
	
	var hill_value = hill.get_noise_2d(point.x, point.z)
	hill_value = remap(hill_value, -1.0, 1.0, -0.1, 0.1)
	hill_value = abs(hill_value)
	
	var continent_flat = lerp(continent_value, lerp(continent_value + hill_value, hill_value, flatten_terrain), continent_mask)
	var result = lerp(continent_flat, mountain_value + 0.1, mountain_mask)
	
	if show_continent:
		return continent_value * altitude
	if show_continent_mask:
		return continent_mask * altitude
	if show_mountain:
		return mountain_value * altitude
	if show_mountain_mask:
		return mountain_mask * altitude
	
	return result * altitude

func get_normal_at(point: Vector3, offset: float) -> Vector3:
	return Vector3.ZERO
