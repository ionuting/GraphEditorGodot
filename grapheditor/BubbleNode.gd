extends Node2D

var radius = 30.0

func _draw():
	# Draw a circular node
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.6, 1, 0.8))
	draw_arc(Vector2.ZERO, radius, 0, 2 * PI, 32, Color(1, 1, 1), 2.0)

func _ready():
	# Ensure the node redraws when needed
	queue_redraw()
