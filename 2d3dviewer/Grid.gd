extends MeshInstance3D

@export var size: int = 50
@export var spacing: float = 1.0
@export var color: Color = Color(0.7, 0.7, 0.7)

func _ready() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)

	for i in range(-size, size + 1):
		# Linii X
		st.add_vertex(Vector3(-size*spacing, 0, i*spacing))
		st.add_vertex(Vector3(size*spacing, 0, i*spacing))

		# Linii Y
		st.add_vertex(Vector3(i*spacing, 0, -size*spacing))
		st.add_vertex(Vector3(i*spacing, 0, size*spacing))

	self.mesh = st.commit()

	# Material transparent
	var mat = StandardMaterial3D.new()
	mat.flags_unshaded = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.3)
	self.material_override = mat

	# Asigură transform local la origine
	self.transform = Transform3D()

	# Neslectabil

	
