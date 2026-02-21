extends StaticBody3D

# This script goes ON the object you want to click, NOT the camera.

func _on_mouse_entered() -> void:
	print("Mouse entered " + name)
	# e.g., self.scale = Vector3(1.1, 1.1, 1.1)

func _on_mouse_exited() -> void:
	print("Mouse left " + name)
	# e.g., self.scale = Vector3(1.0, 1.0, 1.0)

func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("You clicked " + name + " at position " + str(event_position))
