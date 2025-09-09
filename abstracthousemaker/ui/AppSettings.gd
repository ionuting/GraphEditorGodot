extends RefCounted
class_name AppSettings

# Singleton pentru configurările aplicației

static var instance: AppSettings = null

# Validation settings
var validation_enabled: bool = true
var auto_fix_enabled: bool = false
var realtime_validation: bool = true

# UI settings
var property_panel_position: Vector2 = Vector2(10, 10)
var property_panel_size: Vector2 = Vector2(320, 800)
var ui_theme: String = "dark"
var show_tooltips: bool = true

# Shape settings
var default_shape_size: Vector2 = Vector2(300, 300)
var default_extrusion_height: float = 255.0
var default_interior_offset: float = 12.5
var auto_save_enabled: bool = true
var auto_save_interval: float = 30.0

# Window settings
var default_window_width: float = 45.0
var default_window_height: float = 120.0
var default_window_style: String = "standard"

# Door settings
var default_door_width: float = 90.0
var default_door_height: float = 200.0
var default_door_style: String = "standard"

# 3D settings
var default_camera_distance: float = 10.0
var camera_rotation_speed: float = 0.5
var zoom_speed: float = 0.1

# File paths
var shapes_save_path: String = "user://shapes.json"
var settings_save_path: String = "user://app_settings.json"
var export_path: String = "user://exports/"

signal settings_changed(setting_name: String, new_value)

static func get_instance() -> AppSettings:
	if not instance:
		instance = AppSettings.new()
		instance.load_settings()
	return instance

func _init():
	if not instance:
		instance = self

func save_settings():
	var settings_data = {
		"validation": {
			"validation_enabled": validation_enabled,
			"auto_fix_enabled": auto_fix_enabled,
			"realtime_validation": realtime_validation
		},
		"ui": {
			"property_panel_position": {"x": property_panel_position.x, "y": property_panel_position.y},
			"property_panel_size": {"x": property_panel_size.x, "y": property_panel_size.y},
			"ui_theme": ui_theme,
			"show_tooltips": show_tooltips
		},
		"shape_defaults": {
			"default_shape_size": {"x": default_shape_size.x, "y": default_shape_size.y},
			"default_extrusion_height": default_extrusion_height,
			"default_interior_offset": default_interior_offset,
			"auto_save_enabled": auto_save_enabled,
			"auto_save_interval": auto_save_interval
		},
		"window_defaults": {
			"default_window_width": default_window_width,
			"default_window_height": default_window_height,
			"default_window_style": default_window_style
		},
		"door_defaults": {
			"default_door_width": default_door_width,
			"default_door_height": default_door_height,
			"default_door_style": default_door_style
		},
		"3d_settings": {
			"default_camera_distance": default_camera_distance,
			"camera_rotation_speed": camera_rotation_speed,
			"zoom_speed": zoom_speed
		},
		"file_paths": {
			"shapes_save_path": shapes_save_path,
			"settings_save_path": settings_save_path,
			"export_path": export_path
		}
	}
	
	var json_text = JSON.stringify(settings_data, "\t")
	var file = FileAccess.open(settings_save_path, FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
		print("✓ Settings saved to ", settings_save_path)
	else:
		print("✗ Failed to save settings to ", settings_save_path)

func load_settings():
	var file = FileAccess.open(settings_save_path, FileAccess.READ)
	if not file:
		print("No settings file found, using defaults")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("✗ Failed to parse settings JSON, using defaults")
		return
	
	var data = json.data
	if not data is Dictionary:
		print("✗ Invalid settings format, using defaults")
		return
	
	# Load validation settings
	if data.has("validation"):
		var val_data = data.validation
		validation_enabled = val_data.get("validation_enabled", validation_enabled)
		auto_fix_enabled = val_data.get("auto_fix_enabled", auto_fix_enabled)
		realtime_validation = val_data.get("realtime_validation", realtime_validation)
	
	# Load UI settings
	if data.has("ui"):
		var ui_data = data.ui
		if ui_data.has("property_panel_position"):
			var pos_data = ui_data.property_panel_position
			property_panel_position = Vector2(pos_data.x, pos_data.y)
		if ui_data.has("property_panel_size"):
			var size_data = ui_data.property_panel_size
			property_panel_size = Vector2(size_data.x, size_data.y)
		ui_theme = ui_data.get("ui_theme", ui_theme)
		show_tooltips = ui_data.get("show_tooltips", show_tooltips)
	
	# Load shape defaults
	if data.has("shape_defaults"):
		var shape_data = data.shape_defaults
		if shape_data.has("default_shape_size"):
			var size_data = shape_data.default_shape_size
			default_shape_size = Vector2(size_data.x, size_data.y)
		default_extrusion_height = shape_data.get("default_extrusion_height", default_extrusion_height)
		default_interior_offset = shape_data.get("default_interior_offset", default_interior_offset)
		auto_save_enabled = shape_data.get("auto_save_enabled", auto_save_enabled)
		auto_save_interval = shape_data.get("auto_save_interval", auto_save_interval)
	
	# Load window defaults
	if data.has("window_defaults"):
		var window_data = data.window_defaults
		default_window_width = window_data.get("default_window_width", default_window_width)
		default_window_height = window_data.get("default_window_height", default_window_height)
		default_window_style = window_data.get("default_window_style", default_window_style)
	
	# Load door defaults
	if data.has("door_defaults"):
		var door_data = data.door_defaults
		default_door_width = door_data.get("default_door_width", default_door_width)
		default_door_height = door_data.get("default_door_height", default_door_height)
		default_door_style = door_data.get("default_door_style", default_door_style)
	
	# Load 3D settings
	if data.has("3d_settings"):
		var cam_data = data["3d_settings"]
		default_camera_distance = cam_data.get("default_camera_distance", default_camera_distance)
		camera_rotation_speed = cam_data.get("camera_rotation_speed", camera_rotation_speed)
		zoom_speed = cam_data.get("zoom_speed", zoom_speed)
	
	# Load file paths
	if data.has("file_paths"):
		var path_data = data.file_paths
		shapes_save_path = path_data.get("shapes_save_path", shapes_save_path)
		export_path = path_data.get("export_path", export_path)
	
	print("✓ Settings loaded from ", settings_save_path)

# Setter methods with validation and signal emission
func set_validation_enabled(enabled: bool):
	if validation_enabled != enabled:
		validation_enabled = enabled
		var AutoValidator = preload("res://ui/AutoValidator.gd")
		AutoValidator.set_validation_enabled(enabled)
		settings_changed.emit("validation_enabled", enabled)

func set_auto_fix_enabled(enabled: bool):
	if auto_fix_enabled != enabled:
		auto_fix_enabled = enabled
		var AutoValidator = preload("res://ui/AutoValidator.gd")
		AutoValidator.set_auto_fix_enabled(enabled)
		settings_changed.emit("auto_fix_enabled", enabled)

func set_realtime_validation(enabled: bool):
	if realtime_validation != enabled:
		realtime_validation = enabled
		settings_changed.emit("realtime_validation", enabled)

func set_property_panel_position(pos: Vector2):
	if property_panel_position != pos:
		property_panel_position = pos
		settings_changed.emit("property_panel_position", pos)

func set_property_panel_size(size: Vector2):
	if property_panel_size != size:
		property_panel_size = size
		settings_changed.emit("property_panel_size", size)

func set_ui_theme(theme: String):
	if ui_theme != theme:
		ui_theme = theme
		settings_changed.emit("ui_theme", theme)

func set_default_shape_size(size: Vector2):
	if default_shape_size != size:
		default_shape_size = size
		settings_changed.emit("default_shape_size", size)

func set_default_extrusion_height(height: float):
	if default_extrusion_height != height:
		default_extrusion_height = height
		settings_changed.emit("default_extrusion_height", height)

func set_default_interior_offset(offset: float):
	if default_interior_offset != offset:
		default_interior_offset = offset
		settings_changed.emit("default_interior_offset", offset)

# Getter methods for convenient access
func get_validation_settings() -> Dictionary:
	return {
		"validation_enabled": validation_enabled,
		"auto_fix_enabled": auto_fix_enabled,
		"realtime_validation": realtime_validation
	}

func get_ui_settings() -> Dictionary:
	return {
		"property_panel_position": property_panel_position,
		"property_panel_size": property_panel_size,
		"ui_theme": ui_theme,
		"show_tooltips": show_tooltips
	}

func get_shape_defaults() -> Dictionary:
	return {
		"default_shape_size": default_shape_size,
		"default_extrusion_height": default_extrusion_height,
		"default_interior_offset": default_interior_offset,
		"auto_save_enabled": auto_save_enabled,
		"auto_save_interval": auto_save_interval
	}

func get_window_defaults() -> Dictionary:
	return {
		"default_window_width": default_window_width,
		"default_window_height": default_window_height,
		"default_window_style": default_window_style
	}

func get_door_defaults() -> Dictionary:
	return {
		"default_door_width": default_door_width,
		"default_door_height": default_door_height,
		"default_door_style": default_door_style
	}

func reset_to_defaults():
	validation_enabled = true
	auto_fix_enabled = false
	realtime_validation = true
	
	property_panel_position = Vector2(10, 10)
	property_panel_size = Vector2(320, 800)
	ui_theme = "dark"
	show_tooltips = true
	
	default_shape_size = Vector2(300, 300)
	default_extrusion_height = 255.0
	default_interior_offset = 12.5
	auto_save_enabled = true
	auto_save_interval = 30.0
	
	default_window_width = 45.0
	default_window_height = 120.0
	default_window_style = "standard"
	
	default_door_width = 90.0
	default_door_height = 200.0
	default_door_style = "standard"
	
	default_camera_distance = 10.0
	camera_rotation_speed = 0.5
	zoom_speed = 0.1
	
	shapes_save_path = "user://shapes.json"
	export_path = "user://exports/"
	
	print("✓ Settings reset to defaults")

func export_settings(file_path: String) -> bool:
	var export_data = {
		"timestamp": Time.get_datetime_string_from_system(),
		"version": "1.0",
		"settings": get_all_settings()
	}
	
	var json_text = JSON.stringify(export_data, "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
		print("✓ Settings exported to ", file_path)
		return true
	else:
		print("✗ Failed to export settings to ", file_path)
		return false

func import_settings(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("✗ Cannot open settings file: ", file_path)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("✗ Failed to parse settings JSON")
		return false
	
	var data = json.data
	if not data is Dictionary or not data.has("settings"):
		print("✗ Invalid settings file format")
		return false
	
	# Temporarily store current settings for rollback
	var backup = get_all_settings()
	
	try:
		_apply_settings_data(data.settings)
		print("✓ Settings imported from ", file_path)
		return true
	except:
		print("✗ Error applying imported settings, reverting to backup")
		_apply_settings_data(backup)
		return false

func _apply_settings_data(settings_data: Dictionary):
	# Apply the loaded settings using the same structure as load_settings
	# This is a simplified version that could be expanded
	if settings_data.has("validation"):
		var val_data = settings_data.validation
		set_validation_enabled(val_data.get("validation_enabled", validation_enabled))
		set_auto_fix_enabled(val_data.get("auto_fix_enabled", auto_fix_enabled))
		set_realtime_validation(val_data.get("realtime_validation", realtime_validation))

func get_all_settings() -> Dictionary:
	return {
		"validation": get_validation_settings(),
		"ui": get_ui_settings(),
		"shape_defaults": get_shape_defaults(),
		"window_defaults": get_window_defaults(),
		"door_defaults": get_door_defaults()
	}
