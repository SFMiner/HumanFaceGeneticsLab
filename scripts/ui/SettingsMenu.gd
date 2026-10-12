class_name SettingsMenu
extends PopupPanel
## The Settings button's menu, built in code: New game (with a confirm step), Show the tutorial, text size and a
## still tutorial box. Text size and the still box are saved for this browser in user://player_settings.json;
## a New game leaves them alone.

signal new_game_confirmed()
signal tutorial_requested()
signal still_tutorial_changed(still: bool)

const SETTINGS_PATH: String = "user://player_settings.json"
## Window content scale for each text size choice. Larger text leaves less room, so the panels scroll sooner.
const TEXT_SCALES: Array[float] = [1.0, 1.15, 1.3]
const TEXT_SIZE_NAMES: Array[String] = ["Normal", "Large", "Larger"]

var new_game_button: Button = null
var tutorial_button: Button = null
var close_button: Button = null
var confirm_box: VBoxContainer = null
var confirm_label: Label = null
var confirm_yes: Button = null
var confirm_no: Button = null
var text_size_buttons: Array[Button] = []
var still_check: CheckButton = null

var text_size: int = 0
var still_tutorial: bool = false


func _ready() -> void:
	_build()
	_load_settings()
	_apply_text_size()


# ============================================================================
# BUILD
# ============================================================================

func _build() -> void:
	var panel := PanelContainer.new()
	add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	new_game_button = _button("New game", vbox)
	new_game_button.pressed.connect(_on_new_game_pressed)

	confirm_box = VBoxContainer.new()
	confirm_box.visible = false
	vbox.add_child(confirm_box)
	confirm_label = Label.new()
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_label.custom_minimum_size = Vector2(320, 0)
	confirm_box.add_child(confirm_label)
	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_row.add_theme_constant_override("separation", 10)
	confirm_box.add_child(confirm_row)
	confirm_yes = _button("Yes, start over", confirm_row)
	confirm_yes.pressed.connect(_on_confirm_yes)
	confirm_no = _button("Cancel", confirm_row)
	confirm_no.pressed.connect(_hide_confirm)

	tutorial_button = _button("Show the tutorial", vbox)
	tutorial_button.pressed.connect(_on_tutorial_pressed)

	vbox.add_child(HSeparator.new())

	var size_label := Label.new()
	size_label.text = "Text size"
	vbox.add_child(size_label)
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 8)
	vbox.add_child(size_row)
	var group := ButtonGroup.new()
	for i: int in range(TEXT_SIZE_NAMES.size()):
		var b: Button = _button(TEXT_SIZE_NAMES[i], size_row)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_text_size_pressed.bind(i))
		text_size_buttons.append(b)

	still_check = CheckButton.new()
	still_check.text = "Keep the tutorial box still (no flashing)"
	still_check.custom_minimum_size = Vector2(0, 44)
	still_check.toggled.connect(_on_still_toggled)
	vbox.add_child(still_check)

	vbox.add_child(HSeparator.new())

	close_button = _button("Close", vbox)
	close_button.pressed.connect(hide)


func _button(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	parent.add_child(b)
	return b


# ============================================================================
# OPEN / CLOSE
# ============================================================================

## start_level_name names the level a New game starts on (Level 1, or the one a class settings link names).
func open(start_level_name: String) -> void:
	confirm_label.text = "This deletes every human in your library and starts again at %s. Start over?" % start_level_name
	_hide_confirm()
	_sync_controls()
	popup_centered()
	new_game_button.grab_focus()


func _sync_controls() -> void:
	for i: int in range(text_size_buttons.size()):
		text_size_buttons[i].set_pressed_no_signal(i == text_size)
	still_check.set_pressed_no_signal(still_tutorial)


# ============================================================================
# ACTIONS
# ============================================================================

func _on_new_game_pressed() -> void:
	confirm_box.visible = true
	new_game_button.visible = false
	confirm_no.grab_focus()
	reset_size()


func _hide_confirm() -> void:
	confirm_box.visible = false
	new_game_button.visible = true
	if visible:
		new_game_button.grab_focus()
	reset_size()


func _on_confirm_yes() -> void:
	hide()
	new_game_confirmed.emit()


func _on_tutorial_pressed() -> void:
	hide()
	tutorial_requested.emit()


func _on_text_size_pressed(index: int) -> void:
	text_size = index
	_apply_text_size()
	_save_settings()
	# The menu itself scales too; recentre it
	popup_centered()


func _on_still_toggled(on: bool) -> void:
	still_tutorial = on
	_save_settings()
	still_tutorial_changed.emit(on)


func _apply_text_size() -> void:
	var window: Window = get_tree().root if is_inside_tree() else null
	if window != null:
		window.content_scale_factor = TEXT_SCALES[text_size]


# ============================================================================
# SAVE
# ============================================================================

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if data is not Dictionary:
		return
	text_size = clampi(int(data.get("text_size", 0)), 0, TEXT_SCALES.size() - 1)
	still_tutorial = bool(data.get("still_tutorial", false))


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"text_size": text_size, "still_tutorial": still_tutorial}, "\t"))
		file.close()
