extends Node3D

func _ready():
	# Calea către scriptul Python și fișierul DXF de procesat
	var dxf_path = "exemplu_nou.dxf" # sau calea completă dacă nu e în directorul de lucru
	var script_path = "python/dxf_to_json.py"
	var output = []
	# Poți adăuga argumente suplimentare dacă modifici scriptul python să le accepte
	var args = [script_path]
	var exit_code = OS.execute("python", args, output, true)
	print("Rezultat script Python:", output)

func create_polygon(a: float, b: float, output: Array):
	# Exemplu de utilizare a rezultatului (output)
	print("Rezultat script în create_polygon:", output)
