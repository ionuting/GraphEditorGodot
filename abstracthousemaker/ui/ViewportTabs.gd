extends Control
class_name ViewportTabs

# Floating tabs system for 2D/3D viewport management
signal tab_changed(tab_name: String)
signal tab_moved(tab_name: String, new_position: Vector2)
signal tab_closed(tab_name: String)

# Tab management
var tabs: Dictionary = {}
var active_tab: String = "2D"
var tab_buttons: Dictionary = {}

# Dragging system
var is_dragging_tab: bool = false
var dragging_tab: String = ""
var drag_offset: Vector2

# UI Elements
var tab_container: HBoxContainer
var close_buttons: Dictionary = {}

func _ready():
	_setup_tabs_ui()
	_setup_default_tabs()

func _setup_tabs_ui():
	# Main container for tabs
	tab_container = HBoxContainer.new()
	tab_container.position = Vector2(10, 10)
	tab_container.size = Vector2(200, 40)
	add_child(tab_container)
	
	# Apply dark theme to container
	var container_style = StyleBoxFlat.new()
	container_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	container_style.set_corner_radius_all(8)
	container_style.set_border_width_all(1)
	container_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	tab_container.add_theme_stylebox_override("panel", container_style)

func _setup_default_tabs():
	add_tab("2D", "🏗️ 2D Design", true)
	add_tab("3D", "🏠 3D View", false)
	
	# Add instructions label
	var instructions = Label.new()
	instructions.text = "F3: Toggle | 1: 2D | 2: 3D | Drag tabs to move"
	instructions.add_theme_font_size_override("font_size", 10)
	instructions.add_theme_color_override("font_color", Color.GRAY)
	instructions.position = Vector2(10, 55)
	add_child(instructions)

func add_tab(tab_id: String, tab_title: String, is_active: bool = false):
	"""Add a new floating tab"""
	
	# Tab button
	var tab_button = Button.new()
	tab_button.text = tab_title
	tab_button.toggle_mode = true
	tab_button.button_pressed = is_active
	tab_button.custom_minimum_size = Vector2(80, 35)
	
	# Apply tab styling
	_apply_tab_style(tab_button, is_active)
	
	# Connect signals
	tab_button.pressed.connect(_on_tab_pressed.bind(tab_id))
	tab_button.gui_input.connect(_on_tab_input.bind(tab_id))
	
	# Add to container
	tab_container.add_child(tab_button)
	
	# Store references
	tabs[tab_id] = {
		"title": tab_title,
		"button": tab_button,
		"active": is_active
	}
	tab_buttons[tab_id] = tab_button
	
	if is_active:
		active_tab = tab_id
	
	print("📋 Added tab: ", tab_title)

func _apply_tab_style(button: Button, is_active: bool):
	"""Apply consistent styling to tab buttons"""
	
	# Active tab style
	if is_active:
		var active_style = StyleBoxFlat.new()
		active_style.bg_color = Color(0.2, 0.4, 0.6, 1.0)  # Blue active
		active_style.set_corner_radius_all(6)
		active_style.set_border_width_all(2)
		active_style.border_color = Color(0.3, 0.5, 0.8, 1.0)
		button.add_theme_stylebox_override("normal", active_style)
		button.add_theme_stylebox_override("pressed", active_style)
	else:
		var inactive_style = StyleBoxFlat.new()
		inactive_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)  # Dark inactive
		inactive_style.set_corner_radius_all(6)
		inactive_style.set_border_width_all(1)
		inactive_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
		button.add_theme_stylebox_override("normal", inactive_style)
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.25, 0.25, 0.25, 1.0)  # Lighter on hover
		hover_style.set_corner_radius_all(6)
		hover_style.set_border_width_all(1)
		hover_style.border_color = Color(0.4, 0.4, 0.4, 1.0)
		button.add_theme_stylebox_override("hover", hover_style)
	
	# White text for all states
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 12)

func _on_tab_pressed(tab_id: String):
	"""Handle tab selection"""
	set_active_tab(tab_id)

func _on_tab_input(event: InputEvent, tab_id: String):
	"""Handle tab dragging"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Start dragging
				is_dragging_tab = true
				dragging_tab = tab_id
				drag_offset = get_global_mouse_position() - tab_container.global_position
				print("🖱️ Started dragging tab: ", tab_id)
			else:
				# Stop dragging
				if is_dragging_tab and dragging_tab == tab_id:
					is_dragging_tab = false
					tab_moved.emit(tab_id, tab_container.global_position)
					print("🖱️ Stopped dragging tab: ", tab_id)
	
	elif event is InputEventMouseMotion and is_dragging_tab and dragging_tab == tab_id:
		# Update tab container position while dragging
		var new_position = get_global_mouse_position() - drag_offset
		
		# Constrain to viewport bounds
		var viewport_size = get_viewport().size
		new_position.x = clamp(new_position.x, 0, viewport_size.x - tab_container.size.x)
		new_position.y = clamp(new_position.y, 0, viewport_size.y - tab_container.size.y)
		
		tab_container.global_position = new_position

func set_active_tab(tab_id: String):
	"""Set the active tab and update UI"""
	if tab_id in tabs:
		# Deactivate all tabs
		for id in tabs:
			tabs[id].active = false
			tabs[id].button.button_pressed = false
			_apply_tab_style(tabs[id].button, false)
		
		# Activate selected tab
		tabs[tab_id].active = true
		tabs[tab_id].button.button_pressed = true
		_apply_tab_style(tabs[tab_id].button, true)
		
		active_tab = tab_id
		tab_changed.emit(tab_id)
		print("📋 Switched to tab: ", tabs[tab_id].title)

func get_active_tab() -> String:
	"""Get the currently active tab"""
	return active_tab

func move_to_position(new_position: Vector2):
	"""Move the tab container to a specific position"""
	tab_container.position = new_position

func save_tab_settings():
	"""Save tab positions and states"""
	var settings = {
		"position": {"x": tab_container.position.x, "y": tab_container.position.y},
		"active_tab": active_tab
	}
	
	var file = FileAccess.open("user://viewport_tabs_settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()
		print("💾 Viewport tabs settings saved")

func load_tab_settings():
	"""Load saved tab positions and states"""
	if FileAccess.file_exists("user://viewport_tabs_settings.json"):
		var file = FileAccess.open("user://viewport_tabs_settings.json", FileAccess.READ)
		if file:
			var json = JSON.new()
			var parse_result = json.parse(file.get_as_text())
			file.close()
			
			if parse_result == OK:
				var settings = json.data
				if settings.has("position"):
					tab_container.position = Vector2(settings.position.x, settings.position.y)
				if settings.has("active_tab"):
					call_deferred("set_active_tab", settings.active_tab)
				print("🔄 Viewport tabs settings loaded")
