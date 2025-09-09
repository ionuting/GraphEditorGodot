# Demo Implementation Example
# Exemplu de cum să folosești sistemul modular în propriul tău cod

extends Node

# Exemplu de implementare completă folosind modulele create
var shape_manager: ShapeManager
var property_panel: PropertyPanel
var current_shape: TetrisShape2D = null

func _ready():
	setup_modular_system()
	create_demo_shapes()
	demonstrate_functionality()

func setup_modular_system():
	"""Configurează sistemul modular"""
	print("🔧 Setting up modular system...")
	
	# 1. Configurează setările aplicației
	var settings = AppSettings.get_instance()
	settings.set_validation_enabled(true)
	settings.set_auto_fix_enabled(true)
	
	# 2. Inițializează shape manager
	shape_manager = ShapeManager.get_instance()
	shape_manager.shape_added.connect(_on_shape_added)
	shape_manager.shape_modified.connect(_on_shape_modified)
	
	# 3. Creează property panel
	property_panel = preload("res://ui/PropertyPanel.gd").new()
	add_child(property_panel)
	property_panel.property_changed.connect(_on_property_changed)
	property_panel.panel_closed.connect(_on_panel_closed)
	
	# 4. Configurează validatorul automat
	var AutoValidator = preload("res://ui/AutoValidator.gd")
	AutoValidator.set_validation_enabled(true)
	AutoValidator.set_auto_fix_enabled(true)
	
	print("✓ Modular system ready!")

func create_demo_shapes():
	"""Creează forme demo pentru testare"""
	print("\n🏠 Creating demo shapes...")
	
	# Creează o formă rectangle
	var TetrisShape2D = preload("res://TetrisShape2D.gd")
	var shape1 = TetrisShape2D.new()
	shape1.shape_type = "rectangle"
	shape1.position = Vector2(200, 200)
	shape1.set_dimensions(Vector2(300, 250))
	shape1.room_name = "Living Room"
	shape1.central_color = Color.LIGHT_BLUE
	
	# Configurează fereastră
	shape1.set_has_window(true)
	shape1.set_window_style("standard")
	shape1.set_window_width(80)
	shape1.set_window_height(120)
	shape1.set_window_side(90)  # Right side
	
	# Configurează ușă
	shape1.set_has_door(true)
	shape1.set_door_style("standard") 
	shape1.set_door_width(90)
	shape1.set_door_height(200)
	shape1.set_door_side(0)  # Bottom side
	
	add_child(shape1)
	shape_manager.add_shape(shape1)
	
	# Creează a doua formă
	var shape2 = TetrisShape2D.new()
	shape2.shape_type = "rectangle"
	shape2.position = Vector2(600, 200)
	shape2.set_dimensions(Vector2(250, 300))
	shape2.room_name = "Bedroom"
	shape2.central_color = Color.LIGHT_PINK
	
	shape2.set_has_window(true)
	shape2.set_window_style("casement")
	shape2.set_window_width(60)
	shape2.set_window_height(100)
	shape2.set_window_side(180)  # Top side
	
	add_child(shape2)
	shape_manager.add_shape(shape2)
	
	current_shape = shape1
	print("✓ Created 2 demo shapes")

func demonstrate_functionality():
	"""Demonstrează funcționalitățile sistemului"""
	print("\n🎯 Demonstrating functionality...")
	
	# 1. Afișează statisticile
	show_statistics()
	
	# 2. Validează toate formele
	validate_all_shapes()
	
	# 3. Testează property panel
	test_property_panel()
	
	# 4. Demonstrează validarea în timp real
	demonstrate_realtime_validation()
	
	# 5. Export/import
	test_export_import()

func show_statistics():
	"""Afișează statisticile formelor"""
	print("\n📊 Shape Statistics:")
	
	var stats = shape_manager.get_shapes_statistics()
	print("  • Total shapes: ", stats.total_count)
	print("  • Shapes by type: ", stats.by_type)
	print("  • Shapes with windows: ", stats.with_windows)
	print("  • Shapes with doors: ", stats.with_doors)
	print("  • Average area: %.2f" % stats.average_area)
	
	var geometry = shape_manager.get_geometry_summary()
	print("  • Total area: %.2f" % geometry.total_area)
	print("  • Total window area: %.2f" % geometry.total_window_area)
	print("  • Total door area: %.2f" % geometry.total_door_area)

func validate_all_shapes():
	"""Validează toate formele"""
	print("\n🔍 Validation Results:")
	
	var AutoValidator = preload("res://ui/AutoValidator.gd")
	var results = AutoValidator.validate_all_shapes_in_manager(shape_manager)
	
	print("  • Total validated: ", results.total_validated)
	print("  • Valid shapes: ", results.valid_shapes)
	print("  • Invalid shapes: ", results.invalid_shapes)
	print("  • Total warnings: ", results.total_warnings)
	print("  • Total errors: ", results.total_errors)
	
	# Afișează detalii pentru fiecare formă
	for shape_id in results.shape_results:
		var result = results.shape_results[shape_id]
		if not result.is_valid:
			print("    ⚠ Shape %s has issues: %s" % [shape_id, str(result.errors)])

func test_property_panel():
	"""Testează property panel"""
	print("\n🎛️ Testing Property Panel:")
	
	if current_shape and property_panel:
		property_panel.set_shape(current_shape)
		print("  ✓ Property panel configured for shape: ", current_shape.unique_id)
		
		# Testează o modificare
		var old_name = current_shape.room_name
		current_shape.set_room_name("Modified Room")
		print("  ✓ Room name changed from '", old_name, "' to '", current_shape.room_name, "'")

func demonstrate_realtime_validation():
	"""Demonstrează validarea în timp real"""
	print("\n⚡ Realtime Validation Demo:")
	
	if current_shape:
		var AutoValidator = preload("res://ui/AutoValidator.gd")
		
		# Configurează validarea în timp real
		AutoValidator.setup_realtime_validation(current_shape, property_panel)
		
		# Creează o problemă intenționat
		current_shape.set_window_width(500)  # Prea lată pentru formă
		
		# Validează
		var validation = AutoValidator.validate_shape_realtime(current_shape)
		if validation.warnings.size() > 0:
			print("  ⚠ Warning detected: ", validation.warnings[0])
		
		# Auto-fix dacă e activat
		var fixes = AutoValidator.auto_fix_shape_issues(current_shape)
		if fixes.size() > 0:
			print("  🔧 Auto-fixes applied: ", fixes)

func test_export_import():
	"""Testează export/import"""
	print("\n💾 Export/Import Test:")
	
	# Export shapes
	var export_path = "user://demo_shapes.json"
	if shape_manager.export_shapes_to_json(export_path):
		print("  ✓ Shapes exported to: ", export_path)
	
	# Export settings
	var settings = AppSettings.get_instance()
	var settings_path = "user://demo_settings.json"
	if settings.export_settings(settings_path):
		print("  ✓ Settings exported to: ", settings_path)

# Signal handlers
func _on_shape_added(shape: TetrisShape2D):
	print("📦 Shape added: ", shape.unique_id)

func _on_shape_modified(shape: TetrisShape2D):
	print("✏️ Shape modified: ", shape.unique_id)

func _on_property_changed(property_name: String, value):
	print("🔧 Property changed: %s = %s" % [property_name, str(value)])

func _on_panel_closed():
	print("🚪 Property panel closed")

# Funcție principală pentru rulare
func run_demo():
	"""Rulează demo-ul complet"""
	print("🚀 Starting Modular UI System Demo...")
	print("=" * 50)
	
	_ready()
	
	print("\n" + "=" * 50)
	print("✅ Demo completed successfully!")
	print("\nSystemul modular este funcțional și gata de utilizare!")
	print("Verifică fișierele create în user:// pentru export-uri.")
