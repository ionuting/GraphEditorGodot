extends Node3D

# Funcție pentru generarea unui stalp
func create_pillar(size: Vector2, height: float, center: Vector3, material: StandardMaterial3D) -> CSGPolygon3D:
	"""
	size: Vector2(lățime, adâncime) footprint
	height: înălțimea stalpului
	center: Vector3 poziția centrului footprint-ului în lume (Z = bază)
	material: materialul aplicat pe stalp
	return: nod CSGPolygon3D creat
	"""

	# --- 1. Construim footprint-ul pătrat ---
	var hw = size.x / 2.0
	var hd = size.y / 2.0
	var footprint = PackedVector2Array([
		Vector2(-hw, -hd),
		Vector2(hw, -hd),
		Vector2(hw, hd),
		Vector2(-hw, hd)
	])

	# --- 2. Creăm CSGPolygon3D ---
	var pillar = CSGPolygon3D.new()
	pillar.polygon = footprint
	pillar.depth = height
	pillar.operation = CSGShape3D.OPERATION_UNION

	# Poziționăm astfel încât centrul footprint-ului să fie la poziția dată și baza la Z=0
	pillar.position = Vector3(center.x, center.y, center.z + height/2)

	# --- 3. Aplicăm material ---
	pillar.material = material

	# Adăugăm în scenă
	add_child(pillar)

	return pillar


# --- Exemplu de utilizare ---
func _ready():
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8,0.2,0.2)  # roșu

	# Creează un stalp de 0.5 x 0.5 m, înălțime 3 m, poziția centrului la (2,2,0)
	create_pillar(Vector2(0.25,0.25), 3.0, Vector3(2,2,0), mat)

	# Creează alt stalp de 0.3 x 0.3 m, înălțime 2.5 m, poziția centrului la (4,2,0)
	create_pillar(Vector2(0.3,0.3), 2.5, Vector3(4,2,0), mat)
