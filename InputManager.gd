extends Camera3D

@export var elevation_step: float = 0.5 # How much it rises per click
@export var ray_length: float = 1000.0

func _input(event):
	# Check for Left Mouse Click
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var target_tile = get_tile_at_mouse()
			if target_tile:
				raise_tile(target_tile)
		
		# Right click to lower
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var target_tile = get_tile_at_mouse()
			if target_tile:
				lower_tile(target_tile)

func get_tile_at_mouse() -> StaticBody3D:
	var mouse_pos = get_viewport().get_mouse_position()
	var from = project_ray_origin(mouse_pos)
	var to = from + project_ray_normal(mouse_pos) * ray_length
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		# Check if the object we hit is actually a tile
		if collider.get_parent().is_in_group("tiles"):
			return collider
	return null

func raise_tile(tile_body: StaticBody3D):
	# The tile_body is the StaticBody3D; we want to move its parent (the Tile node)
	var tile_node = tile_body.get_parent()
	tile_node.position.y += elevation_step

func lower_tile(tile_body: StaticBody3D):
	var tile_node = tile_body.get_parent()
	tile_node.position.y -= elevation_step
