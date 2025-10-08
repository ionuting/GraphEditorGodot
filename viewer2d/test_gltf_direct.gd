extends Node

func _ready():
	test_gltf_document_loading()

func test_gltf_document_loading():
	var glb_path = "C:/Users/ionut.ciuntuc/Documents/viewer2d/python/dxf/0Firstfloor.glb"
	
	if not FileAccess.file_exists(glb_path):
		print("GLB file not found: ", glb_path)
		return
	
	print("Testing GLTFDocument direct loading...")
	
	var file = FileAccess.open(glb_path, FileAccess.READ)
	if not file:
		print("Cannot open file: ", glb_path)
		return
	
	var glb_data = file.get_buffer(file.get_length())
	file.close()
	
	print("File size: ", glb_data.size(), " bytes")
	
	# Check magic bytes
	if glb_data.size() >= 4:
		var magic = glb_data.slice(0, 4).get_string_from_ascii()
		print("Magic bytes: ", magic)
	
	var gltf_document = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	
	var error = gltf_document.append_from_buffer(glb_data, "", gltf_state)
	print("append_from_buffer result: ", error)
	
	if error == OK:
		var packed_scene = gltf_document.generate_scene(gltf_state)
		print("generate_scene result: ", packed_scene)
		
		if packed_scene:
			var scene = packed_scene.instantiate()
			print("Scene instantiated: ", scene)
			if scene:
				add_child(scene)
				print("SUCCESS: GLB loaded with GLTFDocument!")
			else:
				print("FAILED: Could not instantiate scene")
		else:
			print("FAILED: generate_scene returned null")
	else:
		print("FAILED: append_from_buffer error: ", error)