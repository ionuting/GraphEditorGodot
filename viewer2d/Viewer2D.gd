# CADViewer.gd - Viewer CAD complet funcțional
extends Control

var project_json_path: String = "res://temp_project.json" # Calea implicită pentru fișierul temporar

var _imported_shapes: Array = []

# === GRID POINTS ===
var grid_points: Array = []
var placed_cells: Array = [] # stores RectangleCell instances placed in this viewer

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
	
	if has_signal("shape_placement_finalized"):
		connect("shape_placement_finalized", Callable(self, "_on_shape_placement_finalized"))
	
	_load_project_json()
	
	_setup_file_menu()

func _setup_file_menu():
	var file_btn = _find_node_by_name(get_tree().get_root(), "FileButton")
	if file_btn:
		var popup = file_btn.get_popup()
		popup.clear()
		popup.add_item("Open", 0)
		popup.add_item("Save", 1)
		popup.add_item("Save As", 2)
		popup.add_separator()
		popup.add_item("Generate Layout Sheets", 3)
		popup.add_item("Open Layout Designer", 4)
		popup.id_pressed.connect(Callable(self, "_on_file_menu_pressed"))

# Utility: caută recursiv un nod după nume
func _find_node_by_name(node, name):
	if node.name == name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, name)
		if found:
			return found
	return null

func _on_file_menu_pressed(id):
	match id:
		0:
			_show_open_dialog()
		1:
			save_project_json()
		2:
			_show_save_as_dialog()
		3:
			_generate_layout_sheets()
		4:
			_open_layout_designer()

func _show_open_dialog():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.json ; JSON Files"]
	dialog.title = "Open Project"
	dialog.popup_centered()
	dialog.file_selected.connect(Callable(self, "_on_open_file_selected"))
	add_child(dialog)

func _on_open_file_selected(path):
	project_json_path = path
	_load_project_json()

func _show_save_as_dialog():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.json ; JSON Files"]
	dialog.title = "Save Project As"
	dialog.popup_centered()
	dialog.file_selected.connect(Callable(self, "_on_save_as_file_selected"))
	add_child(dialog)

func _on_save_as_file_selected(path):
	save_project_json(path)

func _generate_layout_sheets():
	print("[DEBUG] Generating layout sheets...")
	
	# Salvează proiectul curent
	save_project_json()
	
	# Verifică dacă avem shapes pentru a genera planșe
	if _imported_shapes.is_empty():
		push_error("No shapes to generate layouts. Please add some shapes first.")
		return
	
	# Rulează convertorul Python
	var output = []
	var project_dir = ProjectSettings.globalize_path("res://")
	var temp_json_path = project_dir + "temp_project.json"
	var converter_script = project_dir + "python/godot_to_layout.py"
	var layout_script = project_dir + "python/layout_generator.py"
	
	print("[DEBUG] Project dir: ", project_dir)
	print("[DEBUG] Temp JSON: ", temp_json_path)
	
	# Execută convertorul Godot -> GLB
	print("[DEBUG] Running Godot to Layout converter...")
	OS.execute("python", [converter_script, temp_json_path, "viewer2d_export"], output)
	
	# Execută generatorul de planșe
	print("[DEBUG] Running Layout Generator...")
	OS.execute("python", [layout_script, "viewer2d_export"], output)
	
	print("[DEBUG] Layout generation completed!")
	print("[DEBUG] Check for generated SVG files in project directory")

func _open_layout_designer():
	"""Deschide Layout Designer într-o fereastră nouă"""
	print("[DEBUG] Opening Layout Designer...")
	get_tree().change_scene_to_file("res://LayoutTest.tscn")

func _on_shape_placement_finalized(tool: Dictionary, center: Vector2, size: Vector2):
	print("[DEBUG] shape_placement_finalized: tool=", tool, " center=", center, " size=", size)
	# Creează un rectangle pentru column
	if tool.has("type") and tool["type"] == "column":
		var w = tool.get("width", size.x)
		var l = tool.get("length", size.y)
		var h = tool.get("height", 3.0)
		var col_id = tool.get("id", "")
		var rect = {
			"id": col_id,
			"type": "column",
			"center": [center.x, center.y],
			"width": w,
			"length": l,
			"height": h
		}
		print("[DEBUG] Adaug column rectangle:", rect)
		add_shape(rect)

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
		MOUSE_BUTTON_LEFT:
			# Placement handling: left mouse used for placement when placement_mode is active
			if placement_mode:
				if event.pressed:
					# start placement (center mode)
					_placement_start = screen_to_world(event.position)
					_is_placing = true
					call_deferred("update")
				else:
					# finalize placement
					if _is_placing:
						_is_placing = false
						var center = _placement_start
						var current = screen_to_world(event.position)
						var half = (current - center).abs()
						var size = Vector2(max(0.001, half.x * 2.0), max(0.001, half.y * 2.0))
						# emit finalized signal with tool data, center and size
						emit_signal("shape_placement_finalized", placement_tool.duplicate(), center, size)
						# exit placement mode
						placement_mode = false
						placement_tool = {}
						_placement_start = null
						_placement_current = null
						call_deferred("update")

func handle_mouse_motion(event: InputEventMouseMotion):
	# Actualizează afișajul coordonatelor
	var world_pos = screen_to_world(event.position)
	update_coordinate_display(world_pos)
	
	# Pan dacă este activ
	if is_panning:
		update_pan(event.position)

	# Update placement preview if active
	if placement_mode and _is_placing:
		_placement_current = screen_to_world(event.position)
		call_deferred("update")

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

	
	# Draw placement preview
	if placement_mode and _is_placing and _placement_start:
		var center = _placement_start
		var curr = _placement_current if _placement_current else center
		var half = (curr - center).abs()
		var rect = Rect2(center - half, half * 2.0)
		var tl = world_to_screen(rect.position)
		var br = world_to_screen(rect.position + rect.size)
		var sr = Rect2(tl, br - tl)
		# translucent fill + outline
		draw_rect(sr, Color(0.0, 1.0, 0.0, 0.12), true)
		draw_rect(sr, Color(0.0, 1.0, 0.0, 0.9), false, 2.0)
	# Cursor pan
	if is_panning:
		draw_pan_cursor()

	for shape in _imported_shapes:
		if shape.has("type") and shape["type"] == "column":
			print("[DEBUG] Drawing column: ", shape)
			if shape.has("center") and shape.has("width") and shape.has("length"):
				var cx = float(shape["center"][0])
				var cy = float(shape["center"][1])
				var w = float(shape["width"])
				var l = float(shape["length"])
				var hw = w * 0.5
				var hl = l * 0.5
				var corners = [
					Vector2(cx + hl, cy - hw),
					Vector2(cx - hl, cy - hw),
					Vector2(cx - hl, cy + hw),
					Vector2(cx + hl, cy + hw)
				]
				for i in range(4):
					var a = world_to_screen(corners[i])
					var b = world_to_screen(corners[(i+1)%4])
					draw_line(a, b, Color(0.2, 0.8, 1.0), 3.0)

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

# --- Placement API ---
signal shape_placement_finalized(tool: Dictionary, center: Vector2, size: Vector2)

var placement_mode: bool = false
var placement_tool: Dictionary = {}
var _placement_start = null
var _placement_current = null
var _is_placing: bool = false

func start_placement(tool: Dictionary) -> void:
	placement_mode = true
	placement_tool = tool.duplicate() if typeof(tool) == TYPE_DICTIONARY else {"item": str(tool)}
	_placement_start = null
	_placement_current = null
	_is_placing = false
	print("Viewer2D: placement started for tool %s" % [placement_tool])

func cancel_placement() -> void:
	placement_mode = false
	placement_tool = {}
	_placement_start = null
	_placement_current = null
	_is_placing = false
	call_deferred("update")

func add_rectangle_cell(cell) -> void:
	# expects a RectangleCell instance
	placed_cells.append(cell)
	queue_redraw()

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

func _load_project_json():
	if FileAccess.file_exists(project_json_path):
		var file = FileAccess.open(project_json_path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var data = JSON.parse_string(text)
			if typeof(data) == TYPE_DICTIONARY and data.has("shapes"):
				_imported_shapes = data["shapes"]
				print("[DEBUG] Proiect CAD încărcat din ", project_json_path)
				queue_redraw()
	else:
		print("[DEBUG] Nu există fișier proiect, se va crea unul nou la prima salvare.")

func save_project_json(path: String = ""):
	var save_path = path if path != "" else project_json_path
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var data = {"shapes": _imported_shapes}
		file.store_string(JSON.stringify(data, "\t"))
		print("[DEBUG] Proiect CAD salvat la ", save_path)
	else:
		push_error("Nu s-a putut salva proiectul la: " + save_path)

func add_shape(shape: Dictionary):
	_imported_shapes.append(shape)
	queue_redraw()
	save_project_json() # Salvează automat în fișierul temporar
