extends Node
class_name StoreyManager

signal storey_canvas_created(storey_id, canvas)
signal storey_canvas_updated(storey_id, canvas)
signal storey_canvas_removed(storey_id)

var project_browser: ProjectBrowser
var viewport_tabs: Node  # Referință către sistemul de tab-uri
var main_scene: Node  # Referință către scena principală
var active_storey_id: String = ""
var canvases: Dictionary = {}  # storey_id -> canvas

func _init(p_project_browser: ProjectBrowser, p_viewport_tabs: Node, p_main_scene: Node):
	project_browser = p_project_browser
	viewport_tabs = p_viewport_tabs
	main_scene = p_main_scene
	
	# Conectăm semnalele de la ProjectBrowser
	project_browser.storey_opened.connect(_on_storey_opened)
	project_browser.storey_closed.connect(_on_storey_closed)
	project_browser.storey_removed.connect(_on_storey_removed)
	project_browser.storey_updated.connect(_on_storey_updated)

func _on_storey_opened(storey_data: Dictionary):
	var storey_id = storey_data.id
	
	# Verificăm dacă există deja un canvas pentru acest etaj
	if canvases.has(storey_id):
		# Deschide tab-ul existent
		viewport_tabs.open_tab(storey_id, storey_data.name)
		active_storey_id = storey_id
		return
	
	# Creăm un nou canvas pentru etaj
	var canvas = _create_storey_canvas(storey_data)
	if canvas:
		canvases[storey_id] = canvas
		project_browser.set_storey_canvas(storey_id, canvas)
		
		# Adăugăm canvas-ul la scenă
		if main_scene.has_node("CanvasLayer"):
			var canvas_layer = main_scene.get_node("CanvasLayer")
			canvas_layer.add_child(canvas)
		else:
			main_scene.add_child(canvas)
		
		# Creăm un tab nou pentru acest canvas
		viewport_tabs.add_tab(storey_id, storey_data.name, canvas)
		viewport_tabs.open_tab(storey_id, storey_data.name)
		
		active_storey_id = storey_id
		storey_canvas_created.emit(storey_id, canvas)

func _on_storey_closed(storey_id: String):
	if canvases.has(storey_id):
		# Ascundem canvas-ul, dar nu-l ștergem
		if canvases[storey_id]:
			canvases[storey_id].visible = false
		
		# Închidem tab-ul
		viewport_tabs.close_tab(storey_id)
		
		if active_storey_id == storey_id:
			active_storey_id = ""

func _on_storey_removed(storey_id: String):
	if canvases.has(storey_id):
		# Ștergem canvas-ul
		if canvases[storey_id]:
			canvases[storey_id].queue_free()
		
		# Închidem tab-ul
		viewport_tabs.close_tab(storey_id)
		
		# Eliminăm referința
		canvases.erase(storey_id)
		
		if active_storey_id == storey_id:
			active_storey_id = ""
		
		storey_canvas_removed.emit(storey_id)

func _on_storey_updated(storey_data: Dictionary):
	var storey_id = storey_data.id
	
	# Actualizăm numele tab-ului dacă există
	if viewport_tabs.has_tab(storey_id):
		viewport_tabs.update_tab_title(storey_id, storey_data.name)
	
	# Actualizăm canvas-ul dacă există
	if canvases.has(storey_id) and canvases[storey_id]:
		_update_storey_canvas(storey_id, storey_data)
		storey_canvas_updated.emit(storey_id, canvases[storey_id])

func _create_storey_canvas(storey_data: Dictionary) -> Node:
	# Creăm un nod Canvas2D pentru etaj
	var canvas = Node2D.new()
	canvas.name = "StoreyCanvas_" + storey_data.id
	
	# Adăugăm un component StoreyCanvas2D (vom crea această clasă)
	var storey_canvas = StoreyCanvas2D.new()
	storey_canvas.name = "StoreyComponent"
	storey_canvas.storey_id = storey_data.id
	storey_canvas.storey_name = storey_data.name
	storey_canvas.base_level = storey_data.base_level
	storey_canvas.top_level = storey_data.top_level
	canvas.add_child(storey_canvas)
	
	# Adăugăm componente necesare pentru desenare
	var polygon_drawer = load("res://PolygonDrawer2D.gd").new()
	polygon_drawer.name = "PolygonDrawer2D"
	polygon_drawer.extrusion_height = storey_data.top_level - storey_data.base_level
	canvas.add_child(polygon_drawer)
	
	# Adăugăm un ShapeLayer pentru formele Tetris
	var shape_layer = Node2D.new()
	shape_layer.name = "ShapeLayer"
	canvas.add_child(shape_layer)
	
	# Facem canvas-ul inițial invizibil
	canvas.visible = false
	
	return canvas

func _update_storey_canvas(storey_id: String, storey_data: Dictionary):
	if not canvases.has(storey_id) or not canvases[storey_id]:
		return
	
	var canvas = canvases[storey_id]
	
	# Actualizăm componentul StoreyCanvas2D
	var storey_component = canvas.get_node_or_null("StoreyComponent")
	if storey_component:
		storey_component.storey_name = storey_data.name
		storey_component.base_level = storey_data.base_level
		storey_component.top_level = storey_data.top_level
	
	# Actualizăm înălțimea de extrudare a PolygonDrawer2D
	var polygon_drawer = canvas.get_node_or_null("PolygonDrawer2D")
	if polygon_drawer:
		polygon_drawer.extrusion_height = storey_data.top_level - storey_data.base_level

# API publică
func get_active_storey_id() -> String:
	return active_storey_id

func get_storey_canvas(storey_id: String) -> Node:
	if canvases.has(storey_id):
		return canvases[storey_id]
	return null

func get_all_canvases() -> Dictionary:
	return canvases.duplicate()

func open_storey(storey_id: String):
	var storey_data = project_browser.get_storey_data(storey_id)
	if not storey_data.is_empty():
		_on_storey_opened(storey_data)

func close_storey(storey_id: String):
	_on_storey_closed(storey_id)

func save_storey_data(storey_id: String) -> Dictionary:
	if not canvases.has(storey_id):
		return {}
	
	var canvas = canvases[storey_id]
	var data = {
		"storey_id": storey_id,
		"shapes": [],
		"polygon": []
	}
	
	# Salvăm datele formelor Tetris
	var shape_layer = canvas.get_node_or_null("ShapeLayer")
	if shape_layer:
		for shape in shape_layer.get_children():
			if shape.has_method("save_data"):
				data.shapes.append(shape.save_data())
	
	# Salvăm datele poligonului
	var polygon_drawer = canvas.get_node_or_null("PolygonDrawer2D")
	if polygon_drawer:
		data.polygon = polygon_drawer.save_points()
	
	return data

func load_storey_data(storey_id: String, data: Dictionary):
	if not canvases.has(storey_id):
		return
	
	var canvas = canvases[storey_id]
	
	# Încărcăm formele Tetris
	var shape_layer = canvas.get_node_or_null("ShapeLayer")
	if shape_layer and data.has("shapes"):
		# Curățăm formele existente
		for child in shape_layer.get_children():
			child.queue_free()
		
		# Încărcăm noile forme
		for shape_data in data.shapes:
			var TetrisShape2D = load("res://TetrisShape2D.gd")
			var shape = TetrisShape2D.new()
			shape_layer.add_child(shape)
			shape.load_data(shape_data)
	
	# Încărcăm poligonul
	var polygon_drawer = canvas.get_node_or_null("PolygonDrawer2D")
	if polygon_drawer and data.has("polygon"):
		polygon_drawer.load_points(data.polygon)
	
	storey_canvas_updated.emit(storey_id, canvas)
