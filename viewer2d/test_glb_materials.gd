extends Node3D

func _ready():
	print("=== Testing GLB material preservation ===")
	
	# Încarcă GLB-ul cu ferestre
	var glb_path = "test_window_materials.glb"
	print("Loading GLB: ", glb_path)
	
	var scene_resource = load(glb_path)
	if scene_resource:
		var scene_instance = scene_resource.instantiate()
		add_child(scene_instance)
		
		print("GLB loaded successfully")
		_check_materials_recursive(scene_instance)
	else:
		print("Failed to load GLB")

func _check_materials_recursive(node: Node, indent: String = ""):
	if node is MeshInstance3D and node.mesh:
		var mesh_name = str(node.name)
		print("%sMesh: %s" % [indent, mesh_name])
		
		# Verifică materialele din mesh
		var mesh = node.mesh
		if mesh.get_surface_count() > 0:
			var surface_material = mesh.surface_get_material(0)
			if surface_material:
				var mat_name = surface_material.resource_name if surface_material else "Unnamed"
				print("%s  GLB Material: %s" % [indent, mat_name])
				
				if surface_material is StandardMaterial3D:
					var std_mat = surface_material as StandardMaterial3D
					print("%s  Color: %s" % [indent, str(std_mat.albedo_color)])
					print("%s  Alpha: %f" % [indent, std_mat.albedo_color.a])
				else:
					print("%s  Material type: %s" % [indent, surface_material.get_class()])
			else:
				print("%s  No mesh material found" % indent)
		else:
			print("%s  No surfaces in mesh" % indent)
		
		# Verifică material override
		if node.get_surface_count() > 0:
			var override_mat = node.get_surface_override_material(0)
			if override_mat:
				print("%s  Override material: %s" % [indent, override_mat.resource_name])
		
		print()
	
	# Recursiv pentru copii
	for child in node.get_children():
		_check_materials_recursive(child, indent + "  ")