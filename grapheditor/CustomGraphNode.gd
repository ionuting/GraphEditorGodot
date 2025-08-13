# BubbleGraphNode.gd
extends GraphNode
class_name BubbleGraphNode

@export var bubble_radius: float = 30.0
@export var bubble_color: Color = Color.CYAN
@export var label_text: String = "Node"
@export var max_connections: int = -1  # -1 pentru nelimitat

var connections_count: int = 0

signal bubble_clicked(node: BubbleGraphNode)

func _ready():
	# Configurează GraphNode pentru a fi transparent
	resizable = false
	draggable = true
	selectable = true
	
	# Ascunde titlul implicit
	title = ""
	
	setup_bubble_ui()

func setup_bubble_ui():
	# Șterge toate copiii existenți
	for child in get_children():
		child.queue_free()
	
	# Creează container principal
	var main_container = Control.new()
	main_container.custom_minimum_size = Vector2(bubble_radius * 2 + 20, bubble_radius * 2 + 20)
	add_child(main_container)
	
	# Creează cercul principal
	var bubble_control = Control.new()
	bubble_control.custom_minimum_size = Vector2(bubble_radius * 2, bubble_radius * 2)
	bubble_control.position = Vector2(10, 10)  # Centrat în container
	bubble_control.draw.connect(_draw_bubble.bind(bubble_control))
	main_container.add_child(bubble_control)
	
	# Adaugă label în centrul cercului
	var label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(5, bubble_radius - 10)
	label.size = Vector2(bubble_radius * 2 - 10, 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	main_container.add_child(label)
	
	# Configurează un singur slot universal care poate conecta în orice direcție
	# Folosim mai multe sloturi pentru a permite conexiuni multiple
	setup_universal_slots()
	
	# Conectează input-urile pentru click pe bubble
	bubble_control.gui_input.connect(_on_bubble_input)

func setup_universal_slots():
	# Creăm multiple sloturi invizibile care permit conexiuni
	# Fiecare slot poate fi folosit pentru input SAU output
	for i in range(10):  # 10 sloturi pentru conexiuni multiple
		set_slot(i, true, 0, bubble_color, true, 0, bubble_color)

func _draw_bubble(control: Control):
	var center = Vector2(bubble_radius, bubble_radius)
	
	# Desenează umbra
	control.draw_circle(center + Vector2(2, 2), bubble_radius + 2, Color(0, 0, 0, 0.3))
	
	# Desenează cercul principal
	control.draw_circle(center, bubble_radius, bubble_color)
	
	# Desenează conturul
	control.draw_arc(center, bubble_radius, 0, TAU, 32, Color.WHITE, 3.0)
	
	# Desenează un punct central dacă are conexiuni
	if connections_count > 0:
		control.draw_circle(center, 5, Color.WHITE)
	
	# Desenează numărul de conexiuni
	if connections_count > 0:
		var font = ThemeDB.fallback_font
		var font_size = 12
		var text = str(connections_count)
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_pos = center - text_size / 2 + Vector2(0, -15)
		control.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)

func _on_bubble_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			bubble_clicked.emit(self)

func set_bubble_color(color: Color):
	bubble_color = color
	# Actualizează toate sloturile cu noua culoare
	for i in range(10):
		set_slot(i, true, 0, color, true, 0, color)
	queue_redraw()

func set_label(text: String):
	label_text = text
	# Caută label-ul și actualizează textul
	for child in get_children():
		for subchild in child.get_children():
			if subchild is Label:
				subchild.text = text
				break

func increment_connections():
	connections_count += 1
	queue_redraw()

func decrement_connections():
	connections_count = max(0, connections_count - 1)
	queue_redraw()

func can_accept_connection() -> bool:
	return max_connections == -1 or connections_count < max_connections

# Override pentru a controla vizibilitatea sloturilor
func _draw():
	super._draw()
	# GraphNode va desena sloturile, dar le facem transparente prin CSS
