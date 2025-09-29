extends Node3D

func _ready():
	var args = ["python/math_test.py", "2", "3"] # argumentele ca string!
	var output = []
	var exit_code = OS.execute("python", args, output, true)
	print("Rezultat script:", output)

func create_polygon(a:float, b:float, output:float):
	a=2
	b=3
	print("Rezultat script:", output)
