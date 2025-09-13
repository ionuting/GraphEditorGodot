# CADViewer2D_Simple.gd
# Versiune simplificată pentru debugging
extends Control

@onready var viewport_container: SubViewport
@onready var camera_2d: Camera2D
@onready var draw_node: Node2D

func _ready():
	print("CADViewer2D_Simple._ready() apelat")
	setup_viewport()
	setup_drawing()
	
	# Test drawing imediat
	call_deferred("test_drawing")

func setup_viewport():
	print("Setup viewport...")
	# Creează SubViewport
	viewport_container = SubViewport.new()
	viewport_container.size = size
	viewport_container.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport_container)
	
	# Creează scena 2D principală
	var main_2d = Node2D.new()
	main_2d.name = "Main2D"
	viewport_container.add_child(main_2d)
	
	# Camera2D
	camera_2d = Camera2D.new()
	camera_2d.name = "Camera2D"
	camera_2d.position = Vector2.ZERO
	camera_2d.zoom = Vector2.ONE
	camera_2d.enabled = true
	main_2d.add_child(camera_2d)
	
	print("Viewport setup complet")

func setup_drawing():
	print("Setup drawing...")
	# Node2D pentru desenare
	draw_node = TestDrawNode.new()
	draw_node.name = "DrawNode"
	viewport_container.get_child(0).add_child(draw_node)
	print("Drawing setup complet")

func test_drawing():
	print("Test drawing...")
	if draw_node:
		draw_node.queue_redraw()
		print("Redraw solicitat")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		print("Mouse click detectat: ", event.position)

# Clasă simplă de test pentru desenare
class TestDrawNode extends Node2D:
	
	func _ready():
		print("TestDrawNode._ready() apelat")
		queue_redraw()
	
	func _draw():
		print("TestDrawNode._draw() apelat!")
		
		# Desenează ceva simplu pentru test
		var viewport_size = get_viewport().size
		
		# Linie roșie orizontală
		draw_line(Vector2(0, viewport_size.y/2), Vector2(viewport_size.x, viewport_size.y/2), Color.RED, 3.0)
		
		# Linie roșie verticală  
		draw_line(Vector2(viewport_size.x/2, 0), Vector2(viewport_size.x/2, viewport_size.y), Color.RED, 3.0)
		
		# Cerc în centru
		draw_circle(viewport_size/2, 20, Color.BLUE)
		
		# Text
		var font = ThemeDB.fallback_font
		draw_string(font, Vector2(50, 50), "TEST DRAWING", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		
		print("Desenare completă!")