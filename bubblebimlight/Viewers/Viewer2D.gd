
extends Control
# CADViewer.gd - Viewer CAD complet funcțional


# === GRID POINTS ===
var grid_points: Array = []

# === UI LABELS ===
var coord_label: Label
var info_label: Label

# Setează punctele de grid (apelabil din Main.gd)
func set_grid_points(points: Array):
	grid_points = points
	queue_redraw()

# === PROPRIETĂȚI CAD ===
var camera_position: Vector2 = Vector2.ZERO
var camera_zoom: float = 1.0
var grid_size: float = 1.0  # Mărimea unei unități grid în coordonate world
var pixels_per_unit: float = 50.0  # Câți pixeli reprezintă o unitate CAD

# === CONSTANTE ===
const MIN_ZOOM = 0.05
const MAX_ZOOM = 50.0
const ZOOM_FACTOR = 1.2

# === VARIABILE PAN ===
var is_panning: bool = false
var pan_start_mouse: Vector2
var pan_start_camera: Vector2

# === CULORI ===
var background_color = Color.BLACK
var grid_color = Color(0.3, 0.3, 0.3, 0.8)
var major_grid_color = Color(0.5, 0.5, 0.5, 1.0)
var axis_color = Color.RED
var origin_color = Color.YELLOW
var text_color = Color.WHITE


func _ready():
	print("=== CAD Viewer Starting ===")
	
	# Setează proprietățile Control-ului
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	
	# Creează UI-ul
	setup_ui()
	
	# Test inițial
	print("Control size: ", size)
	print("Camera position: ", camera_position)
	print("Camera zoom: ", camera_zoom)
	
	# Forțează primul desen
	call_deferred("queue_redraw")
	
	print("=== CAD Viewer Ready ===")

	# Track whether load_level was called before ready
	if has_meta("_pending_load_level"):
		var lvl = get_meta("_pending_load_level")
		remove_meta("_pending_load_level")
		load_level(lvl)

func setup_ui():
	# Label pentru coordonate (stânga jos)
	coord_label = Label.new()
	coord_label.text = "Coordonate: (0.000, 0.000)"
	coord_label.add_theme_color_override("font_color", Color.WHITE)
	coord_label.position = Vector2(10, 40)
	coord_label.size = Vector2(250, 30)
	add_child(coord_label)
	# Label pentru info (dreapta sus)
	info_label = Label.new()
	info_label.text = "Zoom: 1.00x | Grid: 1.0"
	info_label.add_theme_color_override("font_color", Color.WHITE)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label.position = Vector2(300, 40)
	info_label.size = Vector2(200, 30)
	add_child(info_label)
	# Ajustează poziția label-ului info când se schimbă mărimea
	resized.connect(_on_resized)

func _on_resized():
	if info_label:
		info_label.position = Vector2(size.x - 310, 10)

# === CONVERSII COORDONATE ===
func world_to_screen(world_pos: Vector2) -> Vector2:
	var screen_center = size * 0.5
	var relative_pos = (world_pos - camera_position) * pixels_per_unit * camera_zoom
	# În CAD, Y crește în sus, dar pe ecran Y crește în jos
	relative_pos.y = -relative_pos.y
	return screen_center + relative_pos

func screen_to_world(screen_pos: Vector2) -> Vector2:
	var screen_center = size * 0.5
	var relative_pos = screen_pos - screen_center
	# Inversează Y pentru sistemul CAD
	relative_pos.y = -relative_pos.y
	return camera_position + relative_pos / (pixels_per_unit * camera_zoom)

# === INPUT HANDLING ===
func _input(event):
	if not get_rect().has_point(get_local_mouse_position()):
		return
	
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event is InputEventKey:
		handle_keyboard(event)

func handle_mouse_button(event: InputEventMouseButton):
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				zoom_at_point(get_local_mouse_position(), ZOOM_FACTOR)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				zoom_at_point(get_local_mouse_position(), 1.0 / ZOOM_FACTOR)
		MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				start_pan()
			else:
				end_pan()
		MOUSE_BUTTON_RIGHT:
			if event.pressed and event.double_click:
				center_on_origin()

func handle_mouse_motion(event: InputEventMouseMotion):
	# Actualizează afișajul coordonatelor
	var world_pos = screen_to_world(event.position)
	update_coordinate_display(world_pos)
	
	# Pan dacă este activ
	if is_panning:
		update_pan(event.position)

func handle_keyboard(event: InputEventKey):
	if event.pressed:
		match event.keycode:
			KEY_HOME:
				center_on_origin()
			KEY_R:
				if event.ctrl_pressed:
					reset_zoom()


# === ZOOM FUNCTIONS ===
func zoom_at_point(screen_point: Vector2, factor: float):
	var old_world_pos = screen_to_world(screen_point)
	
	var new_zoom = camera_zoom * factor
	new_zoom = clamp(new_zoom, MIN_ZOOM, MAX_ZOOM)
	
	if new_zoom != camera_zoom:
		camera_zoom = new_zoom
		
		# Ajustează camera pentru a menține punctul sub cursor
		var new_world_pos = screen_to_world(screen_point)
		camera_position += old_world_pos - new_world_pos
		
		update_info_display()
		queue_redraw()

func zoom_in():
	zoom_at_point(size * 0.5, ZOOM_FACTOR)

func zoom_out():
	zoom_at_point(size * 0.5, 1.0 / ZOOM_FACTOR)

func reset_zoom():
	camera_zoom = 1.0
	update_info_display()
	queue_redraw()

# === PAN FUNCTIONS ===
func start_pan():
	is_panning = true
	pan_start_mouse = get_local_mouse_position()
	pan_start_camera = camera_position

func update_pan(mouse_pos: Vector2):
	if not is_panning:
		return
	
	var mouse_delta = mouse_pos - pan_start_mouse
	# Inversează Y și scalează cu zoom-ul
	mouse_delta.y = -mouse_delta.y
	var world_delta = mouse_delta / (pixels_per_unit * camera_zoom)
	
	camera_position = pan_start_camera - world_delta
	queue_redraw()

func end_pan():
	is_panning = false

# === NAVIGATION ===
func center_on_origin():
	camera_position = Vector2.ZERO
	queue_redraw()

# === UI UPDATES ===
func update_coordinate_display(world_pos: Vector2):
	if coord_label:
		coord_label.text = "Coordonate: (%.3f, %.3f)" % [world_pos.x, world_pos.y]

func update_info_display():
	if info_label:
		info_label.text = "Zoom: %.2fx | Grid: %.1f | Pan: %s" % [
			camera_zoom, 
			grid_size,
			"ON" if is_panning else "OFF"
		]

# === DRAWING ===

func _draw():
	if size.x <= 0 or size.y <= 0:
		return
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	# Grid
	draw_grid()
	# Axe principale
	draw_axes()
	# Origine
	draw_origin()
	# Puncte grid 2D
	draw_grid_points()
	# Cursor pan
	if is_panning:
		draw_pan_cursor()

# Desenează grid-ul 2D
func draw_grid():
	# Calculează limitele vizibile în coordonate world
	var top_left_world = screen_to_world(Vector2.ZERO)
	var bottom_right_world = screen_to_world(size)

	# Asigură ordinea corectă (top_left < bottom_right)
	var min_x = min(top_left_world.x, bottom_right_world.x)
	var max_x = max(top_left_world.x, bottom_right_world.x)
	var min_y = min(top_left_world.y, bottom_right_world.y)
	var max_y = max(top_left_world.y, bottom_right_world.y)

	# Calculează densitatea grid-ului bazat pe zoom
	var grid_spacing = grid_size
	var screen_grid_size = grid_spacing * pixels_per_unit * camera_zoom

	# Ajustează densitatea grid-ului pentru a evita supraîncărcarea
	while screen_grid_size < 10:
		grid_spacing *= 10
		screen_grid_size = grid_spacing * pixels_per_unit * camera_zoom

	while screen_grid_size > 100:
		grid_spacing /= 10
		screen_grid_size = grid_spacing * pixels_per_unit * camera_zoom

	# Desenează liniile grid-ului
	draw_grid_lines(min_x, max_x, min_y, max_y, grid_spacing)

# Desenează liniile grid-ului

func draw_grid_points():
	if grid_points.size() == 0:
		return
	for pt in grid_points:
		var screen_pt = world_to_screen(pt)
		draw_circle(screen_pt, 4.0, Color.CYAN)

func draw_grid_lines(min_x: float, max_x: float, min_y: float, max_y: float, spacing: float):
	# Linii verticale
	var start_x = floor(min_x / spacing) * spacing
	var x = start_x
	while x <= max_x:
		var screen_x = world_to_screen(Vector2(x, 0)).x
		if screen_x >= 0 and screen_x <= size.x:
			var color = major_grid_color if fmod(abs(x), spacing * 10) < 0.001 else grid_color
			draw_line(
				Vector2(screen_x, 0),
				Vector2(screen_x, size.y),
				color, 1.0
			)
		x += spacing
	
	# Linii orizontale
	var start_y = floor(min_y / spacing) * spacing
	var y = start_y
	while y <= max_y:
		var screen_y = world_to_screen(Vector2(0, y)).y
		if screen_y >= 0 and screen_y <= size.y:
			var color = major_grid_color if fmod(abs(y), spacing * 10) < 0.001 else grid_color
			draw_line(
				Vector2(0, screen_y),
				Vector2(size.x, screen_y),
				color, 1.0
			)
		y += spacing

func draw_axes():
	var origin_screen = world_to_screen(Vector2.ZERO)
	
	# Axa X (orizontală, roșie)
	if origin_screen.y >= 0 and origin_screen.y <= size.y:
		draw_line(
			Vector2(0, origin_screen.y),
			Vector2(size.x, origin_screen.y),
			axis_color, 2.0
		)
	
	# Axa Y (verticală, roșie)
	if origin_screen.x >= 0 and origin_screen.x <= size.x:
		draw_line(
			Vector2(origin_screen.x, 0),
			Vector2(origin_screen.x, size.y),
			axis_color, 2.0
		)

func draw_origin():
	var origin_screen = world_to_screen(Vector2.ZERO)
	
	# Verifică dacă originea este vizibilă
	if origin_screen.x >= -50 and origin_screen.x <= size.x + 50 and \
	   origin_screen.y >= -50 and origin_screen.y <= size.y + 50:
		
		# Cercuri concentrice
		draw_circle(origin_screen, 12.0, Color.BLACK)
		draw_circle(origin_screen, 10.0, origin_color)
		draw_circle(origin_screen, 6.0, Color.BLACK)
		draw_circle(origin_screen, 4.0, origin_color)
		
		# Text (0,0)
		var font = ThemeDB.fallback_font
		var text = "(0,0)"
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(
			font,
			origin_screen + Vector2(15, -text_size.y / 2),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 12,
			text_color
		)

func draw_pan_cursor():
	var mouse_pos = get_local_mouse_position()
	var cursor_size = 20.0
	
	# Cerc semi-transparent
	draw_circle(mouse_pos, cursor_size, Color(1, 1, 0, 0.3))
	draw_circle(mouse_pos, cursor_size, Color.YELLOW, false, 2.0)
	
	# Săgeți în 4 direcții
	var arrow_size = 8.0
	# Sus
	draw_line(mouse_pos + Vector2(0, -cursor_size), mouse_pos + Vector2(0, -cursor_size + arrow_size), Color.WHITE, 2)
	draw_line(mouse_pos + Vector2(0, -cursor_size), mouse_pos + Vector2(-3, -cursor_size + 5), Color.WHITE, 2)
	draw_line(mouse_pos + Vector2(0, -cursor_size), mouse_pos + Vector2(3, -cursor_size + 5), Color.WHITE, 2)
	# Jos  
	draw_line(mouse_pos + Vector2(0, cursor_size), mouse_pos + Vector2(0, cursor_size - arrow_size), Color.WHITE, 2)
	draw_line(mouse_pos + Vector2(0, cursor_size), mouse_pos + Vector2(-3, cursor_size - 5), Color.WHITE, 2)
	draw_line(mouse_pos + Vector2(0, cursor_size), mouse_pos + Vector2(3, cursor_size - 5), Color.WHITE, 2)
	# Stânga
	draw_line(mouse_pos + Vector2(-cursor_size, 0), mouse_pos + Vector2(-cursor_size + arrow_size, 0), Color.WHITE, 2)
	draw_line(mouse_pos + Vector2(-cursor_size, 0), mouse_pos + Vector2(-cursor_size + 5, -3), Color.WHITE, 2)
	draw_line(mouse_pos + Vector2(-cursor_size, 0), mouse_pos + Vector2(-cursor_size + 5, 3), Color.WHITE, 2)
	# Dreapta
	draw_line(mouse_pos + Vector2(cursor_size, 0), mouse_pos + Vector2(cursor_size - arrow_size, 0), Color.WHITE, 2)
	draw_line(mouse_pos + Vector2(cursor_size, 0), mouse_pos + Vector2(cursor_size - 5, -3), Color.WHITE, 2)
	draw_line(mouse_pos + Vector2(cursor_size, 0), mouse_pos + Vector2(cursor_size - 5, 3), Color.WHITE, 2)

# === FUNCȚII PENTRU TESTARE/DEBUG ===
func _on_gui_input(event):
	# Această funcție se apelează automat pentru input-ul GUI
	print("GUI Input: ", event)

func print_debug():
	print("=== DEBUG INFO ===")
	print("Size: ", size)
	print("Camera pos: ", camera_position)
	print("Camera zoom: ", camera_zoom)
	print("Grid size: ", grid_size)
	print("Pixels per unit: ", pixels_per_unit)
	print("Is panning: ", is_panning)
	print("Mouse filter: ", mouse_filter)
	print("Focus mode: ", focus_mode)
	print("==================")


# Public API: încarcă/setează contextul pentru un nivel 2D
func load_level(level_data: Dictionary) -> void:
	# level_data expected keys: name, bottom, top
	if not is_inside_tree() or not is_visible_in_tree():
		# Dacă viewerul nu e încă ready/în tree, păstrează datele în meta și va fi procesat în _ready
		set_meta("_pending_load_level", level_data.duplicate())
		return

	if typeof(level_data) != TYPE_DICTIONARY:
		push_error("load_level expects a Dictionary")
		return

	# Exemplu de comportament: poziționează camera vertical la mijlocul nivelului și ajustează zoom
	var bottom = level_data.get("bottom", 0.0)
	var top = level_data.get("top", bottom + 2.8)
	var mid_y = (bottom + top) * 0.5

	# În world Z/Y mapping: folosim y ca vertical world coord
	camera_position = Vector2(0, mid_y)
	camera_zoom = 1.0
	update_info_display()
	queue_redraw()

	print("Viewer2D: loaded level: ", level_data)
