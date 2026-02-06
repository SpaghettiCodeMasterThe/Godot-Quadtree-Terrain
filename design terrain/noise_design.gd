@tool
extends Node

var altitude: float
var size: float
var seed: int
var keep_seed = false

@export var continent_flattness = 0.9
@export var continent_noise: FastNoiseLite
@export var mountain_shape: FastNoiseLite
@export var mountain_noise: FastNoiseLite
@export var hill_noise: FastNoiseLite

@onready var terrain_node = $"../Terrain"

@export_category("1/10000")
@export var continent_noise_frequency = 0.1
@export var mountain_shape_frequency = 0.3
@export var mountain_noise_frequency = 1.0
@export var hill_noise_frequency = 1.0

@export_category("Show_noise")
@export var show_continent = false
@export var show_mountain_shape = false
@export var show_mountain_noise = false
@export var show_hill = false

@export_category("Show_mask")
@export var show_continent_mask = false
@export var show_mountain_mask = false

@export_category("Mix")
@export var show_flatten_continent = false

@export_category("Reset noises")
@export_tool_button("Danger this will erase all your work","ArrowDown")
var button = null
@export var use_best_values = false
var b_continent_noise_type = FastNoiseLite.TYPE_VALUE
var b_continent_noise_frequency = 0.1
var b_mountain_shape_type = FastNoiseLite.TYPE_PERLIN
var b_mountain_shape_frequency = 0.3
var b_mountain_noise_type = FastNoiseLite.TYPE_PERLIN
var b_mountain_noise_frequency = 1.0
var b_mountain_noise_fractal_type = FastNoiseLite.FRACTAL_RIDGED
var b_hill_noise_type = FastNoiseLite.TYPE_PERLIN
var b_hill_noise_frequency = 1.0

func _ready():
	altitude = terrain_node.altitude
	size = terrain_node.size
	keep_seed = terrain_node.keep_seed
	seed = terrain_node.seed
		
	terrain_node.seed = setup_noises()

func setup_noises() -> int:
	if continent_noise == null or use_best_values:
		continent_noise = FastNoiseLite.new()
		continent_noise.noise_type = b_continent_noise_type
		continent_noise_frequency = b_continent_noise_frequency
		
	if mountain_shape == null or use_best_values:
		mountain_shape = FastNoiseLite.new()
		mountain_shape.noise_type = b_mountain_shape_type
		mountain_shape_frequency = b_mountain_shape_frequency
		
	if mountain_noise == null or use_best_values:
		mountain_noise = FastNoiseLite.new()
		mountain_noise.noise_type = b_mountain_noise_type
		mountain_noise.fractal_type = b_mountain_noise_fractal_type
		mountain_noise_frequency = b_mountain_noise_frequency
		
	if hill_noise == null or use_best_values:
		hill_noise = FastNoiseLite.new()
		hill_noise.noise_type = b_hill_noise_type
		hill_noise_frequency = b_hill_noise_frequency
	
	if use_best_values:
		use_best_values = false
	
	continent_noise.frequency = continent_noise_frequency / 10000
	mountain_shape.frequency = mountain_shape_frequency / 10000
	mountain_noise.frequency = mountain_noise_frequency / 10000
	hill_noise.frequency = hill_noise_frequency / 10000

	if not keep_seed:
		find_seed()
	else:
		continent_noise.seed = seed
		mountain_shape.seed = seed
		mountain_noise.seed = seed
		hill_noise.seed = seed
		
	return seed

func find_seed():
	const grid_res = 8
	var half_size = size / 2
	var quarter_size = half_size / 2
	var offset = Vector3(quarter_size, 0, quarter_size)
	var step = half_size / float(grid_res)
	var max_try = 1000
	var min_valid = pow(grid_res, 2) / 2
	
	while max_try > 0:
		max_try -= 1
		if max_try <= 0:
			printerr("No seed found")
		
		var valid_points = 0
		seed = randi()
		continent_noise.seed = seed
		mountain_shape.seed = seed
		mountain_noise.seed = seed
		hill_noise.seed = seed
			
		for z in range(grid_res):
			for x in range(grid_res):
				var world_pos = Vector3(x + 0.5, 0, z + 0.5) * step + offset
				world_pos.y = get_altitude(world_pos)
				if world_pos.y > 0:
					valid_points += 1
		
		if valid_points > min_valid:
			return

func get_altitude(point: Vector3) -> float:
	var continent_value = continent_noise.get_noise_2d(point.x, point.z)
	continent_value = remap(continent_value, -1.0, 1.0, -2.0, 2.0)
	if show_continent:
		return continent_value * altitude
	var continent_mask = smoothstep(-0.1, 0.1, continent_value)
	if show_continent_mask:
		return continent_mask * altitude
	
	var mountain_shape_value = mountain_shape.get_noise_2d(point.x, point.z)
	if show_mountain_shape:
		return mountain_shape_value * altitude
	var mountain_shape_mask = smoothstep(0.0, 0.5, mountain_shape_value)
	if show_mountain_mask:
		return mountain_shape_mask * altitude
	mountain_shape_mask *= continent_mask
	
	var mountain_noise_value = mountain_noise.get_noise_2d(point.x, point.z)
	mountain_noise_value = remap(mountain_noise_value, -1.0, 1.0, 0.0, 1.0)
	if show_mountain_noise:
		return mountain_noise_value * altitude
	
	var hill_value = hill_noise.get_noise_2d(point.x, point.z)
	hill_value = abs(hill_value)
	hill_value = remap(hill_value, 0.0, 1.0, 0.0, 0.3)
	hill_value -= 0.01
	if show_hill:
		return hill_value * altitude
	
	var continent_flatten = lerp(continent_value, lerp(continent_value, hill_value, continent_flattness), continent_mask)
	if show_flatten_continent:
		return continent_flatten * altitude
	var result = lerp(continent_flatten, mountain_noise_value, mountain_shape_mask)
	
	return result * altitude

func get_normal(point: Vector3, step: float) -> Vector3:
	var h = get_altitude(point)
	var hx = get_altitude(Vector3(point.x + step, 0, point.z)) - get_altitude(Vector3(point.x - step, 0, point.z))
	var hz = get_altitude(Vector3(point.x, 0, point.z + step)) - get_altitude(Vector3(point.x, 0, point.z - step))
	
	var normal = Vector3(-hx / (2 * step), 1.0, -hz / (2 * step))
	return normal.normalized()
