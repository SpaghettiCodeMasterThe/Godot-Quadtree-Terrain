@tool
class_name TerrainMesh

var terrain_noise: TerrainNoise
var resolution: int

func _init(_resolution: int, _terrain_noise: TerrainNoise) -> void:
	resolution = _resolution
	terrain_noise = _terrain_noise
	
func generate_arrays(rect2: Rect2) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	
	var step = float(rect2.size.x) / (resolution - 1)
	
	# Generate vertices, normals, UVs
	for i in range(resolution):
		for j in range(resolution):
			var local_pos = Vector3(float(i), 0.0, float(j)) * step
			var world_pos = Vector3(rect2.position.x, 0, rect2.position.y) + local_pos
			world_pos.y = terrain_noise.get_altitude(world_pos)
			vertices.append(world_pos)
			normals.append(terrain_noise.get_normal(world_pos, step))
			uvs.append(Vector2(float(i) / (resolution - 1), float(j) / (resolution - 1)))

	# Generate triangle indices
	for i in range(resolution - 1):
		for j in range(resolution - 1):
			var a = i * resolution + j
			var b = i * resolution + (j + 1)
			var c = (i + 1) * resolution + j
			var d = (i + 1) * resolution + (j + 1)
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)
			
	# Build final mesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	return {"arrays": arrays}
