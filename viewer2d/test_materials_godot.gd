extends Node3D

func _ready():
	var scene = load("test_window_materials.glb")
	if scene:
		var instance = scene.instantiate()
		add_child(instance)
		_check_materials(instance)

func _check_materials(node):
	if node is MeshInstance3D:
		print("Mesh: ", node.name)
		print("  Surface count: ", node.get_surface_count())
		for i in range(node.get_surface_count()):
			var mat = node.get_surface_override_material(i)
			print("  Surface ", i, " override material: ", mat)
			
			# Verifică și materialul default al surface-ului
			var surface_mat = node.mesh.surface_get_material(i) if node.mesh else null
			print("  Surface ", i, " mesh material: ", surface_mat)
			
			if mat:
				print("    Override material name: ", mat.resource_name)
				if mat.has_method("get_albedo"):
					print("    Override albedo: ", mat.albedo_color)
			
			if surface_mat:
				print("    Mesh material name: ", surface_mat.resource_name)
				if surface_mat.has_method("get_albedo"):
					print("    Mesh albedo: ", surface_mat.albedo_color)
	
	for child in node.get_children():
		_check_materials(child)