extends VBoxContainer

@export var animation_time: float = 0.16
@export var expanded: bool = false

func _ready():
	if get_child_count() < 2:
		push_error("AccordionItemAnimated expects child 0=Button, child 1=VBoxContainer content")
		return
	var header = get_child(0) as Button
	var content = get_child(1) as Control
	header.toggle_mode = true
	var header_cb = Callable(self, "_on_header_pressed")
	header.connect("pressed", header_cb)
	# prepare content: measure natural height and collapse if needed
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	call_deferred("_apply_initial_state")

func _apply_initial_state():
	var content = get_child(1) as Control
	if not content:
		return
	var cm = content.custom_minimum_size
	cm.y = content.get_combined_minimum_size().y if expanded else 0
	content.custom_minimum_size = cm
	content.visible = expanded

func _on_header_pressed():
	var header = get_child(0) as Button
	set_expanded(header.is_pressed())

func set_expanded(v: bool) -> void:
	if expanded == v:
		return
	expanded = v
	var content = get_child(1) as Control
	if not content:
		return
	var natural_h = content.get_combined_minimum_size().y
	var start_h = content.custom_minimum_size.y
	var target_h = natural_h if expanded else 0
	if is_equal_approx(start_h, target_h):
		content.visible = expanded
		return
	var tw = get_tree().create_tween()
	tw.tween_property(content, "custom_minimum_size:y", target_h, animation_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if expanded:
		content.visible = true
	tw.connect("finished", Callable(self, "_on_tween_finished").bind(content, expanded))

func _on_tween_finished(content: Control, should_be_visible: bool) -> void:
	content.visible = should_be_visible
	if should_be_visible:
		var vm = content.custom_minimum_size
		vm.y = content.get_combined_minimum_size().y
		content.custom_minimum_size = vm
	else:
		var vm2 = content.custom_minimum_size
		vm2.y = 0
		content.custom_minimum_size = vm2
