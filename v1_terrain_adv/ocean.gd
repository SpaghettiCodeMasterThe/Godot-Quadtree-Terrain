@tool
extends Node3D

@export var chunk_size = 100
@export var num_chunks = 10
var chunk_resolutions = [64,16,8]
@export var uv_scale = 1.0
var material = preload("res://materials/ocean.material")

var ocean_chunks = {}
#@onready var camera_node = $"../Camera"
var camera_last_position: Vector3
var camera: Camera3D

func _ready() -> void:
	for child in get_children():
		child.queue_free()
		
	if Engine.is_editor_hint():
		camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
		
	camera_last_position = camera.global_position
	
	init_chunks()
	update_chunks()
	
func _process(delta: float) -> void:
	if camera_last_position.distance_to(camera.global_position) > 20:
		camera_last_position = camera.global_position
		update_chunks()
	
func init_chunks():
	ocean_chunks.clear()
	for x in range(num_chunks):
		for z in range(num_chunks):
			var chunk_position = Vector3(x * chunk_size, 0, z * chunk_size)
			ocean_chunks[chunk_position] = {}
			for lod in chunk_resolutions:
				ocean_chunks[chunk_position][lod] = null
	
func update_chunks():
	for chunk_position in ocean_chunks.keys():
		# Select lod
		var chunk_center = chunk_position + Vector3(chunk_size/2, 0, chunk_size/2)
		var distance = chunk_center.distance_to(camera.global_position)
		
		var selected_lod = chunk_resolutions[2]
		
		if distance < chunk_size * 2:
			selected_lod = chunk_resolutions[0]
		elif distance < chunk_size * 4:
			selected_lod = chunk_resolutions[1]
			
		# Generate, show or hide chunk
		for lod in ocean_chunks[chunk_position]:
			if lod == selected_lod:
				if ocean_chunks[chunk_position][lod] == null:
					#print("generate chunk")
					generate_chunk(chunk_position, selected_lod)
				else:
					#print("make chunk visible")
					ocean_chunks[chunk_position][lod].visible = true
			else:
				if not ocean_chunks[chunk_position][lod] == null:
					#print("test")
					ocean_chunks[chunk_position][lod].visible = false

func generate_chunk(chunk_position: Vector3, resolution: int):
	var steps = chunk_size / float(resolution - 1)
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for x in range(resolution):
		for z in range(resolution):
			var vertex = Vector3(x * steps, 0, z * steps)
			var world_pos = vertex + chunk_position
			var uv = Vector2(world_pos.x, world_pos.z) * uv_scale
			surface_tool.set_uv(uv)
			surface_tool.add_vertex(vertex)
			
	for x in range(resolution - 1):
		for z in range(resolution - 1):
			
			var bl := z * resolution + x          # bottom-left
			var br := z * resolution + (x + 1)    # bottom-right
			var tl := (z + 1) * resolution + x    # top-left
			var tr := (z + 1) * resolution + (x + 1)  # top-right
			
			surface_tool.add_index(bl)
			surface_tool.add_index(tl)
			surface_tool.add_index(br)
			
			surface_tool.add_index(br)
			surface_tool.add_index(tl)
			surface_tool.add_index(tr)
	
	surface_tool.index()
	surface_tool.generate_normals()
	#surface_tool.generate_tangents()
	var meshinstance = MeshInstance3D.new()
	meshinstance.mesh = surface_tool.commit()
	meshinstance.set_surface_override_material(0, material)
	meshinstance.position = chunk_position
	add_child(meshinstance)
	ocean_chunks[chunk_position][resolution] = meshinstance
