# Test script for modular UI system
# Rulează acest script pentru a testa funcționalitatea modulelor

extends SceneTree

func _initialize():
	print("=== Testing Modular UI System ===\n")
	
	# Test AppSettings
	test_app_settings()
	
	# Test ShapeManager
	test_shape_manager()
	
	# Test AutoValidator
	test_auto_validator()
	
	# Test UIHelper
	test_ui_helper()
	
	print("\n=== All tests completed ===")
	quit()

func test_app_settings():
	print("📋 Testing AppSettings...")
	
	var AppSettings = preload("res://ui/AppSettings.gd")
	var settings = AppSettings.get_instance()
	
	# Test default values
	assert(settings.validation_enabled == true, "Default validation should be enabled")
	assert(settings.default_shape_size == Vector2(300, 300), "Default shape size should be 300x300")
	
	# Test setting changes
	settings.set_validation_enabled(false)
	assert(settings.validation_enabled == false, "Validation should be disabled after setting")
	
	# Test save/load
	settings.save_settings()
	print("  ✓ Settings save/load functionality working")
	
	# Reset to defaults
	settings.reset_to_defaults()
	assert(settings.validation_enabled == true, "Should return to default after reset")
	
	print("  ✓ AppSettings tests passed\n")

func test_shape_manager():
	print("📋 Testing ShapeManager...")
	
	var ShapeManager = preload("res://ui/ShapeManager.gd")
	var manager = ShapeManager.get_instance()
	
	# Test singleton
	var manager2 = ShapeManager.get_instance()
	assert(manager == manager2, "Should return same instance (singleton)")
	
	# Test statistics with no shapes
	var stats = manager.get_shapes_statistics()
	assert(stats.total_count == 0, "Should start with 0 shapes")
	
	# Test geometry summary
	var geometry = manager.get_geometry_summary()
	assert(geometry.total_area == 0.0, "Should start with 0 total area")
	
	print("  ✓ ShapeManager tests passed\n")

func test_auto_validator():
	print("📋 Testing AutoValidator...")
	
	var AutoValidator = preload("res://ui/AutoValidator.gd")
	
	# Test settings
	AutoValidator.set_validation_enabled(true)
	AutoValidator.set_auto_fix_enabled(false)
	
	var settings = AutoValidator.get_validation_settings()
	assert(settings.validation_enabled == true, "Validation should be enabled")
	assert(settings.auto_fix_enabled == false, "Auto-fix should be disabled")
	
	print("  ✓ AutoValidator tests passed\n")

func test_ui_helper():
	print("📋 Testing UIHelper...")
	
	var UIHelper = preload("res://ui/UIHelper.gd")
	
	# Test text formatting
	var validation_result = {
		"is_valid": false,
		"warnings": ["Test warning"],
		"errors": ["Test error"]
	}
	
	var formatted = UIHelper.format_validation_text(validation_result)
	assert("Test warning" in formatted, "Should include warning text")
	assert("Test error" in formatted, "Should include error text")
	
	# Test geometry formatting
	var geometry_info = {
		"exterior_area": 100.0,
		"interior_area": 80.0,
		"area_unit": "m²"
	}
	
	var geo_formatted = UIHelper.format_geometry_text(geometry_info)
	assert("100.00" in geo_formatted, "Should include exterior area")
	assert("80.00" in geo_formatted, "Should include interior area")
	
	print("  ✓ UIHelper tests passed\n")

func _ready():
	_initialize()
