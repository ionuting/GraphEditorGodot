extends Control

# This script instantiates `Viewers/Viewer3D.tscn` into the SubViewport at runtime
# and exposes a proxy `set_view_data` so Main can forward view payloads.

var viewer_scene := preload("res://Viewers/Viewer3D.tscn")
var viewer_instance: Node = null
var subviewport: SubViewport = null
var _pending_view_data: Dictionary = {}
var current_view_data: Dictionary = {}

signal viewer_tab_closed(view_data, tab_title)

func _ready():
	# find SubViewport inside this Control
	var svc = get_node_or_null("SubViewportContainer")
	if not svc:
		push_error("Viewer3DTab: SubViewportContainer missing")
		return
	# create SubViewport and parent to container if not present
	var sv = svc.get_node_or_null("SubViewport")
	if not sv:
		sv = SubViewport.new()
		sv.name = "SubViewport"
		svc.add_child(sv)
		# Ensure the SubViewport matches the container size immediately and on resize
		subviewport = sv
		# Size may not be final until next frame; set deferred and connect resize
		call_deferred("_on_subviewport_container_resized")
		svc.resized.connect(Callable(self, "_on_subviewport_container_resized"))

	# instantiate Viewer3D scene and add it under SubViewport
	viewer_instance = viewer_scene.instantiate()
	# If the scene root is Node3D we need to add it to the SubViewport
	# (SubViewport accepts Node3D as child)
	sv.add_child(viewer_instance)

	# If any view data was requested before the inner viewer was ready, forward it now
	if _pending_view_data and _pending_view_data.size() > 0:
		if viewer_instance and viewer_instance.has_method("set_view_data"):
			viewer_instance.set_view_data(_pending_view_data)
			_pending_view_data = {}

	# ensure camera is current if viewer exposes set_view_data
	if viewer_instance and viewer_instance.has_method("_ensure_camera"):
		viewer_instance.call_deferred("_ensure_camera")

	# Connect Close button if present
	var close_btn = get_node_or_null("CloseButton") as Button
	if close_btn:
		close_btn.pressed.connect(Callable(self, "_on_close_pressed"))
		# style: small flat icon-like button and tooltip
		close_btn.tooltip_text = "Close tab"
		close_btn.flat = true
		close_btn.custom_minimum_size = Vector2(28, 20)

func _on_close_pressed() -> void:
	# If parent is a TabContainer, remove this child (closing the tab)
	var p = get_parent()
	if p and p is TabContainer:
		var idx = p.get_children().find(self)
		var tab_title = ""
		if idx >= 0 and p.get_tab_count() > idx:
			tab_title = p.get_tab_title(idx)
		# emit closed signal with current view data and title
		emit_signal("viewer_tab_closed", current_view_data.duplicate(), tab_title)
		if idx >= 0:
			p.remove_child(self)
			self.queue_free()
			# adjust current tab index if needed
			if p.get_tab_count() > 0:
				p.current_tab = clamp(idx - 1, 0, p.get_tab_count() - 1)
		return
	# otherwise just free
	queue_free()

func _on_subviewport_container_resized() -> void:
	var svc = get_node_or_null("SubViewportContainer")
	if not svc or not subviewport:
		return
	# Use the container rect size so the SubViewport fills the available area
	var rect = svc.get_rect()
	# SubViewport is a Viewport-derived object (not a Control) so it doesn't
	# have a `position` property; only set the size. The SubViewport is parented
	# to the SubViewportContainer so the container's layout will handle placement.
	subviewport.size = rect.size
	# If we're inside a TabContainer, the tab strip may overlap the top of the
	# content area on some platforms/measures. Ensure a small safe padding so the
	# 3D content doesn't draw under the tab buttons. We add 4px padding to height.
	if rect.size.y > 8:
		subviewport.size = Vector2(rect.size.x, rect.size.y - 4)

func set_view_data(data: Dictionary) -> void:
	# If the inner viewer is ready forward immediately, otherwise store pending
	if viewer_instance and viewer_instance.has_method("set_view_data"):
		viewer_instance.set_view_data(data)
	else:
		_pending_view_data = data
