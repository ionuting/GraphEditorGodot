extends Node2D

var grid_size_minor = 20.0  # Distanța între liniile minore
var grid_size_major = 100.0  # Distanța între liniile majore
var minor_grid_color = Color(0.2, 0.2, 0.2, 0.4)  # Culoare gri deschis pentru liniile minore
var major_grid_color = Color(0.4, 0.4, 0.4, 0.6)  # Culoare gri mai închis pentru liniile majore

func _draw():
	var camera = get_node("/root/Main/Camera2D")
	if camera == null:
		push_error("Camera2D nu a fost găsit în Background!")
		return
	var zoom = camera.zoom
	var offset = camera.offset
	var viewport_size = get_viewport_rect().size / zoom
	var camera_pos = offset - viewport_size / 2.0

	# Calculează limitele grilei în funcție de poziția și zoom-ul camerei
	var start_x = floor((camera_pos.x - viewport_size.x) / grid_size_minor) * grid_size_minor
	var start_y = floor((camera_pos.y - viewport_size.y) / grid_size_minor) * grid_size_minor
	var end_x = camera_pos.x + viewport_size.x * 2.0
	var end_y = camera_pos.y + viewport_size.y * 2.0

	# Desenează liniile minore
	for x in range(start_x, end_x, grid_size_minor):
		draw_line(Vector2(x, start_y), Vector2(x, end_y), minor_grid_color, 1.0)
		if fmod(x, grid_size_major) == 0:
			draw_line(Vector2(x, start_y), Vector2(x, end_y), major_grid_color, 2.0)
	
	for y in range(start_y, end_y, grid_size_minor):
		draw_line(Vector2(start_x, y), Vector2(end_x, y), minor_grid_color, 1.0)
		if fmod(y, grid_size_major) == 0:
			draw_line(Vector2(start_x, y), Vector2(end_x, y), major_grid_color, 2.0)
