@tool
class_name TerrainNoise

var altitude: float
var size: float
var seed: int
var keep_seed = false

var continent_flattness = 0.9
var continent_noise = FastNoiseLite.new()
var mountain_shape = FastNoiseLite.new()
var mountain_noise = FastNoiseLite.new()
var hill_noise = FastNoiseLite.new()

func _init(_altitude: float, _size: float, _keep_seed: bool, _seed:int):
	altitude = _altitude
	size = _size
	keep_seed = _keep_seed
	seed = _seed

func setup() -> int:
	continent_noise.noise_type = FastNoiseLite.TYPE_VALUE
	continent_noise.frequency = 0.00001
	
	mountain_shape.noise_type = FastNoiseLite.TYPE_PERLIN
	mountain_shape.frequency = 0.00003
	
	mountain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	mountain_noise.frequency = 0.0001
	mountain_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	
	hill_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	hill_noise.frequency = 0.0001
	
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
	var continent_mask = smoothstep(-0.1, 0.1, continent_value)
	
	var mountain_shape_value = mountain_shape.get_noise_2d(point.x, point.z)
	var mountain_shape_mask = smoothstep(0.0, 0.5, mountain_shape_value)
	mountain_shape_mask *= continent_mask
	
	var mountain_noise_value = mountain_noise.get_noise_2d(point.x, point.z)
	mountain_noise_value = remap(mountain_noise_value, -1.0, 1.0, 0.0, 1.0)
	
	var hill_value = hill_noise.get_noise_2d(point.x, point.z)
	hill_value = abs(hill_value)
	hill_value = remap(hill_value, 0.0, 1.0, 0.0, 0.3)
	hill_value -= 0.01
	
	var continent_flatten = lerp(continent_value, lerp(continent_value, hill_value, continent_flattness), continent_mask)
	var result = lerp(continent_flatten, mountain_noise_value, mountain_shape_mask)
	
	return result * altitude

func get_normal(point: Vector3, step: float) -> Vector3:
	var h = get_altitude(point)
	var hx = get_altitude(Vector3(point.x + step, 0, point.z)) - get_altitude(Vector3(point.x - step, 0, point.z))
	var hz = get_altitude(Vector3(point.x, 0, point.z + step)) - get_altitude(Vector3(point.x, 0, point.z - step))
	
	var normal = Vector3(-hx / (2 * step), 1.0, -hz / (2 * step))
	return normal.normalized()
