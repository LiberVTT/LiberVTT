extends Node3D

"""
Tile generator script.

Globals:
	x: table_width (how many squares should make up x side)
	y: table_height (how many squares should make up y side)
	l: length of the sides of the squares/hex
	hex: boolean, is it hex (otherwise square)
"""

@export_group("Grid Settings")
@export var table_width: int = 10
@export var table_height: int = 10
@export var tile_length: float = 1.0
@export var is_hex: bool = false

@export_group("Assets")
# Drag a Scene (.tscn) here that contains a MeshInstance3D + StaticBody3D
@export var tile_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate_grid()


func generate_grid() -> void:
	# Clear existing tiles if regenerating
	for child in get_children():
		child.queue_free()

	for row in range(table_height):
		for col in range(table_width):
			var pos = _calculate_position(col, row)
			_spawn_tile(pos, col, row)


func _calculate_position(q: int, r: int) -> Vector3:
	var pos = Vector3.ZERO
	
	if not is_hex:
# Simple Square Math
		pos.x = q * tile_length
		pos.z = r * tile_length
	else:
		# Pointy-Top Hex Math
		# Width of a hex is sqrt(3) * radius
		var h_dist = sqrt(3) * tile_length
		var v_dist = (3.0/2.0) * tile_length

		pos.x = h_dist * (q + (r % 2) * 0.5)
		pos.z = v_dist * r
		
	return pos
	
func _spawn_tile(pos: Vector3, grid_x: int, grid_y: int) -> void:
	if not tile_scene: return
	
	var tile = tile_scene.instantiate()
	add_child(tile)
	tile.position = pos
	
	# Optional: Store grid coordinates in the tile for the editor logic
	tile.set_meta("grid_coord", Vector2i(grid_x, grid_y))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
