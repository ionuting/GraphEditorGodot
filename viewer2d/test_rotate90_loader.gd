extends Node3D

func _ready():
	print("=== TEST ROTATIE 90 GRADE ===")
	var gltf_doc = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	
	var glb_path = "test_rotate90.glb"
	var mapping_path = "test_rotate90_mapping.json"
	
	print("Incarcam GLB: ", glb_path)
	
	# Verificam daca fisierul exista
	if not FileAccess.file_exists(glb_path):
		print("EROARE: Fisierul GLB nu exista!")
		return
	
	# Incarcam GLB
	var error = gltf_doc.append_from_file(glb_path, gltf_state)
	if error != OK:
		print("EROARE: Nu pot incarca GLB - ", error)
		return
	
	var scene = gltf_doc.generate_scene(gltf_state)
	if scene == null:
		print("EROARE: Nu pot genera scena!")
		return
	
	print("✓ GLB incarcat cu succes!")
	add_child(scene)
	
	# Verificam mapping-ul
	if FileAccess.file_exists(mapping_path):
		var file = FileAccess.open(mapping_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_text)
			if parse_result == OK:
				var mapping_data = json.data
				print("✓ Mapping incarcat: ", mapping_data.size(), " entitati")
				
				for entry in mapping_data:
					print("- Mesh: ", entry.mesh_name, " | Layer: ", entry.layer, " | Volume: ", entry.volume)
			else:
				print("EROARE: Nu pot parsa JSON mapping")
	else:
		print("EROARE: Fisierul mapping nu exista!")
	
	print("=== TEST COMPLET ===")