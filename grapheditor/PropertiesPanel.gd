extends Control

# Dynamic properties panel that builds a two-column grid (label, control)
# for a node's `node_info` dictionary and some core properties.

signal property_changed(node, key, value)

var grid = null
var _dragging := false
var _drag_offset := Vector2.ZERO
var _header_height := 26

func _ready():
	_ensure_grid()

func _ensure_grid():
	# Create a ScrollContainer + GridContainer if missing
	var sc: ScrollContainer = get_node_or_null("ScrollContainer")
	if sc == null:
		sc = ScrollContainer.new()
		sc.name = "ScrollContainer"
		add_child(sc)
		sc.anchor_right = 1.0
		sc.anchor_bottom = 1.0
		# offset the scroll container so the draggable header doesn't overlap the content
		sc.position = Vector2(0, _header_height)

	grid = sc.get_node_or_null("PropertiesGrid")
	if grid == null:
		grid = GridContainer.new()
		grid.name = "PropertiesGrid"
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
		grid.custom_minimum_size = Vector2(200, 0)
		sc.add_child(grid)

	# Create a small draggable header if missing
	if not has_node("DragHeader"):
		var header = Panel.new()
		header.name = "DragHeader"
		header.custom_minimum_size = Vector2(200, _header_height)
		header.mouse_filter = Control.MOUSE_FILTER_STOP
		var hl = Label.new()
		hl.text = "Properties"
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hl.anchor_left = 0.0
		hl.anchor_right = 1.0
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hl.position = Vector2(6, 0)
		header.add_child(hl)
		add_child(header)
		# connect header gui input to our handler
		if header.has_method("gui_input"):
			header.gui_input.connect(Callable(self, "_on_header_gui_input"))
	return grid

func _on_header_gui_input(event):
	# Handle header mouse events to drag the whole panel around.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_dragging = true
			# store offset between mouse and panel global position
			_drag_offset = get_viewport().get_mouse_position() - global_position
			# ensure we're on top
			if get_parent() != null:
				get_parent().move_child(self, max(0, get_parent().get_child_count() - 1))
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var desired = get_viewport().get_mouse_position() - _drag_offset
		# optionally clamp inside parent rect
		if get_parent():
			var parent_rect = Rect2(get_parent().global_position, get_parent().size)
			var clamped = desired
			clamped.x = clamp(clamped.x, parent_rect.position.x, parent_rect.position.x + max(0, parent_rect.size.x - size.x))
			clamped.y = clamp(clamped.y, parent_rect.position.y, parent_rect.position.y + max(0, parent_rect.size.y - size.y))
			global_position = clamped
		else:
			global_position = desired

func _clear_grid():
	if grid == null:
		_ensure_grid()
	for c in grid.get_children():
		c.queue_free()

func build_from_node(node):
	# node: the selected node object. Build UI from node.node_info and some core fields.
	_ensure_grid()
	_clear_grid()
	# make editable controls wider: twice the grid base width
	var target_width = 400
	if grid and grid.custom_minimum_size.x > 0:
		target_width = int(max(200, grid.custom_minimum_size.x * 2))
	if node == null:
		return

	# Core fields: Index (editable), Name (editable)
	var idx_lbl = Label.new()
	idx_lbl.text = "Index:"
	grid.add_child(idx_lbl)
	# Safely extract index: prefer node.node_info.index when available, else fallback to node.get("id") when present
	var node_info_for_index = null
	if node and typeof(node) == TYPE_OBJECT and node.has_method("get"):
		node_info_for_index = node.get("node_info")
	var index_value = 0
	if node_info_for_index != null and typeof(node_info_for_index) == TYPE_DICTIONARY and node_info_for_index.has("index"):
		index_value = node_info_for_index["index"]
	else:
		# try safe get of id property
		if node and typeof(node) == TYPE_OBJECT and node.has_method("get"):
			var maybe_id = node.get("id")
			if maybe_id != null:
				index_value = maybe_id
	var idx_le = LineEdit.new()
	idx_le.text = str(index_value)
	idx_le.custom_minimum_size = Vector2(target_width, 0)
	idx_le.text_changed.connect(Callable(self, "_on_index_changed").bind(node))
	grid.add_child(idx_le)

	var name_lbl = Label.new()
	name_lbl.text = "Name:"
	grid.add_child(name_lbl)
	var name_le = LineEdit.new()
	# prefer node_info.name when present (used for connections), else try node.obj_name safely
	var name_val = ""
	if node_info_for_index != null and typeof(node_info_for_index) == TYPE_DICTIONARY and node_info_for_index.has("name"):
		name_val = str(node_info_for_index["name"])
	else:
		if node and typeof(node) == TYPE_OBJECT and node.has_method("get"):
			var maybe_name = node.get("obj_name")
			if maybe_name != null:
				name_val = str(maybe_name)
			else:
				name_val = str(node)
	name_le.text = name_val
	name_le.custom_minimum_size = Vector2(target_width, 0)
	name_le.text_changed.connect(Callable(self, "_on_name_changed").bind(node))
	grid.add_child(name_le)

	# Distances (Interax) - show if present
	if node.get_script() and node.get_script().resource_path.ends_with("interax.gd"):
		var d_lbl = Label.new()
		d_lbl.text = "Distances:"
		grid.add_child(d_lbl)
		var d_le = LineEdit.new()
		d_le.text = "x:" + str(node.distances[0]).replace("[", "").replace("]", "") + "; y:" + str(node.distances[1]).replace("[", "").replace("]", "")
		d_le.custom_minimum_size = Vector2(target_width, 0)
		d_le.text_changed.connect(Callable(self, "_on_distances_changed").bind(node))
		grid.add_child(d_le)

	# Build rows for node_info dictionary
	var ni = null
	if node.has_method("get"):
		ni = node.get("node_info")
	if ni == null:
		return

	for key in ni.keys():
		# avoid duplicating core fields already shown above
		if key == "index" or key == "name":
			continue
		var val = ni[key]
		var lbl = Label.new()
		lbl.text = str(key) + ":"
		grid.add_child(lbl)

		match typeof(val):
			TYPE_BOOL:
				var cb = CheckBox.new()
				if cb.has_method("set_pressed"):
					cb.set_pressed(bool(val))
				else:
					cb.pressed = bool(val)
				cb.toggled.connect(Callable(self, "_on_prop_toggled").bind(node, key))
				grid.add_child(cb)
			TYPE_STRING:
				# Special-case: for draggable_square nodes, expose `type` as an OptionButton with known choices
				if key == "type" and node.get_script() and node.get_script().resource_path.ends_with("draggable_square.gd"):
					var choices = ["room", "cell", "shell"]
					var opt = OptionButton.new()
					opt.custom_minimum_size = Vector2(target_width, 0)
					for c in choices:
						opt.add_item(c)
					# select current value if present
					var sel_idx = 0
					for i in range(choices.size()):
						if choices[i] == str(val):
							sel_idx = i
							break
					opt.select(sel_idx)
					opt.item_selected.connect(Callable(self, "_on_prop_type_selected").bind(node, key, choices))
					grid.add_child(opt)
				else:
					var le = LineEdit.new()
					le.text = str(val)
					le.custom_minimum_size = Vector2(target_width, 0)
					le.text_changed.connect(Callable(self, "_on_prop_text_changed").bind(node, key))
					grid.add_child(le)
			TYPE_INT, TYPE_FLOAT:
				var le2 = LineEdit.new()
				le2.text = str(val)
				le2.custom_minimum_size = Vector2(target_width, 0)
				le2.text_changed.connect(Callable(self, "_on_prop_number_changed").bind(node, key))
				grid.add_child(le2)
			TYPE_ARRAY:
				var arr_lbl = Label.new()
				arr_lbl.text = str(val)
				grid.add_child(arr_lbl)
			TYPE_DICTIONARY:
				var btn = Button.new()
				btn.text = "Edit..."
				btn.custom_minimum_size = Vector2(target_width, 0)
				# optional: could open a nested editor
				btn.pressed.connect(Callable(self, "_on_edit_dict_pressed").bind(node, key))
				grid.add_child(btn)
			_:
				var lblv = Label.new()
				lblv.text = str(val)
				grid.add_child(lblv)

func _on_name_changed(new_text: String, node):
	if node == null:
		return
	node.obj_name = new_text
	# Also sync into node_info if present
	if node.has_method("get"):
		var ni = node.get("node_info")
		if ni != null:
			ni["name"] = new_text
	emit_signal("property_changed", node, "name", new_text)

func _on_index_changed(new_text: String, node):
	if node == null:
		return
	var num = null
	if new_text.is_valid_int():
		num = int(new_text)
	elif new_text.is_valid_float():
		num = int(float(new_text))
	else:
		return
	# update node and node_info if present
	if node.has_method("set"):
		# try to write into node_info if available
		if node.has_method("get"):
			var ni = node.get("node_info")
			if ni != null and typeof(ni) == TYPE_DICTIONARY:
				ni["index"] = num
	# also attempt direct assignment if property exists
	if node.has_method("set") and node.has_meta("index"):
		node.set("index", num)
	emit_signal("property_changed", node, "index", num)

func _on_distances_changed(new_text: String, node):
	# Delegate parsing back to node (similar logic as in main_scene)
	if node == null:
		return
	# Reuse existing parser logic lightly
	var distances = [[0.0], [0.0]]
	var cleaned_text = new_text.replace("[", "").replace("]", "").strip_edges()
	var parts = cleaned_text.split(";")
	for part in parts:
		part = part.strip_edges()
		if part.begins_with("x:"):
			var x_str = part.replace("x:", "").strip_edges()
			var x_values = x_str.split(",")
			distances[0] = []
			for val in x_values:
				val = val.strip_edges()
				if val.is_valid_float():
					var num = float(val)
					if num >= 0.0:
						distances[0].append(num)
		elif part.begins_with("y:"):
			var y_str = part.replace("y:", "").strip_edges()
			var y_values = y_str.split(",")
			distances[1] = []
			for val in y_values:
				val = val.strip_edges()
				if val.is_valid_float():
					var num = float(val)
					if num >= 0.0:
						distances[1].append(num)
	if distances[0].size() > 0 and distances[1].size() > 0:
		node.distances = distances
		if node.has_method("update_labels"):
			node.update_labels()
	emit_signal("property_changed", node, "distances", distances)

func _on_prop_toggled(pressed: bool, node, key):
	if node == null:
		return
	if node.has_method("get"):
		var ni = node.get("node_info")
		if ni != null:
			ni[key] = pressed
	emit_signal("property_changed", node, key, pressed)

func _on_prop_text_changed(new_text: String, node, key):
	if node == null:
		return
	if node.has_method("get"):
		var ni = node.get("node_info")
		if ni != null:
			ni[key] = new_text
	emit_signal("property_changed", node, key, new_text)

func _on_prop_number_changed(new_text: String, node, key):
	if node == null:
		return
	var num = null
	if new_text.is_valid_int():
		num = int(new_text)
	elif new_text.is_valid_float():
		num = float(new_text)
	else:
		return
	if node.has_method("get"):
		var ni = node.get("node_info")
		if ni != null:
			ni[key] = num
	emit_signal("property_changed", node, key, num)

func _on_edit_dict_pressed(_node, key):
	# Placeholder: could open a popup to edit nested dictionaries/arrays
	print("Edit nested dict/array not implemented for:", key)

func _on_prop_type_selected(index: int, node, key, choices):
	if node == null:
		return
	var chosen = choices[index]
	if node.has_method("get"):
		var ni = node.get("node_info")
		if ni != null and typeof(ni) == TYPE_DICTIONARY:
			ni[key] = chosen
	emit_signal("property_changed", node, key, chosen)
