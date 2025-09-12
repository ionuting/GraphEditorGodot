extends Node2D

@export var zoom_speed: float = 0.1
@export var pan_speed: float = 1.0

func _ready():


	# Adaugă un GraphNode de test
	var node = GraphNode.new()
	node.title = "Cub Test"
	node.position = revit_to_2d(Vector3(1,2,0))

	
func revit_to_2d(pos_3d: Vector3) -> Vector2:
	# Ignorăm Z
	return Vector2(pos_3d.x, pos_3d.y)
	
