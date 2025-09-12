extends Node3D

@export var zoom_speed: float = 1.0
@export var pan_speed: float = 0.01
@export var orbit_speed: float = 0.01

var camera: Camera3D

func _ready() -> void:
	camera = $Camera3D

func _unhandled_input(event: InputEvent) -> void:
	# --- Orbit cu butonul mijloc + Alt (ca în Blender) ---
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE and Input.is_key_pressed(KEY_ALT):
		rotate_y(-event.relative.x * orbit_speed)
		rotate_x(-event.relative.y * orbit_speed)
	
	# --- Pan cu butonul mijloc simplu ---
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		var right = -transform.basis.x * event.relative.x * pan_speed
		var up = transform.basis.y * event.relative.y * pan_speed
		translate(right + up)
	
	# --- Zoom cu scroll și centrare pe mouse ---
	elif event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_towards_mouse(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_towards_mouse(zoom_speed)

func zoom_towards_mouse(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)

	# punct țintă la distanță de 10 unități
	var target = from + dir * 10.0
	var move = (target - camera.global_transform.origin).normalized() * delta

	# mutăm camera și pivotul (rig-ul)
	translate(move)
