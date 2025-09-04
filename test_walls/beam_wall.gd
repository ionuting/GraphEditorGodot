extends Node3D

func _ready():
	# Teste pentru diferite scenarii
	test_rectangular_contour()

func create_rectangular_contour(start_point: Vector2, end_point: Vector2, width: float) -> PackedVector2Array:
	"""
	Creează un contur dreptunghiular având ca axă centrală linia dintre start_point și end_point.
	
	Parametri:
	- start_point: punctul de început al axei centrale
	- end_point: punctul de sfârșit al axei centrale  
	- width: lățimea dreptunghiului (perpendicular pe axa centrală)
	
	Returnează: PackedVector2Array cu cele 4 puncte ale dreptunghiului (în sens trigonometric)
	"""
	
	# Calculăm vectorul direcție de la start la end
	var direction = end_point - start_point
	
	# Verificăm dacă punctele sunt diferite
	if direction.length() < 0.001:
		push_error("Punctele start și end sunt prea apropiate pentru a crea un dreptunghi")
		return PackedVector2Array()
	
	# Normalizăm vectorul direcție
	var dir_normalized = direction.normalized()
	
	# Calculăm vectorul perpendicular (rotim cu 90° în sens trigonometric)
	var perpendicular = Vector2(-dir_normalized.y, dir_normalized.x)
	
	# Calculăm jumătate din lățime pentru offset
	var half_width = width * 0.5
	
	# Calculăm cele 4 puncte ale dreptunghiului
	# Punctele sunt calculate în sens trigonometric (counter-clockwise)
	var p1 = start_point + perpendicular * half_width    # stânga-start
	var p2 = end_point + perpendicular * half_width      # stânga-end  
	var p3 = end_point - perpendicular * half_width      # dreapta-end
	var p4 = start_point - perpendicular * half_width    # dreapta-start
	
	# Returnăm punctele în ordine trigonometrică
	return PackedVector2Array([p1, p2, p3, p4])

func create_rectangular_contour_extended(start_point: Vector2, end_point: Vector2, width: float, start_extension: float = 0.0, end_extension: float = 0.0) -> PackedVector2Array:
	"""
	Versiune extinsă care permite extinderea dreptunghiului în ambele direcții.
	
	Parametri suplimentari:
	- start_extension: cu cât să extindă dreptunghiul înapoi de la start_point
	- end_extension: cu cât să extindă dreptunghiul înainte de la end_point
	"""
	
	var direction = end_point - start_point
	if direction.length() < 0.001:
		push_error("Punctele start și end sunt prea apropiate")
		return PackedVector2Array()
	
	var dir_normalized = direction.normalized()
	var perpendicular = Vector2(-dir_normalized.y, dir_normalized.x)
	var half_width = width * 0.5
	
	# Calculăm punctele extinse
	var extended_start = start_point - dir_normalized * start_extension
	var extended_end = end_point + dir_normalized * end_extension
	
	# Calculăm cele 4 puncte ale dreptunghiului extins
	var p1 = extended_start + perpendicular * half_width
	var p2 = extended_end + perpendicular * half_width
	var p3 = extended_end - perpendicular * half_width
	var p4 = extended_start - perpendicular * half_width
	
	return PackedVector2Array([p1, p2, p3, p4])

func get_rectangle_info(start_point: Vector2, end_point: Vector2) -> Dictionary:
	"""
	Returnează informații despre orientarea și dimensiunile dreptunghiului.
	"""
	var direction = end_point - start_point
	var length = direction.length()
	var angle_rad = direction.angle()
	var angle_deg = rad_to_deg(angle_rad)
	
	return {
		"length": length,
		"angle_radians": angle_rad,
		"angle_degrees": angle_deg,
		"direction_vector": direction.normalized()
	}

func test_rectangular_contour():
	"""
	Testează funcția cu diferite scenarii și creează vizualizări.
	"""
	
	print("=== Test Contur Dreptunghiular ===")
	
	# Test 1: Linie orizontală
	var rect1 = create_rectangular_contour(Vector2(0, 0), Vector2(3, 0), 1.0)
	print("Test 1 (orizontal): ", rect1)
	visualize_rectangle(rect1, Color.RED, "Orizontal")
	
	# Test 2: Linie verticală  
	var rect2 = create_rectangular_contour(Vector2(5, 0), Vector2(5, 3), 1.0)
	print("Test 2 (vertical): ", rect2)
	visualize_rectangle(rect2, Color.GREEN, "Vertical")
	
	# Test 3: Linie diagonală (45°)
	var rect3 = create_rectangular_contour(Vector2(8, 0), Vector2(11, 3), 1.0)
	print("Test 3 (diagonal 45°): ", rect3)
	visualize_rectangle(rect3, Color.BLUE, "Diagonal 45°")
	
	# Test 4: Unghi arbitrar
	var rect4 = create_rectangular_contour(Vector2(0, 5), Vector2(4, 7), 0.8)
	var info4 = get_rectangle_info(Vector2(0, 5), Vector2(4, 7))
	print("Test 4 (unghi arbitrar): ", rect4)
	print("  - Lungime: ", info4.length)
	print("  - Unghi: ", info4.angle_degrees, "°")
	visualize_rectangle(rect4, Color.MAGENTA, "Unghi arbitrar")
	
	# Test 5: Cu extensii
	var rect5 = create_rectangular_contour_extended(Vector2(8, 5), Vector2(12, 7), 0.6, 0.5, 1.0)
	print("Test 5 (cu extensii): ", rect5)
	visualize_rectangle(rect5, Color.CYAN, "Cu extensii")

func visualize_rectangle(polygon: PackedVector2Array, color: Color, label: String):
	"""
	Creează o reprezentare vizuală 3D a dreptunghiului pentru testare.
	"""
	if polygon.size() != 4:
		return
		
	var csg_polygon = CSGPolygon3D.new()
	csg_polygon.polygon = polygon
	csg_polygon.depth = 0.1
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.flags_transparent = color.a < 1.0
	csg_polygon.material = material
	
	# Poziționează pentru a evita suprapunerea
	var offset = get_child_count() * Vector3(0, 0.2, 0)
	csg_polygon.position = offset
	
	csg_polygon.name = label
	add_child(csg_polygon)
	
	print("Vizualizare creată: ", label, " la poziția ", offset)
