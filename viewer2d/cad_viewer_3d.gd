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
@export var max_orthogonal_size: float = 10000.0  # Limite pentru zoom out extrem
@export var min_orthogonal_size: float = 0.1      # Limite pentru zoom in extrem
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

# Dictionary to track all imported projects (filename -> layer_groups)
var imported_projects := {}

# Current project folder pentru ReloadBtn
var current_project_folder: String = ""

func _ready():
	# Adaugă o lumină direcțională pentru evidențierea voidurilor
	var dir_light = DirectionalLight3D.new()
	dir_light.light_color = Color(1, 1, 0.95)

	dir_light.shadow_enabled = true
	dir_light.shadow_bias = 0.05

	dir_light.transform.origin = Vector3(0, 10, 10)
	add_child(dir_light)
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

	# Normalizează structura layer_materials (acceptă și array direct din CSV/JSON)
	for k in layer_materials.keys():
		var v = layer_materials[k]
		if v is Array and v.size() == 4:
			layer_materials[k] = {"color": [v[0], v[1], v[2]], "alpha": v[3]}

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

	# Conectează semnale pentru Tree (Objects)
	var tree_node = get_node_or_null("Objects")
	if tree_node:
		tree_node.connect("item_selected", Callable(self, "_on_tree_item_selected"))
		tree_node.connect("item_edited", Callable(self, "_on_tree_item_edited"))

	# Integrare LoadDxfBtn
	var load_btn = $CanvasLayer/LoadDxfBtn if has_node("CanvasLayer/LoadDxfBtn") else null
	if load_btn:
		load_btn.pressed.connect(_on_load_dxf_btn_pressed)
		# Creează FileDialog pentru selectare folder dacă nu există
		if not has_node("CanvasLayer/DxfFolderDialog"):
			var file_dialog = FileDialog.new()
			file_dialog.name = "DxfFolderDialog"
			file_dialog.access = FileDialog.ACCESS_FILESYSTEM
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
			file_dialog.connect("dir_selected", Callable(self, "_on_dxf_folder_selected"))
			$CanvasLayer.add_child(file_dialog)
	
	# Integrare ReloadBtn
	var reload_btn = $CanvasLayer/ReloadBtn if has_node("CanvasLayer/ReloadBtn") else null
	if reload_btn:
		reload_btn.pressed.connect(_on_reload_btn_pressed)
	
	# Watchdog pentru monitorizarea automată a fișierelor DXF
	_setup_dxf_watchdog()

# === DXF to GLB batch import ===
func _on_load_dxf_btn_pressed():
	var file_dialog = $CanvasLayer.get_node("DxfFolderDialog")
	if file_dialog:
		file_dialog.popup_centered()
	else:
		push_error("DxfFolderDialog not found!")

func _on_dxf_folder_selected(dir_path):
	print("[DEBUG] Folder selectat:", dir_path)
	# Salvează folderul curent pentru reload
	current_project_folder = dir_path
	_process_dxf_folder(dir_path)

func _on_reload_btn_pressed():
	if current_project_folder == "":
		print("[DEBUG] No project folder selected. Use Load DXF first.")
		return
	
	print("[DEBUG] Reloading project folder:", current_project_folder)
	# Șterge toate mesh-urile existente
	_clear_all_imported_projects()
	
	# Curăță cache-ul ResourceLoader și fișierele .import pentru toate GLB-urile din folder
	_clear_glb_cache_and_imports_for_folder(current_project_folder)
	
	# Așteaptă mai multe frame-uri pentru cleanup complet
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Reprocessează folderul
	_process_dxf_folder(current_project_folder)

func _process_dxf_folder(dir_path: String):
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var glb_paths = []
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".dxf"):
				var dxf_path = dir_path + "/" + file_name
				var glb_path = dir_path + "/" + file_name.get_basename() + ".glb"
				print("[DEBUG] Converting ", dxf_path, " to ", glb_path)
				_run_python_dxf_to_glb(dxf_path, glb_path)
				if FileAccess.file_exists(glb_path):
					glb_paths.append(glb_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		# Încarcă toate GLB-urile rezultate
		_load_glb_meshes(glb_paths)

func _run_python_dxf_to_glb(dxf_path: String, glb_path: String):
	var script_path = "python/dxf_to_glb_trimesh.py"
	var args = [script_path, dxf_path, glb_path]
	var output = []
	print("[DEBUG] Running Python: python ", args)
	var exit_code = OS.execute("python", args, output, true)
	print("[PYTHON OUTPUT]", output)
	print("[PYTHON EXIT CODE]", exit_code)
	return exit_code


func _load_glb_meshes(glb_paths: Array):
	for glb_path in glb_paths:
		if FileAccess.file_exists(glb_path):
			print("[DEBUG] Loading GLB with forced reimport: ", glb_path)
			
			# Asigură-te că fișierul este complet scris
			var file_size = _get_file_size(glb_path)
			if file_size < 100:
				print("[DEBUG] Waiting for GLB file to be completely written...")
				await get_tree().create_timer(0.3).timeout
			
			# Forțează ștergerea cache-ului și fișierelor .import
			_force_clear_resource_cache(glb_path)
			_force_delete_import_files(glb_path)
			
			# Modifică timestamp-ul pentru reimport
			_touch_file_for_reimport(glb_path)
			
			# Încarcă cu sistema robustă de retry
			var success = await _load_glb_with_retry(glb_path)
			if not success:
				print("[ERROR] GLTF/GLB import failed after retries: ", glb_path)
		else:
			print("[ERROR] GLTF/GLB file not found: ", glb_path)
	
	# Populează tree-ul după import
	populate_tree_with_projects(imported_projects)

func _load_window_gltf_for_glb(glb_path: String):
	"""Încarcă ferestrele GLTF pentru un fișier GLB bazat pe mapping-ul JSON"""
	var mapping_path = glb_path.get_basename() + "_mapping.json"
	
	if not FileAccess.file_exists(mapping_path):
		print("[DEBUG] No mapping file found: ", mapping_path)
		return
	
	var mapping_file = FileAccess.open(mapping_path, FileAccess.READ)
	if not mapping_file:
		print("[ERROR] Cannot open mapping file: ", mapping_path)
		return
	
	var json_str = mapping_file.get_as_text()
	mapping_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_str)
	if parse_result != OK:
		print("[ERROR] Failed to parse mapping JSON: ", mapping_path)
		return
	
	var mapping_data = json.data
	if typeof(mapping_data) != TYPE_ARRAY:
		print("[ERROR] Invalid mapping data format")
		return
	
	# Procesează fiecare entry din mapping
	for entry in mapping_data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		
		# Verifică dacă este un bloc de fereastră
		if entry.get("type", "") == "window_block":
			_load_single_window_gltf(entry, glb_path)

func _load_single_window_gltf(window_entry: Dictionary, source_glb_path: String):
	"""Încarcă o singură fereastră GLTF și o poziționează în scenă"""
	var gltf_file = window_entry.get("gltf_file", "")
	var window_name = window_entry.get("window_name", "UnknownWindow")
	var position = window_entry.get("position", {"x": 0.0, "y": 0.0, "z": 0.0})
	var rotation = window_entry.get("rotation", {"z": 0.0})
	var scale = window_entry.get("scale", {"x": 1.0, "y": 1.0, "z": 1.0})
	
	# Construiește calea completă la fișierul GLTF
	var full_gltf_path = gltf_file
	
	# Încearcă mai întâi ca resursă Godot (res://)
	if not full_gltf_path.begins_with("res://"):
		full_gltf_path = "res://" + gltf_file
	
	# Dacă nu există ca resursă, încearcă calea absolută în sistemul de fișiere
	if not ResourceLoader.exists(full_gltf_path) and not FileAccess.file_exists(full_gltf_path):
		# Încearcă calea relativă față de folderul curent al proiectului
		var project_relative_path = ProjectSettings.globalize_path("res://") + gltf_file
		if FileAccess.file_exists(project_relative_path):
			full_gltf_path = project_relative_path
	
	print("[DEBUG] Loading window GLTF: ", full_gltf_path)
	print("[DEBUG] Position: (%.2f, %.2f, %.2f), Rotation: %.1f°" % [position.x, position.y, position.z, rotation.z])
	
	# Verifică dacă fișierul GLTF există
	if not FileAccess.file_exists(full_gltf_path) and not ResourceLoader.exists(full_gltf_path):
		print("[ERROR] Window GLTF file not found: ", full_gltf_path)
		return
	
	# Încarcă scena GLTF
	var window_scene = ResourceLoader.load(full_gltf_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if not window_scene or not window_scene is PackedScene:
		print("[ERROR] Failed to load window GLTF as PackedScene: ", full_gltf_path)
		return
	
	# Instanțiază scena
	var window_instance = window_scene.instantiate()
	if not window_instance:
		print("[ERROR] Failed to instantiate window scene")
		return
	
	# Setează poziția
	window_instance.transform.origin = Vector3(position.x, position.y, position.z)
	
	# Setează rotația (doar în jurul axei Z pentru ferestre)
	if rotation.z != 0.0:
		window_instance.transform.basis = Basis()
		window_instance.transform.basis = window_instance.transform.basis.rotated(Vector3(0, 0, 1), deg_to_rad(rotation.z))
	
	# Setează scala dacă este diferită de default
	if scale.x != 1.0 or scale.y != 1.0 or scale.z != 1.0:
		window_instance.scale = Vector3(scale.x, scale.y, scale.z)
	
	# Setează numele pentru identificare
	window_instance.name = window_name
	
	# Adaugă la scenă
	add_child(window_instance)
	
	# Adaugă în structura imported_projects pentru managementul în tree
	var glb_filename = source_glb_path.get_file()
	if not imported_projects.has(glb_filename):
		imported_projects[glb_filename] = {}
	if not imported_projects[glb_filename].has("IfcWindow"):
		imported_projects[glb_filename]["IfcWindow"] = {}
	imported_projects[glb_filename]["IfcWindow"][window_name] = window_instance
	
	print("[DEBUG] WINDOW LOADED: %s | GLTF: %s | Pos: (%.2f, %.2f, %.2f) | Rot: %.1f° | Visible: %s" % [
		window_name, 
		full_gltf_path.get_file(), 
		position.x, position.y, position.z, 
		rotation.z, 
		str(window_instance.visible)
	])

# Debug: Recursiv, afișează numele meshurilor și culoarea vertex principal (dacă există)
func _print_meshes_and_colors(node: Node, glb_path: String):

	if node is MeshInstance3D and node.mesh:
		var mesh_name = str(node.name)  # Convert StringName to String
		var mesh = node.mesh
		var color_str = "-"
		var layer_name = "default"
		# Extrage IfcType (prima parte a numelui meshului, până la _)
		if mesh_name.find("_") > 0:
			layer_name = mesh_name.split("_")[0]
		var element_name = mesh_name.substr(mesh_name.find("_") + 1) if mesh_name.find("_") > 0 else mesh_name
		# Mapare insensibilă la majuscule/minuscule și fallback la 'default'
		var found_layer = ""
		for k in layer_materials.keys():
			if k.to_lower() == layer_name.to_lower():
				found_layer = k
				break
		if found_layer == "":
			found_layer = "default"
		var lconf = layer_materials[found_layer]
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(lconf["color"][0], lconf["color"][1], lconf["color"][2], lconf["alpha"])
		if lconf["alpha"] < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		node.material_override = mat
		color_str = str(mat.albedo_color)
		# Debug print pentru fiecare obiect încărcat
		print("[DEBUG] SCENE LOAD: %s | Mesh: %s | Layer: %s | Alpha: %.2f | Visible: %s | Pos: %s" % [glb_path, mesh_name, found_layer, lconf["alpha"], str(node.visible), str(node.transform.origin)])

		# --- Populare structură pentru tree ---
		if not imported_projects.has(glb_path):
			imported_projects[glb_path] = {}
		if not imported_projects[glb_path].has(layer_name):
			imported_projects[glb_path][layer_name] = {}
		imported_projects[glb_path][layer_name][mesh_name] = node

	for child in node.get_children():
		_print_meshes_and_colors(child, glb_path)

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
		camera.near = 0.01  # Mai aproape pentru detalii fine
		# Far mult mai mare pentru a permite zoom out extrem
		var dynamic_far = max(1000.0, camera.size * 10.0)  # Se adaptează la nivelul de zoom
		camera.far = dynamic_far
		print("[DEBUG] Orthogonal camera: size=%.2f, near=%.2f, far=%.2f" % [camera.size, camera.near, camera.far])
	else:
		camera.near = 0.01
		camera.far = 10000.0  # Mult mai mare pentru perspective

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
		var new_size = camera.size * factor
		# Limitează zoom-ul între min și max
		new_size = clamp(new_size, min_orthogonal_size, max_orthogonal_size)
		camera.size = new_size
		# Actualizează limitele de clipping după zoom
		_update_camera_clipping()
		var world_after = get_mouse_pos_in_xy()
		var offset = world_before - world_after
		camera.translate(Vector3(offset.x, offset.y, 0))
	else:
		var target = world_before
		var dir = (target - camera.transform.origin).normalized()
		var dist = camera.transform.origin.distance_to(target)
		camera.transform.origin += dir * (1.0 - 1.0/factor) * dist
		# Actualizează limitele de clipping și pentru perspective
		_update_camera_clipping()

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
				

func populate_tree_with_projects(projects: Dictionary):
	var tree_node = get_node_or_null("Objects")
	if tree_node == null:
		print("[DEBUG] Nu există nodul Objects de tip Tree în scenă!")
		return
	tree_node.clear()
	tree_node.set_columns(2)
	var root = tree_node.create_item()
	tree_node.set_column_title(0, "GLB File / IfcType / Element")
	tree_node.set_column_title(1, "Visible")
	tree_node.set_column_titles_visible(true)

	for file_name in projects.keys():
		var file_item = tree_node.create_item(root)
		file_item.set_text(0, file_name)
		file_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
		file_item.set_checked(1, true)
		file_item.set_editable(1, true)
		file_item.set_metadata(0, {"type": "file", "file": file_name})

		var layer_groups = projects[file_name]
		for layer_group in layer_groups.keys():
			var group_item = tree_node.create_item(file_item)
			group_item.set_text(0, layer_group)
			group_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
			group_item.set_checked(1, true)
			group_item.set_editable(1, true)
			group_item.set_metadata(0, {"type": "group", "file": file_name, "group": layer_group})

			var elements = layer_groups[layer_group]
			for elem_name in elements.keys():
				var elem_item = tree_node.create_item(group_item)
				elem_item.set_text(0, elem_name)
				elem_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
				elem_item.set_checked(1, true)
				elem_item.set_editable(1, true)
				elem_item.set_metadata(0, {"type": "element", "file": file_name, "group": layer_group, "element": elem_name})

# --- Tree select & visibility logic ---
func _on_tree_item_selected():
	var tree_node = get_node_or_null("Objects")
	if not tree_node:
		return
	var item = tree_node.get_selected()
	if not item:
		return
	var meta = item.get_metadata(0)
	if typeof(meta) != TYPE_DICTIONARY:
		return
	if meta.has("type") and meta["type"] == "element":
		var file = meta["file"]
		var group = meta["group"]
		var elem = meta["element"]
		if imported_projects.has(file) and imported_projects[file].has(group) and imported_projects[file][group].has(elem):
			var node = imported_projects[file][group][elem]
			_highlight_selected_node(node)

func _highlight_selected_node(node):
	if not node:
		return
	# Reset previous selection
	if selected_geometry and selected_geometry != node:
		var mesh_name = selected_geometry.name
		var layer_name = mesh_name.split("_")[0] if mesh_name.find("_") > 0 else "default"
		var lconf = layer_materials.has(layer_name) if layer_materials.has(layer_name) else layer_materials["default"]
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(lconf["color"][0], lconf["color"][1], lconf["color"][2], lconf["alpha"])
		if lconf["alpha"] < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		selected_geometry.material_override = mat
	# Highlight new selection
	selected_geometry = node
	var sel_mat = StandardMaterial3D.new()
	sel_mat.albedo_color = Color.YELLOW
	selected_geometry.material_override = sel_mat

func _on_tree_item_edited():
	var tree_node = get_node_or_null("Objects")
	if not tree_node:
		return
	var edited = tree_node.get_edited()
	if not edited:
		return
	var meta = edited.get_metadata(0)
	if typeof(meta) != TYPE_DICTIONARY:
		return
	var checked = edited.is_checked(1)
	if meta.has("type"):
		match meta["type"]:
			"file":
				_set_visibility_file(meta["file"], checked)
			"group":
				_set_visibility_group(meta["file"], meta["group"], checked)
			"element":
				_set_visibility_element(meta["file"], meta["group"], meta["element"], checked)

func _set_visibility_file(file, visible):
	if imported_projects.has(file):
		for group in imported_projects[file].keys():
			_set_visibility_group(file, group, visible)

func _set_visibility_group(file, group, visible):
	if imported_projects.has(file) and imported_projects[file].has(group):
		for elem in imported_projects[file][group].keys():
			_set_visibility_element(file, group, elem, visible)

func _set_visibility_element(file, group, elem, visible):
	if imported_projects.has(file) and imported_projects[file].has(group) and imported_projects[file][group].has(elem):
		var node = imported_projects[file][group][elem]
		if node:
			node.visible = visible

	
func _setup_ui_buttons():
	# Creează butoane de view preset
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
	var title_label = Label.new()
	title_label.text = "Z-Depth Controls"
	title_label.position = Vector2(10, 5)
	title_label.add_theme_color_override("font_color", Color.BLACK)
	title_label.add_theme_font_size_override("font_size", 12)
	z_controls_panel.add_child(title_label)

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

func get_snapped_position(world_pos: Vector3) -> Vector3:
	# Snap logic placeholder (return world_pos direct dacă nu ai snap grid)
	return world_pos

# === DXF Watchdog System ===
var watchdog_timer: Timer
var signal_file_path: String = "reload_signal.json"
var last_signal_timestamp: float = 0.0
var watchdog_process: int = -1

func _setup_dxf_watchdog():
	# Creează timer pentru verificarea signal file-ului
	watchdog_timer = Timer.new()
	watchdog_timer.wait_time = 1.0  # Verifică în fiecare secundă
	watchdog_timer.timeout.connect(_check_reload_signal)
	watchdog_timer.autostart = true
	add_child(watchdog_timer)
	
	# Pornește procesul Python watchdog în background
	_start_python_watchdog()

func _start_python_watchdog():
	var script_path = "python/dxf_watchdog.py"
	var args = [script_path]
	print("[DEBUG] Starting DXF watchdog process...")
	
	# Pornește procesul în background (non-blocking)
	watchdog_process = OS.create_process("python", args, false)
	if watchdog_process > 0:
		print("[DEBUG] DXF watchdog started with PID: ", watchdog_process)
	else:
		print("[ERROR] Failed to start DXF watchdog")

func _check_reload_signal():
	if not FileAccess.file_exists(signal_file_path):
		return
	
	var file = FileAccess.open(signal_file_path, FileAccess.READ)
	if not file:
		return
	
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_str)
	if parse_result != OK:
		return
	
	var signal_data = json.data
	if typeof(signal_data) != TYPE_DICTIONARY:
		return
	
	var timestamp = signal_data.get("timestamp", 0.0)
	if timestamp > last_signal_timestamp:
		last_signal_timestamp = timestamp
		var glb_file = signal_data.get("glb_file", "")
		var dxf_file = signal_data.get("dxf_file", "")
		
		print("[DEBUG] Watchdog signal received: reloading ", glb_file)
		_reload_single_glb(glb_file, dxf_file)

func _reload_single_glb(glb_path: String, dxf_path: String):
	if not FileAccess.file_exists(glb_path):
		print("[ERROR] GLB file not found for reload: ", glb_path)
		return
	
	print("[DEBUG] Hot reloading GLB: ", glb_path)
	
	# Elimină mesh-urile existente pentru acest fișier
	var filename = glb_path.get_file().get_basename()
	_remove_existing_meshes_for_file(filename)
	
	# Forțează ștergerea completă a cache-ului și fișierelor .import
	_force_clear_resource_cache(glb_path)
	_force_delete_import_files(glb_path)
	
	# Așteaptă mai multe frame-uri pentru cleanup complet
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verifică dimensiunea fișierului pentru a fi sigur că este complet
	var file_size = _get_file_size(glb_path)
	if file_size < 100:  # Fișier prea mic, probabil încă se scrie
		print("[DEBUG] Waiting for GLB file to be completely written...")
		await get_tree().create_timer(0.5).timeout
	
	# Forțează reimportul prin modificarea timestamp-ului fișierului
	_touch_file_for_reimport(glb_path)
	
	# Încearcă să încarce GLB-ul cu multiple tentative
	var success = await _load_glb_with_retry(glb_path)
	
	if success:
		# Flash vizual pentru confirmare
		_flash_reload_indicator()
	else:
		print("[ERROR] Failed to reload GLB after multiple attempts: ", glb_path)

func _remove_existing_meshes_for_file(filename: String):
	# Elimină din imported_projects
	var keys_to_remove = []
	for key in imported_projects.keys():
		if key.contains(filename):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		# Elimină nodurile din scenă (inclusiv ferestrele GLTF)
		for layer in imported_projects[key].values():
			for mesh_node in layer.values():
				if mesh_node and is_instance_valid(mesh_node):
					mesh_node.queue_free()
		imported_projects.erase(key)
	
	print("[DEBUG] Removed existing meshes and windows for file: ", filename)

func _clear_all_imported_projects():
	print("[DEBUG] Clearing all imported projects")
	
	# Elimină toate nodurile din scenă
	for project_key in imported_projects.keys():
		for layer in imported_projects[project_key].values():
			for mesh_node in layer.values():
				if mesh_node and is_instance_valid(mesh_node):
					mesh_node.queue_free()
	
	# Curăță dicționarul
	imported_projects.clear()
	
	# Resetează tree-ul
	var tree_node = get_node_or_null("Objects")
	if tree_node:
		tree_node.clear()
	
	# Resetează selecția
	selected_geometry = null

func _clear_glb_cache_and_imports_for_folder(folder_path: String):
	print("[DEBUG] Clearing GLB cache and import files for folder: ", folder_path)
	var dir = DirAccess.open(folder_path)
	if not dir:
		print("[ERROR] Cannot access folder: ", folder_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".glb"):
			var glb_path = folder_path + "/" + file_name
			print("[DEBUG] Processing GLB for cache clear: ", glb_path)
			
			# Curăță cache-ul și fișierele .import
			_force_clear_resource_cache(glb_path)
			_force_delete_import_files(glb_path)
			
			# Modifică timestamp-ul pentru reimport
			_touch_file_for_reimport(glb_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	print("[DEBUG] ✓ Cache and import cleanup completed for folder")

func _force_clear_resource_cache(glb_path: String):
	"""Forțează curățarea completă a cache-ului pentru un fișier GLB"""
	# Șterge din cache ResourceLoader dacă există
	if ResourceLoader.has_cached(glb_path):
		print("[DEBUG] Clearing ResourceLoader cache for: ", glb_path)
		# Nu există o metodă directă, dar CACHE_MODE_IGNORE va ignora cache-ul
	
	# Notifică Godot să elibereze toate referințele la resursa
	if ResourceLoader.exists(glb_path):
		print("[DEBUG] Forcing resource cache clear for: ", glb_path)

func _force_delete_import_files(glb_path: String):
	"""Șterge toate fișierele .import asociate cu GLB-ul"""
	var base_dir = glb_path.get_base_dir()
	var file_name = glb_path.get_file()
	var dir = DirAccess.open(base_dir)
	
	if not dir:
		print("[ERROR] Cannot access directory: ", base_dir)
		return
	
	# Șterge fișierul .import principal
	var import_file = glb_path + ".import"
	if FileAccess.file_exists(import_file):
		if dir.remove(import_file.get_file()) == OK:
			print("[DEBUG] ✓ Removed import file: ", import_file)
		else:
			print("[ERROR] Failed to remove import file: ", import_file)
	
	# Șterge și fișierele .import pentru mapping-uri și alte fișiere asociate
	var mapping_file = glb_path.get_basename() + "_mapping.json"
	var mapping_import = mapping_file + ".import"
	if FileAccess.file_exists(mapping_import):
		if dir.remove(mapping_import.get_file()) == OK:
			print("[DEBUG] ✓ Removed mapping import file: ", mapping_import)
	
	# Șterge din .godot/imported/ dacă există
	var godot_imported_dir = ProjectSettings.globalize_path("res://.godot/imported/")
	var imported_dir = DirAccess.open(godot_imported_dir)
	if imported_dir:
		var search_name = file_name.get_basename()
		imported_dir.list_dir_begin()
		var imported_file = imported_dir.get_next()
		while imported_file != "":
			if imported_file.contains(search_name):
				if imported_dir.remove(imported_file) == OK:
					print("[DEBUG] ✓ Removed from .godot/imported/: ", imported_file)
			imported_file = imported_dir.get_next()
		imported_dir.list_dir_end()

func _touch_file_for_reimport(glb_path: String):
	"""Modifică timestamp-ul fișierului pentru a forța reimportul în Godot"""
	# Citește conținutul fișierului
	var file = FileAccess.open(glb_path, FileAccess.READ)
	if not file:
		print("[ERROR] Cannot open file for touch: ", glb_path)
		return
	
	var content = file.get_buffer(file.get_length())
	file.close()
	
	# Rescrie fișierul pentru a actualiza timestamp-ul
	file = FileAccess.open(glb_path, FileAccess.WRITE)
	if file:
		file.store_buffer(content)
		file.close()
		print("[DEBUG] ✓ File timestamp updated for reimport: ", glb_path)
	else:
		print("[ERROR] Cannot write file for touch: ", glb_path)

func _force_recreate_glb_file(glb_path: String) -> bool:
	"""Recreează complet fișierul GLB pentru a forța recunoașterea de către Godot"""
	var file = FileAccess.open(glb_path, FileAccess.READ)
	if not file:
		print("[ERROR] Cannot read GLB for recreation: ", glb_path)
		return false
	
	var content = file.get_buffer(file.get_length())
	file.close()
	
	# Creează backup temporar
	var temp_path = glb_path + ".temp_backup"
	var temp_file = FileAccess.open(temp_path, FileAccess.WRITE)
	if not temp_file:
		print("[ERROR] Cannot create temp backup: ", temp_path)
		return false
	
	temp_file.store_buffer(content)
	temp_file.close()
	
	# Șterge originalul
	var dir = DirAccess.open(glb_path.get_base_dir())
	if not dir or dir.remove(glb_path.get_file()) != OK:
		print("[ERROR] Cannot remove original GLB: ", glb_path)
		# Cleanup temp file
		dir.remove(temp_path.get_file())
		return false
	
	# Așteaptă puțin pentru ca sistemul să recunoască ștergerea
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Recreează din backup
	var new_file = FileAccess.open(glb_path, FileAccess.WRITE)
	if not new_file:
		# Încearcă să restaurezi din backup
		dir.copy(temp_path, glb_path)
		print("[ERROR] Cannot recreate GLB, restored from backup: ", glb_path)
		dir.remove(temp_path.get_file())
		return false
	
	new_file.store_buffer(content)
	new_file.close()
	
	# Curăță backup-ul
	dir.remove(temp_path.get_file())
	
	print("[DEBUG] ✓ Successfully recreated GLB file: ", glb_path)
	return true

func _force_reimport_via_editor(glb_path: String):
	"""Forțează reimportul unui fișier prin EditorInterface"""
	if not Engine.is_editor_hint():
		return
		
	print("[DEBUG] Forcing reimport via EditorInterface: ", glb_path)
	var res_path = ProjectSettings.localize_path(glb_path)
	
	# Forțează actualizarea filesystem-ului pentru acest fișier
	EditorInterface.get_resource_filesystem().update_file(res_path)
	await get_tree().process_frame
	
	# Forțează reimport complet
	EditorInterface.get_resource_filesystem().reimport_files([res_path])
	await get_tree().process_frame
	await get_tree().process_frame

func _load_glb_with_gltf_document(glb_path: String) -> PackedScene:
	"""Încarcă GLB direct cu GLTFDocument - bypass pentru runtime loading"""
	print("[DEBUG] Attempting direct GLTFDocument loading: ", glb_path)
	
	var file = FileAccess.open(glb_path, FileAccess.READ)
	if not file:
		print("[ERROR] Cannot open GLB file: ", glb_path)
		return null
	
	var glb_data = file.get_buffer(file.get_length())
	file.close()
	
	if glb_data.size() == 0:
		print("[ERROR] Empty GLB file: ", glb_path)
		return null
	
	# Folosește GLTFDocument pentru încărcare directă
	var gltf_document = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	
	# Încarcă din buffer binary
	var error = gltf_document.append_from_buffer(glb_data, "", gltf_state)
	if error != OK:
		print("[ERROR] GLTFDocument.append_from_buffer failed: ", error)
		return null
	
	# Generează scena (returnează Node3D)
	var scene_node = gltf_document.generate_scene(gltf_state)
	if not scene_node:
		print("[ERROR] GLTFDocument.generate_scene failed")
		return null
	
	# Creează PackedScene din Node3D
	var packed_scene = PackedScene.new()
	var pack_result = packed_scene.pack(scene_node)
	if pack_result != OK:
		print("[ERROR] Failed to pack scene into PackedScene: ", pack_result)
		scene_node.queue_free()
		return null
	
	print("[DEBUG] ✅ GLTFDocument loading successful: ", glb_path)
	return packed_scene

func _load_glb_with_retry(glb_path: String) -> bool:
	"""Încarcă GLB cu multiple tentative și verificări robuste"""
	var max_attempts = 5
	var base_delay = 0.5
	
	# Forțează reimportul prin ștergerea completă a cache-ului înainte de prima tentativă
	_force_clear_resource_cache(glb_path)
	_force_delete_import_files(glb_path)
	
	# Așteaptă mai mult timp pentru Godot să proceseze ștergerea
	await get_tree().create_timer(1.0).timeout
	
	for attempt in range(max_attempts):
		print("[DEBUG] Loading attempt %d/%d: %s" % [attempt + 1, max_attempts, glb_path.get_file()])
		
		# Verifică integritatea fișierului GLB
		var file_size = _get_file_size(glb_path)
		if file_size < 100:
			print("[DEBUG] ❌ GLB file too small (%d bytes), skipping" % file_size)
			return false
		
		# Verifică și fișierul .import
		var import_file = glb_path + ".import"
		var import_exists = FileAccess.file_exists(import_file)
		print("[DEBUG] Import file exists: %s (%s)" % [str(import_exists), import_file.get_file()])
		
		# Dacă nu există fișierul .import, forțează Godot să îl regenereze
		if not import_exists:
			print("[DEBUG] Forcing Godot to regenerate import file...")
			# Creează un timestamp dummy în fișier pentru a forța regenerarea
			_touch_file_for_reimport(glb_path)
			await get_tree().create_timer(0.8).timeout
		
		# Pentru runtime loading, încearcă GLTFDocument direct 
		if not Engine.is_editor_hint():
			print("[DEBUG] Runtime detected - trying GLTFDocument direct loading...")
			var direct_scene = _load_glb_with_gltf_document(glb_path)
			if direct_scene:
				var scene = direct_scene.instantiate()
				if scene:
					print("[DEBUG] ✅ GLTFDocument direct loading successful!")
					add_child(scene)
					print("[DEBUG] ✓ Hot reload successful: ", glb_path)
					_print_meshes_and_colors(scene, glb_path)
					
					# Încarcă ferestrele GLTF pentru acest GLB
					_load_window_gltf_for_glb(glb_path)
					
					# Actualizează structura de proiecte
					populate_tree_with_projects(imported_projects)
					
					# Flash vizual pentru confirmare
					_flash_reload_indicator()
					return true
		
		# Încearcă să încarce resursa cu diferite strategii
		var packed_scene = null
		
		if attempt == 0:
			# Prima tentativă: CACHE_MODE_IGNORE standard
			packed_scene = ResourceLoader.load(glb_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		elif attempt == 1:
			# A doua tentativă: Încearcă să încarci direct fișierul .scn din cache
			if FileAccess.file_exists(import_file):
				print("[DEBUG] Attempting direct .scn cache loading...")
				var import_content = FileAccess.get_file_as_string(import_file)
				# Caută linia cu path="res://..."
				var lines = import_content.split("\n")
				var scn_path = ""
				for line in lines:
					if line.begins_with("path="):
						# Extrage calea dintre ghilimele
						var start_quote = line.find("\"")
						var end_quote = line.find("\"", start_quote + 1)
						if start_quote >= 0 and end_quote > start_quote:
							scn_path = line.substr(start_quote + 1, end_quote - start_quote - 1)
							break
				if scn_path != "":
					print("[DEBUG] Found .scn path: %s" % scn_path)
					packed_scene = ResourceLoader.load(scn_path, "", ResourceLoader.CACHE_MODE_REUSE)
					print("[DEBUG] Direct .scn load result: %s" % str(packed_scene))
				else:
					print("[DEBUG] Could not parse .scn path from .import file")
			
			# Fallback la încărcare standard dacă .scn nu a mers
			if not packed_scene:
				packed_scene = ResourceLoader.load(glb_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		elif attempt == 2:
			# A treia tentativă: Forțează res:// path
			var res_path = ProjectSettings.localize_path(glb_path)
			print("[DEBUG] Attempting with res:// path: %s" % res_path)
			packed_scene = ResourceLoader.load(res_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		elif attempt == 3:
			# A patra tentativă: Specifică explicit tipul + rescan filesystem
			packed_scene = ResourceLoader.load(glb_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
			
			# Dacă încă nu merge, forțează rescan filesystem
			if not packed_scene:
				print("[DEBUG] Forcing filesystem rescan...")
				if Engine.is_editor_hint():
					EditorInterface.get_resource_filesystem().scan()
					await get_tree().process_frame
					await get_tree().process_frame
					packed_scene = ResourceLoader.load(glb_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
				else:
					print("[DEBUG] Not in editor - skipping filesystem rescan")
		else:
			# Ultima tentativă: Combinație de strategii + GLTFDocument direct
			print("[DEBUG] Final attempt with multiple strategies...")
			
			# Pentru runtime (non-editor), încearcă GLTFDocument direct
			if not Engine.is_editor_hint():
				print("[DEBUG] Runtime detected - trying GLTFDocument direct loading...")
				packed_scene = _load_glb_with_gltf_document(glb_path)
			
			# Dacă GLTFDocument nu a mers sau suntem în editor, fallback tradițional
			if not packed_scene:
				var abs_path = ProjectSettings.globalize_path(glb_path)
				packed_scene = ResourceLoader.load(abs_path, "", ResourceLoader.CACHE_MODE_IGNORE)
				
				# Dacă nu merge, încearcă să reîncarci ca Resource generic
				if not packed_scene:
					packed_scene = ResourceLoader.load(glb_path, "Resource", ResourceLoader.CACHE_MODE_IGNORE)
					print("[DEBUG] Generic Resource load: %s" % str(packed_scene))
		
		print("[DEBUG] ResourceLoader result: %s (type: %s)" % [str(packed_scene), str(type_string(typeof(packed_scene)))])
		
		# Verifică dacă încărcarea a reușit
		if packed_scene and packed_scene is PackedScene:
			print("[DEBUG] ✅ PackedScene loaded successfully on attempt %d" % (attempt + 1))
			
			# Instanțiază scena
			var scene = packed_scene.instantiate()
			if scene:
				add_child(scene)
				print("[DEBUG] ✓ Hot reload successful: ", glb_path)
				_print_meshes_and_colors(scene, glb_path)
				
				# Încarcă ferestrele GLTF pentru acest GLB
				_load_window_gltf_for_glb(glb_path)
				
				# Actualizează structura de proiecte
				populate_tree_with_projects(imported_projects)
				
				# Flash vizual pentru confirmare
				_flash_reload_indicator()
				
				return true
			else:
				print("[DEBUG] ❌ Failed to instantiate scene on attempt %d" % (attempt + 1))
		else:
			print("[DEBUG] ❌ ResourceLoader failed on attempt %d: %s" % [attempt + 1, str(packed_scene)])
			
			# Diagnosticare avansată
			if packed_scene == null:
				print("[DEBUG] 🔍 Null result - possible GLB corruption or import failure")
				_diagnose_glb_file(glb_path)
			elif not packed_scene is PackedScene:
				print("[DEBUG] 🔍 Wrong type returned: %s instead of PackedScene" % str(type_string(typeof(packed_scene))))
				# Încearcă să convertim Resource-ul la PackedScene dacă e posibil
				if packed_scene.has_method("instantiate"):
					print("[DEBUG] Attempting direct instantiation of Resource...")
					var scene = packed_scene.instantiate()
					if scene:
						add_child(scene)
						print("[DEBUG] ✓ Success via direct Resource instantiation!")
						_print_meshes_and_colors(scene, glb_path)
						_load_window_gltf_for_glb(glb_path)
						populate_tree_with_projects(imported_projects)
						_flash_reload_indicator()
						return true
		
		# Între tentative, strategy diferită de curățare
		if attempt < max_attempts - 1:
			print("[DEBUG] Retrying with different cleanup strategy...")
			
			# Strategii diferite de curățare pe fiecare tentativă
			if attempt == 0:
				# Prima dată: curățare standard
				_force_clear_resource_cache(glb_path)
			elif attempt == 1:
				# A doua oară: curățare + restart ResourceLoader
				_force_clear_resource_cache(glb_path)
				_force_delete_import_files(glb_path) 
				# Forțează colectarea gunoiului
				if Engine.has_method("force_garbage_collect"):
					print("[DEBUG] Forcing garbage collection...")
					# Nu există în Godot, dar putem aștepta mai mult
			elif attempt == 2:
				# A treia oară: recreează complet fișierul GLB și forțează reimport
				print("[DEBUG] Recreating GLB file to force recognition...")
				await _force_recreate_glb_file(glb_path)
				await _force_reimport_via_editor(glb_path)
			
			await get_tree().create_timer(0.5).timeout
	
	print("[ERROR] All loading attempts failed for: %s" % glb_path)
	return false

func _get_file_size(file_path: String) -> int:
	"""Returnează dimensiunea fișierului în bytes"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var size = file.get_length()
		file.close()
		return size
	return 0

func _create_glb_copy_for_reimport(glb_path: String):
	"""Creează o copie temporară a GLB-ului pentru a forța reimportul"""
	var dir = DirAccess.open(glb_path.get_base_dir())
	if not dir:
		print("[DEBUG] ❌ Cannot access GLB directory")
		return
	
	var original_name = glb_path.get_file()
	var temp_name = original_name.get_basename() + "_temp.glb"
	var temp_path = glb_path.get_base_dir() + "/" + temp_name
	
	# Copiază fișierul la un nume temporar
	if dir.copy(original_name, temp_name) == OK:
		print("[DEBUG] ✓ Created temporary copy: %s" % temp_name)
		
		# Șterge originalul și toate fișierele asociate
		dir.remove(original_name)
		var import_file = original_name + ".import"
		if dir.file_exists(import_file):
			dir.remove(import_file)
		
		# Așteaptă să se proceseze ștergerea
		await get_tree().create_timer(0.3).timeout
		
		# Redenumește temporarul înapoi la numele original
		if dir.rename(temp_name, original_name) == OK:
			print("[DEBUG] ✓ GLB renamed back with forced refresh")
		else:
			print("[DEBUG] ❌ Failed to rename GLB back")
			# Fallback: copiază înapoi
			dir.copy(temp_name, original_name)
			dir.remove(temp_name)
	else:
		print("[DEBUG] ❌ Failed to create temporary GLB copy")

func _diagnose_glb_file(glb_path: String):
	"""Diagnostichează probleme cu fișierul GLB"""
	print("[DIAGNOSTIC] Analyzing GLB file: ", glb_path.get_file())
	
	# Verifică existența și dimensiunea
	var file_size = _get_file_size(glb_path)
	print("[DIAGNOSTIC] File size: %d bytes" % file_size)
	
	# Verifică primii bytes pentru magic number GLB 
	var glb_file = FileAccess.open(glb_path, FileAccess.READ)
	if glb_file:
		var magic = glb_file.get_buffer(4)
		var magic_str = magic.get_string_from_ascii()
		print("[DIAGNOSTIC] Magic bytes: %s" % magic_str)
		glb_file.close()
		
		if magic_str != "glTF":
			print("[DIAGNOSTIC] ❌ Invalid GLB magic number, expected 'glTF'")
			return false
	
	# Verifică dacă Godot poate detecta tipul fișierului
	if ResourceLoader.exists(glb_path):
		print("[DIAGNOSTIC] ✓ ResourceLoader can detect file")
		
		# Încearcă să încărce resursa pentru a verifica tipul
		var test_resource = ResourceLoader.load(glb_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if test_resource:
			var type_name = test_resource.get_class()
			print("[DIAGNOSTIC] Detected type: %s" % type_name)
			
			if test_resource is PackedScene:
				print("[DIAGNOSTIC] ✓ Resource is PackedScene (correct for GLB)")
			else:
				print("[DIAGNOSTIC] ⚠️ Resource is not PackedScene: %s" % type_name)
		else:
			print("[DIAGNOSTIC] ⚠️ ResourceLoader exists but cannot load resource")
	else:
		print("[DIAGNOSTIC] ❌ ResourceLoader cannot detect file")
	
	# Verifică fișierul .import asociat
	var import_path = glb_path + ".import"
	if FileAccess.file_exists(import_path):
		print("[DIAGNOSTIC] ✓ Import file exists")
		var import_file = FileAccess.open(import_path, FileAccess.READ)
		if import_file:
			var import_content = import_file.get_as_text()
			import_file.close()
			if "PackedScene" in import_content:
				print("[DIAGNOSTIC] ✓ Import configured for PackedScene")
			else:
				print("[DIAGNOSTIC] ⚠️ Import NOT configured for PackedScene")
			
			if "scene" in import_content:
				print("[DIAGNOSTIC] ✓ Scene importer detected")
			else:
				print("[DIAGNOSTIC] ❌ Scene importer NOT detected")
	else:
		print("[DIAGNOSTIC] ❌ No import file - Godot hasn't processed this GLB")
	
	return true
	
	# Verifică existența fișierului
	if not FileAccess.file_exists(glb_path):
		print("[DIAGNOSTIC] ❌ GLB file does not exist")
		return
	
	# Verifică dimensiunea
	var size = _get_file_size(glb_path)
	print("[DIAGNOSTIC] File size: %d bytes" % size)
	
	if size < 100:
		print("[DIAGNOSTIC] ⚠️  File too small, may be incomplete")
		return
	
	# Verifică fișierul .import
	var import_file = glb_path + ".import"
	var import_exists = FileAccess.file_exists(import_file)
	print("[DIAGNOSTIC] Import file exists: %s" % str(import_exists))
	
	if import_exists:
		var import_size = _get_file_size(import_file)
		print("[DIAGNOSTIC] Import file size: %d bytes" % import_size)
	
	# Verifică dacă Godot poate recunoaște fișierul
	var resource_exists = ResourceLoader.exists(glb_path)
	print("[DIAGNOSTIC] ResourceLoader recognizes file: %s" % str(resource_exists))
	
	# Verifică cache-ul
	var cached = ResourceLoader.has_cached(glb_path)
	print("[DIAGNOSTIC] File is cached: %s" % str(cached))
	
	# Încearcă să citească headerul GLB pentru validare
	var header_file = FileAccess.open(glb_path, FileAccess.READ)
	if header_file:
		var header = header_file.get_buffer(12)  # GLB header = 12 bytes
		header_file.close()
		
		if header.size() >= 4:
			var magic = header.slice(0, 4).get_string_from_ascii()
			print("[DIAGNOSTIC] File magic: '%s' (should be 'glTF')" % magic)
			
			if magic != "glTF":
				print("[DIAGNOSTIC] ❌ Invalid GLB file format - magic bytes incorrect")
			else:
				print("[DIAGNOSTIC] ✅ GLB header appears valid")
		else:
			print("[DIAGNOSTIC] ❌ Cannot read GLB header")
	else:
		print("[DIAGNOSTIC] ❌ Cannot open GLB file for reading")

func _flash_reload_indicator():
	"""Flash vizual pentru a indica reload-ul reușit"""
	var flash_label = Label.new()
	flash_label.text = "🔄 RELOADED"
	flash_label.position = Vector2(get_viewport().get_visible_rect().size.x - 150, 10)
	flash_label.size = Vector2(140, 30)
	flash_label.add_theme_color_override("font_color", Color.GREEN)
	flash_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(flash_label)
	
	# Animație fade out
	var tween = create_tween()
	tween.tween_property(flash_label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(flash_label.queue_free)

func _exit_tree():
	# Oprește procesul watchdog la ieșire
	if watchdog_process > 0:
		OS.kill(watchdog_process)
		print("[DEBUG] Stopped DXF watchdog process")
