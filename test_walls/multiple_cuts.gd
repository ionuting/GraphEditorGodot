extends Node3D

func _ready():
	# Definim dimensiunile cubului
	var cube_size = Vector3(5, 5, 5)
	
	# Material pentru volumul final
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.8)
	
	# Creăm un CSGCombiner3D ca root
	var combiner = CSGCombiner3D.new()
	combiner.operation = CSGShape3D.OPERATION_UNION
	add_child(combiner)
	
	# 1. Volumul exterior (cubul)
	var outer_volume = CSGBox3D.new()
	outer_volume.size = cube_size
	outer_volume.operation = CSGShape3D.OPERATION_UNION
	outer_volume.material = mat
	combiner.add_child(outer_volume)
	
	# 2. Prima formă interioară (cilindru vertical)
	var inner_cylinder1 = CSGCylinder3D.new()
	inner_cylinder1.radius = 0.75
	inner_cylinder1.height = cube_size.y + 0.1  # Putin mai înalt pentru tăiere completă
	inner_cylinder1.operation = CSGShape3D.OPERATION_SUBTRACTION
	inner_cylinder1.position = Vector3(-1, 0, -1)  # Poziționat în partea stângă-spate
	combiner.add_child(inner_cylinder1)
	
	# 3. A doua formă interioară (cilindru vertical)
	var inner_cylinder2 = CSGCylinder3D.new()
	inner_cylinder2.radius = 0.5
	inner_cylinder2.height = cube_size.y + 0.1  # Putin mai înalt pentru tăiere completă
	inner_cylinder2.operation = CSGShape3D.OPERATION_SUBTRACTION
	inner_cylinder2.position = Vector3(1, 0, 1)  # Poziționat în partea dreaptă-față
	combiner.add_child(inner_cylinder2)
	
	# Centrăm combiner-ul în scenă
	combiner.position = Vector3(0, cube_size.y/2, 0)
	
	# Adăugăm o cameră pentru a putea vizualiza scena
	var camera = Camera3D.new()
	camera.position = Vector3(10, 8, 10)
	camera.look_at(Vector3.ZERO)
	add_child(camera)
	
	# Adăugăm lumină directională
	var light = DirectionalLight3D.new()
	light.position = Vector3(5, 10, 5)
	light.look_at(Vector3.ZERO)
	add_child(light)
