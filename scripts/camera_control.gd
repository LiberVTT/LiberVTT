extends Node3D

@export var camera_center: Node3D
@export var camera: Camera3D
@export var indicator_sphere: Node3D
@export var camera_target: Node3D

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
@export var min_pitch: float = -70.0 # Degrees
@export var max_pitch: float = -15.0 # Degrees (looking down)
@export var min_distance: float = 3
@export var max_distance: float = 10

@export_group("Debug")
@export var debug: bool = false
@export var label: Label3D

var _mouse_input: bool = false
var _mouse_start: Vector2 = Vector2.ZERO
var _rotation_input: Vector2 = Vector2.ZERO
var _pan_input: Vector2 = Vector2.ZERO
var _target_zoom: float = 5.0
var _is_dragging: bool = false
var _is_rotating: bool = false
var _raycast_hit: Vector3 = Vector3.ZERO

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
	
	# Find where the mouse is pointing in the world NOW
	var current_mouse_pos: Vector2 = get_viewport().get_mouse_position()
	
	# We project a ray to a plane at the height of our anchor point 
	# to ensure the "drag" feels consistent even if the mouse leaves a mesh
	var ray_origin: Vector3 = camera.project_ray_origin(current_mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(current_mouse_pos)
	
	# Plane math: Find intersection of ray and a horizontal plane at anchor height
	var drag_plane: Plane = Plane(Vector3.UP, _raycast_hit.y)
	var world_pos_now = drag_plane.intersects_ray(ray_origin, ray_dir)
	
	if world_pos_now != null:
		var delta_move = _raycast_hit - world_pos_now
		# Only move on X and Z to keep the camera at its current height
		#global_translate(Vector3(delta_move.x, 0, delta_move.z))
		camera_target.global_translate(Vector3(delta_move.x, 0, delta_move.z))

func _apply_rotation() -> void:
	if !_is_rotating: return
	
	var current_mouse_position: Vector2 = get_viewport().get_mouse_position()
	var difference_vector: Vector2 = (current_mouse_position - _mouse_start) * look_sensitivity
	
	print(_mouse_start, current_mouse_position, difference_vector)
	
	if difference_vector != Vector2.ZERO:
		camera_target.rotation.x = clamp((camera_target.rotation.x - difference_vector.y), deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		camera_target.global_rotation.y += difference_vector.x
		camera_target.rotation.z = 0
	
	_mouse_start = current_mouse_position

func _unhandled_input(event: InputEvent) -> void:
	# 1. Handle world drag with left mouse
		if event is InputEventMouseButton:
			if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				if event.pressed:
					_mouse_start = get_viewport().get_mouse_position()
					var hit: Dictionary = _get_raycast_hit(event.position)
					if hit and event.button_index == MOUSE_BUTTON_LEFT:
						_raycast_hit = hit.position # Lock the world point
						_is_dragging = true
					elif event.button_index == MOUSE_BUTTON_RIGHT:
						_is_rotating = true
						print_debug("rotating")
							# Optional: Uncomment the line below to snap mouse back to start on release
							# Input.warp_mouse(_rotate_start_mouse_pos)
				else:
					_is_dragging = false
					_is_rotating = false
					_mouse_start = Vector2.ZERO
					
		#if event is InputEventMouseMotion and _is_rotating:
			#var hit: Dictionary = _get_raycast_hit(event.position)
			#if hit != {}:
				#if _is_rotating:
					#_rotate_around_point(_raycast_hit, event.relative)
			#else:
				#print("invalid raycast")
				

		# 2. Handle Scroll Wheel (Zoom)new folder
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = max(_target_zoom - zoom_speed, min_zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = min(_target_zoom + zoom_speed, max_zoom)

	# Handle Mouse Motion
		if event is InputEventMouseMotion and _mouse_input:
			#if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				#_rotation_input += event.relative
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_pan_input += event.relative
	

func _handle_keyboard_input(delta: float) -> void:	
	var input_dir: Vector2 = Input.get_vector("move_right", "move_left", "move_forward", "move_backward")
	_pan_input += Vector2(input_dir.x, -input_dir.y) * kb_pan_speed

	var rot_dir: Vector2 = Input.get_vector("rotate_left", "rotate_right", "rotate_down", "rotate_up")
	_rotation_input += rot_dir * kb_look_sensitivity
	
	var zoom_dir: float = Input.get_axis("zoom_in", "zoom_out")
	_target_zoom = clamp(_target_zoom + (zoom_dir * kb_zoom_speed * delta), min_zoom, max_zoom)

func _apply_movement(delta: float) -> void:
	if _rotation_input.length() > 0:
		camera_target.rotate_y(-_rotation_input.x * look_sensitivity)
		
		var current_pitch_rad: float = camera_target.rotation.x
		var change: float = -_rotation_input.y * look_sensitivity
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
			camera_target.global_translate(direction * pan_speed)
			_pan_input = Vector2.ZERO # Reset for next frame
	
	if _is_dragging:
		_apply_world_drag()
	
	if _is_rotating:
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

func _ready() -> void:
	look_sensitivity *= 0.01
	pan_speed *= 0.01

func _process(_delta: float) -> void:
	_update(_delta)
	_update_raycast()
	if debug:
		label.text = "tgt zoom : " + str(_target_zoom) + "\n" + str(camera_target.rotation) + "\n mouse_start: " + str(_mouse_start) + "\n mouse now: " + str(get_viewport().get_mouse_position())
	
func _update(delta) -> void:
	_update_scroll(delta)
	_update_target_movement(delta)
	_update_camera_position(delta)
	
func _update_scroll(delta) -> void:
	camera.position.z = lerp(camera.position.z, _target_zoom, zoom_smoothing * delta)

func _update_target_movement(delta) -> void:
	_handle_keyboard_input(delta)
	_apply_movement(delta)

func _update_camera_position(delta) -> void:
	global_position = lerp(global_position, camera_target.position, look_smoothing * delta)
	global_rotation.x = lerp_angle(global_rotation.x, camera_target.rotation.x, look_smoothing * delta)
	global_rotation.y = lerp_angle(global_rotation.y, camera_target.rotation.y, look_smoothing * delta)
	return
	

#func _update_orbit() -> void:
#	if _rotation_input.length() > 0:
#		rotate_y(-_rotation_input.x * look_sensitivity)
#		
#		var current_pitch_rad = camera_center.rotation.x
#		var change = -_rotation_input.y * look_sensitivity
#		var new_pitch = clamp(rad_to_deg(current_pitch_rad + change), min_pitch, max_pitch)
#		
#		camera_center.rotation.x = deg_to_rad(new_pitch)
#		
#
#func _update_panning() -> void:
#	if _pan_input.length() > 0:
#		# Panning moves the pivot (the center of the orbit)
#		# We use the horizontal forward/right vectors so panning stays flat
#		var forward = -global_transform.basis.z
#		forward.y = 0
#		forward = forward.normalized()
#		
#		var right = global_transform.basis.x
#		right.y = 0
#		right = right.normalized()
#		
#		# Calculate translation based on mouse relative motion
#		var direction = (right * -_pan_input.x) + (forward * _pan_input.y)
#		global_translate(direction * pan_speed)
#		
#		_pan_input = Vector2.ZERO
