# LayoutManager.gd - Sistem de management layout-uri CAD
extends Control

# === PAPER SIZES (în milimetri, convertite la pixeli la 300 DPI) ===
const PAPER_SIZES = {
	"A4_PORTRAIT": Vector2(2480, 3508),    # 210 x 297 mm
	"A4_LANDSCAPE": Vector2(3508, 2480),   # 297 x 210 mm
	"A3_PORTRAIT": Vector2(3508, 4961),    # 297 x 420 mm
	"A3_LANDSCAPE": Vector2(4961, 3508),   # 420 x 297 mm
	"A2_PORTRAIT": Vector2(4961, 7016),    # 420 x 594 mm
	"A2_LANDSCAPE": Vector2(7016, 4961),   # 594 x 420 mm
}

# === CONFIGURAȚII LAYOUT ===
@export var paper_size: String = "A3_LANDSCAPE"
@export var title: String = "Layout Plan"
@export var sheet_number: String = "A101"
@export var drawing_scale: String = "1:100"
@export var show_grid: bool = true

# === PROJECT INTEGRATION ===
var project_folder: String = "python/dxf/"  # Calea implicită către proiect
var available_models: Array[String] = []
var project_tree_data: Dictionary = {}

# === VIEWPORT MANAGEMENT ===
var viewport_containers: Array[Control] = []
var cad_viewers: Array[Node] = []

# === PREDEFINED CAMERA VIEWS ===
enum CameraView {
	TOP,
	FRONT, 
	BACK,
	LEFT,
	RIGHT,
	ISOMETRIC,
	CUSTOM
}

# === CAMERA CONFIGURATIONS ===
const CAMERA_CONFIGS = {
	CameraView.TOP: {
		"position": Vector3(0, 10, 0),
		"rotation": Vector3(-90, 0, 0),
		"projection": "orthogonal",
		"name": "Plan View"
	},
	CameraView.FRONT: {
		"position": Vector3(0, 0, 10),
		"rotation": Vector3(0, 0, 0),
		"projection": "orthogonal", 
		"name": "Front Elevation"
	},
	CameraView.BACK: {
		"position": Vector3(0, 0, -10),
		"rotation": Vector3(0, 180, 0),
		"projection": "orthogonal",
		"name": "Back Elevation"
	},
	CameraView.LEFT: {
		"position": Vector3(-10, 0, 0),
		"rotation": Vector3(0, -90, 0),
		"projection": "orthogonal",
		"name": "Left Elevation"
	},
	CameraView.RIGHT: {
		"position": Vector3(10, 0, 0),
		"rotation": Vector3(0, 90, 0),
		"projection": "orthogonal",
		"name": "Right Elevation"
	},
	CameraView.ISOMETRIC: {
		"position": Vector3(7, 7, 7),
		"rotation": Vector3(-30, 45, 0),
		"projection": "perspective",
		"name": "3D Isometric"
	}
}

func _ready():
	print("[LayoutManager] Initializing layout system...")
	setup_paper_size()
	setup_title_block()
	
	# Încarcă proiectul din folderul implicit
	load_project_folder(project_folder)

func setup_paper_size():
	"""Configurează dimensiunea foii și aspectul general"""
	if paper_size in PAPER_SIZES:
		var size = PAPER_SIZES[paper_size]
		
		# Scalează pentru afișare pe ecran (factor de 0.3 pentru A3)
		var display_scale = 0.25
		var display_size = size * display_scale
		
		set_custom_minimum_size(display_size)
		size = display_size
		
		print("[LayoutManager] Paper size set to " + paper_size + ": " + str(display_size))
		
		# Setează background-ul
		var bg = $Background
		if bg:
			bg.size = display_size
			bg.color = Color.WHITE

func setup_title_block():
	"""Creează title block-ul în colțul din dreapta jos"""
	var title_block = $TitleBlock
	if not title_block:
		return
		
	# Șterge conținutul existent
	for child in title_block.get_children():
		child.queue_free()
	
	# Creează border pentru title block
	var border = ColorRect.new()
	border.color = Color.TRANSPARENT
	border.size = title_block.size
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_block.add_child(border)
	
	# Adaugă text pentru title
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.position = Vector2(10, 10)
	title_block.add_child(title_label)
	
	# Adaugă sheet number
	var sheet_label = Label.new()
	sheet_label.text = "Sheet: " + sheet_number
	sheet_label.add_theme_font_size_override("font_size", 12)
	sheet_label.position = Vector2(10, 35)
	title_block.add_child(sheet_label)
	
	# Adaugă scale
	var scale_label = Label.new()
	scale_label.text = "Scale: " + drawing_scale
	scale_label.add_theme_font_size_override("font_size", 12)
	scale_label.position = Vector2(10, 55)
	title_block.add_child(scale_label)

func add_viewport(position: Vector2, size: Vector2, camera_view: CameraView, glb_path: String = "") -> Control:
	"""Adaugă un nou viewport 3D cu camera configurată"""
	print("[LayoutManager] Adding viewport at " + str(position) + " with size " + str(size))
	
	# Creează container pentru viewport
	var container = Control.new()
	container.position = position
	container.size = size
	container.name = "Viewport_" + str(len(viewport_containers))
	
	# Adaugă border pentru viewport
	var border = ColorRect.new()
	border.color = Color.TRANSPARENT
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.add_theme_stylebox_override("panel", create_border_style())
	container.add_child(border)
	
	# Creează SubViewport pentru rendering 3D
	var sub_viewport = SubViewport.new()
	sub_viewport.size = size
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(sub_viewport)
	
	# Creează camera 3D
	var camera = Camera3D.new()
	setup_camera(camera, camera_view)
	sub_viewport.add_child(camera)
	
	# Încarcă model GLB dacă este specificat
	if glb_path != "":
		load_glb_model(sub_viewport, glb_path)
	else:
		# Creează o scenă test
		create_test_scene(sub_viewport)
	
	# Adaugă label pentru viewport
	var label = Label.new()
	label.text = CAMERA_CONFIGS[camera_view]["name"]
	label.position = Vector2(5, 5)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.BLACK)
	container.add_child(label)
	
	# Adaugă la layout
	$ViewportContainer.add_child(container)
	viewport_containers.append(container)
	
	return container

func setup_camera(camera: Camera3D, view: CameraView):
	"""Configurează camera conform view-ului specificat"""
	var config = CAMERA_CONFIGS[view]
	
	camera.position = config["position"]
	camera.rotation_degrees = config["rotation"]
	
	# Setează proiecția
	if config["projection"] == "orthogonal":
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 20.0  # Dimensiune vizualizare ortogonală
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 45.0

func load_glb_model(viewport: SubViewport, glb_path: String):
	"""Încarcă un model GLB în viewport"""
	if not FileAccess.file_exists(glb_path):
		print("[LayoutManager] GLB file not found: " + glb_path)
		create_test_scene(viewport)
		return
	
	# Încarcă GLB
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var error = gltf.append_from_file(glb_path, state)
	
	if error == OK:
		var scene = gltf.generate_scene(state)
		if scene:
			viewport.add_child(scene)
			print("[LayoutManager] Loaded GLB: " + glb_path)
		else:
			print("[LayoutManager] Failed to generate scene from GLB")
			create_test_scene(viewport)
	else:
		print("[LayoutManager] Error loading GLB: " + str(error))
		create_test_scene(viewport)

func create_test_scene(viewport: SubViewport):
	"""Creează o scenă test cu geometrie simplă"""
	# Adaugă o lumină
	var light = DirectionalLight3D.new()
	light.position = Vector3(5, 5, 5)
	light.rotation_degrees = Vector3(-45, -45, 0)
	viewport.add_child(light)
	
	# Creează câteva primitive pentru test
	create_test_box(viewport, Vector3(0, 0, 0), Vector3(2, 2, 2), Color.RED)
	create_test_box(viewport, Vector3(3, 0, 0), Vector3(1, 3, 1), Color.GREEN)
	create_test_box(viewport, Vector3(-3, 0, 0), Vector3(1, 1, 4), Color.BLUE)

func create_test_box(viewport: SubViewport, pos: Vector3, size: Vector3, color: Color):
	"""Creează o cutie test cu culoare specificată"""
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = pos
	
	# Creează material colorat
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	
	viewport.add_child(mesh_instance)

func create_border_style() -> StyleBox:
	"""Creează stil pentru border-ul viewport-urilor"""
	var style = StyleBoxFlat.new()
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color.BLACK
	style.bg_color = Color.TRANSPARENT
	return style

# === PROJECT MANAGEMENT ===

func load_project_folder(folder_path: String):
	"""Încarcă toate modelele GLB din folderul de proiect"""
	project_folder = folder_path
	available_models.clear()
	project_tree_data.clear()
	
	print("[LayoutManager] Loading project from: " + folder_path)
	
	# Caută toate fișierele GLB din folder
	var dir = DirAccess.open("res://" + folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".glb"):
				var glb_path = "res://" + folder_path + file_name
				available_models.append(glb_path)
				
				# Încarcă și mapping-ul JSON dacă există
				var json_path = "res://" + folder_path + file_name.replace(".glb", "_mapping.json")
				if FileAccess.file_exists(json_path):
					load_mapping_data(glb_path, json_path)
				
				print("[LayoutManager] Found model: " + file_name)
			file_name = dir.get_next()
	else:
		print("[LayoutManager] Could not access project folder: " + folder_path)

func load_mapping_data(glb_path: String, json_path: String):
	"""Încarcă datele de mapping pentru un model GLB"""
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			project_tree_data[glb_path] = json.data
			print("[LayoutManager] Loaded mapping data for: " + glb_path)
		else:
			print("[LayoutManager] Error parsing JSON: " + json_path)

func get_available_models() -> Array[String]:
	"""Returnează lista de modele disponibile în proiect"""
	return available_models

func get_model_tree_data(glb_path: String) -> Dictionary:
	"""Returnează datele de tree pentru un model specific"""
	return project_tree_data.get(glb_path, {})

# === VIEWPORT EDITABILITY ===

var viewport_edit_states: Dictionary = {}  # viewport_id -> bool (locked/unlocked)

func set_viewport_editable(viewport: Control, editable: bool):
	"""Setează dacă un viewport este editabil sau blocat"""
	var viewport_id = viewport.name
	viewport_edit_states[viewport_id] = editable
	
	# Actualizează vizualul viewport-ului
	update_viewport_visual_state(viewport, editable)
	
	print("[LayoutManager] Viewport " + viewport_id + " set to: " + ("EDITABLE" if editable else "LOCKED"))

func update_viewport_visual_state(viewport: Control, editable: bool):
	"""Actualizează aspectul vizual al viewport-ului în funcție de stare"""
	# Găsește border-ul viewport-ului
	for child in viewport.get_children():
		if child is ColorRect:
			var border = child as ColorRect
			if editable:
				# Border verde pentru editabil
				var style = StyleBoxFlat.new()
				style.border_width_left = 3
				style.border_width_right = 3
				style.border_width_top = 3
				style.border_width_bottom = 3
				style.border_color = Color.GREEN
				style.bg_color = Color.TRANSPARENT
				border.add_theme_stylebox_override("panel", style)
			else:
				# Border roșu pentru blocat
				var style = StyleBoxFlat.new()
				style.border_width_left = 2
				style.border_width_right = 2
				style.border_width_top = 2
				style.border_width_bottom = 2
				style.border_color = Color.RED
				style.bg_color = Color.TRANSPARENT
				border.add_theme_stylebox_override("panel", style)
			break

func is_viewport_editable(viewport: Control) -> bool:
	"""Verifică dacă un viewport este editabil"""
	var viewport_id = viewport.name
	return viewport_edit_states.get(viewport_id, true)  # Default: editabil

# === ENHANCED VIEWPORT MANAGEMENT ===

func add_project_viewport(position: Vector2, size: Vector2, camera_view: CameraView, model_index: int = 0) -> Control:
	"""Adaugă un viewport cu model din proiect și controale de editare"""
	var model_path = ""
	if model_index < available_models.size():
		model_path = available_models[model_index]
	
	var viewport = add_viewport(position, size, camera_view, model_path)
	
	# Adaugă controale pentru editare/blocare
	add_viewport_controls(viewport)
	
	# Setează ca editabil inițial
	set_viewport_editable(viewport, true)
	
	return viewport

func add_viewport_controls(viewport: Control):
	"""Adaugă controale pentru editare viewport (pozitionare, blocare)"""
	# Adaugă buton de lock/unlock
	var lock_btn = Button.new()
	lock_btn.text = "🔓"
	lock_btn.size = Vector2(30, 30)
	lock_btn.position = Vector2(viewport.size.x - 35, 5)
	lock_btn.pressed.connect(_on_viewport_lock_toggle.bind(viewport, lock_btn))
	viewport.add_child(lock_btn)
	
	# Adaugă buton pentru tree viewer
	var tree_btn = Button.new()
	tree_btn.text = "🌳"
	tree_btn.size = Vector2(30, 30)
	tree_btn.position = Vector2(viewport.size.x - 70, 5)
	tree_btn.pressed.connect(_on_viewport_tree_toggle.bind(viewport))
	viewport.add_child(tree_btn)
	
	# Adaugă handle pentru redimensionare (colț dreapta jos)
	var resize_handle = Button.new()
	resize_handle.text = "⤡"
	resize_handle.size = Vector2(20, 20)
	resize_handle.position = Vector2(viewport.size.x - 25, viewport.size.y - 25)
	resize_handle.modulate = Color(0.7, 0.7, 0.7, 0.8)
	viewport.add_child(resize_handle)
	
	# Fă viewport-ul draggable când este editabil
	setup_viewport_dragging(viewport)

func _on_viewport_lock_toggle(viewport: Control, lock_btn: Button):
	"""Toggle între starea locked/unlocked a viewport-ului"""
	var is_editable = is_viewport_editable(viewport)
	set_viewport_editable(viewport, not is_editable)
	
	# Actualizează textul butonului
	lock_btn.text = "🔒" if not is_editable else "🔓"

func _on_viewport_tree_toggle(viewport: Control):
	"""Deschide/închide tree-ul de obiecte pentru viewport"""
	var viewport_id = viewport.name
	
	# Verifică dacă există deja un tree pentru acest viewport
	var existing_tree = viewport.get_node_or_null("ObjectTree")
	
	if existing_tree:
		# Închide tree-ul existent
		existing_tree.queue_free()
		print("[LayoutManager] Closed object tree for " + viewport_id)
	else:
		# Creează un nou tree
		create_viewport_object_tree(viewport)
		print("[LayoutManager] Opened object tree for " + viewport_id)

func create_viewport_object_tree(viewport: Control):
	"""Creează un tree de obiecte pentru viewport"""
	# Găsește SubViewport-ul
	var sub_viewport = null
	for child in viewport.get_children():
		if child is SubViewport:
			sub_viewport = child
			break
	
	if not sub_viewport:
		return
	
	# Creează panelul pentru tree
	var tree_panel = Panel.new()
	tree_panel.name = "ObjectTree"
	tree_panel.size = Vector2(200, viewport.size.y - 40)
	tree_panel.position = Vector2(viewport.size.x - 205, 35)
	tree_panel.modulate = Color(1, 1, 1, 0.9)
	
	# Creează tree-ul
	var tree = Tree.new()
	tree.size = Vector2(190, viewport.size.y - 50)
	tree.position = Vector2(5, 5)
	tree.columns = 1
	tree.column_titles_visible = true
	tree.set_column_title(0, "Objects")
	
	# Populează tree-ul cu obiectele din viewport
	populate_viewport_tree(tree, sub_viewport)
	
	# Conectează semnalele pentru selecție
	tree.item_selected.connect(_on_tree_item_selected.bind(sub_viewport))
	
	tree_panel.add_child(tree)
	viewport.add_child(tree_panel)

func populate_viewport_tree(tree: Tree, sub_viewport: SubViewport):
	"""Populează tree-ul cu obiectele din viewport"""
	tree.clear()
	var root = tree.create_item()
	root.set_text(0, "Scene")
	
	# Parcurge toate obiectele din SubViewport
	for child in sub_viewport.get_children():
		if child.name != "Camera3D":  # Exclude camera
			add_node_to_tree(tree, root, child)

func add_node_to_tree(tree: Tree, parent_item: TreeItem, node: Node):
	"""Adaugă un nod și copiii săi în tree"""
	var item = tree.create_item(parent_item)
	item.set_text(0, node.name + " (" + node.get_class() + ")")
	item.set_metadata(0, node)
	
	# Adaugă copiii recursiv
	for child in node.get_children():
		add_node_to_tree(tree, item, child)

func _on_tree_item_selected(sub_viewport: SubViewport):
	"""Callback pentru selecția unui item din tree"""
	# TODO: Implementează highlight/focus pe obiectul selectat
	print("[LayoutManager] Tree item selected in viewport")

func setup_viewport_dragging(viewport: Control):
	"""Configurează dragging pentru viewport când este editabil"""
	# TODO: Implementează sistem de drag & drop pentru viewport-uri
	pass

# === PUBLIC API ===

func set_paper_size(new_size: String):
	"""Schimbă dimensiunea foii"""
	paper_size = new_size
	setup_paper_size()

func add_cad_viewport(pos: Vector2, size: Vector2, view: CameraView, model_path: String = "") -> Control:
	"""API public pentru adăugarea viewport-urilor CAD"""
	return add_viewport(pos, size, view, model_path)

func export_to_svg(file_path: String):
	"""Exportă layout-ul curent ca SVG"""
	print("[LayoutManager] Exporting layout to SVG: " + file_path)
	# TODO: Implementează export SVG direct din Godot
	# Pentru moment, folosește sistemul Python existent
	
func clear_viewports():
	"""Șterge toate viewport-urile"""
	for container in viewport_containers:
		container.queue_free()
	viewport_containers.clear()
	cad_viewers.clear()
