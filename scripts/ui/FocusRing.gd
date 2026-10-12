class_name FocusRing
extends Control
## Yellow outline drawn round a focused control that has no focus style of its own
## (PanelContainer cards and chips, TextureButtons). Add it with FocusRing.attach(control).

const COLOR: Color = Color(1.0, 0.85, 0.2)

## How far outside the parent's content rect the outline sits.
var margin: float = 2.0
var _target: Control = null


static func attach(target: Control, p_margin: float = 2.0) -> void:
	if target.has_node("FocusRing"):
		return
	var ring: FocusRing = FocusRing.new()
	ring.name = "FocusRing"
	ring.margin = p_margin
	target.add_child(ring)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_target = get_parent() as Control
	if _target != null:
		_target.focus_entered.connect(queue_redraw)
		_target.focus_exited.connect(queue_redraw)


func _draw() -> void:
	if _target != null and _target.has_focus():
		draw_rect(Rect2(Vector2(-margin, -margin), size + Vector2(margin, margin) * 2.0), COLOR, false, 3.0)
