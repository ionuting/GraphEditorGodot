extends Node3D

func _ready():
	# Poligon original cu 6 colțuri
	var footprint = PackedVector2Array([
		Vector2(0,0),
		Vector2(2,0),
		Vector2(3,1),
		Vector2(2.5,3),
		Vector2(1,2.5),
		Vector2(0,1)
	])
	
	# Offset interior 0.125
	var inner_polygons = Geometry2D.offset_polygon(footprint, -0.125)
	
	# Material pentru volumul final
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.8)
	
	# OPȚIUNEA 1: Doar volumul interior (simplu)
	show_only_inner_volume(footprint, inner_polygons, mat)
	
	# OPȚIUNEA 2: Combiner cu posibilitate de toggle (decomentează pentru a folosi)
	# show_both_volumes_with_toggle(footprint, inner_polygons, mat)

func show_only_inner_volume(footprint: PackedVector2Array, inner_polygons: Array, mat: StandardMaterial3D):
	if inner_polygons.size() > 0:
		var inner_poly = inner_polygons[0]
		
		var inner_volume = CSGPolygon3D.new()
		inner_volume.polygon = inner_poly
		inner_volume.depth = 2.55
		inner_volume.operation = CSGShape3D.OPERATION_UNION
		inner_volume.position = Vector3(0, 0, 2.55/2)
		inner_volume.material = mat
		
		add_child(inner_volume)
	else:
		print("Offset-ul a fost prea mare - nu se poate crea volumul interior")

func show_both_volumes_with_toggle(footprint: PackedVector2Array, inner_polygons: Array, mat: StandardMaterial3D):
	# Material pentru exterior (diferit pentru a le distinge)
	var outer_mat = StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.8, 0.2, 0.2, 0.5)  # Roșu semi-transparent
	outer_mat.flags_transparent = true
	
	# Creăm un CSGCombiner3D ca root
	var combiner = CSGCombiner3D.new()
	combiner.operation = CSGShape3D.OPERATION_UNION
	add_child(combiner)
	
	# 1. Volumul exterior (poligonul original extrudat)
	var outer_volume = CSGPolygon3D.new()
	outer_volume.polygon = footprint
	outer_volume.depth = 2.55
	outer_volume.operation = CSGShape3D.OPERATION_UNION
	outer_volume.position = Vector3(0, 0, 2.55/2)
	outer_volume.material = outer_mat
	outer_volume.visible = false  # Ascuns inițial
	combiner.add_child(outer_volume)
	
	# 2. Volumul interior - doar dacă există
	if inner_polygons.size() > 0:
		var inner_poly = inner_polygons[0]
		
		var inner_volume = CSGPolygon3D.new()
		inner_volume.polygon = inner_poly
		inner_volume.depth = 2.55
		inner_volume.operation = CSGShape3D.OPERATION_UNION
		inner_volume.position = Vector3(0, 0, 2.55/2)
		inner_volume.material = mat
		combiner.add_child(inner_volume)
		
		# Toggle prin input (exemplu)
		print("Apasă SPAȚIU pentru a comuta între exterior/interior/ambele")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		toggle_volumes()

var display_mode = 0  # 0=interior, 1=exterior, 2=ambele
func toggle_volumes():
	var combiner = get_child(0) as CSGCombiner3D
	if combiner == null or combiner.get_child_count() < 2:
		return
		
	var outer_volume = combiner.get_child(0)
	var inner_volume = combiner.get_child(1)
	
	display_mode = (display_mode + 1) % 3
	
	match display_mode:
		0:  # Doar interior
			outer_volume.visible = false
			inner_volume.visible = true
			print("Afișare: Doar interior")
		1:  # Doar exterior
			outer_volume.visible = true
			inner_volume.visible = false
			print("Afișare: Doar exterior")
		2:  # Ambele
			outer_volume.visible = true
			inner_volume.visible = true
			print("Afișare: Ambele volume")
