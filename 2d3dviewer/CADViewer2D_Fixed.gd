# CADViewer2D_Fixed.gd  
# Versiune simplificată care desenează direct pe Control
extends Control

var rectangle_manager: RectangleManager
var polygon_manager: PolygonManager
var cell_manager: RectangleCellManager
var cell_properties_panel: RectangleCellPropertiesPanel
var wall_manager: WallManager
var window_manager: WindowManager
var window_properties_panel: WindowPropertiesPanel
var placing_rect = false
var drawing_polygon = false
var move_mode = false
var placing_cell = false
var placing_wall = false
var placing_window = false
var wall_has_start: bool = false
var wall_start_point: Vector2 = Vector2.ZERO
var wall_preview_end: Vector2 = Vector2.ZERO

# Double-click tracking for opening properties (AutoCAD-style)
var last_click_time: int = 0
var last_click_target: Object = null

# Camera virtuală
var camera_position: Vector2 = Vector2.ZERO
var camera_zoom: float = 1.0

# Pan (panoramă) variabile
var is_panning: bool = false
var pan_start_pos: Vector2
var pan_start_camera_pos: Vector2

# Constante pentru grid și coordonate
const GRID_UNIT_SIZE = 50.0  # 50 pixeli = 1 unitate AutoCAD
const MIN_ZOOM = 0.1
const MAX_ZOOM = 10.0

func _ready():
	print("CADViewer2D_Fixed._ready() apelat")
	
	# Inițializează managerii
	rectangle_manager = RectangleManager.new()
	polygon_manager = PolygonManager.new()
	cell_manager = RectangleCellManager.new()
	wall_manager = WallManager.new()
	window_manager = WindowManager.new()
	# Window properties panel
	window_properties_panel = WindowPropertiesPanel.new()
	add_child(window_properties_panel)
	window_properties_panel.visible = false
	window_properties_panel.properties_applied.connect(_on_window_properties_applied)
	
	# Inițializează panoul de proprietăți
	cell_properties_panel = RectangleCellPropertiesPanel.new()
	add_child(cell_properties_panel)
	cell_properties_panel.visible = false
	
	# Conectează semnalele panoului
	cell_properties_panel.properties_applied.connect(_on_cell_properties_applied)
	
	# Adaugă butoanele
	create_buttons()
	
	print("Setup complet, forțez redraw...")
	queue_redraw()

func create_buttons():
	# Buton dreptunghi
	var rect_btn = Button.new()
	rect_btn.text = "Adaugă dreptunghi 0.25x0.25"
	rect_btn.position = Vector2(20, 20)
	rect_btn.size = Vector2(200, 40)
	rect_btn.name = "AddRectButton"
	rect_btn.pressed.connect(_on_add_rect_button_pressed)
	add_child(rect_btn)
	
	# Buton poligon
	var poly_btn = Button.new()
	poly_btn.text = "Desenează poligon"
	poly_btn.position = Vector2(240, 20)
	poly_btn.size = Vector2(160, 40)
	poly_btn.name = "AddPolygonButton"
	poly_btn.pressed.connect(_on_add_polygon_button_pressed)
	add_child(poly_btn)
	
	# Buton Move
	var move_btn = Button.new()
	move_btn.text = "Move"
	move_btn.position = Vector2(420, 20)
	move_btn.size = Vector2(80, 40)
	move_btn.name = "MoveButton"
	move_btn.pressed.connect(_on_move_button_pressed)
	add_child(move_btn)
	
	# Buton Rectangle Cell
	var cell_btn = Button.new()
	cell_btn.text = "Rectangle Cell"
	cell_btn.position = Vector2(520, 20)
	cell_btn.size = Vector2(120, 40)
	cell_btn.name = "RectangleCellButton"
	cell_btn.pressed.connect(_on_rectangle_cell_button_pressed)
	add_child(cell_btn)
	
	# Buton Properties Panel
	var props_btn = Button.new()
	props_btn.text = "Cell Properties"
	props_btn.position = Vector2(660, 20)
	props_btn.size = Vector2(120, 40)
	props_btn.name = "PropertiesButton"
	props_btn.pressed.connect(_on_properties_button_pressed)
	add_child(props_btn)

	# Buton Window Properties
	var win_props_btn = Button.new()
	win_props_btn.text = "Window Props"
	win_props_btn.position = Vector2(1360, 20)
	win_props_btn.size = Vector2(120, 40)
	win_props_btn.name = "WindowPropertiesButton"
	win_props_btn.pressed.connect(_on_window_props_button_pressed)
	add_child(win_props_btn)

	# Buton Move by Distance
	var move_by_btn = Button.new()
	move_by_btn.text = "Move by Dist"
	move_by_btn.position = Vector2(800, 20)
	move_by_btn.size = Vector2(120, 40)
	move_by_btn.name = "MoveByButton"
	move_by_btn.pressed.connect(_on_move_by_distance_button_pressed)
	add_child(move_by_btn)

	# Buton Delete
	var delete_btn = Button.new()
	delete_btn.text = "Delete"
	delete_btn.position = Vector2(940, 20)
	delete_btn.size = Vector2(80, 40)
	delete_btn.name = "DeleteButton"
	delete_btn.pressed.connect(_on_delete_button_pressed)
	add_child(delete_btn)

	# Buton Wall
	var wall_btn = Button.new()
	wall_btn.text = "Wall"
	wall_btn.position = Vector2(1040, 20)
	wall_btn.size = Vector2(80, 40)
	wall_btn.name = "WallButton"
	wall_btn.pressed.connect(_on_wall_button_pressed)
	add_child(wall_btn)
	# Window button
	var window_btn = Button.new()
	window_btn.text = "Window"
	window_btn.position = Vector2(1140, 20)
	window_btn.size = Vector2(80, 40)
	window_btn.name = "WindowButton"
	window_btn.pressed.connect(_on_window_button_pressed)
	add_child(window_btn)
	
	# Label pentru coordonate
	var coord_label = Label.new()
	coord_label.text = "Coordonate: (0.000, 0.000)"
	coord_label.position = Vector2(20, 70)
	coord_label.size = Vector2(200, 25)
	coord_label.name = "CoordLabel"
	coord_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(coord_label)
	
	# Label pentru informații dreptunghi
	var info_label = Label.new()
	info_label.text = "Dreptunghiuri: 0 | Poligoane: 0"
	info_label.position = Vector2(20, 100)
	info_label.size = Vector2(300, 25)
	info_label.name = "InfoLabel"
	info_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(info_label)
	
	# Label pentru instrucțiuni
	var help_label = Label.new()
	help_label.text = "Comenzi: SPACE-origine | Z-reset zoom | F-fit all | ESC-deselect/stop mode | Middle Mouse/Shift+Drag-pan | Right Click-închide poligon | Move buton-snap vizual"
	help_label.position = Vector2(20, size.y - 40)
	help_label.size = Vector2(size.x - 40, 25)
	help_label.name = "HelpLabel"
	help_label.add_theme_color_override("font_color", Color.CYAN)
	help_label.add_theme_font_size_override("font_size", 9)
	add_child(help_label)
	
	print("UI creat cu succes")

func _on_add_rect_button_pressed():
	print("Buton apăsat! Activez modul de plasare dreptunghi...")
	placing_rect = true
	drawing_polygon = false
	placing_cell = false
	move_mode = false
	polygon_manager.cancel_drawing()

func _on_add_polygon_button_pressed():
	print("Buton apăsat! Activez modul de desenare poligon...")
	drawing_polygon = true
	placing_rect = false
	placing_cell = false
	move_mode = false
	polygon_manager.start_drawing_polygon()

func _on_move_button_pressed():
	print("Buton apăsat! Activez modul Move cu snap...")
	move_mode = !move_mode  # Toggle move mode
	placing_rect = false
	drawing_polygon = false
	placing_cell = false
	polygon_manager.cancel_drawing()
	
	if move_mode:
		print("Modul Move ACTIVAT - punctele de control sunt vizibile pentru snap")
	else:
		print("Modul Move DEZACTIVAT")
	
	queue_redraw()

func _on_window_button_pressed():
	print("Window button pressed - enter window placement mode")
	placing_window = true
	placing_rect = false
	drawing_polygon = false
	placing_cell = false
	move_mode = false
	polygon_manager.cancel_drawing()
	queue_redraw()

func _on_rectangle_cell_button_pressed():
	print("Buton apăsat! Deschid panoul de proprietăți Rectangle Cell...")
	placing_cell = false
	placing_rect = false
	drawing_polygon = false
	move_mode = false
	polygon_manager.cancel_drawing()
	# Deschide panoul de proprietăți cu valorile default
	var default_props = cell_manager.get_default_properties()
	cell_properties_panel.set_default_properties(default_props)
	cell_properties_panel.visible = true
	update_info_display()
	queue_redraw()

func _on_properties_button_pressed():
	if cell_properties_panel:
		if cell_properties_panel.visible:
			cell_properties_panel.visible = false
		else:
			# Update panel with current selection
			if cell_manager.selected_cell:
				cell_properties_panel.set_cell_properties(cell_manager.selected_cell)
			else:
				# Show default properties when no cell is selected
				var default_props = cell_manager.get_default_properties()
				cell_properties_panel.set_default_properties(default_props)
			cell_properties_panel.visible = true

func _on_window_props_button_pressed():
	# Show the window properties panel for the selected window or defaults
	if window_properties_panel:
		if window_manager and window_manager.selected_window:
			window_properties_panel.set_window_properties(window_manager.selected_window)
		else:
			# show default properties
			window_properties_panel.set_window_properties(null)
		window_properties_panel.visible = true

func _on_move_by_distance_button_pressed():
	# Show a simple popup to enter axis and distance
	# Preserve current selection (don't deselect when opening the dialog)
	var current_selected_cell = cell_manager.selected_cell if cell_manager else null
	var current_selected_rect = rectangle_manager.selected_rectangle if rectangle_manager else null
	var current_selected_polygon = polygon_manager.selected_polygon if polygon_manager else null

	# If a previous dialog instance exists, free it to avoid stale/missing children
	var existing = get_node_or_null("MoveByDialog")
	if existing:
		existing.queue_free()

	# Create dialog (AcceptDialog is available in this project scope)
	var dlg = AcceptDialog.new()
	dlg.name = "MoveByDialog"

	# Build dialog UI
	var vb = VBoxContainer.new()
	# Use Godot 4-compatible minimum size property for containers
	vb.custom_minimum_size = Vector2(300, 140)
	dlg.add_child(vb)

	# Header label as dialog title
	var title_label = Label.new()
	title_label.text = "Move by Distance"
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(title_label)

	# Error label for validation feedback
	var error_label = Label.new()
	error_label.name = "ErrorLabel"
	error_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	error_label.text = ""
	vb.add_child(error_label)

	var axis_h = HBoxContainer.new()
	var axis_label = Label.new()
	axis_label.text = "Axis:"
	axis_h.add_child(axis_label)
	var axis_option = OptionButton.new()
	axis_option.name = "AxisOption"
	axis_option.add_item("X")
	axis_option.add_item("Y")
	axis_h.add_child(axis_option)
	vb.add_child(axis_h)

	var dist_h = HBoxContainer.new()
	var dist_label = Label.new()
	dist_label.text = "Distance:"
	dist_h.add_child(dist_label)
	var dist_input = LineEdit.new()
	dist_input.name = "DistanceInput"
	dist_input.placeholder_text = "e.g. 1.25"
	# Allow negative values and decimals; we'll validate on Apply
	dist_input.clear_button_enabled = true
	dist_h.add_child(dist_input)
	vb.add_child(dist_h)

	var btn_h = HBoxContainer.new()
	btn_h.anchor_right = 1.0
	var apply_btn = Button.new()
	apply_btn.text = "Apply"
	apply_btn.name = "ApplyMove"
	apply_btn.pressed.connect(_on_apply_move_by_distance_pressed)
	btn_h.add_child(apply_btn)
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.name = "CancelMove"
	cancel_btn.pressed.connect(_on_cancel_move_by_distance_pressed)
	btn_h.add_child(cancel_btn)
	vb.add_child(btn_h)

	add_child(dlg)

	# Reset fields and show (use safe get_node_or_null checks)
	var axis_node = dlg.get_node_or_null("AxisOption")
	if axis_node:
		axis_node.select(0)
	var dist_node = dlg.get_node_or_null("DistanceInput")
	if dist_node:
		dist_node.text = ""
	dlg.popup_centered()

	# Restore selection explicitly to avoid accidental deselection side-effects
	if current_selected_cell:
		cell_manager.select_cell(current_selected_cell)
	elif current_selected_rect:
		rectangle_manager.select_rectangle(current_selected_rect)
	elif current_selected_polygon:
		polygon_manager.select_polygon(current_selected_polygon)

	# If a cell is selected and properties panel is visible, refresh it
	if cell_properties_panel and cell_properties_panel.visible and cell_manager and cell_manager.selected_cell:
		cell_properties_panel.set_cell_properties(cell_manager.selected_cell)

func _on_wall_button_pressed():
	print("Wall button pressed - enter wall placement mode")
	placing_wall = true
	placing_rect = false
	drawing_polygon = false
	placing_cell = false
	move_mode = false
	polygon_manager.cancel_drawing()
	wall_has_start = false
	wall_start_point = Vector2.ZERO
	wall_preview_end = Vector2.ZERO
	queue_redraw()


func _on_apply_move_by_distance_pressed():
	var dlg = get_node_or_null("MoveByDialog")
	if dlg == null:
		return
	var axis_opt = dlg.get_node_or_null("AxisOption")
	var dist_input = dlg.get_node_or_null("DistanceInput")
	var error_label = dlg.get_node_or_null("ErrorLabel")
	if axis_opt == null or dist_input == null:
		print("MoveByDialog missing UI nodes; aborting apply")
		# Defensive: hide dialog if it's malformed
		dlg.hide()
		return
	var sel_index = axis_opt.get_selected()
	var axis = axis_opt.get_item_text(sel_index)
	var text = dist_input.text.strip_edges()
	if text == "":
		if error_label:
			error_label.text = "Please enter a distance (numeric)."
		print("No distance entered")
		return
	# Validate numeric input using string helper and convert
	if not text.is_valid_float():
		if error_label:
			error_label.text = "Invalid number. Use format like 1.25 or -0.5"
		print("Invalid distance entered: %s" % text)
		return
	var dist = text.to_float()
	# Clear error and apply
	if error_label:
		error_label.text = ""
	apply_move_by_distance(axis, dist)
	dlg.hide()

func _on_cancel_move_by_distance_pressed():
	var dlg = get_node_or_null("MoveByDialog")
	if dlg:
		dlg.hide()

func apply_move_by_distance(axis: String, distance: float):
	# Translate the currently selected object along axis by distance (world coords)
	var dx = 0.0
	var dy = 0.0
	if axis == "X":
		dx = distance
	else:
		dy = distance

	# Apply to the appropriate manager
	var applied = false
	if cell_manager and cell_manager.selected_cell:
		if cell_manager.call("translate_selected", dx, dy):
			applied = true
	elif rectangle_manager and rectangle_manager.selected_rectangle:
		if rectangle_manager.call("translate_selected", dx, dy):
			applied = true
	elif polygon_manager and polygon_manager.selected_polygon:
		if polygon_manager.call("translate_selected", dx, dy):
			applied = true

	if applied:
		print("Move by distance applied: axis=%s dist=%.3f" % [axis, distance])
		# Update properties panel if cell moved
		if cell_properties_panel and cell_properties_panel.visible and cell_manager.selected_cell:
			cell_properties_panel.set_cell_properties(cell_manager.selected_cell)
		update_info_display()
		queue_redraw()
	else:
		print("No selectable object to move by distance")

func _on_delete_button_pressed():
	var deleted = false
	# Prefer cell selection
	if cell_manager and cell_manager.selected_cell:
		deleted = cell_manager.call("delete_selected")
		if deleted:
			# Clear properties panel
			if cell_properties_panel and cell_properties_panel.visible:
				cell_properties_panel.clear_selection()
	elif rectangle_manager and rectangle_manager.selected_rectangle:
		deleted = rectangle_manager.call("delete_selected")
	elif polygon_manager and polygon_manager.selected_polygon:
		deleted = polygon_manager.call("delete_selected")

	if deleted:
		print("Selected object deleted")
		update_info_display()
		queue_redraw()
	else:
		print("No selected object to delete")

func _on_cell_properties_applied(properties: Dictionary):
	# If the properties are for a Window type, route to window manager
	if properties.has("type") and properties["type"] == "Window":
		# If a window is currently selected, update it
		if window_manager and window_manager.selected_window:
			var ok = window_manager.update_selected_window_from_dict(properties)
			if ok:
				print("Proprietăți aplicate ferestrei selectate")
			else:
				print("Eroare aplicare proprietăți ferestrei")
			cell_properties_panel.visible = false
		else:
			# No window selected - treat as default for new windows and enable placement mode
			if window_manager:
				window_manager.set_default_properties_from_dict(properties)
				print("Proprietăți Window setate ca default, activez modul de plasare!")
				cell_properties_panel.visible = false
				placing_window = true
		queue_redraw()
		update_info_display()
		return

	# Otherwise treat properties as rectangle/cell defaults or apply to selected cell
	if cell_manager and cell_manager.selected_cell:
		var success = cell_manager.update_selected_cell_properties_from_dict(properties)
		if success:
			print("Proprietăți aplicate cell-ului selectat")
			cell_properties_panel.visible = false
		else:
			print("Nu există cell selectat; setez proprietățile ca default")
			cell_manager.set_default_properties_from_dict(properties)
			cell_properties_panel.visible = false
			placing_cell = true
	else:
		cell_manager.set_default_properties_from_dict(properties)
		print("Proprietăți Rectangle Cell setate, activez modul de plasare!")
		cell_properties_panel.visible = false
		placing_cell = true
	queue_redraw()
	update_info_display()

func _on_window_properties_applied(properties: Dictionary):
	# Route properties to window manager
	if window_manager and window_manager.selected_window:
		window_manager.update_selected_window_from_dict(properties)
		window_properties_panel.visible = false
		queue_redraw()
		update_info_display()
	else:
		# set defaults and enable placing mode
		if window_manager:
			window_manager.set_default_properties_from_dict(properties)
			window_properties_panel.visible = false
			placing_window = true
			queue_redraw()
			update_info_display()
		
	queue_redraw()
	update_info_display()

func _input(event):
	# Comenzi rapide cu tastatura
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				# Centrează pe origine
				center_on_origin()
			KEY_Z:
				# Reset zoom
				reset_zoom()
			KEY_F:
				# Fit all rectangles
				fit_rectangles()
			KEY_ESCAPE:
				# Deselectează toate și anulează modurile
				if rectangle_manager.selected_rectangle:
					rectangle_manager.select_rectangle(null)
				if polygon_manager.selected_polygon:
					polygon_manager.select_polygon(null)
				if cell_manager.selected_cell:
					cell_manager.select_cell(null)
					# Clear properties panel
					if cell_properties_panel and cell_properties_panel.visible:
						cell_properties_panel.clear_selection()
				if drawing_polygon:
					polygon_manager.cancel_drawing()
					drawing_polygon = false
				if placing_rect:
					placing_rect = false
				if placing_cell:
					placing_cell = false
				if move_mode:
					move_mode = false
					print("Modul Move DEZACTIVAT cu ESC")
				update_info_display()
				queue_redraw()
			KEY_D:
				# Toggle snap debugging for cells
				cell_manager.debug_snapping = not cell_manager.debug_snapping
				print("Cell snap debugging: %s" % cell_manager.debug_snapping)
			KEY_DELETE:
				# Delete selected object via the same handler as the Delete button
				_on_delete_button_pressed()
		return
	
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
		
	var mouse_pos = get_local_mouse_position()
	var world_pos = screen_to_world(mouse_pos)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Pan cu Shift + click stânga 
		if event.pressed and Input.is_key_pressed(KEY_SHIFT):
			start_pan(mouse_pos)
		elif event.pressed and not is_panning:
			handle_mouse_press(world_pos)
		elif not event.pressed:
			if is_panning:
				end_pan()
			else:
				handle_mouse_release(world_pos)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		# Click dreapta pentru închiderea poligonului
		if event.pressed and drawing_polygon:
			polygon_manager.finish_drawing()
			drawing_polygon = false
			print("Poligon închis cu click dreapta!")
			update_info_display()
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		# Pan cu butonul din mijloc
		if event.pressed:
			start_pan(mouse_pos)
		else:
			end_pan()
	elif event is InputEventMouseMotion:
		if is_panning:
			update_pan(mouse_pos)
		else:
			handle_mouse_motion(world_pos)
	elif event is InputEventMouseButton:
		handle_zoom(event)

func handle_mouse_press(world_pos: Vector2):
	print("Mouse press la world pos AutoCAD: (%.3f, %.3f)" % [world_pos.x, world_pos.y])

	# Double-click detection (AutoCAD-like): two clicks on same target within 400ms
	var click_time = Time.get_ticks_msec()
	var target_obj: Object = null
	
	if placing_rect:
		# Aplică snap la punctele de control ale poligoanelor și cell-urilor când plasezi dreptunghi
		var polygon_snap_points = polygon_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var all_snap_points = polygon_snap_points + cell_snap_points + rectangle_snap_points
		var snapped_pos = rectangle_manager.get_snapped_position(world_pos, all_snap_points)
		
		# Plasează un dreptunghi nou la poziția cu snap
		placing_rect = false
		var rect = rectangle_manager.add_rectangle(snapped_pos, Vector2(0.25, 0.25))
		rectangle_manager.select_rectangle(rect)  # Selectează automat dreptunghiul nou
		print("Dreptunghi desenat la coordonate AutoCAD cu snap: (%.3f, %.3f)" % [snapped_pos.x, snapped_pos.y])
		print("Dimensiuni: 0.25 x 0.25 | Total dreptunghiuri: %d" % rectangle_manager.rectangles.size())
		update_info_display()
		queue_redraw()
		return
	
	if placing_cell:
		# Aplică snap la toate punctele disponibile când plasezi cell
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var polygon_snap_points = polygon_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var all_snap_points = rectangle_snap_points + polygon_snap_points + cell_snap_points
		var snapped_pos = cell_manager.call("get_snapped_position", world_pos, all_snap_points, Callable(self, "world_to_screen"), 10.0)
		
		# Plasează un cell nou la poziția cu snap
		placing_cell = false
		var cell = cell_manager.add_cell(snapped_pos)
		cell_manager.select_cell(cell)  # Selectează automat cell-ul nou
		
		# Update properties panel if visible
		if cell_properties_panel and cell_properties_panel.visible:
			cell_properties_panel.set_cell_properties(cell)
		
		print("Rectangle Cell plasat la coordonate AutoCAD cu snap: (%.3f, %.3f)" % [snapped_pos.x, snapped_pos.y])
		print("Dimensiuni: %.2fx%.2f | Offset: %.3f | Total cells: %d" % [
			cell.width, cell.height, cell.offset, cell_manager.cells.size()
		])
		update_info_display()
		queue_redraw()
		return

	# Wall placement: first click sets start, second click sets end
	if placing_wall:
		# Gather snap points from other managers
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var polygon_snap_points = polygon_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var wall_snap_points = wall_manager.get_snap_points()
		var all_snap_points = rectangle_snap_points + polygon_snap_points + cell_snap_points + wall_snap_points
		# Use rectangle_manager's snap helper for simplicity (it returns world snapped pos)
		var snapped_pos = rectangle_manager.get_snapped_position(world_pos, all_snap_points)
		if not wall_has_start:
			# Set start
			wall_start_point = snapped_pos
			wall_preview_end = snapped_pos
			wall_has_start = true
			print("Wall start set at (%.3f, %.3f)" % [snapped_pos.x, snapped_pos.y])
		else:
			# Set end and create wall
			var wall_end = snapped_pos
			# Create wall with default width 0.25
			var w = wall_manager.add_wall(wall_start_point, wall_end, 0.25)
			wall_manager.select_wall(w)
			placing_wall = false
			wall_has_start = false
			wall_start_point = Vector2.ZERO
			wall_preview_end = Vector2.ZERO
			var info = wall_manager.to_dict(w)
			print("Wall created id=%d ctrl_start=(%.3f, %.3f) ctrl_end=(%.3f, %.3f) geom_start=(%.3f, %.3f) geom_end=(%.3f, %.3f) offsets=(%.3f, %.3f)" % [
				w.id,
				info["ctrl_start"].x, info["ctrl_start"].y,
				info["ctrl_end"].x, info["ctrl_end"].y,
				info["geom_start"].x, info["geom_start"].y,
				info["geom_end"].x, info["geom_end"].y,
				info["start_offset"], info["end_offset"]
			])
			update_info_display()
			queue_redraw()
		return

	# Window placement: single click inserts window at insert point
	if placing_window:
		# snap to existing snap points
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var polygon_snap_points = polygon_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var wall_snap_points = wall_manager.get_snap_points()
		var all_snap_points = rectangle_snap_points + polygon_snap_points + cell_snap_points + wall_snap_points
		var snapped = rectangle_manager.get_snapped_position(world_pos, all_snap_points)
		var w = window_manager.add_window(snapped)
		window_manager.select_window(w)
		placing_window = false
		print("Window created id=%d insert=(%.3f, %.3f)" % [w.id, w.insert_point.x, w.insert_point.y])
		queue_redraw()
		return

	# Check for wall grip click (start editing walls) - high priority over selection
	# Check for window grip click (start editing windows) - give windows priority so they're selectable when overlapping walls
	if window_manager:
		var win_grip_info = window_manager.get_grip_at_position(world_pos, 10.0, Callable(self, "world_to_screen"))
		if win_grip_info["window"]:
			window_manager.start_drag_grip(win_grip_info["window"], win_grip_info["grip"], world_pos)
			print("Started dragging window grip: %d on window id=%d" % [win_grip_info["grip"], win_grip_info["window"].id])
			queue_redraw()
			return

	# Check for wall grip click (start editing walls)
	if wall_manager:
		var grip_info = wall_manager.get_grip_at_position(world_pos, 10.0, Callable(self, "world_to_screen"))
		if grip_info["wall"]:
			# Start dragging that grip
			wall_manager.start_drag_grip(grip_info["wall"], grip_info["grip"], world_pos)
			print("Started dragging wall grip: %d on wall id=%d" % [grip_info["grip"], grip_info["wall"].id])
			queue_redraw()
			return
	
	if drawing_polygon:
		# Aplică snap la punctele de control ale dreptunghiurilor, cell-urilor și altor poligoane
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var other_polygon_snap_points = polygon_manager.get_snap_points()
		var all_snap_points = rectangle_snap_points + cell_snap_points + other_polygon_snap_points
		var snapped_pos = polygon_manager.get_snapped_position(world_pos, all_snap_points)
		
		# Adaugă punct la poligonul curent cu snap
		var polygon_finished = polygon_manager.add_point_to_current(snapped_pos)
		if polygon_finished:
			drawing_polygon = false
			print("Poligon finalizat!")
		else:
			print("Punct adăugat la poligon cu snap la: (%.3f, %.3f)" % [snapped_pos.x, snapped_pos.y])
		update_info_display()
		queue_redraw()
		return
	
	# Determine target for selection/double-click: check cell, rectangle, polygon in order
	# We'll set target_obj so double-click can be detected below
	# Verifică punctele de control ale poligoanelor mai întâi
	if polygon_manager.start_drag_control_point(world_pos):
		print("Început editare punct de control poligon")
		queue_redraw()
		return
	
	# Verifică selecție cell mai întâi
	var cell = cell_manager.get_cell_at_position(world_pos)
	if cell:
		target_obj = cell
		if cell == cell_manager.selected_cell:
			# Dacă este deja selectat, începe drag
			cell_manager.start_drag_cell(cell, world_pos)
			print("Început mutare cell la (%.3f, %.3f)" % [world_pos.x, world_pos.y])
		else:
			# Selectează cell-ul
			cell_manager.select_cell(cell)
			rectangle_manager.select_rectangle(null)  # Deselectează dreptunghiurile
			polygon_manager.select_polygon(null)  # Deselectează poligoanele

			if cell_properties_panel and cell_properties_panel.visible:
				cell_properties_panel.set_cell_properties(cell)
			
			print("Cell selectat: %s la (%.3f, %.3f)" % [cell.cell_name, cell.position.x, cell.position.y])
	else:
		# Verifică selecție dreptunghi sau grip point
		var rect = rectangle_manager.get_rectangle_at_position(world_pos)
		# Check for window selection before rectangle selection fallback
		var win = null
		if window_manager:
			win = window_manager.get_window_at_position(world_pos)
		if win:
			target_obj = win
			if win == window_manager.selected_window:
				# start drag by center
				window_manager.start_drag_grip(win, 1, world_pos)
				print("Început mutare fereastră la (%.3f, %.3f)" % [world_pos.x, world_pos.y])
			else:
				window_manager.select_window(win)
				print("Fereastră selectată id=%d insert=(%.3f, %.3f)" % [win.id, win.insert_point.x, win.insert_point.y])
				# Open dedicated window properties panel
				if window_properties_panel:
					window_properties_panel.set_window_properties(win)
					window_properties_panel.visible = true
				queue_redraw()
				return

		if rect:
			target_obj = rect
			if rect == rectangle_manager.selected_rectangle:
				# Dacă este deja selectat, începe drag
				rectangle_manager.start_drag_rectangle(rect, world_pos)
				print("Început mutare dreptunghi la (%.3f, %.3f)" % [world_pos.x, world_pos.y])
			else:
				# Selectează dreptunghiul
				rectangle_manager.select_rectangle(rect)
				polygon_manager.select_polygon(null)  # Deselectează poligoanele
				cell_manager.select_cell(null)  # Deselectează cell-urile
				
				# Clear properties panel when switching to rectangle
				if cell_properties_panel and cell_properties_panel.visible:
					cell_properties_panel.clear_selection()
				
				print("Dreptunghi selectat la (%.3f, %.3f)" % [rect.position.x, rect.position.y])

		# Verifică selecție poligon
		var polygon = polygon_manager.get_polygon_at_position(world_pos)
		if polygon:
			target_obj = polygon
			if polygon == polygon_manager.selected_polygon:
				# Dacă este deja selectat, începe drag
				polygon_manager.start_drag_polygon(polygon, world_pos)
				print("Început mutare poligon")
			else:
				# Selectează poligonul
				polygon_manager.select_polygon(polygon)
				rectangle_manager.select_rectangle(null)  # Deselectează dreptunghiurile
				cell_manager.select_cell(null)  # Deselectează cell-urile
				
				# Clear properties panel when switching to polygon
				if cell_properties_panel and cell_properties_panel.visible:
					cell_properties_panel.clear_selection()
				
				print("Poligon selectat")
		else:
			# Deselectează toate
			if rectangle_manager.selected_rectangle:
				print("Deselectare dreptunghi")
			if polygon_manager.selected_polygon:
				print("Deselectare poligon")
			if cell_manager.selected_cell:
				print("Deselectare cell")
				# Clear properties panel when deselecting cell
				if cell_properties_panel and cell_properties_panel.visible:
					cell_properties_panel.clear_selection()
			rectangle_manager.select_rectangle(null)
			polygon_manager.select_polygon(null)
			cell_manager.select_cell(null)

	# Double-click handling: if same target as previous click within threshold, open properties
	var dbl_threshold = 400 # ms
	if last_click_target != null and target_obj != null and last_click_target == target_obj and (click_time - last_click_time) <= dbl_threshold:
		# It's a double-click on the same object
		print("Double-click detected on target: %s" % [str(target_obj)])
		# Ensure the object is selected and open the properties panel
		if target_obj is RectangleCell:
			cell_manager.select_cell(target_obj)
			if cell_properties_panel:
				cell_properties_panel.set_cell_properties(target_obj)
				cell_properties_panel.visible = true
		elif target_obj and target_obj.has_method("get_info"):
			# Generic fallback for rectangles/polygons: try to open panel if supported
			if target_obj == rectangle_manager.selected_rectangle:
				# No unified panel for rectangles yet; we reuse cell panel for now and clear selection when switching types
				cell_properties_panel.clear_selection()
				cell_properties_panel.visible = true
			elif target_obj == polygon_manager.selected_polygon:
				cell_properties_panel.clear_selection()
				cell_properties_panel.visible = true
		# reset last click to avoid triple-trigger
		last_click_target = null
		last_click_time = 0
		return

	# Not a double-click: record this click as last
	last_click_time = click_time
	last_click_target = target_obj
	update_info_display()
	queue_redraw()

func handle_mouse_release(world_pos: Vector2):
	if polygon_manager.is_dragging_control_point:
		print("Punct de control poligon editat la coordonate finale: (%.3f, %.3f)" % [world_pos.x, world_pos.y])
		polygon_manager.finish_control_point_drag()
		queue_redraw()
	elif cell_manager.is_dragging:
		print("Cell mutat la coordonate finale: (%.3f, %.3f)" % [world_pos.x, world_pos.y])
		cell_manager.end_drag()
		queue_redraw()
	elif rectangle_manager.dragging_rectangle:
		print("Dreptunghi mutat la coordonate finale: (%.3f, %.3f)" % [world_pos.x, world_pos.y])
		rectangle_manager.end_drag()
		queue_redraw()
	elif polygon_manager.is_dragging:
		print("Poligon mutat la coordonate finale")
		polygon_manager.finish_drag()
		queue_redraw()
	# End wall dragging if active
	elif wall_manager and wall_manager.is_dragging:
		print("Wall drag finished at (%.3f, %.3f)" % [world_pos.x, world_pos.y])
		wall_manager.end_drag()
		queue_redraw()

	# End window dragging if active
	elif window_manager and window_manager.is_dragging:
		print("Window drag finished at (%.3f, %.3f)" % [world_pos.x, world_pos.y])
		window_manager.end_drag()
		queue_redraw()

func handle_mouse_motion(world_pos: Vector2):
	# Actualizează coordonatele în timp real
	update_coordinate_display(world_pos)
	
	# Actualizează hover pentru punctele de control ale poligoanelor
	polygon_manager.update_hover_control_point(world_pos)
	
	# Actualizează hover pentru grip points ale cell-urilor
	cell_manager.update_hover_grip(world_pos)

	# Update hover for walls
	if wall_manager:
		wall_manager.update_hover_grip(world_pos, Callable(self, "world_to_screen"))

	# Update hover for windows
	if window_manager:
		window_manager.update_hover_grip(world_pos, Callable(self, "world_to_screen"))
	
	# Actualizează drag pentru punctele de control ale poligoanelor
	if polygon_manager.is_dragging_control_point:
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var other_polygon_snap_points = polygon_manager.get_snap_points()
		var all_snap_points = rectangle_snap_points + cell_snap_points + other_polygon_snap_points
		polygon_manager.update_control_point_drag(world_pos, all_snap_points)
		queue_redraw()
		return
	
	# Actualizează drag pentru cell-uri (cu snap la toate punctele)
	if cell_manager.is_dragging:
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var polygon_snap_points = polygon_manager.get_snap_points()
		var other_cell_snap_points = cell_manager.get_snap_points()
		var all_snap_points = rectangle_snap_points + polygon_snap_points + other_cell_snap_points
		cell_manager.call("update_drag", world_pos, all_snap_points, Callable(self, "world_to_screen"), 10.0)
		queue_redraw()
	
	# Actualizează drag pentru dreptunghiuri (cu snap la punctele poligoanalor și cell-urilor)
	elif rectangle_manager.dragging_rectangle:
		var polygon_snap_points = polygon_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var all_snap_points = polygon_snap_points + cell_snap_points
		rectangle_manager.update_drag(world_pos, all_snap_points)
		queue_redraw()
	
	# Actualizează drag pentru poligoane (cu snap la punctele dreptunghiurilor și cell-urilor)
	elif polygon_manager.is_dragging:
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var all_snap_points = rectangle_snap_points + cell_snap_points
		polygon_manager.update_drag(world_pos, all_snap_points)
		queue_redraw()
	
	# Redraw pentru preview line în timpul desenării poligoanalor
	elif drawing_polygon:
		queue_redraw()
	
	# Actualizează hover grip
	rectangle_manager.update_hover_grip(world_pos, camera_zoom, screen_to_world_callable())

	# Handle wall dragging: if a wall grip is being dragged, update it with snap
	if wall_manager and wall_manager.is_dragging:
		# aggregate snap points from other managers
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var polygon_snap_points = polygon_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var wall_snap_points = wall_manager.get_snap_points()
		var all_snap_points = rectangle_snap_points + polygon_snap_points + cell_snap_points + wall_snap_points
		# Use rectangle_manager's helper to snap the world_pos to nearest snap point (world coords)
		var snapped = rectangle_manager.get_snapped_position(world_pos, all_snap_points)
		wall_manager.update_drag(snapped, all_snap_points, Callable(self, "world_to_screen"), 10.0)
		queue_redraw()
		return

	# Handle window dragging similarly
	if window_manager and window_manager.is_dragging:
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var polygon_snap_points = polygon_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var wall_snap_points = wall_manager.get_snap_points()
		var window_snap_points = window_manager.get_snap_points()
		var all_snap_points = rectangle_snap_points + polygon_snap_points + cell_snap_points + wall_snap_points + window_snap_points
		var snapped = rectangle_manager.get_snapped_position(world_pos, all_snap_points)
		window_manager.update_drag(snapped, all_snap_points, Callable(self, "world_to_screen"), 10.0)
		queue_redraw()
		return

	# Update wall preview when placing
	if placing_wall and wall_has_start:
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var polygon_snap_points = polygon_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var wall_snap_points = wall_manager.get_snap_points()
		var all_snap_points = rectangle_snap_points + polygon_snap_points + cell_snap_points + wall_snap_points
		wall_preview_end = rectangle_manager.get_snapped_position(world_pos, all_snap_points)
		# keep flag true
		wall_has_start = true
		queue_redraw()
		queue_redraw()


	
	# Actualizează drag
	if rectangle_manager.dragging_rectangle:
		rectangle_manager.update_drag(world_pos)
		queue_redraw()
	elif rectangle_manager.hovered_grip != -1:
		# Redraw pentru a actualiza grip hover
		queue_redraw()

func handle_zoom(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_in()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_out()

func zoom_in():
	var new_zoom = camera_zoom * 1.2
	if new_zoom <= MAX_ZOOM:
		camera_zoom = new_zoom
		queue_redraw()
		print("Zoom in: ", camera_zoom)

func zoom_out():
	var new_zoom = camera_zoom * 0.8
	if new_zoom >= MIN_ZOOM:
		camera_zoom = new_zoom
		queue_redraw()
		print("Zoom out: ", camera_zoom)

# Funcții de conversie coordonate (AutoCAD style - Y în sus)
func screen_to_world(screen_pos: Vector2) -> Vector2:
	# Convertește din coordonate de ecran la coordonate world AutoCAD
	var centered_pos = screen_pos - size * 0.5
	# Inversează Y pentru stilul AutoCAD (Y în sus)
	centered_pos.y = -centered_pos.y
	return centered_pos / (camera_zoom * GRID_UNIT_SIZE) + camera_position

func world_to_screen(world_pos: Vector2) -> Vector2:
	# Convertește din coordonate world AutoCAD la coordonate de ecran
	var screen_coords = (world_pos - camera_position) * (camera_zoom * GRID_UNIT_SIZE)
	# Inversează Y pentru stilul AutoCAD
	screen_coords.y = -screen_coords.y
	return screen_coords + size * 0.5

func _sort_windows_by_priority(a, b):
	# sort ascending by cut_priority (lower first). We draw in that order so higher priority overlays later.
	var pa = 0
	var pb = 0
	if a != null:
		pa = int(a.cut_priority)
	if b != null:
		pb = int(b.cut_priority)
	return pa - pb

func screen_to_world_callable() -> Callable:
	return Callable(self, "screen_to_world")

# Funcții pentru Pan (panoramă)
func start_pan(screen_pos: Vector2):
	is_panning = true
	pan_start_pos = screen_pos
	pan_start_camera_pos = camera_position
	print("Început pan la poziția: %s" % screen_pos)

func update_pan(screen_pos: Vector2):
	if not is_panning:
		return
	
	# Calculează diferența în pixeli
	var pixel_delta = screen_pos - pan_start_pos
	
	# Convertește la coordonate world (inversează Y pentru AutoCAD)
	pixel_delta.y = -pixel_delta.y
	var world_delta = pixel_delta / (camera_zoom * GRID_UNIT_SIZE)
	
	# Actualizează poziția camerei
	camera_position = pan_start_camera_pos - world_delta
	
	queue_redraw()

func end_pan():
	if is_panning:
		is_panning = false
		print("Sfârșit pan. Poziția finală camera: (%.3f, %.3f)" % [camera_position.x, camera_position.y])
		queue_redraw()  # Pentru a elimina indicatorul pan

func draw_pan_indicator():
	# Desenează un cursor în formă de mână în timpul pan-ului
	var mouse_pos = get_local_mouse_position()
	var cursor_size = 16.0
	var cursor_color = Color.YELLOW
	
	# Desenează simbolul mână/mutare
	var cursor_color_alpha = Color(cursor_color.r, cursor_color.g, cursor_color.b, 0.3)
	draw_circle(mouse_pos, cursor_size, cursor_color_alpha)
	draw_circle(mouse_pos, cursor_size, cursor_color, false, 2.0)
	
	# Desenează săgeți în 4 direcții
	var arrow_length = cursor_size * 0.6
	var arrow_color = Color.WHITE
	
	# Săgeată sus
	draw_line(mouse_pos, mouse_pos + Vector2(0, -arrow_length), arrow_color, 2.0)
	draw_line(mouse_pos + Vector2(0, -arrow_length), mouse_pos + Vector2(-4, -arrow_length + 6), arrow_color, 2.0)
	draw_line(mouse_pos + Vector2(0, -arrow_length), mouse_pos + Vector2(4, -arrow_length + 6), arrow_color, 2.0)
	
	# Săgeată jos
	draw_line(mouse_pos, mouse_pos + Vector2(0, arrow_length), arrow_color, 2.0)
	draw_line(mouse_pos + Vector2(0, arrow_length), mouse_pos + Vector2(-4, arrow_length - 6), arrow_color, 2.0)
	draw_line(mouse_pos + Vector2(0, arrow_length), mouse_pos + Vector2(4, arrow_length - 6), arrow_color, 2.0)
	
	# Săgeată stânga
	draw_line(mouse_pos, mouse_pos + Vector2(-arrow_length, 0), arrow_color, 2.0)
	draw_line(mouse_pos + Vector2(-arrow_length, 0), mouse_pos + Vector2(-arrow_length + 6, -4), arrow_color, 2.0)
	draw_line(mouse_pos + Vector2(-arrow_length, 0), mouse_pos + Vector2(-arrow_length + 6, 4), arrow_color, 2.0)
	
	# Săgeată dreapta
	draw_line(mouse_pos, mouse_pos + Vector2(arrow_length, 0), arrow_color, 2.0)
	draw_line(mouse_pos + Vector2(arrow_length, 0), mouse_pos + Vector2(arrow_length - 6, -4), arrow_color, 2.0)
	draw_line(mouse_pos + Vector2(arrow_length, 0), mouse_pos + Vector2(arrow_length - 6, 4), arrow_color, 2.0)

func update_coordinate_display(world_pos: Vector2):
	var coord_label = get_node_or_null("CoordLabel")
	if coord_label:
		coord_label.text = "Coordonate: (%.3f, %.3f)" % [world_pos.x, world_pos.y]

func update_info_display():
	var info_label = get_node_or_null("InfoLabel")
	if info_label and rectangle_manager:
		var selected_info = ""
		if rectangle_manager.selected_rectangle:
			var rect = rectangle_manager.selected_rectangle
			selected_info = " | Dreptunghi selectat: (%.3f, %.3f)" % [rect.position.x, rect.position.y]
		elif polygon_manager.selected_polygon:
			var center = polygon_manager.selected_polygon.get_center()
			selected_info = " | Poligon selectat: (%.3f, %.3f)" % [center.x, center.y]
		elif cell_manager.selected_cell:
			var cell = cell_manager.selected_cell
			selected_info = " | Cell selectat: %s (%.3f, %.3f) [Index: %d]" % [cell.cell_name, cell.position.x, cell.position.y, cell.cell_index]
		
		var mode_info = ""
		if move_mode:
			mode_info = " | MOVE MODE: puncte de control vizibile"
		elif drawing_polygon:
			mode_info = " | DESENEZ POLIGON"
		elif placing_rect:
			mode_info = " | PLASEZ DREPTUNGHI"
		elif placing_cell:
			mode_info = " | PLASEZ RECTANGLE CELL"
		
		info_label.text = "Dreptunghiuri: %d | Poligoane: %d | Cells: %d%s%s" % [
			rectangle_manager.rectangles.size(), 
			polygon_manager.polygons.size(), 
			cell_manager.cells.size(),
			selected_info, 
			mode_info
		]

# Funcții de navigare
func center_on_origin():
	camera_position = Vector2.ZERO
	print("Centrat pe origine (0, 0)")
	queue_redraw()

func reset_zoom():
	camera_zoom = 1.0
	print("Zoom resetat la 1.0")
	queue_redraw()

func fit_rectangles():
	if rectangle_manager.rectangles.is_empty():
		center_on_origin()
		return
	
	# Calculează bounds pentru toate dreptunghiurile
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for rect in rectangle_manager.rectangles:
		var rect_bounds = rect.get_bounds()
		min_pos = min_pos.min(rect_bounds.position)
		max_pos = max_pos.max(rect_bounds.position + rect_bounds.size)
	
	# Centrează camera pe conținut
	var center = (min_pos + max_pos) * 0.5
	camera_position = center
	
	# Ajustează zoom pentru a încadra tot conținutul
	var content_size = max_pos - min_pos
	var margin = 1.0  # Margine în jurul conținutului
	var zoom_x = (size.x * 0.8) / ((content_size.x + margin) * GRID_UNIT_SIZE)
	var zoom_y = (size.y * 0.8) / ((content_size.y + margin) * GRID_UNIT_SIZE)
	camera_zoom = min(zoom_x, zoom_y, MAX_ZOOM)
	camera_zoom = max(camera_zoom, MIN_ZOOM)
	
	print("Fit rectangles - Center: (%.3f, %.3f), Zoom: %.3f" % [center.x, center.y, camera_zoom])
	queue_redraw()

func _draw():
	print("_draw() apelat!")
	
	# Curăță ecranul
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	
	# Desenează grid
	draw_grid()
	
	# Desenează axele
	draw_axes()
	
	# Desenează originea
	draw_origin()
	
	# Desenează etichetele grid-ului
	draw_grid_labels()
	
	# Desenează dreptunghiurile
	draw_rectangles()
	
	# Desenează cell-urile
	draw_cells()
	
	# Desenează poligoanele
	draw_polygons()

	# Desenează pereții
	if wall_manager:
		for w in wall_manager.walls:
			WallRenderer.draw_wall_rect(self, w, Callable(self, "world_to_screen"))
			# Draw grips for walls (highlight hovered grip)
			var hovered = -1
			if wall_manager.hovered_wall == w:
				hovered = wall_manager.hovered_grip
			WallRenderer.draw_grip_points(self, w, Callable(self, "world_to_screen"), hovered)
	# Desenează preview pentru wall în curs de desen
	if placing_wall and wall_has_start:
		WallRenderer.draw_wall_line(self, wall_start_point, wall_preview_end, Color(0.8,0.8,0.2), 2.0, Callable(self, "world_to_screen"))

	# Desenează ferestrele (windows) - ordonate după cut_priority
	if window_manager:
		var win_list = window_manager.windows.duplicate()
		# sort_custom expects a single Callable in Godot 4
		win_list.sort_custom(Callable(self, "_sort_windows_by_priority"))
		for w in win_list:
			WindowRenderer.draw_window(self, w, Callable(self, "world_to_screen"))

	# Desenează indicator pan dacă este activ
	if is_panning:
		draw_pan_indicator()
	
	print("Desenare completă!")

func draw_grid():
	var grid_color = Color.GRAY
	grid_color.a = 0.3
	
	# Limitele vizibile în coordonate world
	var top_left = screen_to_world(Vector2.ZERO)
	var bottom_right = screen_to_world(size)
	
	# Linii verticale
	var start_x = floor(top_left.x)
	var end_x = ceil(bottom_right.x)
	for x in range(int(start_x), int(end_x) + 1):
		var screen_x = world_to_screen(Vector2(x, 0)).x
		if screen_x >= 0 and screen_x <= size.x:
			draw_line(
				Vector2(screen_x, 0),
				Vector2(screen_x, size.y),
				grid_color, 1.0
			)
	
	# Linii orizontale
	# În coordonate AutoCAD, top_left.y > bottom_right.y din cauza inversiunii Y
	var start_y = floor(min(top_left.y, bottom_right.y))
	var end_y = ceil(max(top_left.y, bottom_right.y))
	for y in range(int(start_y), int(end_y) + 1):
		var screen_y = world_to_screen(Vector2(0, y)).y
		if screen_y >= 0 and screen_y <= size.y:
			draw_line(
				Vector2(0, screen_y),
				Vector2(size.x, screen_y),
				grid_color, 1.0
			)

func draw_axes():
	var origin_screen = world_to_screen(Vector2.ZERO)
	var axis_color = Color.RED
	var axis_width = 2.0
	
	# Axa X (linia roșie orizontală prin origine)
	draw_line(
		Vector2(0, origin_screen.y),
		Vector2(size.x, origin_screen.y),
		axis_color, axis_width
	)
	
	# Axa Y (linia roșie verticală prin origine)
	draw_line(
		Vector2(origin_screen.x, 0),
		Vector2(origin_screen.x, size.y),
		axis_color, axis_width
	)

func draw_origin():
	var origin_screen = world_to_screen(Vector2.ZERO)
	
	# Cerc la origine
	draw_circle(origin_screen, 8.0, Color.RED)
	draw_circle(origin_screen, 6.0, Color.BLACK)
	draw_circle(origin_screen, 4.0, Color.RED)
	
	# Eticheta (0,0) - stilul AutoCAD
	var font = ThemeDB.fallback_font
	draw_string(
		font,
		origin_screen + Vector2(10, -10),
		"(0.000, 0.000)",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color.WHITE
	)

func draw_grid_labels():
	# Desenează etichete cu coordonate pe grid
	var font = ThemeDB.fallback_font
	var top_left = screen_to_world(Vector2.ZERO)
	var bottom_right = screen_to_world(size)
	
	# Etichete pe axa X
	var start_x = floor(top_left.x)
	var end_x = ceil(bottom_right.x)
	for x in range(int(start_x), int(end_x) + 1):
		if x != 0 and x % 2 == 0:  # Afișează doar la fiecare 2 unități
			var screen_x = world_to_screen(Vector2(x, 0)).x
			if screen_x >= 30 and screen_x <= size.x - 30:
				var label = "%.0f" % x
				draw_string(font, Vector2(screen_x - 8, size.y - 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.GRAY)
	
	# Etichete pe axa Y
	var start_y = floor(top_left.y)
	var end_y = ceil(bottom_right.y)
	for y in range(int(start_y), int(end_y) + 1):
		if y != 0 and y % 2 == 0:  # Afișează doar la fiecare 2 unități
			var screen_y = world_to_screen(Vector2(0, y)).y
			if screen_y >= 30 and screen_y <= size.y - 30:
				var label = "%.0f" % y
				draw_string(font, Vector2(10, screen_y + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.GRAY)

func draw_rectangles():
	if not rectangle_manager:
		return
	
	# Desenează dreptunghiurile
	for rect in rectangle_manager.rectangles:
		RectangleRenderer.draw_rectangle(self, rect, camera_zoom, Callable(self, "world_to_screen"))
	
	# Desenează grip-urile pentru dreptunghiul selectat
	if rectangle_manager.selected_rectangle:
		RectangleRenderer.draw_grip_points(
			self,
			rectangle_manager.selected_rectangle,
			camera_zoom,
			Callable(self, "world_to_screen"),
			rectangle_manager.hovered_grip
		)
	
	# În move mode, desenează grip-uri pentru toate dreptunghiurile pentru snap vizual
	if move_mode:
		for rect in rectangle_manager.rectangles:
			if rect != rectangle_manager.selected_rectangle:  # Nu duplica pentru cel selectat
				RectangleRenderer.draw_grip_points(
					self,
					rect,
					camera_zoom,
					Callable(self, "world_to_screen"),
					-1,  # Fără hover pentru cele neselectate (folosește -1 pentru GripPoint)
					0.5  # Transparența mai mică pentru a fi mai subtile
				)

func draw_cells():
	if not cell_manager:
		return
	
	# Desenează cell-urile
	for cell in cell_manager.cells:
		RectangleCellRenderer.draw_rectangle_cell(self, cell, camera_zoom, Callable(self, "world_to_screen"))

	# Dacă se trage un cell, desenează și punctele de snap agregate (rectangles, polygons, cells)
	if cell_manager.is_dragging:
		# Puncte snap pentru dreptunghiuri
		RectangleRenderer.draw_all_snap_points(self, rectangle_manager, Callable(self, "world_to_screen"))
		# Puncte snap pentru poligoane
		PolygonRenderer.draw_all_snap_points(self, polygon_manager, Callable(self, "world_to_screen"))
		# Puncte snap pentru cell-uri
		RectangleCellRenderer.draw_all_snap_points(self, cell_manager, Callable(self, "world_to_screen"))
	
	# Desenează grip-urile pentru cell-ul selectat
	if cell_manager.selected_cell:
		RectangleCellRenderer.draw_grip_points(
			self,
			cell_manager.selected_cell,
			camera_zoom,
			Callable(self, "world_to_screen"),
			cell_manager.hovered_grip
		)
	
	# În move mode, desenează grip-uri pentru toate cell-urile pentru snap vizual
	if move_mode:
		for cell in cell_manager.cells:
			if cell != cell_manager.selected_cell:  # Nu duplica pentru cel selectat
				RectangleCellRenderer.draw_grip_points(
					self,
					cell,
					camera_zoom,
					Callable(self, "world_to_screen"),
					Vector2.ZERO,  # Fără hover pentru cele neselectate
					0.5  # Transparența mai mică pentru a fi mai subtile
				)

func draw_polygons():
	if not polygon_manager:
		return
	
	# Desenează poligoanele finalizate
	for polygon in polygon_manager.polygons:
		PolygonRenderer.draw_polygon(self, polygon, Callable(self, "world_to_screen"))
		
		# Desenează punctele de control cu hover și drag pentru poligoanele selectate
		if polygon.is_selected and polygon.is_closed:
			PolygonRenderer.draw_control_points_with_manager(self, polygon, Callable(self, "world_to_screen"), polygon_manager)
		
		# În move mode, desenează punctele de control pentru toate poligoanele pentru snap vizual
		elif move_mode and polygon.is_closed:
			PolygonRenderer.draw_control_points(self, polygon, Callable(self, "world_to_screen"))
	
	# Desenează poligonul curent în desenare cu preview
	if polygon_manager.current_drawing_polygon:
		var preview_pos = Vector2.ZERO
		if drawing_polygon:
			preview_pos = screen_to_world(get_local_mouse_position())
		PolygonRenderer.draw_polygon(
			self, 
			polygon_manager.current_drawing_polygon, 
			Callable(self, "world_to_screen"), 
			true, 
			preview_pos
		)
	
	# Desenează punctele de snap în timpul desenării pentru feedback vizual
	if drawing_polygon or placing_rect or placing_cell or move_mode:
		# Arată punctele de snap ale dreptunghiurilor
		RectangleRenderer.draw_all_snap_points(self, rectangle_manager, Callable(self, "world_to_screen"))
		# Arată punctele de snap ale cell-urilor
		RectangleCellRenderer.draw_all_snap_points(self, cell_manager, Callable(self, "world_to_screen"))
		# Arată punctele de snap ale poligoanalor
		PolygonRenderer.draw_all_snap_points(self, polygon_manager, Callable(self, "world_to_screen"))
