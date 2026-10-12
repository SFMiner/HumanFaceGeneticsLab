extends SceneTree
## The Settings menu: it opens from the Settings button, Escape closes it without leaving the game, New game asks
## first and then empties the library and returns to Level 1 with the tutorial prompt, Show the tutorial starts
## it, and text size and the still tutorial box apply and are saved. The real user:// files are put back after.

const FILES: Array[String] = [
	"user://human_library.json",
	"user://tutorial_state.json",
	"user://player_settings.json",
]
const EXPECTED: int = 17

var _passed: int = 0
var _failed: int = 0
var _saved: Dictionary = {}
var _lab: Control = null
var _state: Node = null


func _init() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + label)


func _run() -> void:
	await get_root().ready
	for path: String in FILES:
		if FileAccess.file_exists(path):
			_saved[path] = FileAccess.get_file_as_string(path)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_state = get_root().get_node("/root/HumanGeneticsState")
	_lab = (load("res://scenes/main/GeneticsLab.tscn") as PackedScene).instantiate()
	get_root().add_child(_lab)
	for i: int in range(8):
		await process_frame
	var menu: PopupPanel = _lab.settings_menu
	var nav: Node = _lab.keyboard

	# Opens from the Settings button with New game focused; Escape closes it and does not leave
	_lab._end_tutorial()
	_lab.settings_button.pressed.emit()
	await process_frame
	_check(menu.visible and _lab.popup_open(), "Settings opens the menu")
	_check(menu.gui_get_focus_owner() == menu.new_game_button, "New game has focus")
	var leaves: int = nav.leave_count
	await _key(KEY_ESCAPE)
	_check(not menu.visible and nav.leave_count == leaves, "Escape closes the menu without leaving")

	# New game asks first; Cancel goes back
	_lab.settings_button.pressed.emit()
	await process_frame
	menu.new_game_button.pressed.emit()
	_check(menu.confirm_box.visible and not menu.new_game_button.visible, "New game asks to confirm")
	_check("Level 1" in menu.confirm_label.text, "the question names Level 1")
	menu.confirm_no.pressed.emit()
	_check(not menu.confirm_box.visible and menu.new_game_button.visible, "Cancel goes back")

	# Play a little: two new humans, Level 3, a parent set
	var made: Array[int] = [_state.generate_random_human(), _state.generate_random_human()]
	_lab.level_dropdown.select(2)
	_lab.level_dropdown.item_selected.emit(2)
	var humans: Array = _state.get_all_humans()
	_lab.breeding_area.set_parent_from_library(humans[0].get("id", 0), "A")
	await process_frame
	_check(_state.current_level_id == 3 and humans.size() >= 2, "set up a game in progress")

	# Yes: library emptied, Level 1, parents cleared, tutorial prompt back
	menu.new_game_button.pressed.emit()
	menu.confirm_yes.pressed.emit()
	for i: int in range(3):
		await process_frame
	_check(not menu.visible, "the menu closes")
	var names: Array[String] = []
	for h: Dictionary in _state.get_all_humans():
		names.append(String(h.get("name", "")))
	_check(_state.get_human(made[0]).is_empty() and names.is_empty(),
			"the library is empty, as on a first visit (%s)" % ", ".join(names))
	_check(_state.current_level_id == 1 and _lab.level_dropdown.get_selected_id() == 1, "back on Level 1")
	_check(_lab.breeding_area._parent_a_id < 0, "parent slots cleared")
	_check(_lab.tutorial_panel.visible, "the tutorial prompt shows again")

	# Show the tutorial starts the first step
	_lab._end_tutorial()
	_lab.settings_button.pressed.emit()
	await process_frame
	menu.tutorial_button.pressed.emit()
	await process_frame
	_check(_lab._tutorial_active and _lab.tutorial_panel.visible, "Show the tutorial starts it")

	# Still tutorial box: no fade running
	menu.still_check.button_pressed = true
	_check(not (_lab.tutorial_panel._blink_tween != null and _lab.tutorial_panel._blink_tween.is_running()), "the tutorial box stops fading")

	# Text size: scales the window and is saved
	menu.text_size_buttons[2].pressed.emit()
	_check(is_equal_approx(get_root().content_scale_factor, 1.3), "Larger scales the window")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://player_settings.json"))
	_check(saved is Dictionary and int(saved.get("text_size", -1)) == 2 and saved.get("still_tutorial") == true, "settings are saved")
	menu.text_size_buttons[0].pressed.emit()
	_check(is_equal_approx(get_root().content_scale_factor, 1.0), "Normal puts it back")

	_finish()


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		get_root().push_input(e)
	await process_frame
	await process_frame


func _finish() -> void:
	_lab.queue_free()
	for path: String in FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if _saved.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(_saved[path])
			f.close()
	print("Settings menu: %d passed, %d failed (expected %d)" % [_passed, _failed, EXPECTED])
	quit(0 if _failed == 0 and _passed == EXPECTED else 1)
