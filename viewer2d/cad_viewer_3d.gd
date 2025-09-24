
# CADViewer.gd (versiunea îmbunătățită cu snap)
extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var canvas: Control = $CanvasLayer/Panel

# Grid & background
@export var grid_size: int = 20
@export var grid_spacing: float = 1.0
@export var grid_color: Color = Color(0.8,0.8,0.8)
@export var background_color: Color = Color(0.95,0.95,0.95)

# Z-depth and drawing plane settings
@export var z_min: float = -10.0
@export var z_max: float = 10.0
@export var drawing_plane_z: float = 0.0

# Snap settings
var snap_enabled: bool = false
var snap_distance: float = 0.5
var snap_preview_marker: MeshInstance3D

# Zoom, Pan, Orbit
@export var zoom_speed: float = 1.1
var pan_last_pos: Vector2
var is_panning := false
var rotate_last_pos: Vector2
var is_rotating := false
var orbit_pivot: Vector3 = Vector3.ZERO

# UI elements
var coord_label: Label
var z_controls_panel: Panel
var _zpanel_dragging: bool = false
var _zpanel_drag_offset: Vector2 = Vector2.ZERO

var selected_geometry: Node3D = null
var default_material: StandardMaterial3D = null
var layer_materials := {}

func _ready():
	if canvas == null:
		var cl = CanvasLayer.new()
		add_child(cl)
		var panel = Panel.new()
		cl.add_child(panel)
		canvas = panel

	default_material = StandardMaterial3D.new()
	default_material.albedo_color = Color(0.5, 1.0, 0.0) # lime green

	# Încarcă config materiale layere
	var config_path = "res://layer_materials.json"
	if FileAccess.file_exists(config_path):
		var config_str = FileAccess.get_file_as_string(config_path)
		var config_data = JSON.parse_string(config_str)
		if typeof(config_data) == TYPE_DICTIONARY:
			layer_materials = config_data

	_set_top_view()

	var env = Environment.new()
	env.background_color = background_color
	env.background_mode = Environment.BG_COLOR
	camera.environment = env

	_create_grid(grid_size, grid_spacing)
	_create_center_lines(50)
	_setup_ui_buttons()
	_setup_coordinate_label()
	_setup_z_controls()
	_update_camera_clipping()
	_create_snap_preview_marker()

	_load_project_json()

	# Import DXF la pornire
	import_dxf_entities("res://out.json")

func import_dxf_entities(path: String):
	print("[DEBUG] Import DXF din ", path)
	if not FileAccess.file_exists(path):
		push_error("Fișierul nu există: %s" % path)
		return
	var json_str = FileAccess.get_file_as_string(path).strip_edges(true, true)
	var data = JSON.parse_string(json_str)
	if data == null:
		push_error("Eroare la parsarea JSON-ului.")
		return
	if typeof(data) == TYPE_ARRAY:
		var objects_node = get_node_or_null("Objects")
		var layer_groups := {}
		for entity in data:
			print("[DEBUG] Entity: ", entity)
			var mat: StandardMaterial3D = null
			var layer_name = "default"
			if entity.has("layer"):
				layer_name = str(entity.layer)
			if layer_materials.has(layer_name):
				var lconf = layer_materials[layer_name]
				mat = StandardMaterial3D.new()
				mat.albedo_color = Color(lconf["color"][0], lconf["color"][1], lconf["color"][2], lconf["alpha"])
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			else:
				mat = default_material
			var static_body = StaticBody3D.new()
			static_body.set_meta("selectable", true)
			static_body.set_meta("entity_data", entity)
			var obj: Node3D = null
			match entity.type:
				"LWPOLYLINE":
					var height = 1.0
					var z = 0.0
					if entity.has("xdata") and entity.xdata.has("QCAD"):
						for item in entity.xdata["QCAD"]:
							if typeof(item) == TYPE_ARRAY and item.size() == 2:
								var val = str(item[1])
								if val.begins_with("height:"):
									height = float(val.split(":")[1])
								elif val.begins_with("z:"):
									z = float(val.split(":")[1])
					obj = create_polygon(entity.points, entity.closed, height, z)
					obj.material_override = mat
					obj.set_meta("layer_name", layer_name)
					var arr: PackedVector2Array = []
					for p in entity.points:
						arr.append(Vector2(p[0], p[1]))
					if entity.closed:
						arr.append(Vector2(entity.points[0][0], entity.points[0][1]))
					var collision = CollisionPolygon3D.new()
					collision.polygon = arr
					static_body.add_child(obj)
					static_body.add_child(collision)
				"CIRCLE":
					obj = create_circle(entity.center, entity.radius)
					obj.material_override = mat
					obj.set_meta("layer_name", layer_name)
					var arr: PackedVector2Array = []
					var segments = 32
					for i in range(segments):
						var angle = (TAU / segments) * i
						var x = entity.center[0] + cos(angle) * entity.radius
						var y = entity.center[1] + sin(angle) * entity.radius
						arr.append(Vector2(x, y))
					arr.append(arr[0])
					var collision = CollisionPolygon3D.new()
					collision.polygon = arr
					static_body.add_child(obj)
					static_body.add_child(collision)
			# grupare pe layere
			if not layer_groups.has(layer_name):
				var group_node = Node3D.new()
				group_node.name = layer_name
				layer_groups[layer_name] = group_node
			layer_groups[layer_name].add_child(static_body)
		# adaugă grupurile la nodul Objects
		if objects_node:
			for k in layer_groups.keys():
				objects_node.add_child(layer_groups[k])
				print("[DEBUG] Added layer group: ", k, " to Objects")
			# Populează Tree-ul UI cu structura layerelor și obiectelor
			populate_tree_with_layers(layer_groups)
		else:
			for k in layer_groups.keys():
				add_child(layer_groups[k])

func populate_tree_with_layers(layer_groups: Dictionary):
		var tree_node = get_node_or_null("Objects")
		if tree_node == null:
			print("[DEBUG] Nu există nodul Objects de tip Tree în scenă!")
			return
		tree_node.clear()
		tree_node.set_columns(2)
		var root = tree_node.create_item()
		tree_node.set_column_title(0, "Name")
		tree_node.set_column_title(1, "Visible")
		tree_node.set_column_titles_visible(true)

		for layer_name in layer_groups.keys():
			var layer_item = tree_node.create_item(root)
			layer_item.set_text(0, layer_name)
			# Adaugă checkbox pentru layer
			layer_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
			layer_item.set_checked(1, true)
			layer_item.set_editable(1, true)
			# Stochează referința la grupul layer
			layer_item.set_metadata(0, layer_groups[layer_name])
			var group_node = layer_groups[layer_name]
			for child in group_node.get_children():
				var obj_item = tree_node.create_item(layer_item)
				# Extrage denumirea din xdata (Name:...) și numărul din handle
				var display_name = child.name
				var entity_data = child.get_meta("entity_data") if child.has_meta("entity_data") else null
				var name_str = ""; var handle_str = ""
				if entity_data != null:
					if entity_data.has("xdata") and entity_data.xdata.has("QCAD"):
						for item in entity_data.xdata["QCAD"]:
							if typeof(item) == TYPE_ARRAY and item.size() == 2 and str(item[1]).begins_with("Name:"):
								name_str = str(item[1]).split(":")[1]
					if entity_data.has("handle"):
						handle_str = str(entity_data.handle)
				if name_str != "" and handle_str != "":
					display_name = "%s_%s" % [name_str, handle_str]
				obj_item.set_text(0, display_name)
				# Adaugă checkbox pentru obiect
				obj_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
				obj_item.set_checked(1, true)
				obj_item.set_editable(1, true)
				# Stochează referința la nodul 3D
				obj_item.set_metadata(0, child)
		# Conectăm semnalul de selecție și toggle pentru checkbox
		tree_node.item_selected.connect(_on_tree_item_selected)
		tree_node.item_edited.connect(_on_tree_item_edited)
func create_polygon(points: Array, closed: bool, height: float = 1.0, z: float = 0.0) -> CSGPolygon3D:
	print("[DEBUG] create_polygon points=", points, " closed=", closed, " height=", height, " z=", z)
	var arr: PackedVector2Array = []
	for p in points:
		arr.append(Vector2(p[0], p[1]))
	if closed:
		arr.append(Vector2(points[0][0], points[0][1]))
	var csg = CSGPolygon3D.new()
	csg.polygon = arr
	csg.mode = CSGPolygon3D.MODE_DEPTH
	csg.depth = height
	csg.transform.origin.z = z + height
	# Adaug CollisionPolygon3D pentru selecție
	var collision = CollisionPolygon3D.new()
	collision.polygon = arr
	csg.add_child(collision)
	csg.set_meta("selectable", true)
	csg.set_meta("original_material", csg.material_override)
	return csg

func create_circle(center: Array, radius: float, segments: int = 32) -> CSGPolygon3D:
	print("[DEBUG] create_circle center=", center, " radius=", radius)
	var arr: PackedVector2Array = []
	for i in range(segments):
		var angle = (TAU / segments) * i
		var x = center[0] + cos(angle) * radius
		var y = center[1] + sin(angle) * radius
		arr.append(Vector2(x, y))
	arr.append(arr[0])
	var csg = CSGPolygon3D.new()
	csg.polygon = arr
	csg.mode = CSGPolygon3D.MODE_DEPTH
	csg.depth = 1.0
	# Adaug CollisionPolygon3D pentru selecție
	var collision = CollisionPolygon3D.new()
	collision.polygon = arr
	csg.add_child(collision)
	csg.set_meta("selectable", true)
	csg.set_meta("original_material", csg.material_override)
	return csg

# Funcții publice pentru snap
func set_snap_enabled(enabled: bool):
	snap_enabled = enabled
	snap_preview_marker.visible = false

func get_drawing_plane_z() -> float:
	return drawing_plane_z

# Funcția de snap modificată
func get_snapped_position(world_pos: Vector3) -> Vector3:
	if not snap_enabled:
		return world_pos
	
	# Caută în scene tree pentru snap grid panel
	var main_scene = get_tree().get_first_node_in_group("main")
	if not main_scene:
		main_scene = get_node("/root/Main") # fallback
	
	if main_scene and main_scene.has_method("get_snap_grid_panel"):
		var snap_panel = main_scene.get_snap_grid_panel()
		if snap_panel and snap_panel.has_method("get_snap_point_at"):
			return snap_panel.get_snap_point_at(world_pos, snap_distance)
	
	return world_pos

# UI setup functions (rămân la fel)
func _setup_ui_buttons():
	var names = ["TOP","FRONT","LEFT","RIGHT","BACK","FREE 3D"]
	for i in range(len(names)):
		var btn = Button.new()
		btn.text = names[i]
		btn.position = Vector2(10, 10 + i*35)
		btn.size = Vector2(100, 30)
		btn.pressed.connect(Callable(self, "_on_view_button_pressed").bind(names[i]))
		canvas.add_child(btn)

func _setup_coordinate_label():
	coord_label = Label.new()
	coord_label.text = "X: 0.0, Y: 0.0, Z: 0.0"
	coord_label.position = Vector2(10, get_viewport().get_visible_rect().size.y - 50)
	coord_label.size = Vector2(300, 30)
	coord_label.add_theme_color_override("font_color", Color.BLACK)
	coord_label.add_theme_font_size_override("font_size", 14)
	canvas.add_child(coord_label)

func _setup_z_controls():
	z_controls_panel = Panel.new()
	
	# Sub butoane (ultimul buton e la y=185 + înălțimea lui 30 = 215)
	var y_offset = 10 + (6 * 35) + 20  # 6 butoane * 35 px + spațiu
	z_controls_panel.position = Vector2(10, y_offset)
	
	z_controls_panel.size = Vector2(240, 160)
	z_controls_panel.add_theme_color_override("bg_color", Color(0.9, 0.9, 0.9, 0.8))
	canvas.add_child(z_controls_panel)

	# Allow the Z controls panel to be floatable/draggable inside the canvas
	var z_gui_cb = Callable(self, "_on_z_controls_gui_input")
	z_controls_panel.gui_input.connect(z_gui_cb)
	
	var title_label = Label.new()
	title_label.text = "Z-Depth Controls"
	title_label.position = Vector2(10, 5)
	title_label.add_theme_color_override("font_color", Color.BLACK)
	title_label.add_theme_font_size_override("font_size", 12)
	z_controls_panel.add_child(title_label)
	
	var z_min_label = Label.new()
	z_min_label.text = "Z Min:"
	z_min_label.position = Vector2(10, 30)
	z_min_label.size = Vector2(50, 20)
	z_min_label.add_theme_color_override("font_color", Color.BLACK)
	z_controls_panel.add_child(z_min_label)
	
	var z_min_spinbox = SpinBox.new()
	z_min_spinbox.position = Vector2(65, 30)
	z_min_spinbox.size = Vector2(80, 20)
	z_min_spinbox.min_value = -100.0
	z_min_spinbox.max_value = 100.0
	z_min_spinbox.step = 0.1
	z_min_spinbox.value = z_min
	z_min_spinbox.value_changed.connect(_on_z_min_changed)
	z_controls_panel.add_child(z_min_spinbox)
	
	var z_max_label = Label.new()
	z_max_label.text = "Z Max:"
	z_max_label.position = Vector2(10, 55)
	z_max_label.size = Vector2(50, 20)
	z_max_label.add_theme_color_override("font_color", Color.BLACK)
	z_controls_panel.add_child(z_max_label)
	
	var z_max_spinbox = SpinBox.new()
	z_max_spinbox.position = Vector2(65, 55)
	z_max_spinbox.size = Vector2(80, 20)
	z_max_spinbox.min_value = -100.0
	z_max_spinbox.max_value = 100.0
	z_max_spinbox.step = 0.1
	z_max_spinbox.value = z_max
	z_max_spinbox.value_changed.connect(_on_z_max_changed)
	z_controls_panel.add_child(z_max_spinbox)
	
	var draw_z_label = Label.new()
	draw_z_label.text = "Draw Z:"
	draw_z_label.position = Vector2(10, 80)
	draw_z_label.size = Vector2(50, 20)
	draw_z_label.add_theme_color_override("font_color", Color.BLACK)
	z_controls_panel.add_child(draw_z_label)
	
	var draw_z_spinbox = SpinBox.new()
	draw_z_spinbox.position = Vector2(65, 80)
	draw_z_spinbox.size = Vector2(80, 20)
	draw_z_spinbox.min_value = -100.0
	draw_z_spinbox.max_value = 100.0
	draw_z_spinbox.step = 0.1
	draw_z_spinbox.value = drawing_plane_z
	draw_z_spinbox.value_changed.connect(_on_drawing_plane_z_changed)
	z_controls_panel.add_child(draw_z_spinbox)
	
	var btn_ground = Button.new()
	btn_ground.text = "Ground (0)"
	btn_ground.position = Vector2(10, 155)
	btn_ground.size = Vector2(70, 25)
	btn_ground.pressed.connect(_set_ground_level)
	z_controls_panel.add_child(btn_ground)
	
	var btn_floor1 = Button.new()
	btn_floor1.text = "Floor 1 (3m)"
	btn_floor1.position = Vector2(135, 155)
	btn_floor1.size = Vector2(70, 25)
	btn_floor1.pressed.connect(_set_floor1_level)
	z_controls_panel.add_child(btn_floor1)
	
	var info_label = Label.new()
	info_label.text = "Visible: %.1f to %.1f" % [z_min, z_max]
	info_label.position = Vector2(10, 135)
	info_label.size = Vector2(200, 20)
	info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.name = "info_label"
	z_controls_panel.add_child(info_label)


func _on_view_button_pressed(view_name: String):
	match view_name:
		"TOP": _set_top_view()
		"FRONT": _set_front_view()
		"LEFT": _set_left_view()
		"RIGHT": _set_right_view()
		"BACK": _set_back_view()
		"FREE 3D": _set_free_view()

# View functions
func _set_top_view():
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.transform.origin = Vector3(0,0,10)
	camera.look_at(Vector3(0,0,0), Vector3(0,1,0))

func _set_front_view():
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.transform.origin = Vector3(0,-10,0)
	camera.look_at(Vector3(0,0,0), Vector3(0,0,1))

func _set_left_view():
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.transform.origin = Vector3(-10,0,0)
	camera.look_at(Vector3(0,0,0), Vector3(0,0,1))

func _set_right_view():
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.transform.origin = Vector3(10,0,0)
	camera.look_at(Vector3(0,0,0), Vector3(0,0,1))

func _set_back_view():
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.transform.origin = Vector3(0,10,0)
	camera.look_at(Vector3(0,0,0), Vector3(0,0,1))

func _set_free_view():
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 60
	camera.transform.origin = Vector3(10,10,10)
	camera.look_at(Vector3(0,0,0), Vector3(0,0,1))

# Grid creation
func _create_grid(size: int, spacing: float):
	var vertices = PackedVector3Array()
	var colors = PackedColorArray()
	for i in range(-size, size + 1):
		if i != 0:
			vertices.append(Vector3(i*spacing, -size*spacing, drawing_plane_z))
			vertices.append(Vector3(i*spacing, size*spacing, drawing_plane_z))
			colors.append(grid_color)
			colors.append(grid_color)
			
			vertices.append(Vector3(-size*spacing, i*spacing, drawing_plane_z))
			vertices.append(Vector3(size*spacing, i*spacing, drawing_plane_z))
			colors.append(grid_color)
			colors.append(grid_color)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var grid_instance = MeshInstance3D.new()
	grid_instance.mesh = mesh
	add_child(grid_instance)

func _create_center_lines(size: float):
	var mesh = ArrayMesh.new()
	var verts = PackedVector3Array([
		Vector3(-size, 0, drawing_plane_z), Vector3(size, 0, drawing_plane_z),
		Vector3(0, -size, drawing_plane_z), Vector3(0, size, drawing_plane_z)
	])
	var colors = PackedColorArray([
		Color.RED, Color.RED,
		Color.GREEN, Color.GREEN
	])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var axes = MeshInstance3D.new()
	axes.mesh = mesh
	add_child(axes)

# Input handling cu snap
func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_mouse(1/zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_mouse(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				pan_last_pos = event.position
				is_panning = true
			else:
				is_panning = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				rotate_last_pos = event.position
				is_rotating = true
				orbit_pivot = get_mouse_pos_in_xy()
			else:
				is_rotating = false

	if event is InputEventMouseMotion and is_panning:
		var delta = event.position - pan_last_pos
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			var scale = camera.size / 200.0
			camera.translate(Vector3(-delta.x*scale, delta.y*scale, 0))
		else:
			var scale = 0.01 * camera.transform.origin.length()
			camera.translate(Vector3(-delta.x*scale, delta.y*scale, 0))
		pan_last_pos = event.position

	if event is InputEventMouseMotion and is_rotating and camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var delta = event.position - rotate_last_pos
		_orbit_camera(delta, orbit_pivot)
		rotate_last_pos = event.position

	if event is InputEventMouseMotion:
		_update_coordinate_display()
		_update_snap_preview()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			var world_pos = get_mouse_pos_in_xy()
			var snapped_pos = get_snapped_position(world_pos)
			print("Mouse position: ", world_pos, " Snapped: ", snapped_pos)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ray_origin = camera.project_ray_origin(event.position)
		var ray_dir = camera.project_ray_normal(event.position)
		var space_state = get_world_3d().direct_space_state
		var ray_params = PhysicsRayQueryParameters3D.new()
		ray_params.from = ray_origin
		ray_params.to = ray_origin + ray_dir * 1000
		var result = space_state.intersect_ray(ray_params)
		if result and result.has("collider"):
			var collider = result["collider"]
			# Acceptă și CSGPolygon3D ca selectabil
			if collider.has_meta("selectable") and collider.get_meta("selectable"):
				if selected_geometry:
					var prev_csg = selected_geometry.get_child(0) if selected_geometry.get_child_count() > 0 else null
					if prev_csg and prev_csg.has_method("set"):
						var layer_name = prev_csg.get_meta("layer_name") if prev_csg.has_meta("layer_name") else "default"
						var mat = default_material
						if layer_materials.has(layer_name):
							var lconf = layer_materials[layer_name]
							mat = StandardMaterial3D.new()
							mat.albedo_color = Color(lconf["color"][0], lconf["color"][1], lconf["color"][2], lconf["alpha"])
							mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						prev_csg.material_override = mat
				selected_geometry = collider
				var sel_mat = StandardMaterial3D.new()
				sel_mat.albedo_color = Color.YELLOW
				var csg = selected_geometry.get_child(0) if selected_geometry.get_child_count() > 0 else null
				if csg and csg.has_method("set"):
					csg.material_override = sel_mat
				print("[DEBUG] Selected geometry: ", selected_geometry)

func _update_snap_preview():
	if not snap_enabled:
		snap_preview_marker.visible = false
		return
	
	var world_pos = get_mouse_pos_in_xy()
	var snapped_pos = get_snapped_position(world_pos)
	
	# Verifică dacă există un punct snap în apropiere
	if world_pos.distance_to(snapped_pos) < snap_distance:
		snap_preview_marker.transform.origin = snapped_pos
		snap_preview_marker.visible = true
	else:
		snap_preview_marker.visible = false

# Z-depth control callbacks
func _on_z_min_changed(value: float):
	z_min = value
	_update_camera_clipping()
	_update_info_label()

func _on_z_max_changed(value: float):
	z_max = value
	_update_camera_clipping()
	_update_info_label()

func _on_drawing_plane_z_changed(value: float):
	drawing_plane_z = value
	_update_drawing_plane_visual()

func _set_ground_level():
	drawing_plane_z = 0.0
	z_min = -2.0
	z_max = 5.0
	_update_z_spinboxes()
	_update_camera_clipping()
	_update_drawing_plane_visual()

func _set_floor1_level():
	drawing_plane_z = 3.0
	z_min = 1.0
	z_max = 8.0
	_update_z_spinboxes()
	_update_camera_clipping()
	_update_drawing_plane_visual()

func _update_z_spinboxes():
	var z_min_spin = z_controls_panel.get_children()[3] as SpinBox
	var z_max_spin = z_controls_panel.get_children()[5] as SpinBox
	var draw_z_spin = z_controls_panel.get_children()[7] as SpinBox
	
	if z_min_spin: z_min_spin.value = z_min
	if z_max_spin: z_max_spin.value = z_max
	if draw_z_spin: draw_z_spin.value = drawing_plane_z

func _update_info_label():
	var info_label = z_controls_panel.get_node("info_label") as Label
	if info_label:
		info_label.text = "Visible: %.1f to %.1f" % [z_min, z_max]

func _update_camera_clipping():
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.near = 0.1
		camera.far = abs(z_max - z_min) + 20.0
	else:
		camera.near = 0.1
		camera.far = 1000.0

func _update_drawing_plane_visual():
	_clear_grid_and_axes()
	_create_grid(grid_size, grid_spacing)
	_create_center_lines(50)

func _clear_grid_and_axes():
	for child in get_children():
		if child is MeshInstance3D and child != camera and child != snap_preview_marker:
			child.queue_free()

func _update_coordinate_display():
	var world_pos = get_mouse_pos_in_xy()
	coord_label.text = "X: %.2f, Y: %.2f, Z: %.2f" % [world_pos.x, world_pos.y, drawing_plane_z]

func _zoom_at_mouse(factor: float):
	var world_before = get_mouse_pos_in_xy()
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size *= factor
		var world_after = get_mouse_pos_in_xy()
		var offset = world_before - world_after
		camera.translate(Vector3(offset.x, offset.y, 0))
	else:
		var target = world_before
		var dir = (target - camera.transform.origin).normalized()
		var dist = camera.transform.origin.distance_to(target)
		camera.transform.origin += dir * (1.0 - 1.0/factor) * dist

func _orbit_camera(delta: Vector2, pivot: Vector3):
	var origin = camera.transform.origin
	var distance = origin.distance_to(pivot)

	var yaw = -delta.x * 0.01
	var pitch = -delta.y * 0.01

	var dir = (origin - pivot).normalized()
	var basis = Basis()
	basis = basis.rotated(Vector3(0,0,1), yaw)
	basis = basis.rotated(Vector3(1,0,0), pitch)
	dir = basis * dir

	camera.transform.origin = pivot + dir * distance
	camera.look_at(pivot, Vector3(0,0,1))

func get_mouse_pos_in_xy() -> Vector3:
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	if dir.z == 0:
		return Vector3(0, 0, drawing_plane_z)
	var t = -(from.z - drawing_plane_z) / dir.z
	var result = from + dir * t
	result.z = drawing_plane_z
	return result

func _spawn_marker(pos: Vector3):
	var sphere = MeshInstance3D.new()
	var s = SphereMesh.new()
	s.radius = 0.1
	sphere.mesh = s
	sphere.transform.origin = Vector3(pos.x, pos.y, drawing_plane_z)
	add_child(sphere)

func _create_snap_preview_marker():
	snap_preview_marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.08
	snap_preview_marker.mesh = sphere
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.MAGENTA
	material.emission_enabled = true
	material.emission = Color.MAGENTA * 0.5
	material.flags_transparent = true
	material.flags_unshaded = true
	snap_preview_marker.material_override = material
	snap_preview_marker.visible = false
	add_child(snap_preview_marker)

func _load_project_json():
	# Placeholder: poți extinde cu logica de serializare/deserializare proiect 3D
	# Momentan nu face nimic, dar nu va da eroare la apel
	pass
	
func _select_geometry(obj):
	# Deselectează geometria precedentă
	if selected_geometry:
		var prev_csg = selected_geometry.get_child(0) if selected_geometry.get_child_count() > 0 else null
		if prev_csg and prev_csg.has_method("set"):
			var layer_name = prev_csg.get_meta("layer_name") if prev_csg.has_meta("layer_name") else "default"
			var mat = default_material
			if layer_materials.has(layer_name):
				var lconf = layer_materials[layer_name]
				mat = StandardMaterial3D.new()
				mat.albedo_color = Color(lconf["color"][0], lconf["color"][1], lconf["color"][2], lconf["alpha"])
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			prev_csg.material_override = mat
	selected_geometry = obj
	var sel_mat = StandardMaterial3D.new()
	sel_mat.albedo_color = Color.YELLOW
	var csg = selected_geometry.get_child(0) if selected_geometry.get_child_count() > 0 else null
	if csg and csg.has_method("set"):
		csg.material_override = sel_mat

func _on_tree_item_selected():
	var tree_node = get_node_or_null("Objects")
	if tree_node == null:
		return
	var selected_item = tree_node.get_selected()
	if selected_item == null:
		return
	var node_ref = selected_item.get_metadata(0)
	if node_ref and node_ref is Node3D:
		# If node_ref is a group (layer), select all its children
		if node_ref.get_child_count() > 0 and node_ref is Node3D and not node_ref.has_meta("entity_data"):
			for child in node_ref.get_children():
				if child is Node3D and child.has_meta("entity_data"):
					_select_geometry(child)
		# If node_ref is a geometry node, select it
		elif node_ref.has_meta("entity_data"):
			_select_geometry(node_ref)

func _on_tree_item_edited():
	var tree_node = get_node_or_null("Objects")
	if tree_node == null:
		return
	var edited_item = tree_node.get_edited()
	if edited_item == null:
		return
	var node_ref = edited_item.get_metadata(0)
	if node_ref and node_ref is Node3D:
		var visible = edited_item.is_checked(1)
		node_ref.visible = visible
