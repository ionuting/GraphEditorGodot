extends Node2D
class_name StoreyCanvas2D

var storey_id: String = ""
var storey_name: String = ""
var base_level: float = 0.0
var top_level: float = 3.0

func _ready():
	_setup_debug_visuals()

func _setup_debug_visuals():
	# Adăugăm informații vizuale despre etaj
	var info_label = Label.new()
	info_label.name = "StoreyInfoLabel"
	info_label.text = "%s\nBase: %.2fm | Top: %.2fm" % [storey_name, base_level, top_level]
	info_label.position = Vector2(10, 10)
	
	var bg = ColorRect.new()
	bg.name = "LabelBackground"
	bg.color = Color(0, 0, 0, 0.5)
	bg.position = Vector2(5, 5)
	bg.size = Vector2(200, 45)
	
	add_child(bg)
	add_child(info_label)

func update_info():
	var info_label = get_node_or_null("StoreyInfoLabel")
	if info_label:
		info_label.text = "%s\nBase: %.2fm | Top: %.2fm" % [storey_name, base_level, top_level]
