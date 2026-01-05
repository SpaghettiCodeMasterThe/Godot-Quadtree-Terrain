@tool
extends Node3D

#@export var keep_forest_mask = false
@export_range(64,2048) var masks_resolution = 256 # Remove (change noise frequency to keep aspect) to use res less than 64
@export_category("Forest")
@export var forest_min_height = 15
@export var forest_max_height = 2200
@export var forest_min_slope_degree = 7.0
@export_category("Cities")
@export var preview_noise_texture = false
@export var cities_mask_config: NoiseTexture2D # WARNING Configure color ramp to see more cities
@export var cities_min = 290.0
@export var cities_max = 1000.0
@export var cities_slope_max = 10.0

@export_category("Result")
@export var keep_result = false
@export var forest_mask: ImageTexture
@export var cities_mask: ImageTexture

@onready var manager_node = $"../Manager"

var terrain_noise: TerrainNoise

var terrain_material = preload("res://materials/terrain.material")

func _ready() -> void:
	terrain_noise = manager_node.terrain_node.terrain_noise
	if terrain_noise == null:
		printerr("no terrain noise resource found for masks.gd")
		return
	
	if not keep_result or forest_mask == null or cities_mask == null:
		generate_cities_mask()
		# Need to wait 1 frame until mask is generated
		await get_tree().process_frame 
		
		generate_forest_mask()
		# Need to wait 1 frame until mask is generated
		await get_tree().process_frame 
	
	terrain_material.set_shader_parameter("cities_mask", cities_mask)
	if preview_noise_texture:
		terrain_material.set_shader_parameter("cities_mask", cities_mask_config)
	
	terrain_material.set_shader_parameter("forest_mask", forest_mask)
	
	# Need to wait 1 frame until mask is generated
	manager_node.masks_done()

func generate_cities_mask():
	# Create base mask for cities
	if cities_mask_config == null:
		cities_mask_config = NoiseTexture2D.new()
	
		cities_mask_config.noise = FastNoiseLite.new()
		cities_mask_config.noise.seed = randi()
		cities_mask_config.noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		cities_mask_config.noise.frequency = 0.1

		cities_mask_config.color_ramp = Gradient.new()
		cities_mask_config.color_ramp.set_offset(0,0.75)
		cities_mask_config.color_ramp.set_offset(1,0.76)
		
		# Apply resolution here too so we have correct last_res
		cities_mask_config.height = masks_resolution
		cities_mask_config.width = masks_resolution
	
	# Apply resolution on existing config
	var last_res = cities_mask_config.get_height()
	cities_mask_config.height = masks_resolution
	cities_mask_config.width = masks_resolution
	
	# If we change masks resolution on existing config change noise frequency to keep aspect
	if masks_resolution < 64:
		printerr("mask resolution is less than 64 and will produce error with noise scale")
	if cities_mask != null:
		var scale_adjust = masks_resolution / float(last_res)
		cities_mask_config.noise.frequency /= float(scale_adjust)
	
	# Wait image to be generated
	await cities_mask_config.changed
	
	var cities_mask_config_image: Image = cities_mask_config.get_image()
	
	if cities_mask_config_image.get_width() != masks_resolution:
		print("error, resolution mismatch (cities_mask_config_image) in generate_cities_mask()")
		return
	
	# Test terrain
	var step = manager_node.terrain_node.terrain_size / float(masks_resolution - 1)
	
	for x in range(masks_resolution):
		for y in range(masks_resolution):
			# No active pixel
			var pixel: Color = cities_mask_config_image.get_pixel(x, y)
			if pixel.r < 1.0: # Only 0.0 or 1.0 pixel
				cities_mask_config_image.set_pixel(x,y,Color.BLACK)
				continue
			# Height
			var world_position = Vector3(x * step, 0, y * step)
			world_position.y = terrain_noise.get_altitude_at(world_position)
			if world_position.y > cities_max or world_position.y < cities_min:
				cities_mask_config_image.set_pixel(x,y,Color.BLACK)
				continue
			# Normal
			var normal = terrain_noise.get_normal_at(world_position)
			var slope_degree = rad_to_deg(acos(normal.dot(Vector3.UP)))
			if slope_degree > cities_slope_max:
				cities_mask_config_image.set_pixel(x,y,Color.BLACK)
				continue
	
	var texture = ImageTexture.new()
	texture = ImageTexture.create_from_image(cities_mask_config_image)
	cities_mask = texture

func generate_forest_mask():
	var cities_mask_image: Image = cities_mask.get_image()
	
	if cities_mask_image.get_width() != masks_resolution:
		print("error, resolution mismatch (cities_mask_image) in (generate_forest_mask())")
		return
	
	var forest_mask_image:Image = Image.create(masks_resolution, masks_resolution, false, Image.FORMAT_R8)
	forest_mask_image.fill(Color.BLACK)
	var step = manager_node.terrain_node.terrain_size / float(masks_resolution - 1)
	
	if forest_mask_image.get_width() != masks_resolution:
		print("error, resolution mismatch (forest_mask_image) (generate_forest_mask())")
		return
	
	for x in range(masks_resolution):
		for z in range(masks_resolution):
			# Test for city
			var city_pixel: Color = cities_mask_image.get_pixel(x, z)
			if city_pixel.r > 0.5:
				continue
			
			var point = Vector3(x * step, 0, z * step)
			point.y = terrain_noise.get_altitude_at(point)
			
			var normal = terrain_noise.get_normal_at(point, step)
			var slope = 1.0 - normal.y
			slope = clamp(slope, 0.0, 1.0)
			var slope_degree = rad_to_deg(acos(1.0 - slope))
			
			# Forest strength
			var strength = 0.0
			if point.y > forest_min_height and slope_degree > forest_min_slope_degree:
				if point.y < forest_max_height:
					strength = 1.0
			
			forest_mask_image.set_pixel(x, z, Color(strength,strength,strength))
	
	var texture = ImageTexture.new()
	texture = ImageTexture.create_from_image(forest_mask_image)
	forest_mask = texture
