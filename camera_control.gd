extends Node3D

@export var pan_center: Node3D
@export var camera: Camera3D
@export var indicator_sphere: MeshInstance3D

@export_group("Movement Settings")
@export var look_sensitivity: float = 0.5
@export var pan_speed: float = 0.5
@export var kb_look_sensitivity: float = 3
@export var kb_pan_speed: float = 2
@export var look_smoothing: float = 10.0

@export_group("Zoom Settings")
@export var zoom_speed: float = 0.8
@export var kb_zoom_speed: float = 4
@export var min_zoom: float = 2.0
@export var max_zoom: float = 20.0
@export var zoom_smoothing: float = 10.0

@export_group("Constraints")
@export var min_pitch: float = -90.0 # Degrees
@export var max_pitch: float = 10.0 # Degrees (looking down)
@export var min_distance: float = 3
@export var max_distance: float = 10

@export_group("Debug")
@export var debug: bool = false
@export var label: Label3D

var _mouse_input = false
var _rotation_input = Vector2.ZERO
var _pan_input = Vector2.ZERO
var _target_zoom : float = 5.0
var _is_dragging: bool = false
var _drag_start_pos = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	# Check for rotation (Right Click)
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_LEFT]:
			_mouse_input = event.pressed
			if event.pressed:
				_is_dragging = true
				_drag_start_pos = event.position # Save where we started
			else:
				_is_dragging = false
				# SNAP BACK: Move the mouse back to where the drag started
				Input.warp_mouse(_drag_start_pos)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# 2. Handle Scroll Wheel (Zoom)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = max(_target_zoom - zoom_speed, min_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = min(_target_zoom + zoom_speed, max_zoom)

	# Handle Mouse Motion
	if event is InputEventMouseMotion and _mouse_input:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_rotation_input += event.relative
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_pan_input += event.relative

func _handle_keyboard_input(delta: float) -> void:	
	var input_dir = Input.get_vector("move_right", "move_left", "move_forward", "move_backward")
	_pan_input += Vector2(input_dir.x, -input_dir.y) * kb_pan_speed

	var rot_dir = Input.get_vector("rotate_right", "rotate_left", "rotate_down", "rotate_up")
	_rotation_input += rot_dir * kb_look_sensitivity
	
	var zoom_dir = Input.get_axis("zoom_in", "zoom_out")
	_target_zoom = clamp(_target_zoom + (zoom_dir * kb_zoom_speed * delta), min_zoom, max_zoom)

func _apply_movement(delta: float) -> void:
	var sprint: float = 1.0
	
	if Input.is_action_pressed("sprint"):
		sprint = 2.0
		label.text += "\nsprint"
	else:
		sprint = 1.0
	
	if _rotation_input.length() > 0:
		rotate_y(-_rotation_input.x * look_sensitivity)
		
		var current_pitch_rad = pan_center.rotation.x
		var change = -_rotation_input.y * look_sensitivity
		var new_pitch = clamp(rad_to_deg(current_pitch_rad + change), min_pitch, max_pitch)
		
		pan_center.rotation.x = deg_to_rad(new_pitch)
		_rotation_input = Vector2.ZERO

	# APPLY PANNING (Mouse + Keyboard influences)
	if _pan_input.length() > 0:
		var forward = -global_transform.basis.z * sprint
		forward.y = 0
		var right = global_transform.basis.x * sprint
		right.y = 0
		
		var direction = (right.normalized() * -_pan_input.x) + (forward.normalized() * _pan_input.y)
		# We use global_translate for the pan so it moves the whole system
		global_translate(direction * pan_speed)
		_pan_input = Vector2.ZERO # Reset for next frame

func _update_raycast() -> void:
	if not indicator_sphere: return
	
	# 1. Get Mouse Position
	var mouse_pos = get_viewport().get_mouse_position()
	
	# 2. Project ray from camera
	var ray_length = 1000
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * ray_length
	
	# 3. Perform the physics query
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	# 4. Handle collision
	if result:
		indicator_sphere.visible = true
		indicator_sphere.global_position = result.position
	else:
		indicator_sphere.visible = false

func _ready() -> void:
	look_sensitivity *= 0.01
	pan_speed *= 0.01

func _process(_delta: float) -> void:
	_handle_keyboard_input(_delta)
	_apply_movement(_delta)
	_update_scroll(_delta)
	_update_raycast()
	if debug:
		label.text = "tgt zoom : " + str(_target_zoom)
	
func _update_scroll(delta) -> void:
	camera.position.z = lerp(camera.position.z, _target_zoom, zoom_smoothing * delta)

'''func _update_orbit() -> void:
	if _rotation_input.length() > 0:
		rotate_y(-_rotation_input.x * look_sensitivity)
		
		var current_pitch_rad = pan_center.rotation.x
		var change = -_rotation_input.y * look_sensitivity
		var new_pitch = clamp(rad_to_deg(current_pitch_rad + change), min_pitch, max_pitch)
		
		pan_center.rotation.x = deg_to_rad(new_pitch)
		
		_rotation_input = Vector2.ZERO
'''
'''func _update_panning() -> void:
	if _pan_input.length() > 0:
		# Panning moves the pivot (the center of the orbit)
		# We use the horizontal forward/right vectors so panning stays flat
		var forward = -global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		
		var right = global_transform.basis.x
		right.y = 0
		right = right.normalized()
		
		# Calculate translation based on mouse relative motion
		var direction = (right * -_pan_input.x) + (forward * _pan_input.y)
		global_translate(direction * pan_speed)
		
		_pan_input = Vector2.ZERO
'''
