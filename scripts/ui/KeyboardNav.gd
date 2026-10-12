class_name KeyboardNav
extends Node
## Keyboard use and the keyboard exit for the sims site (SPEC section 6).
## Tab and Shift+Tab walk every visible control in tree order (the tutorial box first while it is open);
## Tab past the last control or Shift+Tab before the first leaves the game. Escape closes the innermost open
## thing (popup, Teacher Mode panel, naming box, tutorial) through the host's close_topmost(), and leaves
## only when nothing is open. While a popup is open it keeps its own Tab loop, so Tab does not leave.

## Times the keyboard left the game; read by tests/test_keyboard.gd.
var leave_count: int = 0

var _host: Control = null


## host must be a Control with close_topmost() -> bool, popup_open() -> bool and first_stops() -> Array.
func setup(host: Control) -> void:
	_host = host


## Every visible, enabled, focusable control under the host in Tab order.
func stops() -> Array[Control]:
	var out: Array[Control] = []
	if _host == null:
		return out
	for first: Control in _host.first_stops():
		_collect(first, out)
	_collect(_host, out)
	return out


func _collect(node: Control, out: Array[Control]) -> void:
	if not node.is_visible_in_tree():
		return
	if node is SpinBox:
		var inner: LineEdit = (node as SpinBox).get_line_edit()
		if inner.focus_mode != Control.FOCUS_NONE and not out.has(inner):
			out.append(inner)
		return
	if node.focus_mode == Control.FOCUS_ALL and not out.has(node):
		if not (node is BaseButton and (node as BaseButton).disabled):
			out.append(node)
	for child: Node in node.get_children():
		if child is Control:
			_collect(child as Control, out)


func _input(event: InputEvent) -> void:
	# In _input, not _unhandled_input: the GUI takes Tab for its own focus movement before that.
	if _host == null or not (event is InputEventKey and event.pressed):
		return
	if event.is_action_pressed("ui_cancel"):
		if _host.close_topmost():
			get_viewport().set_input_as_handled()
			return
		leave_game()
		get_viewport().set_input_as_handled()
		return
	if _host.popup_open():
		return
	# Exact match (third argument): without it ui_focus_next also matches Shift+Tab
	var forward: bool = event.is_action_pressed("ui_focus_next", true, true)
	var backward: bool = event.is_action_pressed("ui_focus_prev", true, true)
	if not forward and not backward:
		return
	var list: Array[Control] = stops()
	if list.is_empty():
		return
	get_viewport().set_input_as_handled()
	var focus: Control = get_viewport().gui_get_focus_owner()
	var idx: int = list.find(focus)
	if idx < 0:
		(list[0] if forward else list[-1]).grab_focus()
		return
	var target: int = idx + (1 if forward else -1)
	if target < 0 or target >= list.size():
		leave_game()
		return
	list[target].grab_focus()


## Drops focus and asks the sims site's play page to take the keyboard back. On its own page there is no parent.
func leave_game() -> void:
	get_viewport().gui_release_focus()
	leave_count += 1
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
				"if (window.parent !== window) window.parent.postMessage({type: 'sims:leave-game'}, location.origin)")
