extends Control

func _ready():
	print("Test scene loaded successfully!")
	
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()