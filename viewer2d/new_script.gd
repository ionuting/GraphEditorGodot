# CADViewer.gd (versiunea corectată)
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

# Dictionary to track all imported projects (filename -> combiner_node)
var imported_projects := {}

# Import the SectionPlane script
const SectionPlane = preload("res://section_plane.gd")

var section_plane_instance: SectionPlane


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

	# Initialize the section plane instance
	section_plane_instance = SectionPlane.new()
	add_child(section_plane_instance)

	_setup_section_plane_controls()

	# Integrare LoadDxfBtn
	var load_btn = $CanvasLayer/LoadDxfBtn if has_node("CanvasLayer/LoadDxfBtn") else null
	if load_btn:
		print("[DEBUG] LoadDxfBtn found, connecting pressed signal.")
		load_btn.pressed.connect(_on_load_dxf_btn_pressed)
	else:
		print("[DEBUG] LoadDxfBtn NOT found!")

	# Creează FileDialog pentru selectare folder
	if not has_node("CanvasLayer/DxfFolderDialog"):
		var file_dialog = FileDialog.new()
		file_dialog.name = "DxfFolderDialog"
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.mode = FileDialog.FILE_MODE_OPEN_ANY
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		file_dialog.connect("dir_selected", Callable(self, "_on_dxf_folder_selected"))
		$CanvasLayer.add_child(file_dialog)
		print("[DEBUG] DxfFolderDialog created and added to CanvasLayer.")
	else:
		print("[DEBUG] DxfFolderDialog already exists.")

func _on_load_dxf_btn_pressed():
	var file_dialog = $CanvasLayer.get_node("DxfFolderDialog")
	if file_dialog:
		print("[DEBUG] Showing DxfFolderDialog.")
		if ProjectSettings.has_setting("dxf_last_folder"):
			file_dialog.current_dir = ProjectSettings.get_setting("dxf_last_folder")
		else:
			file_dialog.current_dir = ProjectSettings.globalize_path("res://")
		file_dialog.popup_centered()
	else:
		print("[DEBUG] DxfFolderDialog not found!")

func _on_dxf_folder_selected(dir_path):
	print("[DEBUG] Folder selectat:", dir_path)
	ProjectSettings.set_setting("dxf_last_folder", dir_path)
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".dxf"):
				var dxf_path = dir_path + "/" + file_name
				var json_path = dir_path + "/" + file_name.get_basename() + ".json"
				print("[DEBUG] Converting ", dxf_path, " to ", json_path)
				_run_python_dxf_to_json(dxf_path, json_path)
				print("[DEBUG] Importing JSON: ", json_path)
				_import_json_file(json_path)
			file_name = dir.get_next()
		dir.list_dir_end()

func _run_python_dxf_to_json(dxf_path: String, json_path: String):
	var script_path = "python/dxf_to_json.py"
	var args = [script_path, dxf_path, json_path]
	var output = []
	print("[DEBUG] Running Python: python ", args)
	var exit_code = OS.execute("python", args, output, true)
	print("[PYTHON OUTPUT]", output)
	print("[PYTHON EXIT CODE]", exit_code)
	return exit_code

func _import_json_file(json_path: String):
	if not FileAccess.file_exists(json_path):
		push_error("Nu există fișierul JSON: %s" % json_path)
		return
	var json_str = FileAccess.get_file_as_string(json_path).strip_edges(true, true)
	var data = JSON.parse_string(json_str)
	if data == null:
		push_error("Eroare la parsarea JSON-ului: %s" % json_path)
		return
	if typeof(data) == TYPE_ARRAY:
		var combiner = import_dxf_entities_csg_combiner(json_path)
		if combiner != null:
			var fname = json_path.get_file()
			imported_projects[fname] = combiner
		populate_tree_with_projects_csg(imported_projects)

func import_dxf_entities_csg_combiner(path: String):
	print("[DEBUG] Import DXF din ", path)
	if not FileAccess.file_exists(path):
		push_error("Fișierul nu există: %s" % path)
		return null
	var json_str = FileAccess.get_file_as_string(path).strip_edges(true, true)
	var data = JSON.parse_string(json_str)
	if data == null:
		push_error("Eroare la parsarea JSON-ului.")
		return null
	if typeof(data) == TYPE_ARRAY:
		var combiner = CSGCombiner3D.new()
		combiner.name = path.get_file().get_basename() + "_combiner"
		
		# Dictionary pentru a grupa entitățile pe layere
		var layers_dict := {}
		
		for entity in data:
			var layer_name = "default"
			if entity.has("layer"):
				layer_name = str(entity.layer)
			
			# Verifică dacă este layer void
			var is_void_layer = (layer_name == "void")
			
			# Creează layer parent dacă nu există
			if not layers_dict.has(layer_name):
				var layer_parent = CSGCombiner3D.new()
				layer_parent.name = layer_name
				layers_dict[layer_name] = layer_parent
			
			# Obține materialul pentru layer
			var mat: StandardMaterial3D = null
			if layer_materials.has(layer_name):
				var lconf = layer_materials[layer_name]
				mat = StandardMaterial3D.new()
				mat.albedo_color = Color(lconf["color"][0], lconf["color"][1], lconf["color"][2], lconf["alpha"])
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			else:
				mat = default_material
			
			var csg = CSGPolygon3D.new()
			
			# Extrage handle pentru nume unic
			var handle_str = ""
			if entity.has("handle"):
				handle_str = str(entity.handle)
			csg.name = layer_name + "_" + handle_str
			
			# Stochează metadata
			csg.set_meta("selectable", true)
			csg.set_meta("entity_data", entity)
			csg.set_meta("layer_name", layer_name)
			
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
					csg.position.z = z
					var pts := []
					for p in entity.points:
						pts.append(Vector2(p[0], p[1]))
					if entity.closed and pts.size() > 0:
						pts.append(pts[0])
					csg.polygon = PackedVector2Array(pts)
					csg.mode = CSGPolygon3D.MODE_DEPTH
					csg.depth = max(height, 0.01)
					csg.material = mat
					csg.visible = true
				"CIRCLE":
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
					var segments = 32
					var arr: PackedVector2Array = []
					for i in range(segments):
						var angle = (TAU / segments) * i
						var x = entity.center[0] + cos(angle) * entity.radius
						var y = entity.center[1] + sin(angle) * entity.radius
						arr.append(Vector2(x, y))
					arr.append(arr[0])
					csg.polygon = arr
					csg.mode = CSGPolygon3D.MODE_DEPTH
					csg.depth = max(height, 0.01)
					csg.position.z = z
					csg.material = mat
					csg.visible = true
			
			# Setează operația CSG
			if is_void_layer:
				csg.operation = CSGPolygon3D.OPERATION_SUBTRACTION
				print("[DEBUG][CSG SUBTRACTION] layer=", layer_name, " handle=", handle_str)
			else:
				csg.operation = CSGPolygon3D.OPERATION_UNION
				print("[DEBUG][CSG UNION] layer=", layer_name, " handle=", handle_str)
			
			# Adaugă CSG la layer parent
			layers_dict[layer_name].add_child(csg)
		
		# Adaugă toate layer-urile la combiner
		# Primul layerele non-void (UNION), apoi cele void (SUBTRACTION)
		for layer_name in layers_dict.keys():
			if layer_name != "void":
				combiner.add_child(layers_dict[layer_name])
		
		if layers_dict.has("void"):
			combiner.add_child(layers_dict["void"])
		
		# Adaugă combinerul în scenă
		var objects_node = get_node_or_null("Objects")
		if objects_node:
			objects_node.add_child(combiner)
		else:
			add_child(combiner)
		
		return combiner
	return null

func populate_tree_with_projects_csg(projects: Dictionary):
	var tree_node = get_node_or_null("Objects")
	if tree_node == null:
		print("[DEBUG] Nu există nodul Objects de tip Tree în scenă!")
		return
	tree_node.clear()
	tree_node.set_columns(2)
	var root = tree_node.create_item()
	tree_node.set_column_title(0, "File/Layer/Object")
	tree_node.set_column_title(1, "Visible")
	tree_node.set_column_titles_visible(true)
	
	for file_name in projects.keys():
		var file_item = tree_node.create_item(root)
		file_item.set_text(0, file_name)
		file_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
		file_item.set_checked(1, true)
		file_item.set_editable(1, true)
		file_item.set_metadata(0, projects[file_name])
		
		var combiner = projects[file_name]
		
		# Iterează prin layere (copiii combiner-ului)
		for layer_parent in combiner.get_children():
			var layer_item = tree_node.create_item(file_item)
			layer_item.set_text(0, layer_parent.name)
			layer_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
			layer_item.set_checked(1, true)
			layer_item.set_editable(1, true)
			layer_item.set_metadata(0, layer_parent)
			
			# Iterează prin obiecte (copiii layer-ului)
			for child in layer_parent.get_children():
				if child is CSGPolygon3D:
					var obj_item = tree_node.create_item(layer_item)
					obj_item.set_text(0, child.name)
					obj_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
					obj_item.set_checked(1, true)
					obj_item.set_editable(1, true)
					obj_item.set_metadata(0, child)
	
	if not tree_node.is_connected("item_selected", Callable(self, "_on_tree_item_selected")):
		tree_node.item_selected.connect(_on_tree_item_selected)
	if not tree_node.is_connected("item_edited", Callable(self, "_on_tree_item_edited")):
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
	var collision = CollisionPolygon3D.new()
	collision.polygon = arr
	csg.add_child(collision)
	csg.set_meta("selectable", true)
	csg.set_meta("original_material", csg.material_override)
	return csg

func set_snap_enabled(enabled: bool):
	snap_enabled = enabled
	snap_preview_marker.visible = false

func get_drawing_plane_z() -> float:
	return drawing_plane_z

func get_snapped_position(world_pos: Vector3) -> Vector3:
	if not snap_enabled:
		return world_pos
	
	var main_scene = get_tree().get_first_node_in_group("main")
	if not main_scene:
		main_scene = get_node("/root/Main")
	
	if main_scene and main_scene.has_method("get_snap_grid_panel"):
		var snap_panel = main_scene.get_snap_grid_panel()
		if snap_panel and snap_panel.has_method("get_snap_point_at"):
			return snap_panel.get_snap_point_at(world_pos, snap_distance)
	
	return world_pos

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
	var y_offset = 10 + (6 * 35) + 20
	z_controls_panel.position = Vector2(10, y_offset)
	z_controls_panel.size = Vector2(240, 160)
	z_controls_panel.add_theme_color_override("bg_color", Color(0.9, 0.9, 0.9, 0.8))
	canvas.add_child(z_controls_panel)

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
	btn_ground.position = Vector2(10, 125)
	btn_ground.size = Vector2(70, 25)
	btn_ground.pressed.connect(_set_ground_level)
	z_controls_panel.add_child(btn_ground)
	
	var btn_floor1 = Button.new()
	btn_floor1.text = "Floor 1 (3m)"
	btn_floor1.position = Vector2(135, 125)
	btn_floor1.size = Vector2(70, 25)
	btn_floor1.pressed.connect(_set_floor1_level)
	z_controls_panel.add_child(btn_floor1)
	
	var info_label = Label.new()
	info_label.text = "Visible: %.1f to %.1f" % [z_min, z_max]
	info_label.position = Vector2(10, 105)
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
		if camera.projection == Camera3D.PROJECTION_
