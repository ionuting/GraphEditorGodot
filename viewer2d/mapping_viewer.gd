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

func load_all_mappings():
	mapping_data.clear()
	var dir = DirAccess.open(mapping_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with("_mapping.json"):
				var file_path = mapping_folder + file_name
				var json_str = FileAccess.get_file_as_string(file_path)
				var arr = JSON.parse_string(json_str)
				if typeof(arr) == TYPE_ARRAY:
					mapping_data[file_name] = arr
					print("Loaded mapping: %s with %d entries" % [file_name, arr.size()])
			file_name = dir.get_next()
		dir.list_dir_end()

func populate_tree():
	tree.clear()
	tree.set_columns(9)
	tree.set_column_title(0, "File/Element")
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
		
		var uuid_to_entry = {}
		for entry in mapping_data[file_name]:
			if entry.has("uuid"):
				uuid_to_entry[entry["uuid"]] = entry
		
		for entry in mapping_data[file_name]:
			if entry.has("role") and (int(entry["role"]) == 1 or int(entry["role"]) == -1):
				var elem_item = tree.create_item(file_item)
				var name = entry["mesh_name"] if entry.has("mesh_name") else "-"
				var uuid = entry["uuid"] if entry.has("uuid") else "-"
				var role = str(entry["role"]) if entry.has("role") else "0"
				var area = "%.3f" % float(entry["area"]) if entry.has("area") else "0.000"
				var perimeter = "%.3f" % float(entry["perimeter"]) if entry.has("perimeter") else "0.000"
				var lateral_area = "%.3f" % float(entry["lateral_area"]) if entry.has("lateral_area") else "0.000"
				var volume = "%.3f" % float(entry["volume"]) if entry.has("volume") else "0.000"
				var vertices = str(entry["vertices"]) if entry.has("vertices") else "[]"
				
				# Citește is_cut_by din JSON
				var is_cut_by = []
				if entry.has("is_cut_by"):
					is_cut_by = entry["is_cut_by"]
					if is_cut_by.size() > 0:
						print("Solid %s is cut by: %s" % [uuid, str(is_cut_by)])
				
				elem_item.set_text(0, name)
				elem_item.set_text(1, uuid)
				elem_item.set_text(2, role)
				elem_item.set_text(3, area)
				elem_item.set_text(4, perimeter)
				elem_item.set_text(5, lateral_area)
				elem_item.set_text(6, volume)
				elem_item.set_text(7, vertices)
				elem_item.set_text(8, str(is_cut_by))
				
				# Face coloana 8 editabilă doar pentru solide (role == 1)
				if int(role) == 1:
					elem_item.set_editable(8, true)
				
				# Salvează metadata pentru a putea actualiza JSON-ul
				elem_item.set_metadata(0, {"file_name": file_name, "uuid": uuid})

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
						break
			else:
				push_warning("Invalid JSON array format for is_cut_by")
				# Resetează la valoarea anterioară
				populate_tree()

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
