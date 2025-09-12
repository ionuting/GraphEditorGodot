extends Node2D  # GraphNode sau CanvasItem merg și ele

@export var arrow_length: float = 50.0
@export var arrow_size: float = 10.0

func _draw():
	# Originea în coordonate GraphEdit
	draw_arrow(Vector2.ZERO, Vector2(arrow_length, 0), Color.RED)   # X
	draw_arrow(Vector2.ZERO, Vector2(0, arrow_length), Color.GREEN) # Y

func draw_arrow(start: Vector2, end: Vector2, color: Color):
	draw_line(start, end, color, 2)
	var dir = (end - start).normalized()
	var perp = Vector2(-dir.y, dir.x)
	var tip1 = end - dir * arrow_size + perp * arrow_size * 0.5
	var tip2 = end - dir * arrow_size - perp * arrow_size * 0.5
	draw_line(end, tip1, color, 2)
	draw_line(end, tip2, color, 2)
