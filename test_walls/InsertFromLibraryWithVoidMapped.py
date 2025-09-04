extends Node3D
class_name DualGLTFWindowInstantiator

# Referințe către GLTF-urile mapate
@export var visual_gltf_path: String = "res://Library/Windows/window120120_visual.gltf"
@export var cutting_gltf_path: String = "res://Library/Windows/window120120_cut.gltf"

var visual_scene: PackedScene
var cutting_scene: PackedScene

# Parametri de plasare
var placement_mode: bool = false
var preview_window: Node3D
var placed_windows: Array[Dictionary] = []  # Stochează și visual și cutting geometry

# Parametri de input
var current_position: Vector3 = Vector3.ZERO
var current_rotation: Vector3 = Vector3.ZERO
var rotation_step: float = 15.0
var position_step: float = 0.1

# Materiale pentru preview
var preview_material: StandardMaterial3D

func _ready():
	setup_materials()
	load_gltf_scenes()
	print("=== Dual GLTF Window Instantiator ===")
	print("CTRL + W: Activează/Dezactivează modul plasare")
	print("În modul plasare:")
	print("  WASD: Mișcare XZ")
	print("  Q/E: Mișcare Y (sus/jos)")
	print("  Arrow Keys: Rotație")
	print("  ENTER: Plasează fereastra")
	print("  ESC: Anulează plasarea")
	print("  C: Toggle vizibilitate geometrie cutting")

func setup_materials():
	"""Configurează materialele pentru preview."""
	preview_material = StandardMaterial3D.new()
	preview_material.albedo_color = Color(0.5, 0.8, 1.0, 0.6)
	preview_material.flags_transparent = true
	preview_material.flags_unshaded = true

func load_gltf_scenes():
	"""Încarcă ambele scene GLTF."""
	var success = true
	
	# Încarcă GLTF vizual
	if ResourceLoader.exists(visual_gltf_path):
		visual_scene = load(visual_gltf_path)
		if visual_scene:
			print("GLTF vizual încărcat: ", visual_gltf_path)
		else:
			push_error("Nu s-a putut încărca GLTF vizual: " + visual_gltf_path)
			success = false
	else:
		push_error("GLTF vizual nu există: " + visual_gltf_path)
		success = false
	
	# Încarcă GLTF cutting
	if ResourceLoader.exists(cutting_gltf_path):
		cutting_scene = load(cutting_gltf_path)
		if cutting_scene:
			print("GLTF cutting încărcat: ", cutting_gltf_path)
		else:
			push_error("Nu s-a putut încărca GLTF cutting: " + cutting_gltf_path)
			success = false
	else:
		push_error("GLTF cutting nu există: " + cutting_gltf_path)
		success = false
	
	if !success:
		push_error("Unele GLTF-uri nu au fost încărcate corect!")

func _input(event):
	if event is InputEventKey and event.pressed:
		# Activare/dezactivare mod plasare
		if event.keycode == KEY_W and event.ctrl_pressed:
			toggle_placement_mode()
		
		# Input-uri doar în modul plasare
		elif placement_mode:
			handle_placement_input(event)

func toggle_placement_mode():
	"""Activează/dezactivează modul de plasare."""
	placement_mode = !placement_mode
	
	if placement_mode:
		start_placement_mode()
	else:
		end_placement_mode()

func start_placement_mode():
	"""Pornește modul de plasare."""
	if !visual_scene or !cutting_scene:
		push_error("Scene GLTF nu sunt încărcate!")
		placement_mode = false
		return
	
	print("Mod plasare ACTIVAT")
	create_preview_window()

func end_placement_mode():
	"""Oprește modul de plasare."""
	print("Mod plasare DEZACTIVAT")
	remove_preview_window()

func create_preview_window():
	"""Creează fereastra de preview cu ambele geometrii."""
	if preview_window:
		remove_preview_window()
	
	# Container pentru preview
	preview_window = Node3D.new()
	preview_window.name = "WindowPreview"
	
	# Adaugă geometria vizuală
	var visual_instance = visual_scene.instantiate()
	visual_instance.name = "VisualGeometry"
	apply_preview_material(visual_instance)
	preview_window.add_child(visual_instance)
	
	# Adaugă geometria cutting (invizibilă implicit)
	var cutting_instance = cutting_scene.instantiate()
	cutting_instance.name = "CuttingGeometry"
	cutting_instance.visible = false
	
	# Aplică material roșu semi-transparent pentru cutting (când e vizibil)
	var cutting_material = StandardMaterial3D.new()
	cutting_material.albedo_color = Color(1.0, 0.2, 0.2, 0.3)
	cutting_material.flags_transparent = true
	cutting_material.flags_unshaded = true
	apply_preview_material_to_node(cutting_instance, cutting_material)
	
	preview_window.add_child(cutting_instance)
	
	# Setează transformarea
	preview_window.position = current_position
	preview_window.rotation_degrees = current_rotation
	
	add_child(preview_window)

func apply_preview_material(node: Node):
	"""Aplică materialul de preview albastru la toate mesh-urile."""
	apply_preview_material_to_node(node, preview_material)

func apply_preview_material_to_node(node: Node, material: Material):
	"""Aplică un material specific recursiv la toate mesh-urile."""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		for i in range(mesh_instance.mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(i, material)
	
	# Recursiv pentru copiii
	for child in node.get_children():
		apply_preview_material_to_node(child, material)

func remove_preview_window():
	"""Elimină fereastra de preview."""
	if preview_window:
		preview_window.queue_free()
		preview_window = null

func handle_placement_input(event: InputEventKey):
	"""Gestionează input-urile pentru plasare."""
	if !preview_window:
		return
	
	var speed_multiplier = 5.0 if event.shift_pressed else 1.0
	var pos_step = position_step * speed_multiplier
	var rot_step = rotation_step * speed_multiplier
	
	match event.keycode:
		# Mișcare poziție
		KEY_W: current_position.z -= pos_step
		KEY_S: current_position.z += pos_step
		KEY_A: current_position.x -= pos_step
		KEY_D: current_position.x += pos_step
		KEY_Q: current_position.y += pos_step
		KEY_E: current_position.y -= pos_step
		
		# Rotație
		KEY_LEFT: current_rotation.y -= rot_step
		KEY_RIGHT: current_rotation.y += rot_step
		KEY_UP: current_rotation.x -= rot_step
		KEY_DOWN: current_rotation.x += rot_step
		KEY_PAGEUP: current_rotation.z -= rot_step
		KEY_PAGEDOWN: current_rotation.z += rot_step
		
		# Acțiuni speciale
		KEY_C: toggle_cutting_geometry_visibility()
		KEY_ENTER: place_window()
		KEY_ESCAPE: cancel_placement()
		KEY_R: reset_transform()
		KEY_DELETE: delete_last_window()
	
	# Actualizează transformarea preview-ului
	if preview_window:
		preview_window.position = current_position
		preview_window.rotation_degrees = current_rotation

func toggle_cutting_geometry_visibility():
	"""Comută vizibilitatea geometriei de cutting în preview."""
	if preview_window:
		var cutting_node = preview_window.get_node("CuttingGeometry")
		if cutting_node:
			cutting_node.visible = !cutting_node.visible
			print("Geometrie cutting: ", "vizibilă" if cutting_node.visible else "ascunsă")

func place_window():
	"""Plasează fereastra cu ambele geometrii."""
	if !preview_window:
		return
	
	# Creează containerul pentru fereastră
	var window_container = Node3D.new()
	window_container.name = "Window_" + str(placed_windows.size())
	window_container.position = current_position
	window_container.rotation_degrees = current_rotation
	
	# Adaugă geometria vizuală
	var visual_instance = visual_scene.instantiate()
	visual_instance.name = "Visual"
	window_container.add_child(visual_instance)
	
	# Adaugă geometria cutting (invizibilă)
	var cutting_instance = cutting_scene.instantiate()
	cutting_instance.name = "Cutting"
	cutting_instance.visible = false
	
	# Convertește la CSG pentru operațiuni de tăiere
	convert_to_csg_cutting(cutting_instance)
	
	window_container.add_child(cutting_instance)
	
	# Adaugă în scenă
	add_child(window_container)
	
	# Stochează referințele
	var window_data = {
		"container": window_container,
		"visual": visual_instance,
		"cutting": cutting_instance,
		"position": current_position,
		"rotation": current_rotation
	}
	placed_windows.append(window_data)
	
	print("Fereastră plasată la poziția: ", current_position, " cu rotația: ", current_rotation)
	print("Total ferestre plasate: ", placed_windows.size())

func convert_to_csg_cutting(cutting_node: Node3D):
	"""Convertește geometria cutting în CSG pentru operațiuni de tăiere."""
	# Găsește toate MeshInstance3D și le convertește în CSGMesh3D
	convert_mesh_to_csg(cutting_node)

func convert_mesh_to_csg(node: Node):
	"""Convertește recursiv MeshInstance3D în CSGMesh3D."""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var csg_mesh = CSGMesh3D.new()
		csg_mesh.mesh = mesh_instance.mesh
		csg_mesh.operation = CSGShape3D.OPERATION_SUBTRACTION
		csg_mesh.visible = false
		
		# Înlocuiește MeshInstance3D cu CSGMesh3D
		var parent = mesh_instance.get_parent()
		var index = mesh_instance.get_index()
		mesh_instance.queue_free()
		parent.add_child(csg_mesh)
		parent.move_child(csg_mesh, index)
	
	# Recursiv pentru copiii
	for child in node.get_children():
		convert_mesh_to_csg(child)

func apply_window_to_wall(window_index: int, wall_node: CSGShape3D):
	"""Aplică geometria de cutting a unei ferestre la un perete."""
	if window_index < 0 or window_index >= placed_windows.size():
		push_error("Index fereastră invalid: " + str(window_index))
		return
	
	if !wall_node:
		push_error("Wall node este null")
		return
	
	var window_data = placed_windows[window_index]
	var cutting_geometry = window_data.cutting
	
	# Clonează geometria de cutting
	var wall_cutter = cutting_geometry.duplicate()
	
	# Calculează poziția relativă
	var window_container = window_data.container
	var relative_pos = window_container.global_position - wall_node.global_position
	var relative_rot = window_container.global_rotation - wall_node.global_rotation
	
	wall_cutter.position = relative_pos
	wall_cutter.rotation = relative_rot
	wall_cutter.visible = false
	
	# Adaugă ca child al peretelui
	wall_node.add_child(wall_cutter)
	
	print("Geometrie cutting aplicată de la fereastra ", window_index, " la peretele ", wall_node.name)

func get_window_cutting_geometry(window_index: int) -> Node3D:
	"""Returnează geometria de cutting pentru o fereastră specifică."""
	if window_index < 0 or window_index >= placed_windows.size():
		return null
	
	return placed_windows[window_index].cutting

func get_window_visual_geometry(window_index: int) -> Node3D:
	"""Returnează geometria vizuală pentru o fereastră specifică."""
	if window_index < 0 or window_index >= placed_windows.size():
		return null
	
	return placed_windows[window_index].visual

func cancel_placement():
	"""Anulează procesul de plasare."""
	end_placement_mode()

func reset_transform():
	"""Resetează poziția și rotația la zero."""
	current_position = Vector3.ZERO
	current_rotation = Vector3.ZERO
	print("Transform resetat")

func delete_last_window():
	"""Șterge ultima fereastră plasată."""
	if placed_windows.size() > 0:
		var last_window_data = placed_windows.pop_back()
		last_window_data.container.queue_free()
		print("Ultima fereastră ștearsă. Rămân: ", placed_windows.size())

func clear_all_windows():
	"""Șterge toate ferestrele plasate."""
	for window_data in placed_windows:
		if is_instance_valid(window_data.container):
			window_data.container.queue_free()
	
	placed_windows.clear()
	print("Toate ferestrele au fost șterse")