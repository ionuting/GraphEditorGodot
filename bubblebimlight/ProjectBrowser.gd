extends Control

@onready var tree: Tree = $Tree
var edit_dialog: AcceptDialog
var name_edit: LineEdit
var bottom_spin: SpinBox
var top_spin: SpinBox
var editing_level_index: int = -1

# Structura nivelurilor cu bottom/top
var levels = [
	{"name": "Foundations", "bottom": -1.75, "top": 0.0},
	{"name": "Ground Floor", "bottom": 0.0, "top": 2.8},
	{"name": "First floor", "bottom": 2.8, "top": 5.6},
	{"name": "Second Floor", "bottom": 5.6, "top": 8.4}
]

var context_menu: PopupMenu

func _ready():
	# Creează header-ul mai întâi
	_create_header()
	
	# UI pentru editare
	_create_edit_dialog()
	_create_context_menu()
	
	# Setează arborele după ce header-ul este creat
	_setup_tree()
	
	# Conectează semnalurile
	tree.gui_input.connect(_on_tree_gui_input)

func _setup_tree():
	# Curăță arborele dacă există deja conținut
	tree.clear()
	
	# Setează coloana și headerul pentru Tree
	tree.set_column_titles_visible(true)
	tree.set_column_title(0, "Project")

	# Creează structura de proiect - NU mai apelăm tree.create_item() gol
	var root = tree.create_item()
	root.set_text(0, "Project")
	root.set_selectable(0, false)

	var building_factory = tree.create_item(root)
	building_factory.set_text(0, "Building Factory")

	# Adaugă nivelurile cu bottom/top
	for level in levels:
		var item = tree.create_item(building_factory)
		item.set_text(0, "%s (%.2f → %.2f m)" % [level.name, level.bottom, level.top])

	# Extinde tot arborele la pornire
	expand_all_items(root)

func _create_header():
	# Creează un header cu titlu și butoane pentru Tree

	var header = HBoxContainer.new()
	header.anchor_left = 0
	header.anchor_right = 1
	header.anchor_top = 0
	header.anchor_bottom = 0
	header.offset_left = 0
	header.offset_right = 0
	header.offset_top = 0
	header.offset_bottom = 32
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.size_flags_vertical = 0
	# pune header ca și child al Tree astfel încât să fie în același container
	if is_instance_valid(tree):
		tree.add_child(header)
	else:
		add_child(header)

	var tree_label = Label.new()
	tree_label.text = "Project Levels"
	tree_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tree_label)

	var add_level_btn = Button.new()
	add_level_btn.text = "+"
	add_level_btn.tooltip_text = "Add Level"
	add_level_btn.size_flags_horizontal = 0
	add_level_btn.size_flags_vertical = 0
	add_level_btn.custom_minimum_size = Vector2(32, 32)
	# păstrează butonul funcțional (refolosește aceeași funcție de add)
	add_level_btn.pressed.connect(_on_add_level_pressed)
	header.add_child(add_level_btn)

	var remove_level_btn = Button.new()
	remove_level_btn.text = "-"
	remove_level_btn.tooltip_text = "Delete Selected Level"
	remove_level_btn.size_flags_horizontal = 0
	remove_level_btn.size_flags_vertical = 0
	remove_level_btn.custom_minimum_size = Vector2(32, 32)
	remove_level_btn.pressed.connect(_on_remove_level_pressed)
	header.add_child(remove_level_btn)

# Funcție pentru adăugare nivel nou
func _on_add_level_pressed():
	# Creează un nume unic
	var new_level_idx = levels.size() + 1
	var new_name = "Level %d" % new_level_idx
	
	# Calculează bottom și top
	var new_bottom = 0.0
	var new_top = 2.8
	if levels.size() > 0:
		new_bottom = levels[-1].top
		new_top = new_bottom + 2.8
	
	var new_level = {"name": new_name, "bottom": new_bottom, "top": new_top}
	levels.append(new_level)

	# Găsește nodul "Building Factory"
	var building_factory_node = _find_building_factory_node()
	
	if not building_factory_node:
		print("ERROR: Building Factory node not found!")
		return
	
	# Adaugă noul nivel ca și copil al Building Factory
	var new_item = tree.create_item(building_factory_node)
	new_item.set_text(0, "%s (%.2f → %.2f m)" % [new_level.name, new_level.bottom, new_level.top])
	
	# Extinde tot arborele
	expand_all_items(tree.get_root())
	
	# Selectează noul nivel
	new_item.select(0)

# Găsește nodul Building Factory
func _find_building_factory_node() -> TreeItem:
	var root = tree.get_root()
	if not root:
		print("No root found")
		return null
	
	# Debug - să vedem ce copii are root-ul
	print("Root text: ", root.get_text(0))
	var child = root.get_first_child()
	print("Root children:")
	while child:
		print("  - Child: ", child.get_text(0))
		if child.get_text(0) == "Building Factory":
			print("Found Building Factory!")
			return child
		child = child.get_next()
	
	print("Building Factory not found in children")
	return null

# Șterge nivelul selectat
func _on_remove_level_pressed():
	var selected = tree.get_selected()
	if not selected:
		print("No item selected")
		return
	
	var parent = selected.get_parent()
	if not parent:
		print("Selected item has no parent")
		return
	
	# Doar dacă e copil direct al Building Factory
	if parent.get_text(0) != "Building Factory":
		print("Selected item is not a direct child of Building Factory")
		return
	
	# Găsește indexul în levels
	var name = selected.get_text(0).split(" (")[0]
	for i in range(levels.size()):
		if levels[i].name == name:
			levels.remove_at(i)
			print("Removed level: ", name)
			break
	
	# Șterge itemul din arbore
	selected.free()

# Creează dialogul de editare cu nume, bottom și top
func _create_edit_dialog():
	edit_dialog = AcceptDialog.new()
	edit_dialog.dialog_text = "Edit Level Properties"
	edit_dialog.title = "Edit Level"
	edit_dialog.min_size = Vector2(350, 180)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# Campo pentru nume
	var name_label = Label.new()
	name_label.text = "Level Name:"
	vbox.add_child(name_label)
	
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Enter level name..."
	vbox.add_child(name_edit)
	
	# Separator
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# Campo pentru bottom
	var bottom_label = Label.new()
	bottom_label.text = "Bottom Level (m):"
	vbox.add_child(bottom_label)
	
	bottom_spin = SpinBox.new()
	bottom_spin.min_value = -100
	bottom_spin.max_value = 100
	bottom_spin.step = 0.01
	bottom_spin.value_changed.connect(_on_bottom_value_changed)
	vbox.add_child(bottom_spin)
	
	# Campo pentru top
	var top_label = Label.new()
	top_label.text = "Top Level (m):"
	vbox.add_child(top_label)
	
	top_spin = SpinBox.new()
	top_spin.min_value = -100
	top_spin.max_value = 100
	top_spin.step = 0.01
	top_spin.value_changed.connect(_on_top_value_changed)
	vbox.add_child(top_spin)
	
	edit_dialog.add_child(vbox)
	edit_dialog.get_ok_button().text = "Save"
	edit_dialog.confirmed.connect(_on_edit_dialog_save)
	add_child(edit_dialog)

# Validare ca bottom să fie mai mic ca top
func _on_bottom_value_changed(value: float):
	if value >= top_spin.value:
		top_spin.value = value + 0.1

func _on_top_value_changed(value: float):
	if value <= bottom_spin.value:
		bottom_spin.value = value - 0.1

# Deschide dialogul la dublu-click pe nivel
func _on_tree_item_activated():
	var item = tree.get_selected()
	if not item:
		return
	
	var parent = item.get_parent()
	if not parent or parent.get_text(0) != "Building Factory":
		return
	
	var name = item.get_text(0).split(" (")[0]
	for i in range(levels.size()):
		if levels[i].name == name:
			editing_level_index = i
			var level = levels[i]
			name_edit.text = level.name
			bottom_spin.value = level.bottom
			top_spin.value = level.top
			edit_dialog.popup_centered()
			break

# Salvează valorile editate
func _on_edit_dialog_save():
	if editing_level_index >= 0 and editing_level_index < levels.size():
		var new_name = name_edit.text.strip_edges()
		
		# Validare nume
		if new_name == "":
			print("Level name cannot be empty!")
			return
		
		# Verifică dacă numele există deja (exceptând nivelul curent)
		for i in range(levels.size()):
			if i != editing_level_index and levels[i].name == new_name:
				print("Level name already exists: ", new_name)
				return
		
		# Actualizează nivelul
		levels[editing_level_index].name = new_name
		levels[editing_level_index].bottom = bottom_spin.value
		levels[editing_level_index].top = top_spin.value
		
		# Actualizează UI-ul
		_update_tree_texts()
		
		print("Updated level: ", levels[editing_level_index])
	
	editing_level_index = -1

# Funcție recursivă pentru a extinde toate nodurile
func expand_all_items(item: TreeItem):
	if item == null:
		return
	item.set_collapsed(false)
	var child = item.get_first_child()
	while child:
		expand_all_items(child)
		child = child.get_next()

# Actualizează textele în arbore
func _update_tree_texts():
	var building_factory_node = _find_building_factory_node()
	if not building_factory_node:
		return
	
	var item = building_factory_node.get_first_child()
	var idx = 0
	
	while item and idx < levels.size():
		item.set_text(0, "%s (%.2f → %.2f m)" % [levels[idx].name, levels[idx].bottom, levels[idx].top])
		item = item.get_next()
		idx += 1

# Serializare niveluri în JSON
func serialize_levels_to_json() -> String:
	var dict = {}
	for level in levels:
		dict[level.name] = {"bottom": level.bottom, "top": level.top}
	return JSON.stringify(dict, "  ")

# Funcție pentru editare programatică a unui nivel
func set_level_properties(level_name: String, new_name: String = "", new_bottom: float = 0.0, new_top: float = 0.0):
	for level in levels:
		if level.name == level_name:
			if new_name != "":
				level.name = new_name
			level.bottom = new_bottom
			level.top = new_top
			_update_tree_texts()
			break

# Obține informații despre un nivel
func get_level_info(level_name: String) -> Dictionary:
	for level in levels:
		if level.name == level_name:
			return level.duplicate()
	return {}

# Obține toate nivelurile
func get_all_levels() -> Array:
	var result = []
	for level in levels:
		result.append(level.duplicate())
	return result

# Importă niveluri dintr-un JSON
func import_levels_from_json(json_string: String) -> bool:
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Error parsing JSON: ", json.get_error_message())
		return false
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		print("JSON data is not a dictionary")
		return false
	
	levels.clear()
	for level_name in data.keys():
		var level_data = data[level_name]
		if typeof(level_data) == TYPE_DICTIONARY and "bottom" in level_data and "top" in level_data:
			levels.append({
				"name": level_name,
				"bottom": level_data.bottom,
				"top": level_data.top
			})
	
	# Reconstruiește arborele
	_rebuild_tree()
	return true

# Reconstruiește complet arborele
func _rebuild_tree():
	tree.clear()
	
	# Recrează structura
	tree.create_item()
	var root = tree.create_item()
	root.set_text(0, "Project")
	root.set_selectable(0, false)

	var building_factory = tree.create_item(root)
	building_factory.set_text(0, "Building Factory")

	# Adaugă nivelurile
	for level in levels:
		var item = tree.create_item(building_factory)
		item.set_text(0, "%s (%.2f → %.2f m)" % [level.name, level.bottom, level.top])

	# Extinde tot arborele
	expand_all_items(root)

# Creează meniul contextual (Properties / Delete / Add)
func _create_context_menu():
	context_menu = PopupMenu.new()
	context_menu.name = "ProjectContextMenu"
	# ordinea: Properties, Add Level, Delete
	context_menu.add_item("Properties", 1)
	context_menu.add_item("Add Level", 3)
	context_menu.add_item("Delete", 2)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(context_menu)

# Prinde evenimente GUI pe Tree (click dreapta)
func _on_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var item = tree.get_selected()
			if not item:
				# opțional: selectează item-ul sub cursor dacă vrei (necesită mapare coordonate)
				print("No tree item selected for context menu")
				return
			# afișează meniul contextual (centrat simplu)
			context_menu.popup_centered()

# Tratare selecții din meniul contextual
func _on_context_menu_id_pressed(id: int) -> void:
	if id == 1:
		_open_properties_for_selected()
	elif id == 2:
		_on_remove_level_pressed()
	elif id == 3:
		_on_add_level_pressed()

# Deschide dialogul de properties pentru item-ul selectat
func _open_properties_for_selected():
	var item = tree.get_selected()
	if not item:
		return
	var parent = item.get_parent()
	if not parent or parent.get_text(0) != "Building Factory":
		return
	var name = item.get_text(0).split(" (")[0]
	for i in range(levels.size()):
		if levels[i].name == name:
			editing_level_index = i
			var level = levels[i]
			name_edit.text = level.name
			bottom_spin.value = level.bottom
			top_spin.value = level.top
			edit_dialog.popup_centered()
			return
