extends Node3D

@export var camera_center: Node3D
@export var camera: Camera3D
@export var indicator_sphere: Node3D
@export var camera_target: Node3D
@export var debug_check: CheckButton
@export var twod_check: CheckButton
@export var label: Label

@export_group("Movement Settings")
@export var look_sensitivity: float = 0.5
@export var pan_speed: float = 0.5
@export var sprint_multiplier: float = 1.0
@export var kb_look_sensitivity: float = 3
@export var kb_pan_speed: float = 2
@export var look_smoothing: float = 10.0

@export_group("Zoom Settings")
@export var zoom_speed: float = 0.8
@export var kb_zoom_speed: float = 4
@export var zoom_smoothing: float = 10.0

@export_group("Constraints")
@export var min_pitch: float = -70.0 # Degrees
@export var max_pitch: float = -15.0 # Degrees (looking down)
@export var min_zoom: float = 2.0
@export var max_zoom: float = 20.0

var _version_info
var _mouse_input: bool = false
var _mouse_start: Vector2 = Vector2.ZERO
var _rotation_input: Vector2 = Vector2.ZERO
var _pan_input: Vector2 = Vector2.ZERO
var _target_zoom: float = 5.0
var _is_dragging: bool = false
var _is_rotating: bool = false
var _is_twod: bool = false
var _raycast_hit: Vector3 = Vector3.ZERO

const _mouse_multiplier: float = 0.01

func _get_raycast_hit(screen_pos: Vector2) -> Dictionary:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 1000
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	return space.intersect_ray(query)
	
func _jump_to_point(point: Vector3, delta: float):
	global_translate(lerp(camera_center.position, point, look_smoothing))

func _apply_world_drag() -> void:
	if not _is_dragging: return
	
	var current_mouse_pos: Vector2 = get_viewport().get_mouse_position()
	
	var ray_origin: Vector3 = camera.project_ray_origin(current_mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(current_mouse_pos)
	
	# Plane math: Find intersection of ray and a horizontal plane at anchor height
	var drag_plane: Plane = Plane(Vector3.UP, _raycast_hit.y)
	var world_pos_now = drag_plane.intersects_ray(ray_origin, ray_dir)
	
	if world_pos_now != null:
		var delta_move = _raycast_hit - world_pos_now
		camera_target.global_translate(Vector3(delta_move.x, 0, delta_move.z))
		camera_center.global_translate(Vector3(delta_move.x, 0, delta_move.z))

func _apply_rotation() -> void:
	if !_is_rotating: return
	
	var current_mouse_position: Vector2 = get_viewport().get_mouse_position()
	var difference_vector: Vector2 = (current_mouse_position - _mouse_start) * look_sensitivity * _mouse_multiplier
	
	if difference_vector != Vector2.ZERO:
		camera_target.rotation.x = clamp((camera_target.rotation.x - difference_vector.y), deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		camera_target.global_rotation.y -= difference_vector.x
		camera_target.rotation.z = 0
	
	_mouse_start = current_mouse_position

func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.pressed:
				_mouse_start = get_viewport().get_mouse_position()
				var hit: Dictionary = _get_raycast_hit(event.position)
				match event.button_index:
					MOUSE_BUTTON_MIDDLE:						
						if hit:
							_raycast_hit = hit.position # Lock the world point
							_is_dragging = true
					MOUSE_BUTTON_RIGHT:
						_is_rotating = true
					MOUSE_BUTTON_LEFT:
						#jump to the selected piece
						return
					MOUSE_BUTTON_WHEEL_UP:
						_target_zoom = max(_target_zoom - zoom_speed, min_zoom)
					MOUSE_BUTTON_WHEEL_DOWN:
						_target_zoom = min(_target_zoom + zoom_speed, max_zoom)
			else:
				_is_dragging = false
				_is_rotating = false
				_mouse_start = Vector2.ZERO

func _handle_keyboard_input(delta: float) -> void:	
	var input_dir: Vector2 = Input.get_vector("move_right", "move_left", "move_forward", "move_backward")
	_pan_input += Vector2(input_dir.x, -input_dir.y) * kb_pan_speed
	
	var sprint_dir: float = Input.is_action_pressed("sprint")
	_pan_input *= sprint_multiplier * (sprint_dir + 1)
	
	if !_is_twod:
		var rot_dir: Vector2 = Input.get_vector("rotate_left", "rotate_right", "rotate_down", "rotate_up")
		_rotation_input += rot_dir * kb_look_sensitivity
	else:
		var rot_dir: float = Input.get_axis("rotate_left", "rotate_right")
		_rotation_input.x += rot_dir * kb_look_sensitivity
	
	var zoom_dir: float = Input.get_axis("zoom_in", "zoom_out")
	_target_zoom = clamp(_target_zoom + (zoom_dir * kb_zoom_speed * delta), min_zoom, max_zoom)
	
	if Input.is_action_pressed("home"):
		camera_target.global_position = Vector3(0,0,0)
	
	if Input.is_key_pressed(KEY_F1):
		$GUI/Help.visible = true
	else:
		$GUI/Help.visible = false
		

func _apply_movement(delta: float) -> void:
	if _rotation_input.length() > 0:
		camera_target.rotate_y(-_rotation_input.x * look_sensitivity * _mouse_multiplier)
		if !_is_twod:
			var current_pitch_rad: float = camera_target.rotation.x
			var change: float = -_rotation_input.y * look_sensitivity * _mouse_multiplier
			var new_pitch = clamp(rad_to_deg(current_pitch_rad + change), min_pitch, max_pitch)
			
			camera_target.rotation.x = deg_to_rad(new_pitch)
		_rotation_input = Vector2.ZERO

	if _pan_input.length() > 0:
			var forward: Vector3 = -global_transform.basis.z
			forward.y = 0
			var right: Vector3 = global_transform.basis.x
			right.y = 0
			
			var direction: Vector3 = (right.normalized() * -_pan_input.x) + (forward.normalized() * _pan_input.y)
			# We use global_translate for the pan so it moves the whole system
			camera_target.global_translate(direction * pan_speed * _mouse_multiplier)
			_pan_input = Vector2.ZERO # Reset for next frame
	
	if _is_dragging:
		_apply_world_drag()
	
	if _is_rotating and !_is_twod:
		_apply_rotation()
	

func _update_raycast() -> void:
	if not indicator_sphere: return
	
	var result: Dictionary = _get_raycast_hit(get_viewport().get_mouse_position())
	
	# 4. Handle collision
	if result:
		indicator_sphere.visible = true
		indicator_sphere.global_position = result.position
	else:
		indicator_sphere.visible = false

func _init_settings() -> void:
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Zoom Settings/VBoxContainer/Zoom Speed/Zoom Speed Slider".value = zoom_speed
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Zoom Settings/VBoxContainer/(KB) Zoom Speed/(KB) Zoom Speed Slider".value = kb_zoom_speed
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Zoom Settings/VBoxContainer/Zoom Smoothing/Zoom Smoothing Slider".value = zoom_smoothing
	
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/Look Sensitivity/HSlider".value = look_sensitivity
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/Pan Speed/HSlider".value = pan_speed
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/Sprint Multiplier/HSlider".value = sprint_multiplier
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/(KB) Look Sensitivity/HSlider".value = kb_look_sensitivity
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/(KB) Pan Speed/HSlider".value = kb_pan_speed
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/Look Smoothing/HSlider".value = look_smoothing
	
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Constraints/VBoxContainer/Min Pitch/HSlider".value = min_pitch
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Constraints/VBoxContainer/Max Pitch/HSlider".value = max_pitch
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Constraints/VBoxContainer/Min Zoom/Min Zoom Slider".value = min_zoom
	$"GUI/Settins List/VBoxContainer/VSplitContainer/Constraints/VBoxContainer/Max Zoom/Max Zoom Slider".value = max_zoom

func _ready() -> void:
	camera_target.rotation.x = deg_to_rad(max_pitch)
	_init_settings()
	var data = FileAccess.open("res://about.json", FileAccess.READ)
	var raw = data.get_as_text()
	var json = JSON.new()
	var error = json.parse(raw)
	if error == OK:
		_version_info = json.data
	else:
		print("JSON parse error")
	

func _process(_delta: float) -> void:
	_update(_delta)
	_update_raycast()
	_check_update()
			
func _update(delta) -> void:
	_update_scroll(delta)
	_update_target_movement(delta)
	_update_camera_position(delta)
	
func _check_update() -> void:
	if debug_check.button_pressed:
		label.text = _version_info["version"] + "." + _version_info["branch_version"] + " \"" + _version_info["version_name"] + "\" - " + _version_info["branch_name"] +  " - " + _version_info["date"] + "\n" + str(_target_zoom) + " target zoom\n" + str(camera_target.rotation) + " target rotation\n" + str(get_viewport().get_mouse_position()) + " mouse position\n" + str(camera_target.global_position) + " target position"
	else:
		label.text = ""
	
	
func _update_scroll(delta) -> void:
	camera.position.z = lerp(camera.position.z, _target_zoom, zoom_smoothing * delta)

func _update_target_movement(delta) -> void:
	_handle_keyboard_input(delta)
	_apply_movement(delta)

func _update_camera_position(delta) -> void:
	position = lerp(position, camera_target.position, look_smoothing * delta)
	rotation.x = lerp_angle(rotation.x, camera_target.rotation.x, look_smoothing * delta)
	rotation.y = lerp_angle(rotation.y, camera_target.rotation.y, look_smoothing * delta)

func _on_button_pressed() -> void:
	$"GUI/Settins List".visible = !$"GUI/Settins List".visible

func _on_settings_apply() -> void:
	$"GUI/Settins List".visible = !$"GUI/Settins List".visible
	
	zoom_speed = $"GUI/Settins List/VBoxContainer/VSplitContainer/Zoom Settings/VBoxContainer/Zoom Speed/Zoom Speed Slider".value 
	kb_zoom_speed = $"GUI/Settins List/VBoxContainer/VSplitContainer/Zoom Settings/VBoxContainer/(KB) Zoom Speed/(KB) Zoom Speed Slider".value 
	zoom_smoothing = $"GUI/Settins List/VBoxContainer/VSplitContainer/Zoom Settings/VBoxContainer/Zoom Smoothing/Zoom Smoothing Slider".value 
	
	look_sensitivity = $"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/Look Sensitivity/HSlider".value 
	pan_speed = $"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/Pan Speed/HSlider".value 
	sprint_multiplier = $"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/Sprint Multiplier/HSlider".value 
	kb_look_sensitivity = $"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/(KB) Look Sensitivity/HSlider".value
	kb_pan_speed = $"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/(KB) Pan Speed/HSlider".value 
	look_smoothing = $"GUI/Settins List/VBoxContainer/VSplitContainer/Look Settings/VBoxContainer/Look Smoothing/HSlider".value 
	
	min_pitch = $"GUI/Settins List/VBoxContainer/VSplitContainer/Constraints/VBoxContainer/Min Pitch/HSlider".value 
	max_pitch = $"GUI/Settins List/VBoxContainer/VSplitContainer/Constraints/VBoxContainer/Max Pitch/HSlider".value 
	min_zoom = $"GUI/Settins List/VBoxContainer/VSplitContainer/Constraints/VBoxContainer/Min Zoom/Min Zoom Slider".value 
	max_zoom = $"GUI/Settins List/VBoxContainer/VSplitContainer/Constraints/VBoxContainer/Max Zoom/Max Zoom Slider".value 

func _on_d_toggle_toggled(toggled_on: bool) -> void:
	_is_twod = !_is_twod
	if toggled_on:
		# enter pseudo 2d
		camera_target.rotation.x = deg_to_rad(-90)
	else:
		camera_target.rotation.x = deg_to_rad(max_pitch)
		# enter 3d
	return
