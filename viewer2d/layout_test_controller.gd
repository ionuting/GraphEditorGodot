# LayoutTestController.gd - Controller pentru interfața de test layout
extends Control

@onready var layout_sheet = $ScrollContainer/LayoutSheet
@onready var paper_option = $UI/Toolbar/PaperSizeOption
@onready var add_top_btn = $UI/Toolbar/AddViewportBtn
@onready var add_front_btn = $UI/Toolbar/AddFrontBtn  
@onready var add_iso_btn = $UI/Toolbar/AddIsoBtn
@onready var clear_btn = $UI/Toolbar/ClearBtn
@onready var export_btn = $UI/Toolbar/ExportBtn

var next_viewport_position = Vector2(50, 50)
var viewport_spacing = Vector2(50, 50)

# Project model selection
var current_model_index: int = 0
var available_models: Array[String] = []
var model_selector: OptionButton

func _ready():
	print("[LayoutTest] Initializing layout test interface...")
	
	# Încarcă modelele din proiect și creează selectorul
	check_for_test_models()
	setup_model_selector()

func check_for_test_models():
	"""Încarcă modelele din proiectul principal"""
	if layout_sheet:
		# Forțează încărcarea proiectului din python/dxf/
		layout_sheet.load_project_folder("python/dxf/")
		
		available_models = layout_sheet.get_available_models()
		print("[LayoutTest] Loaded " + str(available_models.size()) + " models from project")
		
		# Afișează modelele disponibile
		for model in available_models:
			print("[LayoutTest] Available: " + model)

func setup_model_selector():
	"""Creează un selector pentru modelele disponibile"""
	# Creează OptionButton pentru selectarea modelului
	model_selector = OptionButton.new()
	model_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Adaugă modelele în selector
	for i in range(available_models.size()):
		var model_path = available_models[i]
		var model_name = model_path.get_file().replace(".glb", "")
		model_selector.add_item(model_name, i)
	
	# Conectează semnalul
	model_selector.item_selected.connect(_on_model_selected)
	
	# Adaugă într-un label container
	var container = HBoxContainer.new()
	var label = Label.new()
	label.text = "Model: "
	container.add_child(label)
	container.add_child(model_selector)
	
	# Adaugă în toolbar (înaintea paper size selector)
	var toolbar = $UI/Toolbar
	toolbar.add_child(container)
	toolbar.move_child(container, 0)  # La început
	
	print("[LayoutTest] Model selector setup with " + str(available_models.size()) + " models")

func _on_model_selected(index: int):
	"""Callback pentru schimbarea modelului selectat"""
	current_model_index = index
	var model_name = available_models[index].get_file().replace(".glb", "")
	print("[LayoutTest] Selected model: " + model_name)

func _on_paper_size_selected(index: int):
	"""Schimbă dimensiunea foii"""
	var size_names = ["A3_LANDSCAPE", "A3_PORTRAIT", "A4_LANDSCAPE", "A4_PORTRAIT", "A2_LANDSCAPE", "A2_PORTRAIT"]
	if index < size_names.size() and layout_sheet:
		layout_sheet.set_paper_size(size_names[index])
		# Reset viewport positions
		next_viewport_position = Vector2(50, 50)

func _on_add_top_view():
	"""Adaugă un viewport cu vederea de sus"""
	if layout_sheet:
		# Folosește modelul selectat
		layout_sheet.add_project_viewport(
			next_viewport_position,
			Vector2(400, 300),
			layout_sheet.CameraView.TOP,
			current_model_index
		)
		_advance_viewport_position()

func _on_add_front_view():
	"""Adaugă un viewport cu vederea frontală"""
	if layout_sheet:
		# Folosește modelul selectat
		layout_sheet.add_project_viewport(
			next_viewport_position,
			Vector2(400, 300),
			layout_sheet.CameraView.FRONT,
			current_model_index
		)
		_advance_viewport_position()

func _on_add_iso_view():
	"""Adaugă un viewport izometric"""
	if layout_sheet:
		# Folosește modelul selectat
		layout_sheet.add_project_viewport(
			next_viewport_position,
			Vector2(400, 400),
			layout_sheet.CameraView.ISOMETRIC,
			current_model_index
		)
		_advance_viewport_position()

func _on_clear_all():
	"""Șterge toate viewport-urile"""
	if layout_sheet:
		layout_sheet.clear_viewports()
		next_viewport_position = Vector2(50, 50)

func _on_export_svg():
	"""Exportă layout-ul ca SVG"""
	if layout_sheet:
		var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
		var filename = "layout_export_" + timestamp + ".svg"
		layout_sheet.export_to_svg(filename)
		print("[LayoutTest] Export requested: " + filename)

func _advance_viewport_position():
	"""Avansează pozițiile pentru următorul viewport"""
	next_viewport_position.x += 450  # Lățime viewport + spațiu
	if next_viewport_position.x > 1200:  # Wrap to next row
		next_viewport_position.x = 50
		next_viewport_position.y += 350  # Înălțime viewport + spațiu
