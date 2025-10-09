# CADViewer.gd (versiunea îmbunătățită cu snap)
extends Node3D

# IMMEDIATE DEBUG - This should print as soon as script loads
func _init():
	print("🚨 CAD_VIEWER_3D.GD SCRIPT LOADED! _init() called")

@onready var camera: Camera3D = $Camera3D
@onready var canvas: CanvasLayer = $CanvasLayer

# Grid & background
@export var grid_spacing: float = 1.0
@export var grid_color: Color = Color(0.8,0.8,0.8,0.3)
@export var background_color: Color = Color(0.95,0.95,0.95)

# Infinite Grid settings
var grid_visible: bool = true
var grid_z_position: float = 0.0
var infinite_grid: MeshInstance3D
var grid_material: StandardMaterial3D



# Snap settings
var snap_enabled: bool = false
var snap_distance: float = 0.5
var snap_preview_marker: MeshInstance3D

# Zoom, Pan, Orbit
@export var zoom_speed: float = 1.05  # Zoom mai puțin sensibil (5% în loc de 10%)
@export var max_orthogonal_size: float = 10000.0  # Limite pentru zoom out extrem
@export var min_orthogonal_size: float = 0.1      # Limite pentru zoom in extrem
var pan_last_pos: Vector2
var is_panning := false
var rotate_last_pos: Vector2
var is_rotating := false
var orbit_pivot: Vector3 = Vector3.ZERO

# UI elements
var coord_label: Label

# Grid UI controls
var grid_controls_panel: Panel
var grid_visible_checkbox: CheckBox
var grid_z_slider: HSlider
var grid_z_label: Label

var selected_geometry: Node3D = null
var default_material: StandardMaterial3D = null
var layer_materials := {}

# Dictionary to track all imported projects (filename -> layer_groups)
var imported_projects := {}

# Current project folder pentru ReloadBtn
var current_project_folder: String = ""

# === CUT SHADER SECTION SYSTEM ===
var cut_shader_integration: Node3D = null
var section_planes_data: Array = []
var current_section_state: Dictionary = {}

# Section visibility and control variables
var horizontal_section_enabled: bool = false
var vertical_section_enabled: bool = false
var horizontal_section_z: float = 1.0
var horizontal_section_depth: float = 0.5
var vertical_section_x: float = 0.0
var vertical_section_y: float = 0.0
var vertical_section_depth: float = 0.5

# Section UI controls
var section_controls_panel: Panel
var h_section_checkbox: CheckBox
var v_section_checkbox: CheckBox
var h_section_slider: HSlider
var h_depth_slider: HSlider
var v_section_x_slider: HSlider
var v_section_y_slider: HSlider
var v_depth_slider: HSlider

# Section effects
var section_material: StandardMaterial3D
var section_shader: Shader

# Section planes for visualization
var section_plane_horizontal: MeshInstance3D
var section_plane_vertical_x: MeshInstance3D
var section_plane_vertical_y: MeshInstance3D

# Additional UI controls for sections
var vertical_section_toggle: CheckBox

# Drawing plane and depth control variables
var drawing_plane_z: float = 0.0
var z_min: float = -2.0
var z_max: float = 5.0

func _ready():
	print("🚨🚨🚨 CAD_VIEWER_3D.GD _ready() FUNCTION STARTED! 🚨🚨🚨")
	print("=== CAD VIEWER 3D - SCENE STARTUP DEBUG ===")
	print("[DEBUG] _ready() called - initializing scene...")
	print("[DEBUG] Grid settings - visible:", grid_visible, "z_position:", grid_z_position, "spacing:", grid_spacing)
	
	# Adaugă o lumină direcțională pentru evidențierea voidurilor
	var dir_light = DirectionalLight3D.new()
	dir_light.light_color = Color(1, 1, 0.95)

	dir_light.shadow_enabled = true
	dir_light.shadow_bias = 0.05

	dir_light.transform.origin = Vector3(0, 10, 10)
	add_child(dir_light)
	print("[DEBUG] DirectionalLight3D added")
	if canvas == null:
		var cl = CanvasLayer.new()
		add_child(cl)
		canvas = cl

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
	print("[DEBUG] Camera set to top view")

	var env = Environment.new()
	env.background_color = background_color
	env.background_mode = Environment.BG_COLOR
	camera.environment = env
	print("[DEBUG] Environment configured with background color:", background_color)

	print("[DEBUG] Creating infinite grid...")
	_create_infinite_grid()
	print("[DEBUG] Creating center lines...")
	_create_center_lines(50)
	print("[DEBUG] Setting up UI buttons...")
	_setup_ui_buttons()
	print("[DEBUG] Setting up coordinate label...")
	_setup_coordinate_label()
	print("[DEBUG] Setting up grid controls...")
	_setup_grid_controls()
	print("[DEBUG] Updating camera clipping...")
	_update_camera_clipping()
	print("[DEBUG] Creating snap preview marker...")
	_create_snap_preview_marker()
	print("=== CAD VIEWER 3D - SCENE STARTUP COMPLETE ===")
	print("[DEBUG] Final grid state - infinite_grid node:", infinite_grid != null, "visible:", infinite_grid.visible if infinite_grid else "N/A")
	
	# Integrare Export IFC Button
	var export_ifc_btn = $CanvasLayer/ExportIfcBtn if has_node("CanvasLayer/ExportIfcBtn") else null
	if export_ifc_btn:
		export_ifc_btn.pressed.connect(_on_export_ifc_btn_pressed)

	print("[DEBUG] 🔥🔥🔥 READY TO MOVE TO UI INTEGRATION SECTION 🔥🔥🔥")
	print("[DEBUG] *** STEP 9: Moving to UI integration section ***")
	
	# DEBUGGING CRITICAL: Salvează în fișier pentru a vedea dacă se ajunge aici
	var debug_file = FileAccess.open("user://debug_ready_log.txt", FileAccess.WRITE)
	if debug_file:
		debug_file.store_line("STEP 9: UI integration section reached at " + str(Time.get_unix_time_from_system()))
		debug_file.close()
	
	# Conectează semnale pentru Tree (Objects)
	print("[DEBUG] *** STEP 10: Connecting Tree signals ***")
	var tree_node = get_node_or_null("Objects")
	if tree_node:
		tree_node.connect("item_selected", Callable(self, "_on_tree_item_selected"))
		tree_node.connect("item_edited", Callable(self, "_on_tree_item_edited"))
		print("[DEBUG] ✓ Tree signals connected")
	else:
		print("[DEBUG] ✗ Tree node not found")

	print("[DEBUG] *** STEP 11: Starting UI integration ***")
	# Integrare LoadDxfBtn
	print("[DEBUG] *** SEARCHING FOR LoadDxfBtn ***")
	
	# DEBUGGING CRITICAL: Salvează în fișier progresul
	var debug_file2 = FileAccess.open("user://debug_ready_log.txt", FileAccess.WRITE_READ)
	if debug_file2:
		debug_file2.seek_end()
		debug_file2.store_line("STEP 11: Searching for LoadDxfBtn at " + str(Time.get_unix_time_from_system()))
		debug_file2.close()
	
	var load_btn = $CanvasLayer/LoadDxfBtn if has_node("CanvasLayer/LoadDxfBtn") else null
	if load_btn:
		print("[DEBUG] ✓ LoadDxfBtn found, connecting...")
		load_btn.pressed.connect(_on_load_dxf_btn_pressed)
		print("[DEBUG] ✓ LoadDxfBtn connected successfully")
	else:
		print("[ERROR] ✗ LoadDxfBtn NOT FOUND!")
	
	# Conectează FileDialog-ul existent din scenă
	print("[DEBUG] *** SEARCHING FOR DxfFolderDialog ***")
	print("[DEBUG] Checking path: CanvasLayer/DxfFolderDialog")
	print("[DEBUG] has_node result:", has_node("CanvasLayer/DxfFolderDialog"))
	
	# DEBUGGING CRITICAL: Salvează în fișier progresul
	var debug_file3 = FileAccess.open("user://debug_ready_log.txt", FileAccess.WRITE_READ)
	if debug_file3:
		debug_file3.seek_end()
		debug_file3.store_line("STEP 12: Searching for DxfFolderDialog - has_node result: " + str(has_node("CanvasLayer/DxfFolderDialog")) + " at " + str(Time.get_unix_time_from_system()))
		debug_file3.close()
	var file_dialog = $CanvasLayer/DxfFolderDialog if has_node("CanvasLayer/DxfFolderDialog") else null
	if file_dialog:
		print("[DEBUG] FileDialog found during initialization!")
		print("[DEBUG] FileDialog class:", file_dialog.get_class())
		print("[DEBUG] FileDialog file_mode:", file_dialog.file_mode)
		print("[DEBUG] FileDialog access:", file_dialog.access)
		
		# Listează toate semnalele disponibile
		print("[DEBUG] Available signals:")
		var signal_list = file_dialog.get_signal_list()
		for signal_info in signal_list:
			print("[DEBUG] - Signal:", signal_info.name)
		
		# În Godot 4, pentru FILE_MODE_OPEN_DIR, semnalul poate fi diferit
		if file_dialog.has_signal("dir_selected"):
			file_dialog.dir_selected.connect(Callable(self, "_on_dxf_folder_selected"))
			print("[DEBUG] FileDialog dir_selected connected successfully")
		elif file_dialog.has_signal("files_selected"):
			file_dialog.files_selected.connect(Callable(self, "_on_dxf_files_selected"))
			print("[DEBUG] FileDialog files_selected connected successfully")
		elif file_dialog.has_signal("file_selected"):
			file_dialog.file_selected.connect(Callable(self, "_on_dxf_file_selected"))
			print("[DEBUG] FileDialog file_selected connected successfully")
		else:
			print("[ERROR] No suitable signal found on FileDialog")
		
		# Debug info despre FileDialog
		print("[DEBUG] FileDialog file_mode:", file_dialog.file_mode)
		print("[DEBUG] FileDialog access:", file_dialog.access)
		print("[DEBUG] Available signals:", file_dialog.get_signal_list())
	else:
		print("[ERROR] DxfFolderDialog not found in scene!")
	
	print("[DEBUG] *** STEP 12: FileDialog section completed ***")
	
	# Integrare ReloadBtn
	print("[DEBUG] *** STEP 13: Searching for ReloadBtn ***")
	var reload_btn = $CanvasLayer/ReloadBtn if has_node("CanvasLayer/ReloadBtn") else null
	if reload_btn:
		reload_btn.pressed.connect(_on_reload_btn_pressed)
	
	# Integrare Cut Shader System
	_setup_cut_shader_integration()
	
	print("[DEBUG] *** ALL INITIALIZATION COMPLETE - SETTING UP WATCHDOG ***")
	# Watchdog pentru monitorizarea automată a fișierelor DXF (la sfârșit să nu blocheze inițializarea)
	_setup_dxf_watchdog()

# === DXF to GLB batch import ===
func _on_load_dxf_btn_pressed():
	print("[DEBUG] *** LOAD DXF BUTTON PRESSED ***")
	print("[DEBUG] 🔥 BUTTON CLICK CONFIRMED - FUNCTION IS WORKING! 🔥")
	
	# Salvează în fișier pentru debugging
	var debug_file = FileAccess.open("user://button_press_log.txt", FileAccess.WRITE)
	if debug_file:
		debug_file.store_line("Button pressed at: " + str(Time.get_unix_time_from_system()))
		debug_file.close()
	
	print("[DEBUG] Checking for FileDialog...")
	
	var file_dialog = $CanvasLayer/DxfFolderDialog if has_node("CanvasLayer/DxfFolderDialog") else null
	if file_dialog:
		print("[DEBUG] FileDialog found!")
		print("[DEBUG] FileDialog type:", file_dialog.get_class())
		print("[DEBUG] FileDialog file_mode:", file_dialog.file_mode)
		print("[DEBUG] FileDialog access:", file_dialog.access)
		print("[DEBUG] FileDialog current_dir:", file_dialog.current_dir)
		
		# Verifică conexiunile de semnal
		var connections = file_dialog.get_signal_connection_list("dir_selected")
		print("[DEBUG] dir_selected connections:", connections.size())
		for connection in connections:
			print("[DEBUG] - Connected to:", connection.callable.get_object(), "method:", connection.callable.get_method())
		
		# TEST RUNTIME: Forțează reconnectarea semnalului
		if connections.size() == 0:
			print("[DEBUG] Nu există conexiuni - conectez semnalul în runtime...")
			file_dialog.dir_selected.connect(Callable(self, "_on_dxf_folder_selected"))
			print("[DEBUG] Semnal conectat cu succes în runtime!")
		else:
			print("[DEBUG] Există", connections.size(), "conexiuni existente")
		
		# Verifică din nou după reconnectare
		connections = file_dialog.get_signal_connection_list("dir_selected")
		print("[DEBUG] dir_selected connections DUPĂ reconnectare:", connections.size())
		
		# BACKUP: Conectează și alte semnale pentru debugging
		if not file_dialog.file_selected.is_connected(_on_backup_file_selected):
			file_dialog.file_selected.connect(_on_backup_file_selected)
			print("[DEBUG] Conectat backup semnal file_selected")
		
		if not file_dialog.files_selected.is_connected(_on_backup_files_selected):
			file_dialog.files_selected.connect(_on_backup_files_selected)
			print("[DEBUG] Conectat backup semnal files_selected")
		
		print("[DEBUG] Opening FileDialog popup...")
		file_dialog.popup_centered(Vector2i(800, 600))
		print("[DEBUG] FileDialog should be visible now")
	else:
		print("[ERROR] DxfFolderDialog not found!")
		print("[DEBUG] Available CanvasLayer children:")
		if has_node("CanvasLayer"):
			var canvas = $CanvasLayer
			for child in canvas.get_children():
				print("[DEBUG] - Child:", child.name, "type:", child.get_class())
		push_error("DxfFolderDialog not found!")

func _on_dxf_folder_selected(dir_path):
	print("[DEBUG] *** _on_dxf_folder_selected CALLED ***")
	print("[DEBUG] Folder selectat:", dir_path)
	print("[DEBUG] Folder exists:", DirAccess.open(dir_path) != null)
	
	# Salvează folderul curent pentru reload
	current_project_folder = dir_path
	
	# Verifică conținutul folderului
	var dir = DirAccess.open(dir_path)
	if dir:
		var dxf_count = 0
		var glb_count = 0
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.to_lower().ends_with(".dxf"):
				dxf_count += 1
			elif file_name.to_lower().ends_with(".glb"):
				glb_count += 1
			file_name = dir.get_next()
		dir.list_dir_end()
		print("[DEBUG] Found in folder - DXF files:", dxf_count, " GLB files:", glb_count)
	
	_process_dxf_folder(dir_path)

# Funcții alternative pentru diferite semnale de FileDialog
func _on_dxf_files_selected(files: PackedStringArray):
	print("[DEBUG] *** _on_dxf_files_selected CALLED ***")
	print("[DEBUG] Files selected:", files)
	if files.size() > 0:
		var dir_path = files[0].get_base_dir()
		print("[DEBUG] Extracted directory:", dir_path)
		_on_dxf_folder_selected(dir_path)

func _on_dxf_file_selected(file_path: String):
	print("[DEBUG] *** _on_dxf_file_selected CALLED ***")
	print("[DEBUG] File selected:", file_path)
	var dir_path = file_path.get_base_dir()
	print("[DEBUG] Extracted directory:", dir_path)
	_on_dxf_folder_selected(dir_path)

# Funcții de backup pentru debugging FileDialog
func _on_backup_file_selected(file_path: String):
	print("[DEBUG] *** BACKUP _on_backup_file_selected CALLED ***")
	print("[DEBUG] Backup file selected:", file_path)
	var dir_path = file_path.get_base_dir()
	print("[DEBUG] Redirecting to folder processing:", dir_path)
	_on_dxf_folder_selected(dir_path)

func _on_backup_files_selected(files: PackedStringArray):
	print("[DEBUG] *** BACKUP _on_backup_files_selected CALLED ***")
	print("[DEBUG] Backup files selected:", files.size(), "files")
	if files.size() > 0:
		var dir_path = files[0].get_base_dir()
		print("[DEBUG] Redirecting to folder processing:", dir_path)
		_on_dxf_folder_selected(dir_path)

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
	print("[DEBUG] *** _process_dxf_folder STARTED ***")
	print("[DEBUG] Processing folder:", dir_path)
	
	var dir = DirAccess.open(dir_path)
	if not dir:
		print("[ERROR] Could not open directory:", dir_path)
		return
	
	print("[DEBUG] Directory opened successfully")
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var glb_paths = []
	var dxf_files_found = []
	
	while file_name != "":
		if not dir.current_is_dir():
			print("[DEBUG] Found file:", file_name)
			if file_name.to_lower().ends_with(".dxf"):
				dxf_files_found.append(file_name)
				var dxf_path = dir_path + "/" + file_name
				var glb_path = dir_path + "/" + file_name.get_basename() + ".glb"
				print("[DEBUG] Will convert:", dxf_path, " -> ", glb_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	print("[DEBUG] Found", dxf_files_found.size(), "DXF files:", dxf_files_found)
	
	# Procesează fiecare fișier DXF
	for dxf_file in dxf_files_found:
		var dxf_path = dir_path + "/" + dxf_file
		var glb_path = dir_path + "/" + dxf_file.get_basename() + ".glb"
		
		print("[DEBUG] Converting:", dxf_path, "->", glb_path)
		var exit_code = _run_python_dxf_to_glb(dxf_path, glb_path)
		print("[DEBUG] Conversion exit code:", exit_code)
		
		if FileAccess.file_exists(glb_path):
			print("[DEBUG] GLB file created successfully:", glb_path)
			glb_paths.append(glb_path)
		else:
			print("[ERROR] GLB file not created:", glb_path)
	
	print("[DEBUG] Total GLB files to load:", glb_paths.size())
	if glb_paths.size() > 0:
		print("[DEBUG] Starting GLB loading...")
		_load_glb_meshes(glb_paths)
	else:
		print("[WARNING] No GLB files to load")

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

func _load_mapping_metadata_for_glb(glb_path: String, scene_root: Node3D):
	"""Încarcă metadata din fișierul de mapping și o atașează la mesh-uri pentru export IFC"""
	var mapping_path = glb_path.get_basename() + "_mapping.json"
	
	if not FileAccess.file_exists(mapping_path):
		print("[DEBUG] No mapping file found for metadata: ", mapping_path)
		return
	
	var mapping_file = FileAccess.open(mapping_path, FileAccess.READ)
	if not mapping_file:
		print("[ERROR] Cannot open mapping file for metadata: ", mapping_path)
		return
	
	var json_str = mapping_file.get_as_text()
	mapping_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_str)
	if parse_result != OK:
		print("[ERROR] Failed to parse mapping JSON for metadata: ", mapping_path)
		return
	
	var mapping_data = json.data
	if typeof(mapping_data) != TYPE_ARRAY:
		print("[ERROR] Invalid mapping data format for metadata")
		return
	
	print("[DEBUG] Loading metadata from mapping for %d entries" % mapping_data.size())
	
	# Creează un dicționar pentru căutare rapidă după mesh_name
	var mapping_by_name = {}
	for entry in mapping_data:
		if typeof(entry) == TYPE_DICTIONARY:
			var mesh_name = entry.get("mesh_name", "")
			if mesh_name != "":
				mapping_by_name[mesh_name] = entry
	
	# Aplică metadata la toate mesh-urile din scenă
	_apply_metadata_recursive(scene_root, mapping_by_name)

func _apply_metadata_recursive(node: Node, mapping_by_name: Dictionary):
	"""Aplică recursiv metadata la mesh-uri din mapping"""
	if node is MeshInstance3D:
		var mesh_name = str(node.name)
		
		# Caută în mapping după numele exact
		if mapping_by_name.has(mesh_name):
			var entry = mapping_by_name[mesh_name]
			_apply_metadata_to_mesh(node, entry)
		else:
			# Încearcă căutare parțială pentru mesh-uri cu nume modificate
			for key in mapping_by_name.keys():
				if mesh_name in key or key in mesh_name:
					var entry = mapping_by_name[key]
					_apply_metadata_to_mesh(node, entry)
					break
	
	# Recursiv în copii
	for child in node.get_children():
		_apply_metadata_recursive(child, mapping_by_name)

func _apply_metadata_to_mesh(mesh_node: MeshInstance3D, mapping_entry: Dictionary):
	"""Aplică metadata din mapping la un mesh"""
	# Metadata de bază
	mesh_node.set_meta("uuid", mapping_entry.get("uuid", ""))
	mesh_node.set_meta("layer", mapping_entry.get("layer", "default"))
	mesh_node.set_meta("mesh_name", mapping_entry.get("mesh_name", ""))
	
	# Proprietăți geometrice pentru IfcSpace
	var layer = mapping_entry.get("layer", "")
	if layer == "IfcSpace":
		mesh_node.set_meta("area", mapping_entry.get("area", 0.0))
		mesh_node.set_meta("perimeter", mapping_entry.get("perimeter", 0.0))
		mesh_node.set_meta("lateral_area", mapping_entry.get("lateral_area", 0.0))
		mesh_node.set_meta("volume", mapping_entry.get("volume", 0.0))
		mesh_node.set_meta("height", mapping_entry.get("height", 2.8))
		mesh_node.set_meta("vertices", mapping_entry.get("vertices", []))
		
		print("[DEBUG] Applied IfcSpace metadata to: %s | Area: %.2f | Volume: %.3f | UUID: %s" % [
			mapping_entry.get("mesh_name", ""),
			mapping_entry.get("area", 0.0),
			mapping_entry.get("volume", 0.0),
			mapping_entry.get("uuid", "")
		])

# Debug: Recursiv, afișează numele meshurilor și culoarea vertex principal (dacă există)
func _print_meshes_and_colors(node: Node, glb_path: String):

	if node is MeshInstance3D and node.mesh:
		var mesh_name = str(node.name)  # Convert StringName to String
		var mesh = node.mesh
		var color_str = "-"
		var layer_name = "default"
		
		# Extrage layer-ul din numele encodat (format: MeshName_LAYER_LayerName)
		var actual_layer = "default"
		if "_LAYER_" in mesh_name:
			var parts = mesh_name.split("_LAYER_")
			if parts.size() >= 2:
				actual_layer = parts[1]  # Layer-ul real din encoding
				print("[DEBUG] Detected encoded layer: %s from mesh: %s" % [actual_layer, mesh_name])
		else:
			# Fallback la metoda veche (prima parte până la _)
			if mesh_name.find("_") > 0:
				actual_layer = mesh_name.split("_")[0]
		
		# Verifică dacă mesh-ul are deja un material valid din GLB
		var existing_material = null
		var should_use_glb_material = false
		var material_source = "none"
		
		# Încearcă să găsească materialul din GLB în diferite locuri
		if node.mesh and node.mesh.get_surface_count() > 0:
			existing_material = node.mesh.surface_get_material(0)  # Material din mesh
			if existing_material != null:
				material_source = "mesh_surface"
		
		if existing_material == null and node.get_surface_count() > 0:
			existing_material = node.get_surface_override_material(0)  # Material override
			if existing_material != null:
				material_source = "surface_override"
		
		# De asemenea, verifică dacă există material override deja setat
		if existing_material == null and node.material_override != null:
			existing_material = node.material_override
			material_source = "material_override"
		
		print("[DEBUG] Material search for %s: source=%s, material=%s" % [mesh_name, material_source, existing_material])
		
		if existing_material != null:
			# Verifică dacă materialul din GLB are un nume care indică encoding-ul nostru
			var mat_name = existing_material.resource_name if existing_material else ""
			
			# Încearcă și numele materialului dacă resource_name nu există
			if mat_name == "" and existing_material.has_method("get_name"):
				mat_name = existing_material.get_name()
			
			print("[DEBUG] Found material name: '%s' (begins with Material_: %s)" % [mat_name, str(mat_name.begins_with("Material_"))])
			
			if mat_name != "" and mat_name.begins_with("Material_"):
				print("[DEBUG] ✓ Found GLB material with encoding: %s" % mat_name)
				should_use_glb_material = true
				
				# Încearcă să acceseze culoarea din material
				if existing_material is StandardMaterial3D:
					var std_mat = existing_material as StandardMaterial3D
					color_str = str(std_mat.albedo_color)
					print("[DEBUG] GLB StandardMaterial3D color: %s" % color_str)
				else:
					color_str = "GLB_Material(%s)" % existing_material.get_class()
					print("[DEBUG] GLB material type: %s" % existing_material.get_class())
			else:
				print("[DEBUG] ✗ Material name doesn't match encoding pattern: '%s'" % mat_name)
		
		# Doar suprascrie materialul dacă nu există unul valid din GLB
		if not should_use_glb_material:
			# Mapare insensibilă la majuscule/minuscule și fallback la 'default'
			var found_layer = ""
			for k in layer_materials.keys():
				if k.to_lower() == actual_layer.to_lower():
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
			print("[DEBUG] SCENE LOAD (Override): %s | Mesh: %s | Layer: %s->%s | Alpha: %.2f | Color: %s" % [glb_path, mesh_name, actual_layer, found_layer, lconf["alpha"], color_str])
		else:
			print("[DEBUG] SCENE LOAD (GLB Material): %s | Mesh: %s | Layer: %s | Material: %s | Color: %s | Preserved from GLB" % [glb_path, mesh_name, actual_layer, existing_material.resource_name if existing_material else "Unknown", color_str])
		
		# Setează layer_name pentru structura de date
		layer_name = actual_layer

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
	set_section_for_view("top")

func _set_front_view():
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.transform.origin = Vector3(0,-10,0)
	camera.look_at(Vector3(0,0,0), Vector3(0,0,1))
	set_section_for_view("front")

func _set_left_view():
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.transform.origin = Vector3(-10,0,0)
	camera.look_at(Vector3(0,0,0), Vector3(0,0,1))
	set_section_for_view("left")

func _set_right_view():
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.transform.origin = Vector3(10,0,0)
	camera.look_at(Vector3(0,0,0), Vector3(0,0,1))
	set_section_for_view("right")

func _set_back_view():
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.transform.origin = Vector3(0,10,0)
	camera.look_at(Vector3(0,0,0), Vector3(0,0,1))
	set_section_for_view("back")

func _set_free_view():
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 60
	camera.transform.origin = Vector3(10,10,10)
	camera.look_at(Vector3(0,0,0), Vector3(0,0,1))
	set_section_for_view("free")

func _on_fit_all_pressed():
	"""Încadrează toate obiectele în camera curentă"""
	var bbox = _calculate_scene_bounding_box()
	if bbox.has_volume():
		_fit_camera_to_bbox(bbox)
		print("[CADViewer] Fit All: fitted to bbox ", bbox)
	else:
		print("[CADViewer] Fit All: no objects found or invalid bbox")

func _calculate_scene_bounding_box() -> AABB:
	"""Calculează bounding box-ul întregii scene"""
	var combined_bbox = AABB()
	var first_object = true
	
	# Parcurge toate copiii pentru a găsi MeshInstance3D
	for child in get_children():
		if child is MeshInstance3D:
			var mesh_instance = child as MeshInstance3D
			if mesh_instance.mesh != null:
				var mesh_bbox = mesh_instance.get_aabb()
				# Transformă bbox-ul în spațiul global
				mesh_bbox = mesh_instance.transform * mesh_bbox
				
				if first_object:
					combined_bbox = mesh_bbox
					first_object = false
				else:
					combined_bbox = combined_bbox.merge(mesh_bbox)
	
	return combined_bbox

func _fit_camera_to_bbox(bbox: AABB):
	"""Pozitionează camera pentru a încadra bbox-ul"""
	var bbox_center = bbox.get_center()
	var bbox_size = bbox.size
	
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		# Pentru camera ortogonală, calculează dimensiunea necesară
		var max_extent = max(bbox_size.x, max(bbox_size.y, bbox_size.z))
		camera.size = max_extent * 1.2  # 20% padding
		
		# Păstrează direcția curentă a camerei, dar centrează pe bbox
		var current_forward = -camera.transform.basis.z
		var distance = max_extent * 2.0  # Distanța optimă
		camera.transform.origin = bbox_center - current_forward * distance
		camera.look_at(bbox_center, Vector3.UP)
		
	else:
		# Pentru camera perspective
		var max_extent = bbox_size.length()
		var distance = max_extent * 1.5  # Distanța pentru perspective
		
		var current_forward = -camera.transform.basis.z
		camera.transform.origin = bbox_center - current_forward * distance
		camera.look_at(bbox_center, Vector3.UP)






# Grid creation
func _create_infinite_grid():
	"""Creează un grid infinit cu linii vizibile"""
	print("[GRID_DEBUG] Starting infinite grid creation...")
	print("[GRID_DEBUG] Grid parameters - size: 500, spacing:", grid_spacing, "z_position:", grid_z_position, "visible:", grid_visible)
	print("[GRID_DEBUG] Grid color:", grid_color)
	
	# Creează liniile grid-ului într-un mod dinamic și mare
	var grid_vertices = PackedVector3Array()
	var grid_colors = PackedColorArray()
	
	# Grid foarte mare pentru efectul "infinit"
	var grid_size = 500  # Mult mai mare decât înainte
	var spacing = grid_spacing
	
	# Linii pe X (paralele cu axa X)
	for i in range(-grid_size, grid_size + 1):
		grid_vertices.append(Vector3(-grid_size * spacing, i * spacing, grid_z_position))
		grid_vertices.append(Vector3(grid_size * spacing, i * spacing, grid_z_position))
		grid_colors.append(grid_color)
		grid_colors.append(grid_color)
	
	# Liniile pe Y (paralele cu axa Y) 
	for i in range(-grid_size, grid_size + 1):
		grid_vertices.append(Vector3(i * spacing, -grid_size * spacing, grid_z_position))
		grid_vertices.append(Vector3(i * spacing, grid_size * spacing, grid_z_position))
		grid_colors.append(grid_color)
		grid_colors.append(grid_color)
	
	# Creează mesh-ul
	var grid_arrays = []
	grid_arrays.resize(Mesh.ARRAY_MAX)
	grid_arrays[Mesh.ARRAY_VERTEX] = grid_vertices
	grid_arrays[Mesh.ARRAY_COLOR] = grid_colors
	var grid_mesh = ArrayMesh.new()
	grid_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, grid_arrays)
	
	# Creează material transparent
	grid_material = StandardMaterial3D.new()
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.vertex_color_use_as_albedo = true
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.no_depth_test = false
	grid_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	
	# Creează instanța
	infinite_grid = MeshInstance3D.new()
	infinite_grid.mesh = grid_mesh
	infinite_grid.material_override = grid_material
	infinite_grid.position.z = grid_z_position
	infinite_grid.visible = grid_visible
	add_child(infinite_grid)
	
	print("[GRID_DEBUG] Infinite grid MeshInstance3D created successfully!")
	print("[GRID_DEBUG] Grid stats: ", grid_vertices.size() / 2, " lines, mesh surfaces:", grid_mesh.get_surface_count())
	print("[GRID_DEBUG] Grid position:", infinite_grid.position)
	print("[GRID_DEBUG] Grid visible:", infinite_grid.visible)
	print("[GRID_DEBUG] Grid material transparency:", grid_material.transparency)
	print("[GRID_DEBUG] Grid added to scene tree as child of:", get_name())
	print("[CADViewer] Infinite grid created with ", grid_vertices.size() / 2, " lines at Z=", grid_z_position)

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

	# === HOTKEYS ===
	# F - Fit All (Frame All objects)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F:  # Fit All (Frame All)
				_on_fit_all_pressed()

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
	_update_camera_clipping()
	_update_drawing_plane_visual()



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
	# Pentru grid infinit, doar actualizăm poziția Z
	if infinite_grid:
		infinite_grid.position.z = grid_z_position

func _clear_grid_and_axes():
	for child in get_children():
		if child is MeshInstance3D and child != camera and child != snap_preview_marker and child != infinite_grid:
			child.queue_free()

func _update_coordinate_display():
	var world_pos = get_mouse_pos_in_xy()
	coord_label.text = "X: %.2f, Y: %.2f, Z: %.2f" % [world_pos.x, world_pos.y, grid_z_position]

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
	print("[DEBUG] === POPULATING TREE WITH PROJECTS ===")
	print("[DEBUG] Projects structure: ", projects.keys())
	
	var tree_node = get_node_or_null("Objects")
	if tree_node == null:
		print("[ERROR] Nu există nodul Objects de tip Tree în scenă!")
		return
		
	print("[DEBUG] Tree node found successfully: ", tree_node)
	tree_node.clear()
	tree_node.set_columns(2)
	var root = tree_node.create_item()
	tree_node.set_column_title(0, "GLB File / IfcType / Element")
	tree_node.set_column_title(1, "Visible")
	tree_node.set_column_titles_visible(true)
	
	print("[DEBUG] Tree setup complete, columns: ", tree_node.columns)

	for file_name in projects.keys():
		print("[DEBUG] Creating file item: ", file_name)
		var file_item = tree_node.create_item(root)
		file_item.set_text(0, file_name)
		file_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
		file_item.set_checked(1, true)
		file_item.set_editable(1, true)
		var file_metadata = {"type": "file", "file": file_name}
		file_item.set_metadata(0, file_metadata)
		print("[DEBUG] File item created with metadata: ", file_metadata)

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
	print("[DEBUG] Tree item edited triggered!")
	
	var tree_node = get_node_or_null("Objects")
	if not tree_node:
		print("[ERROR] Tree node 'Objects' not found!")
		return
		
	var edited = tree_node.get_edited()
	if not edited:
		print("[ERROR] No edited item found!")
		return
		
	var meta = edited.get_metadata(0)
	if typeof(meta) != TYPE_DICTIONARY:
		print("[ERROR] Invalid metadata type: ", typeof(meta))
		return
		
	var checked = edited.is_checked(1)
	print("[DEBUG] Item edited: ", edited.get_text(0), " | Checked: ", checked, " | Type: ", meta.get("type", "unknown"))
	
	if meta.has("type"):
		match meta["type"]:
			"file":
				print("[DEBUG] Setting visibility for file: ", meta["file"], " to ", checked)
				_set_visibility_file(meta["file"], checked)
			"group":
				print("[DEBUG] Setting visibility for group: ", meta["group"], " in file: ", meta["file"], " to ", checked)
				_set_visibility_group(meta["file"], meta["group"], checked)
			"element":
				print("[DEBUG] Setting visibility for element: ", meta["element"], " in group: ", meta["group"], " file: ", meta["file"], " to ", checked)
				_set_visibility_element(meta["file"], meta["group"], meta["element"], checked)
	else:
		print("[ERROR] No 'type' in metadata: ", meta)

func _set_visibility_file(file, visible):
	print("[DEBUG] _set_visibility_file called for file: '%s', visible: %s" % [file, visible])
	print("[DEBUG] imported_projects has file: ", imported_projects.has(file))
	print("[DEBUG] Available files in imported_projects: ", imported_projects.keys())
	
	if imported_projects.has(file):
		print("[DEBUG] Processing groups in file '%s': %s" % [file, imported_projects[file].keys()])
		for group in imported_projects[file].keys():
			_set_visibility_group(file, group, visible)
	else:
		print("[ERROR] File '%s' not found in imported_projects!" % file)

func _set_visibility_group(file, group, visible):
	print("[DEBUG] _set_visibility_group called for group: '%s' in file: '%s', visible: %s" % [group, file, visible])
	
	if imported_projects.has(file) and imported_projects[file].has(group):
		print("[DEBUG] Processing elements in group '%s': %s" % [group, imported_projects[file][group].keys()])
		for elem in imported_projects[file][group].keys():
			_set_visibility_element(file, group, elem, visible)
	else:
		print("[ERROR] Group '%s' not found in file '%s'!" % [group, file])
		if imported_projects.has(file):
			print("[DEBUG] Available groups in file: ", imported_projects[file].keys())

func _set_visibility_element(file, group, elem, visible):
	if imported_projects.has(file) and imported_projects[file].has(group) and imported_projects[file][group].has(elem):
		var node = imported_projects[file][group][elem]
		if node:
			node.visible = visible
			print("[DEBUG] Set visibility for element '%s' to %s (node: %s)" % [elem, visible, node.name])
		else:
			print("[ERROR] Node is null for element: %s in group: %s, file: %s" % [elem, group, file])
	else:
		print("[ERROR] Path not found in imported_projects: file=%s, group=%s, elem=%s" % [file, group, elem])
		print("[DEBUG] Available files: ", imported_projects.keys())
		if imported_projects.has(file):
			print("[DEBUG] Available groups in file '%s': " % file, imported_projects[file].keys())
			if imported_projects[file].has(group):
				print("[DEBUG] Available elements in group '%s': " % group, imported_projects[file][group].keys())

	
func _setup_ui_buttons():
	print("[UI_DEBUG] Setting up UI buttons...")
	
	# Obține referința la panelul din dreapta din scene
	var right_panel = canvas.get_node_or_null("Panel")
	if not right_panel:
		print("[UI_DEBUG] ERROR: Right panel not found! Creating buttons in canvas instead.")
		right_panel = canvas
	else:
		print("[UI_DEBUG] Right panel found - size:", right_panel.size, "position:", right_panel.position)
	
	# Creează butoane de view preset în panelul din dreapta
	var names = ["TOP","FRONT","LEFT","RIGHT","BACK","FREE 3D"]
	for i in range(len(names)):
		var btn = Button.new()
		btn.text = names[i]
		# Poziționează butoanele în panel (poziții relative la panel)
		btn.position = Vector2(5, 5 + i*25)  # Poziții relative la panel
		btn.size = Vector2(80, 22)  # Butoane mai mici pentru a încăpea în panel
		btn.pressed.connect(Callable(self, "_on_view_button_pressed").bind(names[i]))
		right_panel.add_child(btn)
		print("[UI_DEBUG] Added button:", names[i], "at position:", btn.position)
	
	# Creează butonul Fit All în panelul din dreapta
	var fit_all_btn = Button.new()
	fit_all_btn.text = "FIT ALL"
	fit_all_btn.position = Vector2(5, 5 + len(names)*25)  # Sub ultimul buton
	fit_all_btn.size = Vector2(80, 22)
	fit_all_btn.pressed.connect(Callable(self, "_on_fit_all_pressed"))
	fit_all_btn.add_theme_color_override("font_color", Color.WHITE)
	fit_all_btn.add_theme_color_override("font_color_pressed", Color.WHITE)
	fit_all_btn.modulate = Color(0.2, 0.6, 0.8)  # Culoare albastră
	right_panel.add_child(fit_all_btn)
	print("[UI_DEBUG] Added FIT ALL button at position:", fit_all_btn.position)
	
	print("[UI_DEBUG] UI buttons setup complete - all buttons added to right panel")

func _setup_coordinate_label():
	coord_label = Label.new()
	coord_label.text = "X: 0.0, Y: 0.0, Z: 0.0"
	coord_label.position = Vector2(220, get_viewport().get_visible_rect().size.y - 50)  # Lângă panelul de grid
	coord_label.size = Vector2(300, 30)
	coord_label.add_theme_color_override("font_color", Color.BLACK)
	coord_label.add_theme_font_size_override("font_size", 14)
	canvas.add_child(coord_label)
	print("[UI_DEBUG] Coordinate label positioned next to grid controls panel")

func _setup_grid_controls():
	"""Creează controalele UI pentru grid infinit"""
	print("[UI_DEBUG] Setting up grid controls...")
	print("[UI_DEBUG] Canvas available:", canvas != null)
	print("[UI_DEBUG] Canvas name:", canvas.get_name() if canvas else "N/A")
	
	# Creează panelul de grid controls în partea de jos a ecranului pentru a nu se suprapune
	grid_controls_panel = Panel.new()
	grid_controls_panel.position = Vector2(10, get_viewport().get_visible_rect().size.y - 120)  # Jos în stânga
	grid_controls_panel.size = Vector2(200, 80)
	grid_controls_panel.add_theme_color_override("bg_color", Color(0.9, 0.9, 0.9, 0.8))
	canvas.add_child(grid_controls_panel)
	print("[UI_DEBUG] Grid controls panel created and added to canvas at bottom-left")
	
	# Title
	var title_label = Label.new()
	title_label.text = "Grid Controls"
	title_label.position = Vector2(10, 5)
	title_label.add_theme_color_override("font_color", Color.BLACK)
	title_label.add_theme_font_size_override("font_size", 12)
	grid_controls_panel.add_child(title_label)
	
	# Grid Visibility Checkbox
	grid_visible_checkbox = CheckBox.new()
	grid_visible_checkbox.text = "Show Grid"
	grid_visible_checkbox.position = Vector2(10, 25)
	grid_visible_checkbox.button_pressed = grid_visible
	grid_visible_checkbox.toggled.connect(_on_grid_visibility_toggled)
	grid_controls_panel.add_child(grid_visible_checkbox)
	
	# Grid Z Position Label
	grid_z_label = Label.new()
	grid_z_label.text = "Grid Z: 0.00"
	grid_z_label.position = Vector2(10, 50)
	grid_z_label.add_theme_color_override("font_color", Color.BLACK)
	grid_z_label.add_theme_font_size_override("font_size", 10)
	grid_controls_panel.add_child(grid_z_label)
	
	# Grid Z Position Slider
	grid_z_slider = HSlider.new()
	grid_z_slider.position = Vector2(70, 50)
	grid_z_slider.size = Vector2(120, 20)
	grid_z_slider.min_value = -100.0
	grid_z_slider.max_value = 100.0
	grid_z_slider.step = 0.01
	grid_z_slider.value = grid_z_position
	grid_z_slider.value_changed.connect(_on_grid_z_changed)
	grid_controls_panel.add_child(grid_z_slider)
	
	print("[UI_DEBUG] Grid controls setup complete!")
	print("[UI_DEBUG] - Panel position:", grid_controls_panel.position, "size:", grid_controls_panel.size)
	print("[UI_DEBUG] - Checkbox state:", grid_visible_checkbox.button_pressed)
	print("[UI_DEBUG] - Slider range:", grid_z_slider.min_value, "to", grid_z_slider.max_value, "current:", grid_z_slider.value)
	print("[UI_DEBUG] - Panel children count:", grid_controls_panel.get_child_count())

# === GRID CALLBACKS ===

func _on_grid_visibility_toggled(button_pressed: bool):
	"""Toggle grid visibility"""
	print("[CALLBACK_DEBUG] Grid visibility toggle called - new state:", button_pressed)
	grid_visible = button_pressed
	if infinite_grid:
		infinite_grid.visible = grid_visible
		print("[CALLBACK_DEBUG] Grid visibility updated - infinite_grid.visible:", infinite_grid.visible)
	else:
		print("[CALLBACK_DEBUG] ERROR: infinite_grid is null!")
	print("[CADViewer] Grid visibility: ", grid_visible)

func _on_grid_z_changed(value: float):
	"""Update grid Z position"""
	print("[CALLBACK_DEBUG] Grid Z position changed called - new value:", value)
	grid_z_position = value
	# Recreate grid with new Z position
	if infinite_grid:
		print("[CALLBACK_DEBUG] Freeing old grid instance...")
		infinite_grid.queue_free()
	print("[CALLBACK_DEBUG] Recreating grid at new Z position...")
	_create_infinite_grid()
	# Update label
	if grid_z_label:
		grid_z_label.text = "Grid Z: %.2f" % grid_z_position
		print("[CALLBACK_DEBUG] Label updated to:", grid_z_label.text)
	print("[CADViewer] Grid Z position: ", grid_z_position)
	
	# Horizontal Section Z Position
	var h_z_label = Label.new()
	h_z_label.text = "H-Section Z:"
	h_z_label.position = Vector2(10, 55)
	h_z_label.add_theme_color_override("font_color", Color.BLACK)
	section_controls_panel.add_child(h_z_label)
	
	h_section_slider = HSlider.new()
	h_section_slider.position = Vector2(90, 55)
	h_section_slider.size = Vector2(120, 20)
	h_section_slider.min_value = -10.0
	h_section_slider.max_value = 10.0
	h_section_slider.step = 0.1
	h_section_slider.value = horizontal_section_z
	h_section_slider.value_changed.connect(_on_horizontal_section_z_changed)
	section_controls_panel.add_child(h_section_slider)
	
	# Horizontal Section Depth
	var h_depth_label = Label.new()
	h_depth_label.text = "H-Depth:"
	h_depth_label.position = Vector2(10, 80)
	h_depth_label.add_theme_color_override("font_color", Color.BLACK)
	section_controls_panel.add_child(h_depth_label)
	
	h_depth_slider = HSlider.new()
	h_depth_slider.position = Vector2(90, 80)
	h_depth_slider.size = Vector2(120, 20)
	h_depth_slider.min_value = 0.5
	h_depth_slider.max_value = 10.0
	h_depth_slider.step = 0.1
	h_depth_slider.value = horizontal_section_depth
	h_depth_slider.value_changed.connect(_on_horizontal_depth_changed)
	section_controls_panel.add_child(h_depth_slider)
	
	# Vertical Section Toggle
	vertical_section_toggle = CheckBox.new()
	vertical_section_toggle.text = "Vertical Section"
	vertical_section_toggle.position = Vector2(10, 110)
	vertical_section_toggle.button_pressed = vertical_section_enabled
	vertical_section_toggle.toggled.connect(_on_vertical_section_toggled)
	section_controls_panel.add_child(vertical_section_toggle)
	
	# Vertical Section X Position
	var v_x_label = Label.new()
	v_x_label.text = "V-Section X:"
	v_x_label.position = Vector2(10, 135)
	v_x_label.add_theme_color_override("font_color", Color.BLACK)
	section_controls_panel.add_child(v_x_label)
	
	v_section_x_slider = HSlider.new()
	v_section_x_slider.position = Vector2(90, 135)
	v_section_x_slider.size = Vector2(120, 20)
	v_section_x_slider.min_value = -20.0
	v_section_x_slider.max_value = 20.0
	v_section_x_slider.step = 0.1
	v_section_x_slider.value = vertical_section_x
	v_section_x_slider.value_changed.connect(_on_vertical_section_x_changed)
	section_controls_panel.add_child(v_section_x_slider)
	
	# Vertical Section Y Position
	var v_y_label = Label.new()
	v_y_label.text = "V-Section Y:"
	v_y_label.position = Vector2(10, 160)
	v_y_label.add_theme_color_override("font_color", Color.BLACK)
	section_controls_panel.add_child(v_y_label)
	
	v_section_y_slider = HSlider.new()
	v_section_y_slider.position = Vector2(90, 160)
	v_section_y_slider.size = Vector2(120, 20)
	v_section_y_slider.min_value = -20.0
	v_section_y_slider.max_value = 20.0
	v_section_y_slider.step = 0.1
	v_section_y_slider.value = vertical_section_y
	v_section_y_slider.value_changed.connect(_on_vertical_section_y_changed)
	section_controls_panel.add_child(v_section_y_slider)
	
	# Vertical Section Depth
	var v_depth_label = Label.new()
	v_depth_label.text = "V-Depth:"
	v_depth_label.position = Vector2(10, 185)
	v_depth_label.add_theme_color_override("font_color", Color.BLACK)
	section_controls_panel.add_child(v_depth_label)
	
	v_depth_slider = HSlider.new()
	v_depth_slider.position = Vector2(90, 185)
	v_depth_slider.size = Vector2(120, 20)
	v_depth_slider.min_value = 1.0
	v_depth_slider.max_value = 20.0
	v_depth_slider.step = 0.1
	v_depth_slider.value = vertical_section_depth
	v_depth_slider.value_changed.connect(_on_vertical_depth_changed)
	section_controls_panel.add_child(v_depth_slider)
	
	print("[CADViewer] Section controls setup complete")

func _create_section_planes():
	"""Creează planurile vizuale pentru sectiuni"""
	# Material pentru planurile de sectiune
	section_material = StandardMaterial3D.new()
	section_material.albedo_color = Color(1.0, 0.0, 0.0, 0.3)  # Roșu transparent
	section_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	section_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	section_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Vizibil din ambele părți
	
	# Horizontal section plane (XY)
	section_plane_horizontal = MeshInstance3D.new()
	var plane_mesh_h = PlaneMesh.new()
	plane_mesh_h.size = Vector2(50, 50)  # Dimensiune mare pentru a acoperi scena
	section_plane_horizontal.mesh = plane_mesh_h
	section_plane_horizontal.material_override = section_material
	section_plane_horizontal.visible = false
	add_child(section_plane_horizontal)
	
	# Vertical section plane X (YZ)
	section_plane_vertical_x = MeshInstance3D.new()
	var plane_mesh_vx = PlaneMesh.new()
	plane_mesh_vx.size = Vector2(50, 50)
	section_plane_vertical_x.mesh = plane_mesh_vx
	section_plane_vertical_x.material_override = section_material.duplicate()
	section_plane_vertical_x.material_override.albedo_color = Color(0.0, 1.0, 0.0, 0.3)  # Verde
	section_plane_vertical_x.rotation_degrees = Vector3(0, 0, 90)  # Rotire pentru YZ plane
	section_plane_vertical_x.visible = false
	add_child(section_plane_vertical_x)
	
	# Vertical section plane Y (XZ)
	section_plane_vertical_y = MeshInstance3D.new()
	var plane_mesh_vy = PlaneMesh.new()
	plane_mesh_vy.size = Vector2(50, 50)
	section_plane_vertical_y.mesh = plane_mesh_vy
	section_plane_vertical_y.material_override = section_material.duplicate()
	section_plane_vertical_y.material_override.albedo_color = Color(0.0, 0.0, 1.0, 0.3)  # Albastru
	section_plane_vertical_y.rotation_degrees = Vector3(90, 0, 0)  # Rotire pentru XZ plane
	section_plane_vertical_y.visible = false
	add_child(section_plane_vertical_y)
	
	print("[CADViewer] Section planes created")

# === SECTION CALLBACKS ===

func _on_horizontal_section_toggled(button_pressed: bool):
	"""Toggle horizontal section"""
	horizontal_section_enabled = button_pressed
	section_plane_horizontal.visible = button_pressed
	_update_section_effects()
	print("[CADViewer] Horizontal section: ", button_pressed)

func _on_vertical_section_toggled(button_pressed: bool):
	"""Toggle vertical section"""
	vertical_section_enabled = button_pressed
	section_plane_vertical_x.visible = button_pressed
	section_plane_vertical_y.visible = button_pressed
	_update_section_effects()
	print("[CADViewer] Vertical section: ", button_pressed)

func _on_horizontal_section_z_changed(value: float):
	"""Update horizontal section Z position"""
	horizontal_section_z = value
	section_plane_horizontal.position.z = value
	_update_section_effects()

func _on_horizontal_depth_changed(value: float):
	"""Update horizontal section depth"""
	horizontal_section_depth = value
	_update_section_effects()

func _on_vertical_section_x_changed(value: float):
	"""Update vertical section X position"""
	vertical_section_x = value
	section_plane_vertical_x.position.x = value
	_update_section_effects()

func _on_vertical_section_y_changed(value: float):
	"""Update vertical section Y position"""
	vertical_section_y = value
	section_plane_vertical_y.position.y = value
	_update_section_effects()

func _on_vertical_depth_changed(value: float):
	"""Update vertical section depth"""
	vertical_section_depth = value
	_update_section_effects()

func _update_section_effects():
	"""Aplicare efecte de sectiune la toate obiectele din scenă"""
	_apply_section_to_node(self)

func _apply_section_to_node(node: Node):
	"""Aplică efectele de sectiune recursiv la un nod și copiii săi"""
	# Pentru MeshInstance3D nodes, aplică shader-ul de sectiune
	if node is MeshInstance3D:
		_apply_section_to_mesh(node)
	
	# Continuă recursiv pentru copii
	for child in node.get_children():
		_apply_section_to_node(child)

func _apply_section_to_mesh(mesh_instance: MeshInstance3D):
	"""Aplică efectul de sectiune la un MeshInstance3D"""
	if not mesh_instance.material_override:
		return
	
	var material = mesh_instance.material_override
	if material is StandardMaterial3D:
		var std_material = material as StandardMaterial3D
		
		# Calculează efectul de fade bazat pe distanța de la planurile de sectiune
		var mesh_pos = mesh_instance.global_position
		var fade_factor = 1.0
		
		# Horizontal section fade
		if horizontal_section_enabled:
			var distance_to_h_plane = abs(mesh_pos.z - horizontal_section_z)
			if distance_to_h_plane > horizontal_section_depth / 2.0:
				fade_factor *= 0.3  # Fade out
		
		# Vertical section fade  
		if vertical_section_enabled:
			var distance_to_v_plane_x = abs(mesh_pos.x - vertical_section_x)
			var distance_to_v_plane_y = abs(mesh_pos.y - vertical_section_y)
			
			if distance_to_v_plane_x > vertical_section_depth / 2.0 or distance_to_v_plane_y > vertical_section_depth / 2.0:
				fade_factor *= 0.3  # Fade out
		
		# Aplică fade factor la material
		var original_color = std_material.albedo_color
		std_material.albedo_color = Color(original_color.r, original_color.g, original_color.b, original_color.a * fade_factor)

func _create_snap_preview_marker():
	snap_preview_marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.08
	snap_preview_marker.mesh = sphere
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.MAGENTA
	material.emission_enabled = true
	material.emission = Color.MAGENTA * 0.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
					
					# Adaugă metadata din mapping pentru export IFC
					_load_mapping_metadata_for_glb(glb_path, scene)
					
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
				
				# Adaugă metadata din mapping pentru export IFC
				_load_mapping_metadata_for_glb(glb_path, scene)
				
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
	tween.tween_callback(flash_label.queue_free.bind())

# === IFC Space Export ===
func _on_export_ifc_btn_pressed():
	"""Exportă IfcSpace-urile din scena curentă în format IFC"""
	print("[DEBUG] Starting IFC Space export...")
	
	# Verifică dacă avem IfcSpace-uri în scenă
	var space_nodes = _find_ifcspace_nodes()
	if space_nodes.is_empty():
		print("[WARNING] No IfcSpace elements found in scene")
		_show_export_message("No IfcSpace elements found to export", false)
		return
	
	# Creează folder pentru export dacă nu există
	var export_dir = "exported_ifc"
	if not DirAccess.dir_exists_absolute(export_dir):
		DirAccess.open(".").make_dir(export_dir)
	
	# Generează nume fișier cu timestamp
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var base_name = "spaces_export_" + timestamp
	var godot_data_path = export_dir + "/" + base_name + "_geometry.json"
	var ifc_output_path = export_dir + "/" + base_name + ".ifc"
	
	# Exportă geometria din Godot
	var geometry_data = _extract_space_geometry_data(space_nodes)
	if not _save_json_file(godot_data_path, geometry_data):
		_show_export_message("Failed to save geometry data", false)
		return
	
	# Găsește cel mai recent fișier de mapping
	var mapping_path = _find_latest_mapping_file()
	if mapping_path == "":
		print("[ERROR] No mapping file found. Import a DXF/GLB project first.")
		_show_export_message("No mapping file found. Import a DXF/GLB project first.", false)
		return
	
	# Rulează exportul Python IFC
	var success = _run_python_ifc_export(godot_data_path, mapping_path, ifc_output_path)
	
	if success:
		print("[SUCCESS] IFC export completed: ", ifc_output_path)
		_show_export_message("IFC export completed successfully!\nFile: " + ifc_output_path, true)
	else:
		print("[ERROR] IFC export failed")
		_show_export_message("IFC export failed. Check console for details.", false)

func _find_ifcspace_nodes() -> Array:
	"""Găsește toate nodurile IfcSpace din scenă"""
	var space_nodes = []
	_find_ifcspace_recursive(self, space_nodes)
	print("[DEBUG] Found %d IfcSpace nodes" % space_nodes.size())
	return space_nodes

func _find_ifcspace_recursive(node: Node, space_nodes: Array):
	"""Caută recursiv nodurile IfcSpace"""
	var is_ifcspace = false
	
	# Verifică dacă nodul curent este un MeshInstance3D
	if node is MeshInstance3D:
		# Prioritate 1: Verifică metadata layer
		if node.has_meta("layer"):
			var layer = node.get_meta("layer")
			if layer == "IfcSpace":
				is_ifcspace = true
				print("[DEBUG] Found IfcSpace by metadata: ", node.name)
		
		# Prioritate 2: Verifică numele nodului doar dacă nu a fost găsit prin metadata
		elif "IfcSpace" in str(node.name):
			is_ifcspace = true
			print("[DEBUG] Found IfcSpace by name: ", node.name)
		
		# Adaugă nodul doar o singură dată
		if is_ifcspace:
			# Verifică dacă nodul nu există deja în array (pentru siguranță extra)
			if node not in space_nodes:
				space_nodes.append(node)
			else:
				print("[WARNING] Prevented duplicate IfcSpace node: ", node.name)
	
	# Recursiv în copii
	for child in node.get_children():
		_find_ifcspace_recursive(child, space_nodes)

func _extract_space_geometry_data(space_nodes: Array) -> Dictionary:
	"""Extrage datele geometrice din nodurile IfcSpace și le îmbogățește cu datele din JSON de mapare"""
	var spaces_data = []
	
	# Încarcă datele din fișierul de mapare JSON pentru a obține valorile corecte
	var mapping_data = _load_mapping_data_for_spaces()
	
	for node in space_nodes:
		if not node is MeshInstance3D or not node.mesh:
			continue
			
		var space_data = {}
		space_data["mesh_name"] = str(node.name)
		space_data["uuid"] = node.get_meta("uuid") if node.has_meta("uuid") else ""
		
		# Extrage vertices din mesh pentru geometria 3D
		var vertices = []
		var mesh = node.mesh
		
		if mesh is ArrayMesh and mesh.get_surface_count() > 0:
			var arrays = mesh.surface_get_arrays(0)
			if arrays[Mesh.ARRAY_VERTEX]:
				var vertex_array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				for vertex in vertex_array:
					# Transformă vertex-ul în spațiul world
					var world_vertex = node.to_global(vertex)
					vertices.append([world_vertex.x, world_vertex.y, world_vertex.z])
		
		# Limitează numărul de vertices pentru a evita duplicatele (în general conturul de bază)
		if vertices.size() > 100:
			# Încearcă să extragi doar conturul exterior (primul segment)
			var step = max(1, vertices.size() / 20)  # Max 20 puncte pentru contur
			var simplified_vertices = []
			for i in range(0, vertices.size(), step):
				simplified_vertices.append(vertices[i])
			vertices = simplified_vertices
		
		space_data["vertices"] = vertices
		space_data["vertex_count"] = vertices.size()
		
		# IMPORTANT: Înlocuiește valorile din metadata cu cele corecte din JSON de mapare
		var mapping_entry = _find_mapping_entry_for_space(space_data["uuid"], space_data["mesh_name"], mapping_data)
		if mapping_entry:
			# Folosește valorile calculate corect din JSON (inclusiv Opening_area)
			space_data["height"] = _calculate_space_height_from_xdata(mapping_entry)
			space_data["area"] = float(mapping_entry.get("area", 0.0))
			space_data["volume"] = float(mapping_entry.get("volume", 0.0))
			space_data["perimeter"] = float(mapping_entry.get("perimeter", 0.0))
			space_data["lateral_area"] = float(mapping_entry.get("lateral_area", 0.0))
			
			print("[DEBUG] Enhanced space data from JSON mapping: %s" % space_data["mesh_name"])
			print("  - Area: %.3fm², Perimeter: %.3fm, Lateral Area: %.3fm²" % [space_data["area"], space_data["perimeter"], space_data["lateral_area"]])
			print("  - Volume: %.3fm³, Height: %.3fm, UUID: %s" % [space_data["volume"], space_data["height"], space_data["uuid"]])
		else:
			# Fallback: folosește metadata din Godot dacă nu găsim în JSON
			space_data["height"] = node.get_meta("height") if node.has_meta("height") else 2.8
			space_data["area"] = node.get_meta("area") if node.has_meta("area") else 0.0
			space_data["volume"] = node.get_meta("volume") if node.has_meta("volume") else 0.0
			space_data["perimeter"] = 0.0  # Nu există în metadata Godot
			space_data["lateral_area"] = 0.0  # Nu există în metadata Godot
			
			print("[WARNING] Could not find mapping data for space: %s, using fallback values" % space_data["mesh_name"])
		
		spaces_data.append(space_data)
		print("[DEBUG] Extracted enhanced geometry for space: %s (%d vertices)" % [space_data["mesh_name"], vertices.size()])
	
	return {"spaces": spaces_data, "export_timestamp": Time.get_unix_time_from_system()}

func _load_mapping_data_for_spaces() -> Array:
	"""Încarcă datele din fișierul JSON de mapare pentru spații IfcSpace"""
	var mapping_file = _find_latest_mapping_file()
	if mapping_file.is_empty():
		print("[WARNING] No mapping file found for IFC Space export")
		return []
	
	print("[DEBUG] Loading mapping data from: %s" % mapping_file)
	
	var file = FileAccess.open(mapping_file, FileAccess.READ)
	if not file:
		print("[ERROR] Could not open mapping file: %s" % mapping_file)
		return []
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("[ERROR] Failed to parse JSON mapping file: %s" % json.get_error_message())
		return []
	
	var mapping_data = json.data
	if not mapping_data is Array:
		print("[ERROR] Mapping file does not contain an array")
		return []
	
	# Filtrează doar entitățile IfcSpace
	var space_entries = []
	for entry in mapping_data:
		if entry is Dictionary and entry.get("layer", "") == "IfcSpace":
			space_entries.append(entry)
	
	print("[DEBUG] Found %d IfcSpace entries in mapping file" % space_entries.size())
	return space_entries

func _find_mapping_entry_for_space(uuid: String, mesh_name: String, mapping_data: Array) -> Dictionary:
	"""Găsește intrarea din mapping care corespunde cu spațiul dat"""
	
	# Prioritate 1: Caută după UUID exact
	for entry in mapping_data:
		if entry.get("uuid", "") == uuid and not uuid.is_empty():
			print("[DEBUG] Found mapping entry by UUID: %s" % uuid)
			return entry
	
	# Prioritate 2: Caută după mesh_name exact
	for entry in mapping_data:
		if entry.get("mesh_name", "") == mesh_name and not mesh_name.is_empty():
			print("[DEBUG] Found mapping entry by mesh_name: %s" % mesh_name)
			return entry
	
	# Prioritate 3: Caută după partea de bază a numelui (fără sufixe)
	var base_name = mesh_name.split("_")[0] if "_" in mesh_name else mesh_name
	for entry in mapping_data:
		var entry_base_name = entry.get("mesh_name", "").split("_")[0] if "_" in entry.get("mesh_name", "") else entry.get("mesh_name", "")
		if entry_base_name == base_name and not base_name.is_empty():
			print("[DEBUG] Found mapping entry by base name: %s -> %s" % [base_name, entry.get("mesh_name", "")])
			return entry
	
	print("[WARNING] No mapping entry found for space: UUID=%s, mesh_name=%s" % [uuid, mesh_name])
	return {}

func _calculate_space_height_from_xdata(mapping_entry: Dictionary) -> float:
	"""Calculează înălțimea spațiului din datele XDATA din mapping"""
	
	# Caută în XDATA pentru înălțime
	var xdata = mapping_entry.get("xdata", {})
	if xdata is Dictionary:
		# Caută câmpuri comune pentru înălțime
		for height_field in ["Height", "height", "Space_Height", "floor_height"]:
			if xdata.has(height_field):
				var height_value = xdata[height_field]
				if height_value is String:
					# Dacă este string, încearcă să-l convertești la float
					return float(height_value) if height_value.is_valid_float() else 2.8
				elif height_value is float or height_value is int:
					return float(height_value)
		
		print("[DEBUG] XDATA found but no height field: %s" % str(xdata.keys()))
	
	# Fallback: calculează înălțimea din volum și arie dacă sunt disponibile
	var volume = float(mapping_entry.get("volume", 0.0))
	var area = float(mapping_entry.get("area", 0.0))
	
	if volume > 0.0 and area > 0.0:
		var calculated_height = volume / area
		print("[DEBUG] Calculated height from volume/area: %.3fm (V=%.3f, A=%.3f)" % [calculated_height, volume, area])
		return calculated_height
	
	# Fallback final: înălțime standard
	print("[DEBUG] Using default height: 2.8m")
	return 2.8

func _find_latest_mapping_file() -> String:
	"""Găsește cel mai recent fișier de mapping din folderul curent"""
	var mapping_files = []
	var dir = DirAccess.open(".")
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with("_mapping.json"):
				var full_path = dir.get_current_dir() + "/" + file_name
				var file_time = FileAccess.get_modified_time(full_path)
				mapping_files.append({"path": full_path, "time": file_time})
			file_name = dir.get_next()
		dir.list_dir_end()
	
	if mapping_files.is_empty():
		return ""
	
	# Sortează după timp și returnează cel mai recent
	mapping_files.sort_custom(func(a, b): return a.time > b.time)
	var latest = mapping_files[0]["path"]
	print("[DEBUG] Using mapping file: ", latest)
	return latest

func _save_json_file(file_path: String, data: Dictionary) -> bool:
	"""Salvează datele în format JSON"""
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("[ERROR] Cannot create file: ", file_path)
		return false
	
	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("[DEBUG] Saved geometry data: ", file_path)
	return true

func _run_python_ifc_export(godot_data_path: String, mapping_path: String, ifc_output_path: String) -> bool:
	"""Rulează script-ul Python pentru exportul IFC"""
	var script_path = "python/ifc_space_exporter.py"
	var project_name = "Godot CAD Viewer Spaces"
	
	var args = [script_path, godot_data_path, mapping_path, ifc_output_path, project_name]
	var output = []
	
	print("[DEBUG] Running Python IFC export: python ", args)
	var exit_code = OS.execute("python", args, output, true)
	
	print("[PYTHON IFC OUTPUT] ", output)
	print("[PYTHON IFC EXIT CODE] ", exit_code)
	
	return exit_code == 0

func _show_export_message(message: String, success: bool):
	"""Afișează un mesaj de export în UI"""
	var message_label = Label.new()
	message_label.text = message
	message_label.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 200, 100)
	message_label.size = Vector2(400, 100)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if success:
		message_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		message_label.add_theme_color_override("font_color", Color.RED)
	
	message_label.add_theme_font_size_override("font_size", 14)
	
	# Fundal semi-transparent
	var panel = Panel.new()
	panel.position = message_label.position - Vector2(10, 10)
	panel.size = message_label.size + Vector2(20, 20)
	panel.add_theme_color_override("bg_color", Color(0, 0, 0, 0.7))
	
	canvas.add_child(panel)
	canvas.add_child(message_label)
	
	# Animație fade out după 5 secunde
	var tween = create_tween()
	tween.tween_interval(5.0)  # Schimbat din tween_delay în tween_interval
	tween.tween_property(panel, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(message_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(panel.queue_free.bind())
	tween.tween_callback(message_label.queue_free.bind())

# === CUT SHADER INTEGRATION METHODS ===

func _setup_cut_shader_integration():
	"""Inițializează integrarea sistemului cut shader"""
	print("[CutShader] Setting up cut shader integration...")
	
	# Găsește nodul de integrare cut shader
	cut_shader_integration = get_node_or_null("CutShaderIntegration")
	if cut_shader_integration:
		print("[CutShader] Found cut shader integration node")
		# Conectează semnalele
		if cut_shader_integration.has_signal("section_dxf_exported"):
			cut_shader_integration.section_dxf_exported.connect(_on_cut_shader_dxf_exported)
		if cut_shader_integration.has_signal("cut_shader_preview_updated"):
			cut_shader_integration.cut_shader_preview_updated.connect(_on_cut_shader_preview_updated)
	else:
		print("[CutShader] Cut shader integration node not found")
	
	# Inițializează materialul pentru secțiuni
	_init_section_material()
	
	# Setup section controls în UI
	_setup_section_controls()
	
	print("[CutShader] Cut shader integration setup complete")

func _init_section_material():
	"""Inițializează materialul pentru efectele de secțiune"""
	section_material = StandardMaterial3D.new()
	section_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	section_material.albedo_color = Color(1.0, 0.0, 0.0, 0.3)  # Roșu semi-transparent
	section_material.no_depth_test = false
	section_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func _setup_section_controls():
	"""Creează controalele UI pentru secțiuni"""
	if not canvas:
		print("[CutShader] No canvas found for section controls")
		return
	
	# Creează panelul pentru controalele de secțiune
	section_controls_panel = Panel.new()
	section_controls_panel.name = "SectionControlsPanel"
	section_controls_panel.position = Vector2(10, get_viewport().get_visible_rect().size.y - 200)
	section_controls_panel.size = Vector2(220, 180)
	section_controls_panel.add_theme_color_override("bg_color", Color(0.1, 0.1, 0.2, 0.9))
	canvas.add_child(section_controls_panel)
	
	var y_offset = 10
	
	# Title
	var title = Label.new()
	title.text = "Section Controls"
	title.position = Vector2(10, y_offset)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 12)
	section_controls_panel.add_child(title)
	y_offset += 25
	
	# Horizontal Section
	h_section_checkbox = CheckBox.new()
	h_section_checkbox.text = "Horizontal Section"
	h_section_checkbox.position = Vector2(10, y_offset)
	h_section_checkbox.button_pressed = horizontal_section_enabled
	h_section_checkbox.toggled.connect(_on_horizontal_section_toggled)
	section_controls_panel.add_child(h_section_checkbox)
	y_offset += 25
	
	# Horizontal Section Z Position
	var h_z_label = Label.new()
	h_z_label.text = "H-Section Z:"
	h_z_label.position = Vector2(10, y_offset)
	h_z_label.add_theme_color_override("font_color", Color.WHITE)
	section_controls_panel.add_child(h_z_label)
	
	h_section_slider = HSlider.new()
	h_section_slider.position = Vector2(90, y_offset)
	h_section_slider.size = Vector2(120, 20)
	h_section_slider.min_value = -10.0
	h_section_slider.max_value = 10.0
	h_section_slider.step = 0.1
	h_section_slider.value = horizontal_section_z
	h_section_slider.value_changed.connect(_on_horizontal_section_z_changed)
	section_controls_panel.add_child(h_section_slider)
	y_offset += 25
	
	# Horizontal Section Depth
	var h_depth_label = Label.new()
	h_depth_label.text = "H-Depth:"
	h_depth_label.position = Vector2(10, y_offset)
	h_depth_label.add_theme_color_override("font_color", Color.WHITE)
	section_controls_panel.add_child(h_depth_label)
	
	h_depth_slider = HSlider.new()
	h_depth_slider.position = Vector2(90, y_offset)
	h_depth_slider.size = Vector2(120, 20)
	h_depth_slider.min_value = 0.1
	h_depth_slider.max_value = 5.0
	h_depth_slider.step = 0.1
	h_depth_slider.value = horizontal_section_depth
	h_depth_slider.value_changed.connect(_on_horizontal_depth_changed)
	section_controls_panel.add_child(h_depth_slider)
	y_offset += 30
	
	# Vertical Section
	v_section_checkbox = CheckBox.new()
	v_section_checkbox.text = "Vertical Section"
	v_section_checkbox.position = Vector2(10, y_offset)
	v_section_checkbox.button_pressed = vertical_section_enabled
	v_section_checkbox.toggled.connect(_on_vertical_section_toggled)
	section_controls_panel.add_child(v_section_checkbox)
	y_offset += 25
	
	# Cut Shader Export Button
	var export_btn = Button.new()
	export_btn.text = "Export Cut Shader DXF"
	export_btn.position = Vector2(10, y_offset)
	export_btn.size = Vector2(200, 25)
	export_btn.pressed.connect(_export_cut_shader_dxf)
	section_controls_panel.add_child(export_btn)

func _get_current_section_data() -> Dictionary:
	"""Returnează datele curente ale secțiunilor pentru integrarea cut shader"""
	var section_data = {}
	
	if horizontal_section_enabled:
		section_data["horizontal"] = {
			"origin": Vector3(0, 0, horizontal_section_z),
			"normal": Vector3(0, 0, 1),
			"enabled": true,
			"depth_range": [horizontal_section_z - horizontal_section_depth/2, 
							horizontal_section_z + horizontal_section_depth/2]
		}
	
	if vertical_section_enabled:
		section_data["vertical"] = {
			"origin": Vector3(vertical_section_x, vertical_section_y, 0),
			"normal": Vector3(1, 0, 0),  # sau Vector3(0, 1, 0) pentru vertical Y
			"enabled": true,
			"depth_range": [vertical_section_x - vertical_section_depth/2,
							vertical_section_x + vertical_section_depth/2]
		}
	
	# Adaugă informații despre camera pentru secțiuni dinamice
	if camera:
		var cam_pos = camera.global_transform.origin
		var cam_forward = -camera.global_transform.basis.z
		
		section_data["camera_section"] = {
			"origin": cam_pos,
			"normal": cam_forward,
			"enabled": true,
			"depth_range": [0.0, 3.0]
		}
	
	return section_data

func _export_cut_shader_dxf():
	"""Exportă secțiunea curentă folosind sistemul cut shader"""
	if not cut_shader_integration:
		print("[CutShader] Cut shader integration not available")
		return
	
	print("[CutShader] Initiating cut shader DXF export...")
	
	# Actualizează datele de secțiune
	current_section_state = _get_current_section_data()
	
	# Apelează sistemul cut shader pentru export
	if cut_shader_integration.has_method("_export_dxf_section"):
		cut_shader_integration._export_dxf_section()
	else:
		print("[CutShader] Export method not found in cut shader integration")

func _on_cut_shader_dxf_exported(file_path: String):
	"""Handler pentru semnalul de export DXF completat"""
	print("[CutShader] DXF export completed: ", file_path)
	
	# Afișează mesaj de succes
	var message = "Cut Shader DXF exported successfully!\nFile: " + file_path.get_file()
	_show_export_message(message, true)

func _on_cut_shader_preview_updated(preview_data: Dictionary):
	"""Handler pentru actualizarea preview-ului cut shader"""
	print("[CutShader] Preview updated: ", preview_data)
	
	# Aici poți adăuga logica pentru afișarea preview-ului în viewer
	# De exemplu, overlay-uri sau highlight-uri pe mesh-uri

func set_section_for_view(view_name: String):
	"""Setează parametrii de secțiune bazați pe view-ul curent"""
	match view_name:
		"top":
			horizontal_section_enabled = true
			horizontal_section_z = 1.5  # Secțiune standard la înălțimea camerei
			_update_section_ui()
		"front", "back":
			vertical_section_enabled = true
			vertical_section_y = 0.0
			_update_section_ui()
		"left", "right":
			vertical_section_enabled = true
			vertical_section_x = 0.0
			_update_section_ui()
		"free":
			# În view-ul liber, folosește poziția camerei pentru secțiuni dinamice
			_update_dynamic_sections()

func _update_section_ui():
	"""Actualizează UI-ul pentru a reflecta starea curentă a secțiunilor"""
	if h_section_checkbox:
		h_section_checkbox.button_pressed = horizontal_section_enabled
	if h_section_slider:
		h_section_slider.value = horizontal_section_z
	if h_depth_slider:
		h_depth_slider.value = horizontal_section_depth
	if v_section_checkbox:
		v_section_checkbox.button_pressed = vertical_section_enabled

func _update_dynamic_sections():
	"""Actualizează secțiunile dinamice bazate pe poziția camerei"""
	if camera and cut_shader_integration:
		var cam_pos = camera.global_transform.origin
		var cam_forward = -camera.global_transform.basis.z
		
		# Actualizează secțiunea bazată pe camera
		horizontal_section_z = cam_pos.z
		
		# Sincronizează cu sistemul cut shader
		if cut_shader_integration.has_method("_sync_with_existing_sections"):
			cut_shader_integration._sync_with_existing_sections()

# === FUNCȚII UTILITARE LIPSĂ ===

func _update_info_label():
	"""Actualizează label-ul cu informații despre starea curentă"""
	if coord_label:
		var info_text = "Z-Min: %.2f | Z-Max: %.2f | Drawing Plane: %.2f" % [z_min, z_max, drawing_plane_z]
		coord_label.text = info_text

func _update_z_spinboxes():
	"""Actualizează controalele UI pentru Z-depth"""
	# Această funcție ar trebui să actualizeze SpinBox-urile pentru z_min, z_max și drawing_plane_z
	# Dacă controalele UI există, le actualizează cu valorile curente
	print("[DEBUG] Z-spinboxes updated: z_min=%.2f, z_max=%.2f, drawing_plane_z=%.2f" % [z_min, z_max, drawing_plane_z])



func _exit_tree():
	# Oprește procesul watchdog la ieșire
	if watchdog_process > 0:
		OS.kill(watchdog_process)
		print("[DEBUG] Stopped DXF watchdog process")
