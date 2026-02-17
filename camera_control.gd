extends Node3D

@export var pan_center: Node3D

@export_group("Movement Settings")
@export var look_sensitivity: float = 0.5
@export var pan_speed: float = 0.5

@export_group("Constraints")
@export var min_pitch: float = -80.0 # Degrees
@export var max_pitch: float = -10.0 # Degrees (looking down)

var _mouse_input = false
var _rotation_input = Vector2.ZERO
var _pan_input = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	# Check for rotation (Right Click)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_input = event.pressed
		if event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Check for panning (Left Click)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_input = event.pressed
		if event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Handle Mouse Motion
	if event is InputEventMouseMotion and _mouse_input:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_rotation_input = event.relative
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_pan_input = event.relative

func _ready() -> void:
	look_sensitivity *= 0.01
	pan_speed *= 0.01

func _process(_delta: float) -> void:
	_update_rotation()
	_update_panning()

func _update_rotation():
	# Rotate the pivot around the Y axis (yaw)
	rotate_y(-_rotation_input.x * look_sensitivity)
	
	# Rotate the inner gimbal/camera around the X axis (pitch)
	# We use the child camera to avoid "tilting" the whole coordinate system
	var camera = get_child(0)
	camera.rotate_x(-_rotation_input.y * look_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, -deg_to_rad(85), deg_to_rad(85))
	
	_rotation_input = Vector2.ZERO

func _update_panning():
	if _pan_input.length() > 0:
		# Calculate movement vectors relative to the current Y rotation
		# This ensures 'Forward' is always where the camera is facing horizontally
		var forward = -transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		
		var right = transform.basis.x
		right.y = 0
		right = right.normalized()
		
		# Calculate final translation
		# Panning left/right (x) and forward/backward (y)
		var motion = (right * -_pan_input.x) + (forward * _pan_input.y)
		global_translate(motion * pan_speed)
		
		_pan_input = Vector2.ZERO
