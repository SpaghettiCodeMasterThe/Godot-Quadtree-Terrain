extends Camera3D

# Configuration properties (adjust in Inspector)
@export var base_speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var acceleration: float = 10.0
@export var speed_wheel_factor: float = 1.3
@export var move_fast_multiplier: float = 5.0
@export_range(0.01, 1000.0) var min_speed_multiplier: float = 0.01
@export_range(0.01, 1000.0) var max_speed_multiplier: float = 10000.0

# Internal state
var speed_multiplier: float = 1000.0
var yaw: float = 0.0
var pitch: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var mouse_delta: Vector2 = Vector2.ZERO

func _ready():
	if not Engine.is_editor_hint():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Initialize rotation from current camera orientation
	var rot = rotation
	yaw = rot.y
	pitch = rot.x
	
	# Get environment and sun
	if get_world_3d().environment == null:
		get_world_3d().environment = create_default_environment()
		
	var sun_found = false
	for node in get_tree().current_scene.get_children(true):
		if node is DirectionalLight3D:
			sun_found = true
			break
	
	if not sun_found:
		var sun = create_default_sun()
		get_tree().current_scene.call_deferred("add_child", sun)

func _input(event: InputEvent) -> void:
	# ESC to quit game
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	
	# Capture mouse motion delta
	if event is InputEventMouseMotion:
		mouse_delta = event.relative
	
	# Mouse wheel for speed adjustment
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			speed_multiplier = min(speed_multiplier * speed_wheel_factor, max_speed_multiplier)
			print("Speed: %.2fx" % speed_multiplier)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			speed_multiplier = max(speed_multiplier / speed_wheel_factor, min_speed_multiplier)
			print("Speed: %.2fx" % speed_multiplier)

func _process(delta: float) -> void:
	_handle_rotation(delta)
	_handle_movement(delta)
	mouse_delta = Vector2.ZERO  # Reset after processing

func _handle_rotation(delta: float) -> void:
	# Apply mouse sensitivity to accumulated delta
	yaw -= mouse_delta.x * mouse_sensitivity
	pitch = clamp(pitch - mouse_delta.y * mouse_sensitivity, -PI/2 + 0.01, PI/2 - 0.01)
	
	# Apply rotation to camera
	rotation = Vector3(pitch, yaw, 0.0)

func _handle_movement(delta: float) -> void:
	# Get camera's LOCAL basis vectors (fully relative to camera orientation)
	var basis = global_transform.basis
	var forward = -basis.z  # Camera's forward direction
	var right = basis.x     # Camera's right direction
	var up = basis.y        # Camera's up direction (tilts with pitch!)
	
	# Build target velocity from input using LOCAL axes
	var target_velocity = Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):   # W
		target_velocity += forward
	if Input.is_action_pressed("move_backward"):  # S
		target_velocity -= forward
	if Input.is_action_pressed("move_left"):      # A
		target_velocity -= right
	if Input.is_action_pressed("move_right"):     # D
		target_velocity += right
	if Input.is_action_pressed("move_up"):        # E
		target_velocity += up      # Moves along camera's tilted up axis!
	if Input.is_action_pressed("move_down"):      # Q
		target_velocity -= up      # Moves along camera's tilted down axis!
	
	# Shift boost
	var current_speed_mult = speed_multiplier
	if Input.is_action_pressed("move_fast"):
		current_speed_mult *= move_fast_multiplier
	
	# Apply acceleration for smooth movement
	if target_velocity.length() > 0.01:
		target_velocity = target_velocity.normalized() * base_speed * current_speed_mult
		velocity = velocity.lerp(target_velocity, min(acceleration * delta, 1.0))
	else:
		velocity = velocity.lerp(Vector3.ZERO, min(acceleration * 2.0 * delta, 1.0))
	
	# Apply movement in world space
	global_transform.origin += velocity * delta

# Optional: Release mouse when window loses focus
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if not Engine.is_editor_hint():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func create_default_environment() -> Environment:
	var env = Environment.new()
	
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky.sky_material = sky_material
	env.sky = sky
	
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.background_mode = Environment.BG_SKY
	
	return env

func create_default_sun() -> DirectionalLight3D:
	var sun = DirectionalLight3D.new()
	sun.light_energy = 1.0
	sun.light_color = Color.WHITE
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, 30, 0)
	return sun
