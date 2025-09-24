extends Tree

func _ready():
	# Creează structura foldabilă
	clear()
	var root = create_item()
	root.set_text(0, "Tools")

	# Column
	var col_item = create_item(root)
	col_item.set_text(0, "Column")
	_populate_from_json(col_item, "library/BIM objects/columns.json")

	# Wall
	var wall_item = create_item(root)
	wall_item.set_text(0, "Wall")
	_populate_from_json(wall_item, "library/BIM objects/walls.json")

	# Shell
	var shell_item = create_item(root)
	shell_item.set_text(0, "Shell")
	_populate_from_json(shell_item, "library/BIM objects/shells.json")

	# Advanced (exemplu)
	var advanced = create_item(root)
	advanced.set_text(0, "Advanced")
	var shell2 = create_item(advanced)
	shell2.set_text(0, "Shell Offset")

	# Conectează semnalul pentru click (Godot 4.x)
	connect("item_activated", Callable(self, "_on_item_activated"))

# Utility: populează sub-itemii din json
func _populate_from_json(parent, rel_path):
	var path = rel_path
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	var data = JSON.parse_string(text)
	if typeof(data) == TYPE_ARRAY:
		for obj in data:
			var name = obj.get("id", "")
			if name != "":
				var item = create_item(parent)
				item.set_text(0, name)

func _on_item_activated(index):
	var item = _get_item_by_index(index)
	if item:
		var name = item.get_text(0)
		print("Tool selected: ", name)
		# Dacă e sub-item de column, trimite semnal către Viewer2D
		var parent = item.get_parent()
		if parent and parent.get_text(0) == "Column":
			# Caută Viewer2D în scenă
			var viewer = get_tree().get_root().find_node("Viewer2D", true, false)
			if viewer:
				# Încarcă parametrii din JSON
				var col_data = _get_column_data_by_id(name)
				if col_data:
					viewer.start_placement(col_data)
					print("Placement mode pentru column: ", name)

# Utility: caută datele column după id
func _get_column_data_by_id(col_id):
	var path = "library/BIM objects/columns.json"
	if not FileAccess.file_exists(path):
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text = file.get_as_text()
	var data = JSON.parse_string(text)
	if typeof(data) == TYPE_ARRAY:
		for obj in data:
			if obj.get("id", "") == col_id:
				return obj
	return null

# Utility: traverse tree to get item by index
func _get_item_by_index(idx):
	var root = get_root()
	if not root:
		return null
	var stack = [root]
	var count = 0
	while stack.size() > 0:
		var current = stack.pop_front()
		if count == idx:
			return current
		count += 1
		var child = current.get_first_child()
		while child:
			stack.append(child)
			child = child.get_next()
	return null
