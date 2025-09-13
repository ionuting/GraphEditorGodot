# CADRenderer.gd
# Renderer custom pentru grid, axe și dreptunghiuri
extends Node2D

var cad_viewer: Control

func _ready():
	print("CADRenderer._ready() apelat!")
	# Asigură-te că redraw-ul este apelat
	queue_redraw()
	print("CADRenderer queue_redraw() apelat în _ready()")

func set_cad_viewer(viewer: Control):
	cad_viewer = viewer

func _draw():
	print("CADRenderer._draw() apelat!")
	if not cad_viewer:
		print("EROARE: cad_viewer este null!")
		return
		
	print("Apelez _draw_grid_and_shapes_internal...")
	# Apelează funcțiile de desenare din CADViewer2D
	cad_viewer._draw_grid_and_shapes_internal(self)
	print("_draw_grid_and_shapes_internal completă!")

func request_redraw():
	print("CADRenderer.request_redraw() apelat!")
	queue_redraw()