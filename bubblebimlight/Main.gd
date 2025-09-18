# Main.gd
extends Control

@onready var cad_viewer: Node3D
var snap_grid_panel: Control
var snap_grid_panel_scene = preload("res://Shapes/GridPoints.tscn")
var project_browser_scene = preload("res://ProjectBrowser.tscn")   # added
var project_browser_instance: Control = null                      # added
var viewer3dtab_scene = preload("res://Viewers/2DViewer.tscn")
var viewer3dtab_instance: Control = null

func _ready():
	_setup_main_scene()
	_setup_ui_buttons()
	_create_project_browser_panel()   # added

func _setup_main_scene():
	# Obține TabContainer existent sau creează unul nou (direct sub acest Control)
	var tab_container: TabContainer = null
	if has_node("TabContainer"):
		tab_container = get_node("TabContainer") as TabContainer
	else:
		tab_container = TabContainer.new()
		tab_container.name = "TabContainer"
		# ocupă tot spațiul
		tab_container.anchor_left = 0
		tab_container.anchor_top = 0
		tab_container.anchor_right = 1
		tab_container.anchor_bottom = 1
		add_child(tab_container)

	# Asigură-te că TabContainer este child direct al acestui Control
	if tab_container.get_parent() != self:
		# mută-l sub node-ul curent
		if tab_container.get_parent():
			tab_container.get_parent().remove_child(tab_container)
		add_child(tab_container)

	# Curăță copii existenți (dacă e gol nu face nimic)
	for c in tab_container.get_children():
		tab_container.remove_child(c)
		c.queue_free()

	# Încarcă și adaugă Viewer2D ca prim tab (implicit)
	var viewer2d_scene = preload("res://Viewers/2DViewer.tscn")
	var viewer2d = viewer2d_scene.instantiate()
	if viewer2d is Control:
		viewer2d.anchor_left = 0
		viewer2d.anchor_top = 0
		viewer2d.anchor_right = 1
		viewer2d.anchor_bottom = 1
		viewer2d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		viewer2d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(viewer2d)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, "2D View")

	# Rezervă tab pentru 3D (placeholder) — lazy load
	var placeholder = Panel.new()
	placeholder.name = "3D_Placeholder"
	placeholder.anchor_left = 0
	placeholder.anchor_top = 0
	placeholder.anchor_right = 1
	placeholder.anchor_bottom = 1
	tab_container.add_child(placeholder)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, "3D View")

	# Conectare pentru lazy-loading 3D (evit dublarea conexiunii)
	var on_tab_changed_callable = Callable(self, "_on_tab_changed")
	if not tab_container.is_connected("tab_changed", on_tab_changed_callable):
		tab_container.tab_changed.connect(on_tab_changed_callable)

	# Asigură afișarea 2D la start și redraw
	tab_container.current_tab = 0
	if viewer2d and is_instance_valid(viewer2d):
		viewer2d.call_deferred("queue_redraw")
		if viewer2d.has_method("grab_focus"):
			viewer2d.call_deferred("grab_focus")

func _on_tab_changed(tab_idx: int) -> void:
	var tab_container = get_node("TabContainer") as TabContainer
	# dacă indexul este 3D view (ultimul tab), instanțiem scena 3D o singură dată
	if tab_container.get_tab_title(tab_idx) == "3D View":
		if not viewer3dtab_instance or not is_instance_valid(viewer3dtab_instance):
			viewer3dtab_instance = viewer3dtab_scene.instantiate()
			# înlocuiește placeholder cu instanța reală
			var placeholder = tab_container.get_child(tab_idx)
			tab_container.remove_child(placeholder)
			placeholder.queue_free()
			tab_container.add_child(viewer3dtab_instance)
			# set cad_viewer dacă există nod Viewer3D
			if viewer3dtab_instance.has_node("Viewer3D"):
				cad_viewer = viewer3dtab_instance.get_node("Viewer3D")
			else:
				cad_viewer = null

# Trimite puncte de grid către Viewer2D
func set_2d_grid_points(points: Array):
	var tab_container = get_node("TabContainer")
	for i in tab_container.get_children():
		if i.has_method("set_grid_points"):
			i.set_grid_points(points)

func _setup_ui_buttons():
	# Creează un CanvasLayer (implicit name "CanvasLayer") și un Panel orizontal în partea de sus
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)

	var top_panel = Panel.new() # default name "Panel" => get_node("CanvasLayer/Panel/snap_toggle") funcționează
	top_panel.anchor_left = 0
	top_panel.anchor_right = 1
	top_panel.anchor_top = 0
	top_panel.anchor_bottom = 0
	top_panel.offset_left = 0
	top_panel.offset_right = 0
	# înălțimea top bar-ului
	top_panel.offset_top = 0
	top_panel.offset_bottom = 48
	top_panel.add_theme_color_override("bg_color", Color(0.08, 0.08, 0.08, 0.95))
	canvas_layer.add_child(top_panel)

	# Container pentru butoane (orizontal) — folosește MarginContainer pentru padding
	var margin = MarginContainer.new()
	margin.anchor_left = 0
	margin.anchor_top = 0
	margin.anchor_right = 1
	margin.anchor_bottom = 1
	# Folosește theme constant overrides în Godot 4 pentru padding
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	top_panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.anchor_left = 0
	hbox.anchor_top = 0
	hbox.anchor_right = 1
	hbox.anchor_bottom = 1
	# spațiere între butoane (folosește theme constant override)
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	# Buton pentru deschiderea grid panel-ului
	var grid_btn = Button.new()
	grid_btn.text = "Snap Grid"
	grid_btn.custom_minimum_size = Vector2(100, 32)
	grid_btn.pressed.connect(_on_snap_grid_pressed)
	hbox.add_child(grid_btn)

	# Buton pentru toggle snap (toggle_mode = true)
	var snap_toggle_btn = Button.new()
	snap_toggle_btn.name = "snap_toggle" # păstrăm numele pentru _on_snap_toggled
	snap_toggle_btn.text = "Snap: OFF"
	snap_toggle_btn.toggle_mode = true
	snap_toggle_btn.custom_minimum_size = Vector2(120, 32)
	snap_toggle_btn.toggled.connect(_on_snap_toggled)
	hbox.add_child(snap_toggle_btn)

func _on_snap_grid_pressed():
	if snap_grid_panel and is_instance_valid(snap_grid_panel):
		# Dacă panoul există deja, îl aducem în față
		snap_grid_panel.move_to_front()
		return
	
	# Creează noul panel
	snap_grid_panel = snap_grid_panel_scene.instantiate()
	snap_grid_panel.set_cad_viewer(cad_viewer)
	
	# Poziționează panoul în centrul ecranului
	var viewport_size = get_viewport().get_visible_rect().size
	snap_grid_panel.position = Vector2(
		(viewport_size.x - snap_grid_panel.custom_minimum_size.x) / 2,
		(viewport_size.y - snap_grid_panel.custom_minimum_size.y) / 2
	)
	
	# Conectează semnalele
	snap_grid_panel.grid_updated.connect(_on_grid_updated)
	snap_grid_panel.panel_closed.connect(_on_grid_panel_closed)
	
	# Adaugă panoul la scena principală
	get_tree().root.add_child(snap_grid_panel)

func _on_snap_toggled(button_pressed: bool):
	var btn = get_node("CanvasLayer/Panel/snap_toggle") as Button
	if btn:
		btn.text = "Snap: ON" if button_pressed else "Snap: OFF"
	
	# Actualizează starea snap în CAD viewer
	if cad_viewer and cad_viewer.has_method("set_snap_enabled"):
		cad_viewer.set_snap_enabled(button_pressed)

func _on_grid_updated(x_dimensions: Array, y_dimensions: Array):
	print("Grid updated with %d x %d points" % [x_dimensions.size(), y_dimensions.size()])
	# Trimite punctele către Viewer2D
	var points = []
	for x in x_dimensions:
		for y in y_dimensions:
			points.append(Vector2(x, y))
	set_2d_grid_points(points)

func _on_grid_panel_closed():
	snap_grid_panel = null
	print("Snap grid panel closed")

# Funcție helper pentru a obține referința la snap grid panel
func get_snap_grid_panel() -> Control:
	return snap_grid_panel

# Inserare panel lateral cu Project Browser
func _create_project_browser_panel():
	# nu crea duplicat
	if project_browser_instance and is_instance_valid(project_browser_instance):
		return

	# Panel fix pe stânga
	var left_panel = PanelContainer.new()
	left_panel.name = "ProjectBrowserPanel"
	left_panel.anchor_left = 0
	left_panel.anchor_top = 0
	left_panel.anchor_right = 0
	left_panel.anchor_bottom = 1
	left_panel.offset_left = 0
	left_panel.offset_top = 0
	left_panel.offset_right = 260   # lățimea panelului
	left_panel.offset_bottom = 0
	add_child(left_panel)

	# instanțiază scena ProjectBrowser și o pune în panel
	project_browser_instance = project_browser_scene.instantiate()
	left_panel.add_child(project_browser_instance)

	# opțional: păstrează referința la cad_viewer dacă e nevoie
	if project_browser_instance.has_method("get_all_levels"):
		# exemplu: proiect browser poate citi nivelele din Main dacă vrei
		pass
