# Main.gd
extends Control

@onready var cad_viewer: Node3D
var snap_grid_panel: Control
var snap_grid_panel_scene = preload("res://Shapes/GridPoints.tscn")
var project_browser_scene = preload("res://ProjectBrowser.tscn")   # added
var project_browser_instance: Control = null                      # added
var viewer2d_scene = preload("res://Viewers/2DViewer.tscn")
var viewer3dtab_scene = preload("res://Viewers/Viewer3DTab.tscn")
var viewer3dtab_instance: Control = null
var pending_view3d_data: Dictionary = {}
var _closed_tabs_stack: Array = [] # stack of {view_data, title}

func _ready():
	_setup_main_scene()
	_setup_ui_buttons()
	_create_project_browser_panel()   # added

func _setup_main_scene():
	# Ensure a responsive main layout exists (left panel + central tabs)
	var main_layout = get_node_or_null("MainLayout") as HBoxContainer
	if not main_layout:
		main_layout = HBoxContainer.new()
		main_layout.name = "MainLayout"
		main_layout.anchor_left = 0
		main_layout.anchor_top = 0
		main_layout.anchor_right = 1
		main_layout.anchor_bottom = 1
		add_child(main_layout)

	# Find or create TabContainer as a child of MainLayout
	var tab_container: TabContainer = main_layout.get_node_or_null("TabContainer") as TabContainer
	if not tab_container:
		tab_container = TabContainer.new()
		tab_container.name = "TabContainer"
		# let HBoxContainer/layout handle sizing; make tab container expand
		tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_layout.add_child(tab_container)

	# Ensure the TabContainer is placed inside MainLayout (already done above)

	# Curăță copii existenți (dacă e gol nu face nimic)
	for c in tab_container.get_children():
		tab_container.remove_child(c)
		c.queue_free()

	# Încarcă și adaugă Viewer2D ca prim tab (implicit)
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

	# Ensure tabs are visible below the top panel (if present). If we created
	# a top panel in _setup_ui_buttons, it has height 48 by default; set offset_top
	# to that height so the TabContainer tabs are not positioned off-screen.
	if tab_container and tab_container.has_method("set_offset") == false:
		# TabContainer uses `offset_top` property in this project; set conservative value
		tab_container.offset_top = 0
	if viewer2d and is_instance_valid(viewer2d):
		viewer2d.call_deferred("queue_redraw")
		if viewer2d.has_method("grab_focus"):
			viewer2d.call_deferred("grab_focus")

func _on_tab_changed(tab_idx: int) -> void:
	var tab_container = _get_tab_container()
	if not tab_container:
		return
	# dacă indexul este 3D view (ultimul tab), instanțiem scena 3D o singură dată
	if tab_container.get_tab_title(tab_idx) == "3D View":
		if not viewer3dtab_instance or not is_instance_valid(viewer3dtab_instance):
			viewer3dtab_instance = viewer3dtab_scene.instantiate()
			# înlocuiește placeholder cu instanța reală
			var placeholder = tab_container.get_child(tab_idx)
			tab_container.remove_child(placeholder)
			placeholder.queue_free()
			# Insert the viewer instance at the same tab index so callers expecting
			# the child at `tab_idx` continue to work (don't append at end)
			tab_container.add_child(viewer3dtab_instance)
			# move the newly added child to the original placeholder index
			if tab_container.has_method("move_child"):
				tab_container.move_child(viewer3dtab_instance, tab_idx)
			# set cad_viewer dacă există nod Viewer3D
			# viewer3dtab_instance is a Control wrapper; search recursively for the Node3D named "Viewer3D"
			var found = _find_child_by_name(viewer3dtab_instance, "Viewer3D")
			if found:
				cad_viewer = found
				# if we had pending view data (open_view_3d called before the scene was ready), apply it
				if pending_view3d_data.size() > 0 and found.has_method("set_view_data"):
					found.set_view_data(pending_view3d_data)
					pending_view3d_data = {}
			else:
				cad_viewer = null

func _find_child_by_name(root: Node, name: String) -> Node:
	# Recursive search for a child node by name inside `root` (depth-first)
	if not root:
		return null
	for ch in root.get_children():
		if ch.name == name:
			return ch
		var res = _find_child_by_name(ch, name)
		if res:
			return res
	return null


func _get_tab_container() -> TabContainer:
	# Prefer the TabContainer child inside MainLayout, then fallback to scene root lookup
	var main_layout = get_node_or_null("MainLayout") as HBoxContainer
	if main_layout:
		var tc = main_layout.get_node_or_null("TabContainer")
		if tc and tc is TabContainer:
			return tc

	var root_tc = get_node_or_null("TabContainer")
	if root_tc and root_tc is TabContainer:
		return root_tc

	return null

# Public API: open a level in 2D (called from ProjectBrowser)
func _on_project_open_level_2d(level_data: Dictionary) -> void:
	open_level_2d(level_data)

# Public API: open a 3D view (called from ProjectBrowser)
func _on_project_open_view_3d(view_data: Dictionary) -> void:
	open_view_3d(view_data)

func _on_project_open_view_3d_new(view_data: Dictionary) -> void:
	# Create a new Viewer3DTab and add it as a new tab with title "3D View"
	var tab_container = _get_tab_container()
	if not tab_container:
		# fallback: add to main as child
		var viewer3d_tab = viewer3dtab_scene.instantiate()
		add_child(viewer3d_tab)
		if viewer3d_tab and viewer3d_tab.has_method("set_view_data"):
			viewer3d_tab.set_view_data(view_data)
		return

	var viewer3d_tab = viewer3dtab_scene.instantiate()
	if viewer3d_tab is Control:
		viewer3d_tab.anchor_left = 0
		viewer3d_tab.anchor_top = 0
		viewer3d_tab.anchor_right = 1
		viewer3d_tab.anchor_bottom = 1
	# If the view has a name, set tab title accordingly
	tab_container.add_child(viewer3d_tab)
	var title = str(view_data.get("name", "3D View"))
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, title)
	# connect closed signal to track closed tabs
	if viewer3d_tab.has_signal("viewer_tab_closed"):
		viewer3d_tab.connect("viewer_tab_closed", Callable(self, "_on_viewer_tab_closed"))
	tab_container.current_tab = tab_container.get_tab_count() - 1
	# Forward view data (Viewer3DTab buffers if necessary)
	if viewer3d_tab.has_method("set_view_data"):
		viewer3d_tab.set_view_data(view_data)

func _on_viewer_tab_closed(view_data: Dictionary, tab_title: String) -> void:
	# push to stack for reopen
	_closed_tabs_stack.append({"view": view_data.duplicate(), "title": tab_title})

func _on_reopen_tab_pressed() -> void:
	if _closed_tabs_stack.size() == 0:
		print("No closed tabs to reopen")
		return
	var entry = _closed_tabs_stack.pop_back()
	if not entry:
		return
	_on_project_open_view_3d_new(entry.view)

func open_level_2d(level_data: Dictionary) -> void:
	# Find or create a container to host viewers. Prefer `TabContainer`, otherwise fall back to a VBoxContainer
	var container_info = _get_or_create_view_container()
	var host = container_info.host
	var is_tab = container_info.is_tab

	# If it's a TabContainer, try to reuse a 2D tab by title
	if is_tab:
		var tab_container = host as TabContainer
		for i in range(tab_container.get_tab_count()):
			if tab_container.get_tab_title(i) == "2D View":
				var candidate = tab_container.get_child(i)
				if candidate and candidate.has_method("load_level"):
					candidate.load_level(level_data)
					tab_container.current_tab = i
					return

	# Instantiate a new 2D viewer
	var viewer2d = viewer2d_scene.instantiate()
	if viewer2d is Control:
		viewer2d.anchor_left = 0
		viewer2d.anchor_top = 0
		viewer2d.anchor_right = 1
		viewer2d.anchor_bottom = 1
		viewer2d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		viewer2d.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if is_tab:
		(host as TabContainer).add_child(viewer2d)
		(host as TabContainer).set_tab_title((host as TabContainer).get_tab_count() - 1, "2D View")
		(host as TabContainer).current_tab = (host as TabContainer).get_tab_count() - 1
	else:
		host.add_child(viewer2d)

	if viewer2d.has_method("load_level"):
		viewer2d.load_level(level_data)

func open_view_3d(view_data: Dictionary) -> void:
	# Find or create a container to host viewers. Prefer `TabContainer`, otherwise fall back to a VBoxContainer
	var container_info = _get_or_create_view_container()
	var host = container_info.host
	var is_tab = container_info.is_tab

	if is_tab:
		var tab_container = host as TabContainer
		# Look for an existing 3D View tab
		for i in range(tab_container.get_tab_count()):
			if tab_container.get_tab_title(i) == "3D View":
				var child = tab_container.get_child(i)
				# if placeholder, instantiate real content
				if child and not child.has_method("set_view_data") and child.name == "3D_Placeholder":
					_on_tab_changed(i)
					child = tab_container.get_child(i)
				if child and child.has_method("set_view_data"):
					child.set_view_data(view_data)
					tab_container.current_tab = i
					return

		# If not found, create or reuse reserved 3D tab (lazy load)
		var idx = -1
		for i in range(tab_container.get_tab_count()):
			if tab_container.get_tab_title(i) == "3D View":
				idx = i
				break
		if idx == -1:
			var placeholder = Panel.new()
			placeholder.name = "3D_Placeholder"
			placeholder.anchor_left = 0
			placeholder.anchor_top = 0
			placeholder.anchor_right = 1
			placeholder.anchor_bottom = 1
			tab_container.add_child(placeholder)
			tab_container.set_tab_title(tab_container.get_tab_count() - 1, "3D View")
			idx = tab_container.get_tab_count() - 1

		# Force lazy load for that tab
		_on_tab_changed(idx)
		var new_child = tab_container.get_child(idx)
		if new_child and new_child.has_method("set_view_data"):
			new_child.set_view_data(view_data)
			tab_container.current_tab = idx
		return

	# If no TabContainer exists, create and add a 3D viewer Control under the host (Main)
	# Instantiate the Viewer3DTab (which in turn instantiates Viewer3D)
	var viewer3d_tab = viewer3dtab_scene.instantiate()
	viewer3d_tab.name = "3D View"
	# Ensure proper anchoring
	if viewer3d_tab is Control:
		viewer3d_tab.anchor_left = 0
		viewer3d_tab.anchor_top = 0
		viewer3d_tab.anchor_right = 1
		viewer3d_tab.anchor_bottom = 1
	host.add_child(viewer3d_tab)

	# Try to find the inner 3D viewer and call set_view_data
	var found = _find_child_by_name(viewer3d_tab, "Viewer3D")
	if found and found.has_method("set_view_data"):
		found.set_view_data(view_data)

# Helper: wrap a Node3D instance into a SubViewport if necessary
func _wrap_node3d_in_viewport(node3d: Node3D) -> Control:
	var sub_vc = SubViewportContainer.new()
	sub_vc.anchor_left = 0
	sub_vc.anchor_top = 0
	sub_vc.anchor_right = 1
	sub_vc.anchor_bottom = 1
	var sub_v = SubViewport.new()
	sub_vc.add_child(sub_v)
	sub_v.add_child(node3d)
	return sub_vc


func _get_or_create_view_container() -> Dictionary:
	# Returns a dictionary {"host": Node, "is_tab": bool}
	# Prefer an existing TabContainer named "TabContainer". If absent, create a VBoxContainer
	var tab_container = _get_tab_container()
	if tab_container:
		return {"host": tab_container, "is_tab": true}

	# Try to find an existing fallback container
	var fallback = get_node_or_null("ViewerHost")
	if fallback and fallback is Control:
		return {"host": fallback, "is_tab": false}

	# Create a fallback container under this Main Control to host viewer Controls
	var v = VBoxContainer.new()
	v.name = "ViewerHost"
	v.anchor_left = 0
	v.anchor_top = 0
	v.anchor_right = 1
	v.anchor_bottom = 1
	# Expand so added controls fill the available space
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(v)
	return {"host": v, "is_tab": false}

# Trimite puncte de grid către Viewer2D
func set_2d_grid_points(points: Array):
	var tab_container = _get_tab_container()
	if not tab_container:
		return
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
	top_panel.offset_bottom = 0
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

	# Reopen closed tab button
	var reopen_btn = Button.new()
	reopen_btn.name = "reopen_tab"
	reopen_btn.text = "Reopen Tab"
	reopen_btn.custom_minimum_size = Vector2(120, 32)
	reopen_btn.pressed.connect(Callable(self, "_on_reopen_tab_pressed"))
	hbox.add_child(reopen_btn)

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

	# Panel fix pe stânga — add into MainLayout so HBoxContainer manages layout
	var main_layout = get_node_or_null("MainLayout") as HBoxContainer
	if not main_layout:
		# fallback: ensure main layout exists
		main_layout = HBoxContainer.new()
		main_layout.name = "MainLayout"
		main_layout.anchor_left = 0
		main_layout.anchor_top = 0
		main_layout.anchor_right = 1
		main_layout.anchor_bottom = 1
		add_child(main_layout)

	var left_panel = PanelContainer.new()
	left_panel.name = "ProjectBrowserPanel"
	# give it a default minimum width instead of offset_right
	left_panel.custom_minimum_size = Vector2(260, 0)
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_layout.add_child(left_panel)

	# instanțiază scena ProjectBrowser și o pune în panel
	project_browser_instance = project_browser_scene.instantiate()
	left_panel.add_child(project_browser_instance)
	# Dock the project browser to fill the left panel (ensure it's visually on the left)
	if project_browser_instance is Control:
		project_browser_instance.anchor_left = 0
		project_browser_instance.anchor_top = 0
		project_browser_instance.anchor_right = 1
		project_browser_instance.anchor_bottom = 1
		project_browser_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		project_browser_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Connect signals from the Project Browser for opening views
	if project_browser_instance and project_browser_instance.has_method("connect"):
		if project_browser_instance.has_signal("open_level_2d"):
			project_browser_instance.connect("open_level_2d", Callable(self, "_on_project_open_level_2d"))
		if project_browser_instance.has_signal("open_view_3d"):
			project_browser_instance.connect("open_view_3d", Callable(self, "_on_project_open_view_3d"))
		if project_browser_instance.has_signal("open_view_3d_new"):
			project_browser_instance.connect("open_view_3d_new", Callable(self, "_on_project_open_view_3d_new"))
		if project_browser_instance.has_signal("level_renamed"):
			project_browser_instance.connect("level_renamed", Callable(self, "_on_level_renamed"))

	# opțional: păstrează referința la cad_viewer dacă e nevoie
	if project_browser_instance.has_method("get_all_levels"):
		# exemplu: proiect browser poate citi nivelele din Main dacă vrei
		pass
