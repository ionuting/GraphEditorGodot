extends Node3D
class_name WindowInstantiator

# Referința către scena GLTF
@export var window_scene_path: String = "res://Library/Windows/window120120.gltf"
var window_scene: PackedScene

# Parametri de plasare
var placement_mode: bool = false
var preview_window: Node3D
var placed_windows: Array[Node3D] = []

# Parametri de input
var current_position: Vector3 = Vector3.ZERO
var current_rotation: Vector3 = Vector3.ZERO
var rotation_step: float = 15.0  # grade
var position_step: float = 0.1   # unități

# Materiale pentru preview
var preview_material: StandardMaterial3D

func _ready():
	setup_materials()
	load_window_scene()
	print("=== Instantiator Fereastră GLTF ===")
	print("CTRL + W: Activează/Dezactivează modul plasare")
	print("În modul plasare:")
	print("  WASD: Mișcare XZ")
	print("  Q/E: Mișcare Y (sus/jos)")
	print("  Arrow Keys: Rotație")
	print("  ENTER: Plasează fereastra")
	print("  ESC: Anulează plasarea")
	print("  SHIFT: Mișcare/rotație rapidă")

func setup_materials():
	"""Configurează materialul pentru preview."""
	preview_material = StandardMaterial3D.new()
	preview_material.albedo_color = Color(0.5, 0.8, 1.0, 0.6)
	preview_material.flags_transparent = true
	preview_material.flags_unshaded = true

func load_window_scene():
	"""Încarcă scena GLTF."""
	if ResourceLoader.exists(window_scene_path):
		window_scene = load(window_scene_path)
		if window_scene:
			print("Scena GLTF încărcată cu succes: ", window_scene_path)
		else:
			push_error("Nu s-a putut încărca scena GLTF: " + window_scene_path)
	else:
		push_error("Fișierul GLTF nu există: " + window_scene_path)

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
	if !window_scene:
		push_error("Scena GLTF nu este încărcată!")
		placement_mode = false
		return
	
	print("Mod plasare ACTIVAT")
	create_preview_window()

func end_placement_mode():
	"""Oprește modul de plasare."""
	print("Mod plasare DEZACTIVAT")
	remove_preview_window()

func create_preview_window():
	"""Creează fereastra de preview."""
	if preview_window:
		remove_preview_window()
	
	# Instantiază scena GLTF
	preview_window = window_scene.instantiate()
	
	# Aplică material de preview la toate mesh-urile
	apply_preview_material(preview_window)
	
	# Setează poziția și rotația inițială
	preview_window.position = current_position
	preview_window.rotation_degrees = current_rotation
	
	add_child(preview_window)

func apply_preview_material(node: Node):
	"""Aplică materialul de preview recursiv la toate mesh-urile."""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var surface_count = mesh_instance.get_surface_override_material_count()
		for i in range(mesh_instance.mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(i, preview_material)
	
	# Recursiv pentru copiii
	for child in node.get_children():
		apply_preview_material(child)

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
		KEY_W:  # Înainte (Z-)
			current_position.z -= pos_step
		KEY_S:  # Înapoi (Z+)
			current_position.z += pos_step
		KEY_A:  # Stânga (X-)
			current_position.x -= pos_step
		KEY_D:  # Dreapta (X+)
			current_position.x += pos_step
		KEY_Q:  # Sus (Y+)
			current_position.y += pos_step
		KEY_E:  # Jos (Y-)
			current_position.y -= pos_step
		
		# Rotație
		KEY_LEFT:   # Rotație Y- (stânga)
			current_rotation.y -= rot_step
		KEY_RIGHT:  # Rotație Y+ (dreapta)
			current_rotation.y += rot_step
		KEY_UP:     # Rotație X- (sus)
			current_rotation.x -= rot_step
		KEY_DOWN:   # Rotație X+ (jos)
			current_rotation.x += rot_step
		KEY_PAGEUP:   # Rotație Z- (roll stânga)
			current_rotation.z -= rot_step
		KEY_PAGEDOWN: # Rotație Z+ (roll dreapta)
			current_rotation.z += rot_step
		
		# Acțiuni
		KEY_ENTER:  # Plasează fereastra
			place_window()
		KEY_ESCAPE: # Anulează plasarea
			cancel_placement()
		KEY_R:      # Reset poziție și rotație
			reset_transform()
		KEY_DELETE: # Șterge ultima fereastră plasată
			delete_last_window()
	
	# Actualizează poziția și rotația preview-ului
	if preview_window:
		preview_window.position = current_position
		preview_window.rotation_degrees = current_rotation

func place_window():
	"""Plasează fereastra la poziția curentă."""
	if !preview_window:
		return
	
	# Creează o nouă instanță pentru plasare finală
	var new_window = window_scene.instantiate()
	new_window.position = current_position
	new_window.rotation_degrees = current_rotation
	
	# Adaugă la scenă și la lista de ferestre
	add_child(new_window)
	placed_windows.append(new_window)
	
	print("Fereastră plasată la poziția: ", current_position, " cu rotația: ", current_rotation)
	print("Total ferestre plasate: ", placed_windows.size())

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
		var last_window = placed_windows.pop_back()
		last_window.queue_free()
		print("Ultima fereastră ștearsă. Rămân: ", placed_windows.size())

func place_window_at(position: Vector3, rotation_degrees: Vector3 = Vector3.ZERO) -> Node3D:
	"""Plasează o fereastră programatic la o poziție specifică."""
	if !window_scene:
		push_error("Scena GLTF nu este încărcată!")
		return null
	
	var new_window = window_scene.instantiate()
	new_window.position = position
	new_window.rotation_degrees = rotation_degrees
	
	add_child(new_window)
	placed_windows.append(new_window)
	
	return new_window

func get_window_info(window_index: int) -> Dictionary:
	"""Returnează informații despre o fereastră plasată."""
	if window_index < 0 or window_index >= placed_windows.size():
		return {}
	
	var window = placed_windows[window_index]
	return {
		"position": window.position,
		"rotation": window.rotation_degrees,
		"global_position": window.global_position,
		"global_rotation": window.global_rotation_degrees
	}

func clear_all_windows():
	"""Șterge toate ferestrele plasate."""
	for window in placed_windows:
		if is_instance_valid(window):
			window.queue_free()
	
	placed_windows.clear()
	print("Toate ferestrele au fost șterse")

# Exemplu de utilizare programatică
func _on_test_placement():
	"""Funcție de test pentru plasare programatică."""
	# Plasează ferestre în diverse poziții
	place_window_at(Vector3(0, 1.5, 0))
	place_window_at(Vector3(3, 1.5, 0), Vector3(0, 90, 0))
	place_window_at(Vector3(0, 1.5, 3), Vector3(0, 180, 0))
