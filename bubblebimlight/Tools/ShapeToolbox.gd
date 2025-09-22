extends Control

class_name ShapeToolbox

signal shape_selected(category: String, item: String)

@onready var _tree: Tree = null

func _ready():
    # Build UI programmatically so the scene remains portable
    custom_minimum_size = Vector2(260, 380)
    add_theme_color_override("bg_color", Color(0.12, 0.12, 0.12, 0.95))

    var vbox = VBoxContainer.new()
    vbox.anchor_left = 0
    vbox.anchor_top = 0
    vbox.anchor_right = 1
    vbox.anchor_bottom = 1
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(vbox)

    var title = Label.new()
    title.text = "Shape Toolbox"
    title.add_theme_font_size_override("font_size", 16)
    title.add_theme_color_override("font_color", Color(0.9,0.9,0.9))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    var sep = HSeparator.new()
    vbox.add_child(sep)

    _tree = Tree.new()
    _tree.columns = 1
    _tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _tree.hide_root = true
    vbox.add_child(_tree)

    _populate_tree()
    _tree.item_activated.connect(Callable(self, "_on_item_activated"))

    # optional: double-click also triggers
    _tree.item_selected.connect(Callable(self, "_on_item_selected"))

func _populate_tree():
    _tree.clear()

    var categories = {
        "Elements": ["Room", "Shell", "Roof"],
        "Windows": ["Simple", "Double"],
        "Doors": ["Simple", "Double"],
        "Foundation": ["Shell", "Cell"],
        "Structural": ["Wall", "Column", "Beam", "Hole"]
    }

    for cat_name in categories.keys():
        var cat_item = _tree.create_item()
        cat_item.set_text(0, str(cat_name))
        cat_item.collapsed = false
        cat_item.set_selectable(0, false)
        for sub in categories[cat_name]:
            var child = _tree.create_item(cat_item)
            child.set_text(0, str(sub))
            # store metadata so activation can read category + item
            child.set_metadata(0, {"category": cat_name, "item": sub})

func _on_item_activated(item: TreeItem, column: int) -> void:
    if not item:
        return
    var md = item.get_metadata(column)
    if typeof(md) == TYPE_DICTIONARY and md.has("category") and md.has("item"):
        emit_signal("shape_selected", md["category"], md["item"])

func _on_item_selected(item: TreeItem, column: int) -> void:
    # single-click select: show tooltip or quick preview (for now emit as well)
    if not item:
        return
    var md = item.get_metadata(column)
    if typeof(md) == TYPE_DICTIONARY and md.has("category") and md.has("item"):
        # emit selection (UI consumer can decide whether to treat as placement or preview)
        emit_signal("shape_selected", md["category"], md["item"])

func get_all_items() -> Array:
    var out = []
    var root = _tree.get_root()
    var it = root
    while it:
        var child = it.get_first_child()
        while child:
            var md = child.get_metadata(0)
            if typeof(md) == TYPE_DICTIONARY:
                out.append(md)
            child = child.get_next()
        it = it.get_next()
    return out
