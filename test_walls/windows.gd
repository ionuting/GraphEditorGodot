extends Node3D
class_name Window3D

# Proprietăți fereastră
@export var window_width: float = 1.2
@export var window_height: float = 1.5
@export var window_depth: float = 0.2
@export var frame_thickness: float = 0.05
@export var glass_thickness: float = 0.01
@export var cutting_margin: float = 0.01  # Marjă suplimentară pentru tăiere

# Materiale
var frame_material: StandardMaterial3D
var glass_material: StandardMaterial3D

# Referințe la componente
var visual_group: Node3D
var cutting_group: Node3D

func _ready():
	setup_materials()
	create_window_element()

func setup_materials():
	"""Configurează materialele pentru fereastră."""
	
	# Material pentru ramă
	frame_material = StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.4, 0.3, 0.2)  # Maro pentru ramă
	frame_material.metallic = 0.2
	frame_material.roughness = 0.8
	
	# Material pentru sticlă
	glass_material = StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.8, 0.9, 1.0, 0.3)  # Albastru transparent
	glass_material.metallic = 0.0
	glass_material.roughness = 0.0
	glass_material.flags_transparent = true
	glass_material.flags_use_point_size = true

func create_window_element():
	"""Creează elementul complet de fereastră."""
	
	# Grup pentru partea vizibilă
	visual_group = Node3D.new()
	visual_group.name = "WindowVisual"
	add_child(visual_group)
	
	# Grup pentru geometria de tăiere (invizibilă)
	cutting_group = Node3D.new()
	cutting_group.name = "WindowCutting"
	add_child(cutting_group)
	
	# Creează componentele vizuale
	create_window_frame()
	create_window_glass()
	
	# Creează geometria de tăiere
	create_cutting_geometry()

func create_window_frame():
	"""Creează rama ferestrei folosind CSG operations."""
	
	# Combiner pentru ramă
	var frame_combiner = CSGCombiner3D.new()
	frame_combiner.name = "Frame"
	frame_combiner.operation = CSGShape3D.OPERATION_UNION
	visual_group.add_child(frame_combiner)
	
	# Rama exterioară (solidă)
	var outer_frame = CSGBox3D.new()
	outer_frame.size = Vector3(window_width, window_height, window_depth)
	outer_frame.operation = CSGShape3D.OPERATION_UNION
	outer_frame.material = frame_material
	frame_combiner.add_child(outer_frame)
	
	# Gaura interioară (pentru sticlă)
	var inner_cutout = CSGBox3D.new()
	inner_cutout.size = Vector3(
		window_width - 2 * frame_thickness,
		window_height - 2 * frame_thickness,
		window_depth + 0.01  # Puțin mai adâncă pentru tăiere completă
	)
	inner_cutout.operation = CSGShape3D.OPERATION_SUBTRACTION
	frame_combiner.add_child(inner_cutout)

func create_window_glass():
	"""Creează sticla ferestrei."""
	
	var glass = CSGBox3D.new()
	glass.name = "Glass"
	glass.size = Vector3(
		window_width - 2 * frame_thickness - 0.005,  # Puțin mai mică ca rama
		window_height - 2 * frame_thickness - 0.005,
		glass_thickness
	)
	glass.material = glass_material
	glass.operation = CSGShape3D.OPERATION_UNION
	visual_group.add_child(glass)

func create_cutting_geometry():
	"""Creează geometria invizibilă pentru tăierea pereților."""
	
	# Geometrie de tăiere - mai mare cu marginea specificată
	var cutting_box = CSGBox3D.new()
	cutting_box.name = "CuttingVolume"
	cutting_box.size = Vector3(
		window_width + 2 * cutting_margin,
		window_height + 2 * cutting_margin,
		window_depth + 2 * cutting_margin
	)
	
	# Setează operațiunea de scădere pentru tăiere
	cutting_box.operation = CSGShape3D.OPERATION_SUBTRACTION
	
	# Face geometria invizibilă
	cutting_box.visible = false
	
	# Adaugă la grupul de tăiere
	cutting_group.add_child(cutting_box)

func get_cutting_geometry() -> CSGShape3D:
	"""Returnează geometria de tăiere pentru a fi folosită de alte obiecte."""
	return cutting_group.get_child(0) as CSGShape3D

func apply_to_wall(wall_node: CSGShape3D):
	"""Aplică tăierea ferestrei la un perete."""
	if wall_node == null:
		push_error("Wall node is null")
		return
	
	var cutting_geometry = get_cutting_geometry()
	if cutting_geometry == null:
		push_error("Cutting geometry not found")
		return
	
	# Clonează geometria de tăiere
	var wall_cutter = cutting_geometry.duplicate()
	
	# Calculează poziția relativă între fereastră și perete
	var relative_pos = global_position - wall_node.global_position
	var relative_rot = global_rotation - wall_node.global_rotation
	
	wall_cutter.position = relative_pos
	wall_cutter.rotation = relative_rot
	wall_cutter.visible = false  # Păstrează invizibil
	
	# Adaugă geometria de tăiere ca child al peretelui
	wall_node.add_child(wall_cutter)
	
	print("Fereastră aplicată la perete: ", wall_node.name)

func create_test_wall() -> CSGBox3D:
	"""Creează un perete de test pentru demonstrație."""
	var wall = CSGBox3D.new()
	wall.name = "TestWall"
	wall.size = Vector3(4.0, 3.0, 0.2)
	wall.operation = CSGShape3D.OPERATION_UNION
	
	# Material perete
	var wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.8, 0.8, 0.7)
	wall.material = wall_material
	
	return wall

func set_window_size(width: float, height: float, depth: float = 0.2):
	"""Permite modificarea dimensiunilor ferestrei."""
	window_width = width
	window_height = height
	window_depth = depth
	
	# Recreează geometria cu noile dimensiuni
	if visual_group:
		visual_group.queue_free()
	if cutting_group:
		cutting_group.queue_free()
	
	create_window_element()

func set_position_on_wall(wall_position: Vector3, wall_normal: Vector3, offset_from_surface: float = 0.0):
	"""Poziționează fereastra pe un perete dat."""
	global_position = wall_position + wall_normal * offset_from_surface
	
	# Orientează fereastra perpendicular pe perete
	look_at(global_position + wall_normal, Vector3.UP)

# Test și demonstrație
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				test_window_creation()
			KEY_2:
				test_wall_cutting()
			KEY_3:
				test_different_sizes()

func test_window_creation():
	"""Test pentru crearea ferestrei."""
	print("=== Test creare fereastră ===")
	position = Vector3(0, 1, 0)

func test_wall_cutting():
	"""Test pentru tăierea pereților."""
	print("=== Test tăiere perete ===")
	
	# Creează perete de test
	var test_wall = create_test_wall()
	get_parent().add_child(test_wall)
	test_wall.position = Vector3(0, 1.5, -0.5)
	
	# Aplică fereastra la perete
	position = Vector3(0, 1.5, -0.4)  # Poziționează fereastra în fața peretelui
	apply_to_wall(test_wall)

func test_different_sizes():
	"""Test cu dimensiuni diferite."""
	print("=== Test dimensiuni diferite ===")
	set_window_size(2.0, 1.8, 0.25)
	position = Vector3(3, 1, 0)
