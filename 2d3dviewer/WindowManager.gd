class_name WindowManager

extends RefCounted

class WindowObject:
	var insert_point: Vector2
	# rectangle dimensions relative to insert_point before transform
	var length: float = 1.2
	var width: float = 0.25
	# translation along local X before rotation (order: translate then rotate)
	var translation_x: float = 0.0
	# rotation in degrees applied after translation
	var rotation_deg: float = 0.0
	# offset distance from insert point to rectangle center along local X (default 1.25)
	var insert_offset: float = 1.25
	var sill: float = 0.90
	var cut_priority: int = 10
	var name: String = "Window"
	var material: String = ""
	var is_exterior: bool = false
	var id: int = 0
	var is_selected: bool = false

	func get_local_rect_center():
		# Starting from insert_point, apply translation_x along local X and offset
		return insert_point + Vector2(insert_offset + translation_x, 0)

	func get_world_rect_polygon():
		# Returns polygon points in world space after translation and rotation
		var center = get_local_rect_center()
		var rad = deg_to_rad(rotation_deg)
		var cosr = cos(rad)
		var sinr = sin(rad)
		var hx = length * 0.5
		var hy = width * 0.5
		var pts_local = [Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)]
		var pts_world = []
		for p in pts_local:
			# rotate around center
			var rx = p.x * cosr - p.y * sinr
			var ry = p.x * sinr + p.y * cosr
			pts_world.append(Vector2(rx, ry) + center)
		return pts_world

var windows: Array[WindowObject] = []
var selected_window: WindowObject = null
var next_id: int = 1
var default_properties: Dictionary = {
	"length": 1.2,
	"width": 0.25,
	"translation_x": 0.0,
	"rotation_deg": 0.0,
	"insert_offset": 1.25,
	"sill": 0.90,
	"cut_priority": 10,
	"name": "Window",
	"material": "",
	"is_exterior": false
}

# Drag/hover state for grips
var is_dragging: bool = false
var dragging_window: WindowObject = null
var dragging_grip: int = -1 # 0=insert,1=center,2=rotation
var hovered_grip: int = -1
var hovered_window: WindowObject = null

const SNAP_DISTANCE_SCREEN = 10.0

func add_window(insert_point: Vector2) -> WindowObject:
	var w = WindowObject.new()
	w.insert_point = insert_point
	w.id = next_id
	next_id += 1
	windows.append(w)
	return w

func select_window(w: WindowObject):
	if selected_window:
		selected_window.is_selected = false
	selected_window = w
	if w:
		w.is_selected = true

func delete_selected() -> bool:
	if selected_window:
		windows.erase(selected_window)
		selected_window = null
		return true
	return false

func get_snap_points() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for w in windows:
		pts.append(w.insert_point)
	return pts

func get_window_bounds(w: WindowObject) -> Rect2:
	var pts = w.get_world_rect_polygon()
	var xs = []
	var ys = []
	for p in pts:
		xs.append(p.x)
		ys.append(p.y)
	var min_x = xs.min()
	var min_y = ys.min()
	var max_x = xs.max()
	var max_y = ys.max()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func get_window_at_position(world_pos: Vector2) -> WindowObject:
	for i in range(windows.size() - 1, -1, -1):
		var w = windows[i]
		var bounds = get_window_bounds(w)
		if bounds.has_point(world_pos):
			return w
	return null

func get_grip_points(w: WindowObject) -> Dictionary:
	# Return world positions for grips: insert point, center, rotation handle
	var center = w.get_local_rect_center()
	var insert_p = w.insert_point
	# rotation handle: place above the top side by 1.0 * max(length,width)
	var pts = w.get_world_rect_polygon()
	var top_mid = (pts[0] + pts[1]) * 0.5
	var bottom_mid = (pts[3] + pts[2]) * 0.5
	var dir = (bottom_mid - top_mid).normalized()
	var handle_offset = max(w.length, w.width) * 0.5 + 0.2
	var rot_handle = top_mid - dir * handle_offset
	return {0: insert_p, 1: center, 2: rot_handle}

func get_grip_at_position(world_pos: Vector2, snap_distance_screen: float = SNAP_DISTANCE_SCREEN, world_to_screen_func: Callable = Callable()) -> Dictionary:
	var result = {"window": null, "grip": -1}
	var min_dist = INF
	var screen_pos = world_pos
	if world_to_screen_func and world_to_screen_func.is_valid():
		screen_pos = world_to_screen_func.call(world_pos)
	for w in windows:
		var grips = get_grip_points(w)
		for grip_idx in grips.keys():
			var gp = grips[grip_idx]
			var gp_screen = gp
			if world_to_screen_func and world_to_screen_func.is_valid():
				gp_screen = world_to_screen_func.call(gp)
			var d = screen_pos.distance_to(gp_screen)
			if d <= snap_distance_screen and d < min_dist:
				min_dist = d
				result["window"] = w
				result["grip"] = grip_idx
	return result

func start_drag_grip(w: WindowObject, grip_idx: int, world_pos: Vector2):
	dragging_window = w
	dragging_grip = grip_idx
	is_dragging = true
	select_window(w)

func update_drag(world_pos: Vector2, external_snap_points: Array[Vector2] = [], world_to_screen_func: Callable = Callable(), snap_pixels: float = 10.0):
	if not is_dragging or not dragging_window:
		return
	# Simple behaviors:
	# grip 0: move insert_point
	# grip 1: translate window center (move whole window by delta)
	# grip 2: rotate window around center based on angle to world_pos
	if dragging_grip == 0:
		dragging_window.insert_point = world_pos
	elif dragging_grip == 1:
		var center = dragging_window.get_local_rect_center()
		var delta = world_pos - center
		# apply delta to insert_point (so window moves as center moves)
		dragging_window.insert_point += delta
	elif dragging_grip == 2:
		var center = dragging_window.get_local_rect_center()
		var v = world_pos - center
		if v.length() > 0:
			dragging_window.rotation_deg = rad_to_deg(atan2(v.y, v.x))

func end_drag():
	is_dragging = false
	dragging_window = null
	dragging_grip = -1

func update_hover_grip(world_pos: Vector2, world_to_screen_func: Callable = Callable()):
	var info = get_grip_at_position(world_pos, SNAP_DISTANCE_SCREEN, world_to_screen_func)
	if info["window"]:
		hovered_grip = info["grip"]
		hovered_window = info["window"]
	else:
		hovered_grip = -1
		hovered_window = null

func translate_selected(dx: float, dy: float) -> bool:
	if not selected_window:
		return false
	selected_window.insert_point += Vector2(dx, dy)
	return true


func to_dict(w: WindowObject) -> Dictionary:
	return {
		"id": w.id,
		"insert_point": w.insert_point,
		"length": w.length,
		"width": w.width,
		"translation_x": w.translation_x,
		"rotation_deg": w.rotation_deg,
		"insert_offset": w.insert_offset,
		"sill": w.sill,
		"cut_priority": w.cut_priority,
		"name": w.name,
		"material": w.material,
		"is_exterior": w.is_exterior
	}

func update_selected_window_from_dict(properties: Dictionary) -> bool:
	if not selected_window:
		return false
	# Apply common fields
	if properties.has("length"):
		selected_window.length = properties["length"]
	if properties.has("width"):
		selected_window.width = properties["width"]
	if properties.has("translation_x"):
		selected_window.translation_x = properties["translation_x"]
	if properties.has("rotation_deg"):
		selected_window.rotation_deg = properties["rotation_deg"]
	if properties.has("insert_offset"):
		selected_window.insert_offset = properties["insert_offset"]
	if properties.has("sill"):
		selected_window.sill = properties["sill"]
	if properties.has("cut_priority"):
		selected_window.cut_priority = int(properties["cut_priority"])
	if properties.has("name"):
		selected_window.name = str(properties["name"])
	if properties.has("material"):
		selected_window.material = str(properties["material"])
	if properties.has("is_exterior"):
		selected_window.is_exterior = bool(properties["is_exterior"])
	return true

func set_default_properties_from_dict(properties: Dictionary):
	for k in properties.keys():
		default_properties[k] = properties[k]

func get_default_properties() -> Dictionary:
	return default_properties.duplicate(true)
