extends Node3D

# Dimensiuni cub în sistem Revit:
# X (Est) = 1m
# Y (Nord) = 2m  
# Z (Sus) = 5m
const GLB_PATH := "res://models/axes/axes.glb"

func _ready():
	create_revit_coordinate_system()
	import_axes()
	
func import_axes():
	var glb_scene: PackedScene = load(GLB_PATH)
	if glb_scene:
		var instance: Node3D = glb_scene.instantiate()
		add_child(instance)
		#instance.translation = Vector3(0, 0, 0)  # poziționează în scenă
	else:
		push_error("Nu am reușit să încarc fișierul: %s" % GLB_PATH)
		
func create_revit_coordinate_system():
	# 1. Creează containerul pentru sistemul de coordonate Revit
	var revit_system = Node3D.new()
	revit_system.name = "RevitCoordinateSystem"
	add_child(revit_system)
	
	# 2. Aplică transformarea pentru conversie Revit → Godot
	# Revit: X=Est, Y=Nord, Z=Sus
	# Godot: X=Dreapta, Y=Sus, Z=Către tine
	revit_system.transform = Transform3D(
		Vector3(1, 0, 0),    # X Revit → X Godot
		Vector3(0, 0, -1),    # Y Revit → Z Godot  
		Vector3(0, 1, 0),   # Z Revit → -Y Godot
		Vector3.ZERO
	)
	
	# 3. Creează cubul cu dimensiunile Revit
	create_test_cube(revit_system)



	# 5. Adaugă și un cub Godot nativ pentru comparație
	create_godot_reference_cube()

func create_test_cube(parent: Node3D):
	# Dimensiuni în sistemul Revit: 1m x 2m x 5m
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "RevitCube_1x2x5m"

	# Creează mesh-ul cubului
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.0, 2.0, 5.0)  # X=1m, Y=2m, Z=5m în Revit
	mesh_instance.mesh = box_mesh

	# Material pentru vizibilitate
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.BLUE
	material.flags_transparent = true
	material.albedo_color.a = 0.7
	mesh_instance.material_override = material

	parent.add_child(mesh_instance)

	# Pozițiile cubului pentru a fi vizibil (centrat pe origine)
	mesh_instance.position = Vector3(0.5, 1.0, 2.5)  # Centrat în Revit


func create_godot_reference_cube():
	# Cub de referință în sistemul Godot nativ (pentru comparație)
	var ref_cube = MeshInstance3D.new()
	ref_cube.name = "GodotReference_1x2x5m"
	add_child(ref_cube)

	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.0, 2.0, 5.0)  # Observă diferența!
	ref_cube.mesh = box_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN
	material.flags_transparent = true
	material.albedo_color.a = 0.3
	ref_cube.material_override = material
	
	# Poziționat lângă cubul Revit pentru comparație
	ref_cube.position = Vector3(5, 2.5, 1.0)

# Funcție pentru debug - printează informații despre transformare
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space
		print_transformation_info()

func print_transformation_info():
	var revit_system = get_node("RevitCoordinateSystem")
	print("=== INFORMAȚII TRANSFORMARE ===")
	print("Transform Revit System: ", revit_system.transform)
	print("Basis: ", revit_system.transform.basis)
	print("Origin: ", revit_system.transform.origin)

	var cube = revit_system.get_node("RevitCube_1x2x5m")
	print("Poziție cub în Revit: ", cube.position)
	print("Poziție cub globală: ", cube.global_position)
	print("Scale cub: ", cube.scale)
