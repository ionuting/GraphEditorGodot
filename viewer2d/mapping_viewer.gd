extends Control

@export var mapping_folder: String = "res://python/dxf/"
var mapping_data := {}
var clipboard_value: String = ""
@onready var tree: Tree = $Tree
@onready var context_menu: PopupMenu = PopupMenu.new()
@onready var refresh_button: Button = $RefreshButton  # Adaugă un Button în scenă

func _ready():
	# Adaugă context menu
	add_child(context_menu)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	
	# Conectează semnalele tree
	tree.item_edited.connect(_on_tree_item_edited)
	
	# Conectează butonul de refresh (dacă există)
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)
	
	load_all_mappings()
	populate_tree()

func load_all_mappings():
	"""Încarcă toate fișierele JSON disponibile din folderul python/dxf"""
	mapping_data.clear()
	
	# Detectează automat toate fișierele JSON din folderul python/dxf
	var json_folder_path = "res://python/dxf/"
	var dir = DirAccess.open(json_folder_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var json_files = []
		
		while file_name != "":
			if file_name.ends_with("_mapping.json") and not file_name.begins_with("."):
				json_files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		
		print_debug("📁 Found " + str(json_files.size()) + " JSON files in " + json_folder_path)
		for json_file in json_files:
			print_debug("   - " + json_file)
			load_mapping(json_file)
		
		if json_files.is_empty():
			print_debug("⚠️ No JSON files found in " + json_folder_path)
	else:
		print_debug("❌ Cannot access directory: " + json_folder_path)

func test_boolean_calculations():
	"""Testează calculele matematice pentru boolean operations cu datele de test"""
	print_debug("🧮 === TESTING BOOLEAN CALCULATIONS ===")
	
	if not mapping_data.has("test_boolean_mapping.json"):
		print_debug("❌ test_boolean_mapping.json not loaded!")
		return
	
	var test_data = mapping_data["test_boolean_mapping.json"]
	print_debug("📊 Test data contains " + str(test_data.size()) + " entries")
	
	# Creează mapping UUID -> entry pentru test
	var uuid_to_entry = {}
	for entry in test_data:
		if entry.has("uuid"):
			uuid_to_entry[entry["uuid"]] = entry
	
	# Testează calculele pentru solid-001 (care are 2 voids)
	for entry in test_data:
		if entry.get("uuid", "") == "solid-001":
			print_debug("\n🔍 TESTING SOLID-001 (Main Wall with Door + Window):")
			var calculated = calculate_parent_values(entry, uuid_to_entry)
			
			print_debug("📈 EXPECTED vs CALCULATED:")
			print_debug("   Expected final_area: %.3f, Got: %.3f" % [42.0, calculated.final_area])  # 50-5-3=42
			print_debug("   Expected final_volume: %.3f, Got: %.3f" % [105.0, calculated.final_volume])  # 125-12.5-7.5=105
			print_debug("   Expected total_perimeter: %.3f, Got: %.3f" % [46.0, calculated.total_perimeter])  # 28+10+8=46
			print_debug("   Expected total_lateral_area: %.3f, Got: %.3f" % [90.0, calculated.total_lateral_area])  # 70+12.5+7.5=90
			break
	
	# Testează și solidele generate din tăiere (solid_flag=0)
	for entry in test_data:
		if entry.has("solid_flag") and int(entry["solid_flag"]) == 0:
			print_debug("\n🔍 TESTING CUT RESULT: " + str(entry.get("mesh_name", "Unknown")))
			print_debug("   UUID: " + str(entry.get("uuid", "N/A")))
			print_debug("   Area: %.3f" % float(entry.get("area", 0.0)))
			print_debug("   Volume: %.3f" % float(entry.get("volume", 0.0)))
			print_debug("   ✅ Cut results are final values (no further calculation needed)")
			break

func _on_refresh_pressed():
	print("Refreshing mapping data...")
	load_all_mappings()
	populate_tree()

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			# Verifică dacă clicul este în zona tree-ului
			if tree.get_global_rect().has_point(mouse_event.global_position):
				var selected_item = tree.get_selected()
				if selected_item:
					var local_pos = tree.get_local_mouse_position()
					var column = get_column_at_position(local_pos)
					if column >= 0:
						show_context_menu(selected_item, column, mouse_event.global_position)
						get_viewport().set_input_as_handled()
	
	# Shortcut F5 pentru refresh
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_F5:
			_on_refresh_pressed()
		elif event.pressed and event.keycode == KEY_F6:
			test_boolean_calculations()

func get_column_at_position(pos: Vector2) -> int:
	# Metodă simplificată pentru detectarea coloanei
	var x_offset = 0.0
	for i in range(tree.columns):
		var col_width = tree.size.x / float(tree.columns)  # Distribuție egală
		if pos.x >= x_offset and pos.x < x_offset + col_width:
			return i
		x_offset += col_width
	return -1

func show_context_menu(item: TreeItem, column: int, global_pos: Vector2):
	context_menu.clear()
	context_menu.add_item("Copy", 0)
	
	# Adaugă "Paste" doar pentru coloana 8 editabilă
	if column == 8 and item.is_editable(8):
		context_menu.add_item("Paste", 1)
	
	# Salvează contextul
	context_menu.set_meta("selected_column", column)
	context_menu.set_meta("selected_item", item)
	
	# Afișează meniul
	context_menu.position = Vector2i(global_pos)
	context_menu.popup()

func _on_context_menu_id_pressed(id: int):
	var selected_item = context_menu.get_meta("selected_item") as TreeItem
	var column = context_menu.get_meta("selected_column") as int
	
	if not selected_item:
		return
	
	match id:
		0: # Copy
			clipboard_value = selected_item.get_text(column)
			print("Copied from column %d: %s" % [column, clipboard_value])
		1: # Paste
			if column == 8 and selected_item.is_editable(8):
				selected_item.set_text(column, clipboard_value)
				# Trigger manual save
				tree.set_edited(selected_item)
				tree.set_meta("edited_column", column)
				_on_tree_item_edited()
				print("Pasted to column 8: ", clipboard_value)

func load_mapping(file_name: String):
	var file_path = "res://python/dxf/" + file_name
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			mapping_data[file_name] = json.data
			print_debug("Loaded mapping data for: " + file_name + " (" + str(json.data.size()) + " entries)")
		else:
			print_debug("Error parsing JSON for: " + file_name + " - " + json.get_error_message())
	else:
		print_debug("Could not open file: " + file_path)

func populate_tree():
	tree.clear()
	tree.set_columns(9)
	tree.set_column_title(0, "Element (Hierarchical)")
	tree.set_column_title(1, "UUID")
	tree.set_column_title(2, "Role")
	tree.set_column_title(3, "Area")
	tree.set_column_title(4, "Perimeter")
	tree.set_column_title(5, "Lateral Area")
	tree.set_column_title(6, "Volume")
	tree.set_column_title(7, "Vertices")
	tree.set_column_title(8, "Is cut by (UUIDs)")
	tree.set_column_titles_visible(true)
	
	var root = tree.create_item()
	
	for file_name in mapping_data.keys():
		var file_item = tree.create_item(root)
		file_item.set_text(0, file_name)
		
		# Creează mapping pentru UUID-uri
		var uuid_to_entry = {}
		for entry in mapping_data[file_name]:
			if entry.has("uuid"):
				uuid_to_entry[entry["uuid"]] = entry
		
		# Procesează solidele cu operații boolean și cele generate din tăiere
		for entry in mapping_data[file_name]:
			# Solidele normale cu operații boolean (role=1, is_cut_by există)
			if entry.has("role") and int(entry["role"]) == 1 and entry.has("is_cut_by"):
				var is_cut_by = entry["is_cut_by"] if entry.has("is_cut_by") else []
				
				# Doar solidele care sunt tăiate devin părinți
				if is_cut_by.size() > 0:
					create_hierarchical_item(file_item, entry, uuid_to_entry, file_name)
				else:
					# Solidele simple fără operații boolean rămân la nivel plat
					create_simple_item(file_item, entry, file_name)
			
			# Solidele generate din tăiere (solid_flag=0) - acestea sunt rezultatul tăierii
			elif entry.has("solid_flag") and int(entry["solid_flag"]) == 0:
				create_cut_result_item(file_item, entry, uuid_to_entry, file_name)
			
			# Alte elemente (voids, geometrie simplă) - exclude cele care au deja fost procesate
			elif not (entry.has("solid_flag") and int(entry["solid_flag"]) == 0) and not (entry.has("role") and int(entry["role"]) == 1):
				create_simple_item(file_item, entry, file_name)

func create_hierarchical_item(parent: TreeItem, solid_entry: Dictionary, uuid_to_entry: Dictionary, file_name: String):
	# Creează elementul părinte (rezultatul operației boolean)
	var parent_item = tree.create_item(parent)
	var parent_name = solid_entry["mesh_name"] if solid_entry.has("mesh_name") else "Unknown"
	var parent_uuid = solid_entry["uuid"] if solid_entry.has("uuid") else ""
	
	# Calculează valorile finale ale părintelui
	var calculated_values = calculate_parent_values(solid_entry, uuid_to_entry)
	
	parent_item.set_text(0, "🔗 " + parent_name + " (BOOLEAN RESULT)")
	parent_item.set_text(1, parent_uuid)
	parent_item.set_text(2, "PARENT")
	parent_item.set_text(3, "%.3f" % calculated_values.final_area)
	parent_item.set_text(4, "%.3f" % calculated_values.total_perimeter)
	parent_item.set_text(5, "%.3f" % calculated_values.total_lateral_area)
	parent_item.set_text(6, "%.3f" % calculated_values.final_volume)
	parent_item.set_text(7, str(solid_entry["vertices"]) if solid_entry.has("vertices") else "[]")
	parent_item.set_text(8, str(solid_entry["is_cut_by"]))
	
	# Face părinte-ul editabil
	parent_item.set_editable(8, true)
	parent_item.set_metadata(0, {"file_name": file_name, "uuid": parent_uuid})
	
	# Adaugă geometria brută ca primul copil
	var raw_child = tree.create_item(parent_item)
	raw_child.set_text(0, "📦 " + parent_name + " (RAW SOLID)")
	raw_child.set_text(1, parent_uuid)
	raw_child.set_text(2, "RAW")
	raw_child.set_text(3, "%.3f" % float(solid_entry.get("area", 0.0)))
	raw_child.set_text(4, "%.3f" % float(solid_entry.get("perimeter", 0.0)))
	raw_child.set_text(5, "%.3f" % float(solid_entry.get("lateral_area", 0.0)))
	raw_child.set_text(6, "%.3f" % float(solid_entry.get("volume", 0.0)))
	raw_child.set_text(7, str(solid_entry["vertices"]) if solid_entry.has("vertices") else "[]")
	raw_child.set_text(8, "-")
	
	# Adaugă toate void-urile ca copii
	var is_cut_by = solid_entry["is_cut_by"] if solid_entry.has("is_cut_by") else []
	for void_uuid in is_cut_by:
		if uuid_to_entry.has(void_uuid):
			var void_entry = uuid_to_entry[void_uuid]
			var void_child = tree.create_item(parent_item)
			var void_name = void_entry["mesh_name"] if void_entry.has("mesh_name") else "Unknown Void"
			
			void_child.set_text(0, "✂️ " + void_name + " (CUTTING VOID)")
			void_child.set_text(1, void_uuid)
			void_child.set_text(2, "VOID")
			void_child.set_text(3, "%.3f" % float(void_entry.get("area", 0.0)))
			void_child.set_text(4, "%.3f" % float(void_entry.get("perimeter", 0.0)))
			void_child.set_text(5, "%.3f" % float(void_entry.get("lateral_area", 0.0)))
			void_child.set_text(6, "%.3f" % float(void_entry.get("volume", 0.0)))
			void_child.set_text(7, str(void_entry["vertices"]) if void_entry.has("vertices") else "[]")
			void_child.set_text(8, "-")

func create_cut_result_item(parent: TreeItem, cut_entry: Dictionary, uuid_to_entry: Dictionary, file_name: String):
	# Creează element părinte pentru solide generate din tăiere (solid_flag=0)
	var parent_item = tree.create_item(parent)
	var parent_name = cut_entry["mesh_name"] if cut_entry.has("mesh_name") else "Unknown Cut"
	var parent_uuid = cut_entry["uuid"] if cut_entry.has("uuid") else ""
	
	# Pentru solidele generate din tăiere, valorile sunt deja finale
	var final_area = float(cut_entry.get("area", 0.0))
	var final_volume = float(cut_entry.get("volume", 0.0))
	var final_perimeter = float(cut_entry.get("perimeter", 0.0))
	var final_lateral_area = float(cut_entry.get("lateral_area", 0.0))
	
	parent_item.set_text(0, "🔄 " + parent_name + " (CUT RESULT)")
	parent_item.set_text(1, parent_uuid)
	parent_item.set_text(2, "CUT_RESULT")
	parent_item.set_text(3, "%.3f" % final_area)
	parent_item.set_text(4, "%.3f" % final_perimeter)
	parent_item.set_text(5, "%.3f" % final_lateral_area)
	parent_item.set_text(6, "%.3f" % final_volume)
	parent_item.set_text(7, str(cut_entry["vertices"]) if cut_entry.has("vertices") else "[]")
	parent_item.set_text(8, "-")
	
	# Adaugă rezultatul tăierii ca primul copil
	var result_child = tree.create_item(parent_item)
	result_child.set_text(0, "📐 " + parent_name + " (FINAL GEOMETRY)")
	result_child.set_text(1, parent_uuid)
	result_child.set_text(2, "FINAL")
	result_child.set_text(3, "%.3f" % final_area)
	result_child.set_text(4, "%.3f" % final_perimeter)
	result_child.set_text(5, "%.3f" % final_lateral_area)
	result_child.set_text(6, "%.3f" % final_volume)
	result_child.set_text(7, str(cut_entry["vertices"]) if cut_entry.has("vertices") else "[]")
	result_child.set_text(8, "-")
	
	# Adaugă informații despre voidurile care au tăiat (generic "Cut")
	# Pentru solidele cu solid_flag=0, nu avem explicit is_cut_by, dar putem deduce
	var cut_info_child = tree.create_item(parent_item)
	cut_info_child.set_text(0, "✂️ Cut (GENERIC CUTTING OPERATION)")
	cut_info_child.set_text(1, "generic-cut")
	cut_info_child.set_text(2, "CUT_INFO")
	cut_info_child.set_text(3, "N/A")
	cut_info_child.set_text(4, "N/A")
	cut_info_child.set_text(5, "N/A")
	cut_info_child.set_text(6, "N/A")
	cut_info_child.set_text(7, "[]")
	cut_info_child.set_text(8, "Generated by cutting operation")

func create_simple_item(parent: TreeItem, entry: Dictionary, file_name: String):
	# Creează elemente simple fără operații boolean
	var elem_item = tree.create_item(parent)
	var name = entry["mesh_name"] if entry.has("mesh_name") else "-"
	var uuid = entry["uuid"] if entry.has("uuid") else "-"
	var role = str(entry["role"]) if entry.has("role") else "0"
	var area = "%.3f" % float(entry["area"]) if entry.has("area") else "0.000"
	var perimeter = "%.3f" % float(entry["perimeter"]) if entry.has("perimeter") else "0.000"
	var lateral_area = "%.3f" % float(entry["lateral_area"]) if entry.has("lateral_area") else "0.000"
	var volume = "%.3f" % float(entry["volume"]) if entry.has("volume") else "0.000"
	var vertices = str(entry["vertices"]) if entry.has("vertices") else "[]"
	
	elem_item.set_text(0, "⬜ " + name + " (SIMPLE)")
	elem_item.set_text(1, uuid)
	elem_item.set_text(2, role)
	elem_item.set_text(3, area)
	elem_item.set_text(4, perimeter)
	elem_item.set_text(5, lateral_area)
	elem_item.set_text(6, volume)
	elem_item.set_text(7, vertices)
	elem_item.set_text(8, "[]")
	
	elem_item.set_metadata(0, {"file_name": file_name, "uuid": uuid})

func calculate_parent_values(solid_entry: Dictionary, uuid_to_entry: Dictionary) -> Dictionary:
	# Calcule matematice pentru valorile finale ale părintelui
	var raw_area = float(solid_entry.get("area", 0.0))
	var raw_perimeter = float(solid_entry.get("perimeter", 0.0))
	var raw_lateral_area = float(solid_entry.get("lateral_area", 0.0))
	var raw_volume = float(solid_entry.get("volume", 0.0))
	
	var void_total_area = 0.0
	var void_total_perimeter = 0.0
	var void_total_lateral_area = 0.0
	var void_total_volume = 0.0
	
	var solid_uuid = solid_entry.get("uuid", "N/A")
	print_debug("🔢 BOOLEAN MATH pentru solid UUID: " + str(solid_uuid))
	print_debug("   RAW SOLID: area=%.3f, volume=%.3f, perimeter=%.3f, lateral=%.3f" % [raw_area, raw_volume, raw_perimeter, raw_lateral_area])
	
	# Sumează valorile tuturor void-urilor
	var is_cut_by = solid_entry["is_cut_by"] if solid_entry.has("is_cut_by") else []
	print_debug("   PROCESSING " + str(is_cut_by.size()) + " VOIDS: " + str(is_cut_by))
	
	for void_uuid in is_cut_by:
		if uuid_to_entry.has(void_uuid):
			var void_entry = uuid_to_entry[void_uuid]
			var v_area = float(void_entry.get("area", 0.0))
			var v_perimeter = float(void_entry.get("perimeter", 0.0))
			var v_lateral = float(void_entry.get("lateral_area", 0.0))
			var v_volume = float(void_entry.get("volume", 0.0))
			
			void_total_area += v_area
			void_total_perimeter += v_perimeter
			void_total_lateral_area += v_lateral
			void_total_volume += v_volume
			
			print_debug("   VOID " + str(void_uuid) + ": area=%.3f, volume=%.3f, perimeter=%.3f, lateral=%.3f" % [v_area, v_volume, v_perimeter, v_lateral])
		else:
			print_debug("   ⚠️ VOID UUID NOT FOUND: " + str(void_uuid))
	
	# Calculează valorile finale conform relațiilor matematice
	var final_area = raw_area - void_total_area
	var final_volume = raw_volume - void_total_volume
	var total_perimeter = raw_perimeter + void_total_perimeter
	var total_lateral_area = raw_lateral_area + void_total_lateral_area
	
	print_debug("   CALCULATIONS:")
	print_debug("   final_area = %.3f - %.3f = %.3f" % [raw_area, void_total_area, final_area])
	print_debug("   final_volume = %.3f - %.3f = %.3f" % [raw_volume, void_total_volume, final_volume])
	print_debug("   total_perimeter = %.3f + %.3f = %.3f" % [raw_perimeter, void_total_perimeter, total_perimeter])
	print_debug("   total_lateral_area = %.3f + %.3f = %.3f" % [raw_lateral_area, void_total_lateral_area, total_lateral_area])
	
	return {
		"final_area": final_area,              # Area solidului - aria void-urilor
		"final_volume": final_volume,        # Volumul solidului - volumul void-urilor
		"total_perimeter": total_perimeter,  # Suma perimetrelor
		"total_lateral_area": total_lateral_area,  # Suma ariilor laterale
		"void_count": is_cut_by.size(),
		"void_total_area": void_total_area,
		"void_total_volume": void_total_volume
	}

func _on_tree_item_edited():
	var edited_item = tree.get_edited()
	var column = tree.get_edited_column()
	
	# Pentru paste manual, folosim meta data
	if column == -1 and tree.has_meta("edited_column"):
		column = tree.get_meta("edited_column")
		tree.remove_meta("edited_column")
	
	if column == 8:  # Coloana "Is cut by"
		var metadata = edited_item.get_metadata(0)
		if metadata and metadata.has("file_name") and metadata.has("uuid"):
			var file_name = metadata["file_name"]
			var uuid = metadata["uuid"]
			var new_value = edited_item.get_text(8)
			
			# Parsează noul array de UUIDs
			var parsed_array = JSON.parse_string(new_value)
			if typeof(parsed_array) == TYPE_ARRAY:
				# Actualizează mapping_data
				for entry in mapping_data[file_name]:
					if entry.has("uuid") and entry["uuid"] == uuid:
						entry["is_cut_by"] = parsed_array
						# Salvează înapoi în fișier
						save_mapping(file_name)
						
						# Recalculează și actualizează valorile părintelui în timp real
						update_parent_calculated_values(edited_item, entry, file_name)
						break
			else:
				push_warning("Invalid JSON array format for is_cut_by")
				# Resetează la valoarea anterioară
				populate_tree()

func update_parent_calculated_values(parent_item: TreeItem, solid_entry: Dictionary, file_name: String):
	# Recalculează valorile părintelui după modificarea relațiilor
	var uuid_to_entry = {}
	for entry in mapping_data[file_name]:
		if entry.has("uuid"):
			uuid_to_entry[entry["uuid"]] = entry
	
	var calculated_values = calculate_parent_values(solid_entry, uuid_to_entry)
	
	# Actualizează valorile în tabel
	parent_item.set_text(3, "%.3f" % calculated_values.final_area)
	parent_item.set_text(4, "%.3f" % calculated_values.total_perimeter)
	parent_item.set_text(5, "%.3f" % calculated_values.total_lateral_area)
	parent_item.set_text(6, "%.3f" % calculated_values.final_volume)
	
	# Actualizează structura ierarhică pentru a reflecta noile relații
	refresh_parent_children(parent_item, solid_entry, uuid_to_entry)

func refresh_parent_children(parent_item: TreeItem, solid_entry: Dictionary, uuid_to_entry: Dictionary):
	# Șterge toți copiii existenți
	var child = parent_item.get_first_child()
	while child:
		var next_child = child.get_next()
		child.free()
		child = next_child
	
	# Recreează copiii cu noile relații
	var parent_name = solid_entry["mesh_name"] if solid_entry.has("mesh_name") else "Unknown"
	var parent_uuid = solid_entry["uuid"] if solid_entry.has("uuid") else ""
	
	# Adaugă geometria brută ca primul copil
	var raw_child = tree.create_item(parent_item)
	raw_child.set_text(0, "📦 " + parent_name + " (RAW SOLID)")
	raw_child.set_text(1, parent_uuid)
	raw_child.set_text(2, "RAW")
	raw_child.set_text(3, "%.3f" % float(solid_entry.get("area", 0.0)))
	raw_child.set_text(4, "%.3f" % float(solid_entry.get("perimeter", 0.0)))
	raw_child.set_text(5, "%.3f" % float(solid_entry.get("lateral_area", 0.0)))
	raw_child.set_text(6, "%.3f" % float(solid_entry.get("volume", 0.0)))
	raw_child.set_text(7, str(solid_entry["vertices"]) if solid_entry.has("vertices") else "[]")
	raw_child.set_text(8, "-")
	
	# Adaugă toate void-urile ca copii
	var is_cut_by = solid_entry["is_cut_by"] if solid_entry.has("is_cut_by") else []
	for void_uuid in is_cut_by:
		if uuid_to_entry.has(void_uuid):
			var void_entry = uuid_to_entry[void_uuid]
			var void_child = tree.create_item(parent_item)
			var void_name = void_entry["mesh_name"] if void_entry.has("mesh_name") else "Unknown Void"
			
			void_child.set_text(0, "✂️ " + void_name + " (CUTTING VOID)")
			void_child.set_text(1, void_uuid)
			void_child.set_text(2, "VOID")
			void_child.set_text(3, "%.3f" % float(void_entry.get("area", 0.0)))
			void_child.set_text(4, "%.3f" % float(void_entry.get("perimeter", 0.0)))
			void_child.set_text(5, "%.3f" % float(void_entry.get("lateral_area", 0.0)))
			void_child.set_text(6, "%.3f" % float(void_entry.get("volume", 0.0)))
			void_child.set_text(7, str(void_entry["vertices"]) if void_entry.has("vertices") else "[]")
			void_child.set_text(8, "-")

func save_mapping(file_name: String):
	var file_path = mapping_folder + file_name
	var json_str = JSON.stringify(mapping_data[file_name], "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		print("Saved changes to: ", file_name)
	else:
		push_error("Failed to save file: ", file_name)
