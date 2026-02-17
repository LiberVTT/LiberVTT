extends Node3D

@export var pan_center: Node3D
@export var camera: Camera3D

@export_group("Movement Settings")
@export var look_sensitivity: float = 0.5
@export var pan_speed: float = 0.5

@export_group("Zoom Settings")
@export var zoom_speed: float = 0.8
@export var min_zoom: float = 2.0
@export var max_zoom: float = 20.0
@export var zoom_smoothing: float = 10.0

@export_group("Constraints")
@export var min_pitch: float = -80.0 # Degrees
@export var max_pitch: float = -10.0 # Degrees (looking down)
@export var min_distance: float = 3
@export var max_distance: float = 10

@export_group("Debug")
@export var label: Label3D

var _mouse_input = false
var _rotation_input = Vector2.ZERO
var _pan_input = Vector2.ZERO
var _target_zoom : float = 5.0

func _unhandled_input(event: InputEvent) -> void:
	# Check for rotation (Right Click)
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_LEFT]:
			_mouse_input = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		
		# 2. Handle Scroll Wheel (Zoom)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = max(_target_zoom - zoom_speed, min_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = min(_target_zoom + zoom_speed, max_zoom)

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
	_update_orbit()
	_update_panning()
	_update_scroll(_delta)
	label.text = "tgt zoom : " + str(_target_zoom)
	
func _update_scroll(delta) -> void:
	camera.position.z = lerp(camera.position.z, _target_zoom, zoom_smoothing * delta)

func _update_orbit() -> void:
	if _rotation_input.length() > 0:
		rotate_y(-_rotation_input.x * look_sensitivity)
		
		var current_pitch_rad = pan_center.rotation.x
		var change = -_rotation_input.y * look_sensitivity
		var new_pitch = clamp(rad_to_deg(current_pitch_rad + change), min_pitch, max_pitch)
		
		pan_center.rotation.x = deg_to_rad(new_pitch)
		
		_rotation_input = Vector2.ZERO
		
func _update_panning() -> void:
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
