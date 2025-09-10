extends Control
class_name ProjectBrowser

signal storey_opened(storey_data)
signal storey_closed(storey_id)
signal storey_added(storey_data)
signal storey_removed(storey_id)
signal storey_updated(storey_data)

# Componente UI
var tree: Tree
var add_storey_btn: Button
var remove_storey_btn: Button
var properties_container: VBoxContainer

# Date și referințe
var root_item: TreeItem
var project_item: TreeItem
var current_item: TreeItem
var storeys_data: Dictionary = {}  # id -> storey_data
var next_storey_id: int = 1

# Constante
const DEFAULT_FOUNDATION_NAME = "Foundation"
const DEFAULT_FIRST_FLOOR_NAME = "First Floor"
const DEFAULT_SECOND_FLOOR_NAME = "Second Floor"

func _init():
	_setup_ui()
	_setup_initial_data()
	_update_tree()

func _setup_ui():
	# Container principal
	self.name = "ProjectBrowser"
	self.anchor_right = 1.0
	self.anchor_bottom = 1.0
	self.size_flags_vertical = SIZE_EXPAND_FILL
	
	# Adăugăm un StyleBox pentru fundal
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style_box)
	add_child(panel)
	
	# Container vertical principal
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(main_container)
	
	# Titlu
	var title = Label.new()
	title.text = "Project Browser"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	main_container.add_child(HSeparator.new())
	
	# Tree View pentru proiect și etaje
	tree = Tree.new()
	tree.size_flags_vertical = SIZE_EXPAND_FILL
	tree.allow_reselect = true
	tree.custom_minimum_size = Vector2(0, 200)
	tree.columns = 1
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_SINGLE
	tree.item_selected.connect(_on_tree_item_selected)
	tree.item_activated.connect(_on_tree_item_activated)
	main_container.add_child(tree)
	
	# Butoane pentru adăugare/ștergere etaje
	var buttons_container = HBoxContainer.new()
	buttons_container.size_flags_horizontal = SIZE_EXPAND_FILL
	main_container.add_child(buttons_container)
	
	add_storey_btn = Button.new()
	add_storey_btn.text = "Add Storey"
	add_storey_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	add_storey_btn.pressed.connect(_on_add_storey_pressed)
	buttons_container.add_child(add_storey_btn)
	
	remove_storey_btn = Button.new()
	remove_storey_btn.text = "Remove Storey"
	remove_storey_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	remove_storey_btn.pressed.connect(_on_remove_storey_pressed)
	remove_storey_btn.disabled = true
	buttons_container.add_child(remove_storey_btn)
	
	main_container.add_child(HSeparator.new())
	
	# Container pentru proprietăți
	var properties_label = Label.new()
	properties_label.text = "Properties"
	properties_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(properties_label)
	
	properties_container = VBoxContainer.new()
	properties_container.size_flags_vertical = SIZE_EXPAND_FILL
	main_container.add_child(properties_container)
	
	_setup_properties_ui()

func _setup_properties_ui():
	# Vom popula acest container când se selectează un etaj
	properties_container.add_child(Label.new())  # Placeholder

func _setup_initial_data():
	# Creare date inițiale pentru proiect cu 3 etaje default
	_add_storey_data(DEFAULT_FOUNDATION_NAME, 0.0, 3.0)   # Foundation
	_add_storey_data(DEFAULT_FIRST_FLOOR_NAME, 3.0, 6.0)  # First Floor
	_add_storey_data(DEFAULT_SECOND_FLOOR_NAME, 6.0, 9.0) # Second Floor

func _add_storey_data(name: String, base_level: float, top_level: float) -> Dictionary:
	var storey_id = "storey_" + str(next_storey_id)
	next_storey_id += 1
	
	var storey_data = {
		"id": storey_id,
		"name": name,
		"base_level": base_level,
		"top_level": top_level,
		"canvas": null,  # Va fi creat când se deschide etajul
		"visible": true,
		"canvas_dirty": false
	}
	
	storeys_data[storey_id] = storey_data
	storey_added.emit(storey_data)
	
	return storey_data

func _update_tree():
	tree.clear()
	root_item = tree.create_item()
	
	# Elementul Project
	project_item = tree.create_item(root_item)
	project_item.set_text(0, "Project")
	project_item.set_icon(0, get_theme_icon("Folder", "EditorIcons") if has_theme_icon("Folder", "EditorIcons") else null)
	
	# Elementul Storeys (container pentru etaje)
	var storeys_item = tree.create_item(project_item)
	storeys_item.set_text(0, "Storeys")
	storeys_item.set_icon(0, get_theme_icon("Folder", "EditorIcons") if has_theme_icon("Folder", "EditorIcons") else null)
	
	# Adăugăm etajele în ordine, de jos în sus
	var sorted_storeys = []
	for storey_id in storeys_data:
		sorted_storeys.append(storeys_data[storey_id])
	
	# Sortare după base_level (de jos în sus)
	sorted_storeys.sort_custom(func(a, b): return a.base_level < b.base_level)
	
	# Adăugare în tree
	for storey_data in sorted_storeys:
		var storey_item = tree.create_item(storeys_item)
		storey_item.set_text(0, storey_data.name)
		storey_item.set_icon(0, get_theme_icon("CanvasItem", "EditorIcons") if has_theme_icon("CanvasItem", "EditorIcons") else null)
		storey_item.set_metadata(0, storey_data.id)

# Actualizarea UI-ului de proprietăți când se selectează un etaj
func _update_properties_ui(storey_data: Dictionary):
	# Curățăm containerul de proprietăți
	for child in properties_container.get_children():
		child.queue_free()
	
	# Titlu
	var title = Label.new()
	title.text = "Storey Properties"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	properties_container.add_child(title)
	
	properties_container.add_child(HSeparator.new())
	
	# Proprietate: Nume
	var name_container = HBoxContainer.new()
	name_container.size_flags_horizontal = SIZE_EXPAND_FILL
	properties_container.add_child(name_container)
	
	var name_label = Label.new()
	name_label.text = "Name:"
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_container.add_child(name_label)
	
	var name_edit = LineEdit.new()
	name_edit.text = storey_data.name
	name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(new_text): _on_storey_name_changed(storey_data.id, new_text))
	name_container.add_child(name_edit)
	
	# Proprietate: Base Level
	var base_container = HBoxContainer.new()
	base_container.size_flags_horizontal = SIZE_EXPAND_FILL
	properties_container.add_child(base_container)
	
	var base_label = Label.new()
	base_label.text = "Base Level:"
	base_label.size_flags_horizontal = SIZE_EXPAND_FILL
	base_container.add_child(base_label)
	
	var base_spin = SpinBox.new()
	base_spin.min_value = -50.0
	base_spin.max_value = 200.0
	base_spin.step = 0.1
	base_spin.value = storey_data.base_level
	base_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	base_spin.value_changed.connect(func(value): _on_storey_base_level_changed(storey_data.id, value))
	base_container.add_child(base_spin)
	
	# Proprietate: Top Level
	var top_container = HBoxContainer.new()
	top_container.size_flags_horizontal = SIZE_EXPAND_FILL
	properties_container.add_child(top_container)
	
	var top_label = Label.new()
	top_label.text = "Top Level:"
	top_label.size_flags_horizontal = SIZE_EXPAND_FILL
	top_container.add_child(top_label)
	
	var top_spin = SpinBox.new()
	top_spin.min_value = -50.0
	top_spin.max_value = 200.0
	top_spin.step = 0.1
	top_spin.value = storey_data.top_level
	top_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	top_spin.value_changed.connect(func(value): _on_storey_top_level_changed(storey_data.id, value))
	top_container.add_child(top_spin)
	
	# Butoane
	var buttons_container = HBoxContainer.new()
	buttons_container.size_flags_horizontal = SIZE_EXPAND_FILL
	properties_container.add_child(buttons_container)
	
	var open_button = Button.new()
	open_button.text = "Open"
	open_button.size_flags_horizontal = SIZE_EXPAND_FILL
	open_button.pressed.connect(func(): _open_storey(storey_data.id))
	buttons_container.add_child(open_button)

# Event handlers
func _on_tree_item_selected():
	var selected = tree.get_selected()
	if selected and selected != project_item:
		current_item = selected
		var metadata = selected.get_metadata(0)
		
		if metadata is String and metadata.begins_with("storey_"):
			var storey_data = storeys_data[metadata]
			_update_properties_ui(storey_data)
			remove_storey_btn.disabled = false
		else:
			remove_storey_btn.disabled = true
	else:
		remove_storey_btn.disabled = true

func _on_tree_item_activated():
	var selected = tree.get_selected()
	if selected and selected != project_item:
		var metadata = selected.get_metadata(0)
		
		if metadata is String and metadata.begins_with("storey_"):
			_open_storey(metadata)

func _on_add_storey_pressed():
	var new_storey_name = "Storey " + str(next_storey_id)
	
	# Determinăm nivelul de bază și cel superior pentru noul etaj
	var highest_top_level = 0.0
	for storey_id in storeys_data:
		var storey = storeys_data[storey_id]
		highest_top_level = max(highest_top_level, storey.top_level)
	
	var base_level = highest_top_level
	var top_level = base_level + 3.0  # Înălțime standard de 3 metri
	
	_add_storey_data(new_storey_name, base_level, top_level)
	_update_tree()

func _on_remove_storey_pressed():
	if current_item and current_item != project_item:
		var metadata = current_item.get_metadata(0)
		
		if metadata is String and metadata.begins_with("storey_"):
			var storey_id = metadata
			var storey_data = storeys_data[storey_id]
			
			# Emitem semnalul înainte de a șterge datele
			storey_removed.emit(storey_id)
			
			# Închidem canvas-ul dacă este deschis
			if storey_data.canvas:
				storey_closed.emit(storey_id)
			
			# Ștergem datele
			storeys_data.erase(storey_id)
			
			# Actualizăm UI-ul
			_update_tree()
			
			# Resetăm selecția
			current_item = null
			remove_storey_btn.disabled = true
			
			# Curățăm panoul de proprietăți
			for child in properties_container.get_children():
				child.queue_free()

func _on_storey_name_changed(storey_id: String, new_name: String):
	if storeys_data.has(storey_id):
		storeys_data[storey_id].name = new_name
		_update_tree()
		storey_updated.emit(storeys_data[storey_id])

func _on_storey_base_level_changed(storey_id: String, new_level: float):
	if storeys_data.has(storey_id):
		storeys_data[storey_id].base_level = new_level
		storey_updated.emit(storeys_data[storey_id])

func _on_storey_top_level_changed(storey_id: String, new_level: float):
	if storeys_data.has(storey_id):
		storeys_data[storey_id].top_level = new_level
		storey_updated.emit(storeys_data[storey_id])

func _open_storey(storey_id: String):
	if storeys_data.has(storey_id):
		var storey_data = storeys_data[storey_id]
		storey_opened.emit(storey_data)
		print("Opening storey: ", storey_data.name)

# API publică pentru acces extern
func get_storey_data(storey_id: String) -> Dictionary:
	if storeys_data.has(storey_id):
		return storeys_data[storey_id].duplicate()
	return {}

func get_all_storeys() -> Array:
	var result = []
	for storey_id in storeys_data:
		result.append(storeys_data[storey_id].duplicate())
	return result

func set_storey_canvas(storey_id: String, canvas_node):
	if storeys_data.has(storey_id):
		storeys_data[storey_id].canvas = canvas_node
		storeys_data[storey_id].canvas_dirty = false
		storey_updated.emit(storeys_data[storey_id])

func mark_storey_dirty(storey_id: String):
	if storeys_data.has(storey_id):
		storeys_data[storey_id].canvas_dirty = true
		storey_updated.emit(storeys_data[storey_id])

func save_project_data() -> Dictionary:
	var save_data = {
		"storeys": {},
		"next_storey_id": next_storey_id
	}
	
	for storey_id in storeys_data:
		var storey = storeys_data[storey_id]
		save_data.storeys[storey_id] = {
			"id": storey.id,
			"name": storey.name,
			"base_level": storey.base_level,
			"top_level": storey.top_level,
			"visible": storey.visible
		}
	
	return save_data

func load_project_data(data: Dictionary):
	storeys_data.clear()
	
	if data.has("next_storey_id"):
		next_storey_id = data.next_storey_id
	
	if data.has("storeys"):
		for storey_id in data.storeys:
			var storey = data.storeys[storey_id]
			storeys_data[storey_id] = {
				"id": storey.id,
				"name": storey.name,
				"base_level": storey.base_level,
				"top_level": storey.top_level,
				"visible": storey.visible,
				"canvas": null,
				"canvas_dirty": false
			}
	
	_update_tree()
