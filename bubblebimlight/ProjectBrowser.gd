extends Control

signal open_level_2d(level_data)
signal level_renamed(old_name, new_name)
signal open_view_3d(view_data)
signal open_view_3d_new(view_data)

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

# Lista de vederi 3D
var views3d = [
	{"name": "Default 3D"}
]

var edit_3d_dialog: AcceptDialog
var view_name_edit: LineEdit

# UI Components
var main_container: VBoxContainer
var levels_section: VBoxContainer
var views_section: VBoxContainer
var _titlebar: Panel
var _dragging: bool = false

func _ready():
	print("ProjectBrowser: Initializing...")
	_setup_main_layout()
	_create_edit_dialogs()
	_create_context_menu()
	_setup_tree()
	tree.gui_input.connect(Callable(self, "_on_tree_gui_input"))
	# Handle double-click (item_activated) to open levels in 2D
	if tree.has_signal("item_activated"):
		tree.item_activated.connect(Callable(self, "_on_tree_item_activated"))

	# Make titlebar draggable
	if _titlebar:
		_titlebar.mouse_filter = Control.MOUSE_FILTER_STOP
		_titlebar.connect("gui_input", Callable(self, "_on_titlebar_input"))

	set_process_input(true)
	print("ProjectBrowser: Initialization complete")

func _setup_main_layout():
	print("ProjectBrowser: Setting up main layout...")
	
	# Create main vertical container
	# Create a floating titlebar that acts as drag handle
	_titlebar = Panel.new()
	_titlebar.name = "TitleBar"
	# make the titlebar stretch horizontally within its parent and use
	# offsets for padding so it can't overflow and cover the main scene
	_titlebar.anchor_left = 0
	_titlebar.anchor_top = 0
	_titlebar.anchor_right = 1
	_titlebar.anchor_bottom = 0
	_titlebar.offset_left = 10
	_titlebar.offset_top = 20    # start 20px lower
	_titlebar.offset_right = -10  # 10px padding from the right edge
	_titlebar.offset_bottom = 50
	add_child(_titlebar)

	var title_label = Label.new()
	title_label.text = "Project Browser"
	title_label.position = Vector2(8,8)
	_titlebar.add_child(title_label)

	# Create main vertical container
	main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.anchor_left = 0
	main_container.anchor_top = 0
	main_container.anchor_right = 1
	main_container.anchor_bottom = 1
	main_container.offset_left = 4
	# leave space for titlebar by moving top down
	main_container.offset_top = 60
	main_container.offset_right = -4
	main_container.offset_bottom = -4
	main_container.add_theme_constant_override("separation", 8)
	add_child(main_container)
	
	# Create levels section
	_create_levels_section()
	
	# Add separator
	var separator = HSeparator.new()
	separator.name = "SectionSeparator"
	main_container.add_child(separator)
	
	# Create 3D views section
	_create_views_section()
	
	# Reposition tree to fill remaining space
	if tree:
		# Remove tree from its current parent and add to main container
		if tree.get_parent():
			tree.get_parent().remove_child(tree)
		main_container.add_child(tree)
		tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tree.custom_minimum_size = Vector2(0, 200)

func _create_levels_section():
	print("ProjectBrowser: Creating levels section...")
	
	# Create levels header
	var levels_header = HBoxContainer.new()
	levels_header.name = "LevelsHeader"
	levels_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_header.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_container.add_child(levels_header)
	
	# Levels title
	var levels_label = Label.new()
	levels_label.text = "Project Levels"
	levels_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_label.add_theme_font_size_override("font_size", 14)
	levels_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	levels_header.add_child(levels_label)
	
	# Add level button
	var add_level_btn = Button.new()
	add_level_btn.name = "AddLevelButton"
	add_level_btn.text = "+"
	add_level_btn.tooltip_text = "Add Level"
	add_level_btn.custom_minimum_size = Vector2(28, 28)
	add_level_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_level_btn.pressed.connect(Callable(self, "_on_add_level_pressed"))
	levels_header.add_child(add_level_btn)
	
	# Remove level button
	var remove_level_btn = Button.new()
	remove_level_btn.name = "RemoveLevelButton"
	remove_level_btn.text = "-"
	remove_level_btn.tooltip_text = "Delete Selected Level"
	remove_level_btn.custom_minimum_size = Vector2(28, 28)
	remove_level_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	remove_level_btn.pressed.connect(Callable(self, "_on_remove_level_pressed"))
	levels_header.add_child(remove_level_btn)

func _create_views_section():
	print("ProjectBrowser: Creating 3D views section...")
	
	# Create views header
	var views_header = HBoxContainer.new()
	views_header.name = "ViewsHeader"
	views_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	views_header.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_container.add_child(views_header)
	
	# Views title
	var views_label = Label.new()
	views_label.text = "3D Views"
	views_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	views_label.add_theme_font_size_override("font_size", 14)
	views_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	views_header.add_child(views_label)
	
	# Add view button
	var add_view_btn = Button.new()
	add_view_btn.name = "AddViewButton"
	add_view_btn.text = "+"
	add_view_btn.tooltip_text = "Add 3D View"
	add_view_btn.custom_minimum_size = Vector2(28, 28)
	add_view_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_view_btn.pressed.connect(Callable(self, "_on_add_3d_view_pressed"))
	views_header.add_child(add_view_btn)
	
	# Remove view button
	var remove_view_btn = Button.new()
	remove_view_btn.name = "RemoveViewButton"
	remove_view_btn.text = "-"
	remove_view_btn.tooltip_text = "Remove Selected 3D View"
	remove_view_btn.custom_minimum_size = Vector2(28, 28)
	remove_view_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	remove_view_btn.pressed.connect(Callable(self, "_on_remove_3d_view_pressed"))
	views_header.add_child(remove_view_btn)

	# try to bring this Control to the front of its parent children
	if get_parent():
		var p = get_parent()
		p.move_child(self, p.get_child_count() - 1)

func _setup_tree():
	print("ProjectBrowser: Setting up tree...")
	
	if not tree:
		push_error("Tree node not found!")
		return
	
	# Configure tree
	tree.clear()
	tree.set_column_titles_visible(true)
	tree.set_column_title(0, "Items")
	tree.set_hide_root(false)
	tree.allow_reselect = true
	tree.allow_rmb_select = true
	
	# Create tree structure
	var root = tree.create_item()
	root.set_text(0, "Project")
	root.set_selectable(0, false)
	
	# Building Factory section
	var building_factory = tree.create_item(root)
	building_factory.set_text(0, "Building Factory")
	building_factory.set_selectable(0, false)
	
	# Add levels
	for level in levels:
		var item = tree.create_item(building_factory)
		item.set_text(0, "%s (%.2f → %.2f m)" % [level.name, level.bottom, level.top])
		item.set_metadata(0, {"type": "level", "data": level})
	
	# 3D Views section
	var views_node = tree.create_item(root)
	views_node.set_text(0, "3D Views")
	views_node.set_selectable(0, false)
	
	# Add 3D views
	for view in views3d:
		var view_item = tree.create_item(views_node)
		view_item.set_text(0, str(view.get("name", view)))
		view_item.set_metadata(0, {"type": "view3d", "data": view})
	
	# Expand all by default
	expand_all_items(root)
	print("ProjectBrowser: Tree setup complete")

func _create_edit_dialogs():
	print("ProjectBrowser: Creating edit dialogs...")
	
	# Level edit dialog
	_create_level_edit_dialog()
	
	# 3D view edit dialog
	_create_3d_view_edit_dialog()

func _create_level_edit_dialog():
	edit_dialog = AcceptDialog.new()
	edit_dialog.name = "LevelEditDialog"
	edit_dialog.title = "Edit Level"
	edit_dialog.min_size = Vector2(350, 200)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# Name field
	var name_label = Label.new()
	name_label.text = "Level Name:"
	vbox.add_child(name_label)
	
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Enter level name..."
	vbox.add_child(name_edit)
	
	# Bottom level
	var bottom_label = Label.new()
	bottom_label.text = "Bottom Level (m):"
	vbox.add_child(bottom_label)
	
	bottom_spin = SpinBox.new()
	bottom_spin.min_value = -100
	bottom_spin.max_value = 100
	bottom_spin.step = 0.01
	bottom_spin.value_changed.connect(Callable(self, "_on_bottom_value_changed"))
	vbox.add_child(bottom_spin)
	
	# Top level
	var top_label = Label.new()
	top_label.text = "Top Level (m):"
	vbox.add_child(top_label)
	
	top_spin = SpinBox.new()
	top_spin.min_value = -100
	top_spin.max_value = 100
	top_spin.step = 0.01
	top_spin.value_changed.connect(Callable(self, "_on_top_value_changed"))
	vbox.add_child(top_spin)
	
	edit_dialog.add_child(vbox)
	edit_dialog.get_ok_button().text = "Save"
	edit_dialog.confirmed.connect(Callable(self, "_on_edit_dialog_save"))
	add_child(edit_dialog)

func _create_3d_view_edit_dialog():
	edit_3d_dialog = AcceptDialog.new()
	edit_3d_dialog.name = "ViewEditDialog"
	edit_3d_dialog.title = "Create 3D View"
	edit_3d_dialog.min_size = Vector2(300, 120)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var name_label = Label.new()
	name_label.text = "View Name:"
	vbox.add_child(name_label)
	
	view_name_edit = LineEdit.new()
	view_name_edit.placeholder_text = "Enter 3D view name..."
	vbox.add_child(view_name_edit)
	
	edit_3d_dialog.add_child(vbox)
	edit_3d_dialog.get_ok_button().text = "Create"
	edit_3d_dialog.confirmed.connect(Callable(self, "_on_create_3d_view_confirmed"))
	add_child(edit_3d_dialog)

func _create_context_menu():
	context_menu = PopupMenu.new()
	context_menu.name = "ProjectContextMenu"
	context_menu.add_item("Properties", 1)
	context_menu.add_separator()
	context_menu.add_item("Open in 2D", 2)
	context_menu.add_item("Open in 3D", 3)
	context_menu.add_item("Open in 3D (new)", 6)
	context_menu.add_separator()
	context_menu.add_item("Add Level", 4)
	context_menu.add_item("Delete", 5)
	context_menu.id_pressed.connect(Callable(self, "_on_context_menu_id_pressed"))
	add_child(context_menu)

# Event handlers
func _on_add_level_pressed():
	print("ProjectBrowser: Adding new level...")
	
	var new_level_idx = levels.size() + 1
	var new_name = "Level %d" % new_level_idx
	
	var new_bottom = 0.0
	var new_top = 2.8
	if levels.size() > 0:
		new_bottom = levels[-1].top
		new_top = new_bottom + 2.8
	
	var new_level = {"name": new_name, "bottom": new_bottom, "top": new_top}
	levels.append(new_level)
	
	_rebuild_tree()
	_select_level_by_name(new_name)
	print("ProjectBrowser: New level added: ", new_name)

func _on_remove_level_pressed():
	print("ProjectBrowser: Removing selected level...")
	
	var selected = tree.get_selected()
	if not selected:
		print("ProjectBrowser: No item selected")
		return
	
	var metadata = selected.get_metadata(0)
	if not metadata or metadata.get("type") != "level":
		print("ProjectBrowser: Selected item is not a level")
		return
	
	var level_data = metadata.get("data", {})
	var level_name = level_data.get("name", "")
	
	# Remove from levels array
	for i in range(levels.size()):
		if levels[i].name == level_name:
			levels.remove_at(i)
			print("ProjectBrowser: Removed level: ", level_name)
			break
	
	_rebuild_tree()

func _on_add_3d_view_pressed():
	print("ProjectBrowser: Opening add 3D view dialog...")
	view_name_edit.text = ""
	edit_3d_dialog.title = "Create 3D View"
	edit_3d_dialog.popup_centered()

func _on_remove_3d_view_pressed():
	print("ProjectBrowser: Removing selected 3D view...")
	
	var selected = tree.get_selected()
	if not selected:
		print("ProjectBrowser: No item selected")
		return
	
	var metadata = selected.get_metadata(0)
	if not metadata or metadata.get("type") != "view3d":
		print("ProjectBrowser: Selected item is not a 3D view")
		return
	
	var view_data = metadata.get("data", {})
	var view_name = str(view_data.get("name", ""))
	
	remove_3d_view(view_name)

func _on_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var item = tree.get_selected()
			if item:
				# Position context menu at mouse cursor
				context_menu.position = get_global_mouse_position()
				context_menu.popup()

func _on_tree_item_activated() -> void:
	# Called when the user double-clicks an item in the Tree
	var selected = tree.get_selected()
	if not selected:
		return
	var metadata = selected.get_metadata(0)
	if not metadata:
		return
	var mtype = metadata.get("type")
	if mtype == "level":
		var level_data = metadata.get("data", {})
		emit_signal("open_level_2d", level_data.duplicate())
	elif mtype == "view3d":
		var view_data = metadata.get("data", {})
		emit_signal("open_view_3d", view_data.duplicate())

func _on_titlebar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				set_process(true)
			else:
				_dragging = false
				set_process(false)

func _input(event: InputEvent) -> void:
	if _dragging and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		# move this Control by the delta in global coordinates
		position += mm.relative

func _on_context_menu_id_pressed(id: int) -> void:
	var selected = tree.get_selected()
	if not selected:
		return
	
	match id:
		1: # Properties
			_open_properties_for_selected()
		2: # Open in 2D
			_emit_open_level_2d_for_selected()
		3: # Open in 3D
			_emit_open_view_3d_for_selected()
		6: # Open in 3D (new tab)
			_emit_open_view_3d_new_for_selected()
		4: # Add Level
			_on_add_level_pressed()
		5: # Delete
			var metadata = selected.get_metadata(0)
			if metadata:
				if metadata.get("type") == "level":
					_on_remove_level_pressed()
				elif metadata.get("type") == "view3d":
					_on_remove_3d_view_pressed()

func _open_properties_for_selected():
	var selected = tree.get_selected()
	if not selected:
		return
	
	var metadata = selected.get_metadata(0)
	if not metadata or metadata.get("type") != "level":
		return
	
	var level_data = metadata.get("data", {})
	var level_name = level_data.get("name", "")
	
	# Find level index
	for i in range(levels.size()):
		if levels[i].name == level_name:
			editing_level_index = i
			var level = levels[i]
			name_edit.text = level.name
			bottom_spin.value = level.bottom
			top_spin.value = level.top
			edit_dialog.popup_centered()
			return

func _emit_open_level_2d_for_selected():
	var selected = tree.get_selected()
	if not selected:
		return
	
	var metadata = selected.get_metadata(0)
	if not metadata or metadata.get("type") != "level":
		return
	
	var level_data = metadata.get("data", {})
	print("ProjectBrowser: Opening level 2D: ", level_data.get("name", "Unknown"))
	emit_signal("open_level_2d", level_data.duplicate())

func _emit_open_view_3d_for_selected():
	var selected = tree.get_selected()
	if not selected:
		return
	
	var metadata = selected.get_metadata(0)
	if not metadata or metadata.get("type") != "view3d":
		return
	
	var view_data = metadata.get("data", {})
	print("ProjectBrowser: Opening view 3D: ", view_data.get("name", "Unknown"))
	emit_signal("open_view_3d", view_data.duplicate())

func _emit_open_view_3d_new_for_selected():
	var selected = tree.get_selected()
	if not selected:
		return

	var metadata = selected.get_metadata(0)
	if not metadata or metadata.get("type") != "view3d":
		return

	var view_data = metadata.get("data", {})
	print("ProjectBrowser: Opening view 3D (new tab): ", view_data.get("name", "Unknown"))
	emit_signal("open_view_3d_new", view_data.duplicate())

# Validation handlers
func _on_bottom_value_changed(value: float):
	if value >= top_spin.value:
		top_spin.value = value + 0.1

func _on_top_value_changed(value: float):
	if value <= bottom_spin.value:
		bottom_spin.value = value - 0.1

func _on_edit_dialog_save():
	if editing_level_index >= 0 and editing_level_index < levels.size():
		var new_name = name_edit.text.strip_edges()
		
		if new_name == "":
			print("ProjectBrowser: Level name cannot be empty!")
			return
		
		# Check for duplicate names
		for i in range(levels.size()):
			if i != editing_level_index and levels[i].name == new_name:
				print("ProjectBrowser: Level name already exists: ", new_name)
				return
		
		var old_name = levels[editing_level_index].name
		levels[editing_level_index].name = new_name
		levels[editing_level_index].bottom = bottom_spin.value
		levels[editing_level_index].top = top_spin.value
		
		_rebuild_tree()
		_select_level_by_name(new_name)
		
		emit_signal("level_renamed", old_name, new_name)
		print("ProjectBrowser: Updated level: ", levels[editing_level_index])
	
	editing_level_index = -1

func _on_create_3d_view_confirmed():
	var name = view_name_edit.text.strip_edges()
	if name == "":
		print("ProjectBrowser: 3D view name cannot be empty")
		return
	
	# Check for duplicates
	for v in views3d:
		if str(v.get("name", v)) == name:
			print("ProjectBrowser: 3D view already exists: ", name)
			return
	
	add_3d_view(name)
	_select_3d_view_by_name(name)

# Utility functions
func expand_all_items(item: TreeItem):
	if item == null:
		return
	item.set_collapsed(false)
	var child = item.get_first_child()
	while child:
		expand_all_items(child)
		child = child.get_next()

func _rebuild_tree():
	print("ProjectBrowser: Rebuilding tree...")
	
	# Store current selection
	var selected_item = tree.get_selected()
	var selected_text = ""
	if selected_item:
		selected_text = selected_item.get_text(0)
	
	_setup_tree()
	
	# Restore selection if possible
	if selected_text != "":
		_select_item_by_text(selected_text)

func _select_item_by_text(text: String):
	var root = tree.get_root()
	_recursive_find_and_select(root, text)

func _recursive_find_and_select(item: TreeItem, text: String):
	if not item:
		return false
	
	if item.get_text(0) == text:
		item.select(0)
		return true
	
	var child = item.get_first_child()
	while child:
		if _recursive_find_and_select(child, text):
			return true
		child = child.get_next()
	
	return false

func _select_level_by_name(name: String):
	var root = tree.get_root()
	if not root:
		return
	
	var building_factory = root.get_first_child()
	while building_factory:
		if building_factory.get_text(0) == "Building Factory":
			var level_item = building_factory.get_first_child()
			while level_item:
				var level_text = level_item.get_text(0)
				if level_text.begins_with(name + " ("):
					level_item.select(0)
					return
				level_item = level_item.get_next()
			return
		building_factory = building_factory.get_next()

func _select_3d_view_by_name(name: String):
	var root = tree.get_root()
	if not root:
		return
	
	var views_node = root.get_first_child()
	while views_node:
		if views_node.get_text(0) == "3D Views":
			var view_item = views_node.get_first_child()
			while view_item:
				if view_item.get_text(0) == name:
					view_item.select(0)
					return
				view_item = view_item.get_next()
			return
		views_node = views_node.get_next()

# API functions
func add_3d_view(view_name: String):
	views3d.append({"name": view_name})
	_rebuild_tree()
	print("ProjectBrowser: Added 3D view: ", view_name)

func remove_3d_view(view_name: String):
	for i in range(views3d.size()):
		var v = views3d[i]
		if (typeof(v) == TYPE_DICTIONARY and v.get("name", "") == view_name) or str(v) == view_name:
			views3d.remove_at(i)
			_rebuild_tree()
			print("ProjectBrowser: Removed 3D view: ", view_name)
			return

func get_all_levels() -> Array:
	var result = []
	for level in levels:
		result.append(level.duplicate())
	return result

func get_level_info(level_name: String) -> Dictionary:
	for level in levels:
		if level.name == level_name:
			return level.duplicate()
	return {}

func serialize_levels_to_json() -> String:
	var dict = {}
	for level in levels:
		dict[level.name] = {"bottom": level.bottom, "top": level.top}
	return JSON.stringify(dict, "  ")

func import_levels_from_json(json_string: String) -> bool:
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("ProjectBrowser: Error parsing JSON: ", json.get_error_message())
		return false
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		print("ProjectBrowser: JSON data is not a dictionary")
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
	
	_rebuild_tree()
	return true
