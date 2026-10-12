# GeneticsLab.gd
# Main controller for the Human Face Genetics Simulator
# Manages the overall UI layout, level selection, and coordinates between panels
# Educational purpose: Provide the main learning environment for genetics concepts

extends Control

# ============================================================================
# SIGNALS
# ============================================================================

signal level_selected(level_id: int)
signal teacher_mode_requested()

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var library_panel: Control = $MainVBox/MainHBox/LibraryPanel
@onready var breeding_area: Control = $MainVBox/MainHBox/RecombinationArea
@onready var level_dropdown: OptionButton = $MainVBox/TopBar/VBox/HBox/LevelDropdown
@onready var teacher_mode_button: Button = $MainVBox/TopBar/VBox/HBox/TeacherModeButton
@onready var settings_button: Button = $MainVBox/TopBar/VBox/HBox/SettingsButton
@onready var teacher_mode_banner: PanelContainer = $MainVBox/TopBar/VBox/TeacherModeBanner
@onready var teacher_mode_status: Label = $MainVBox/TopBar/VBox/TeacherModeBanner/StatusLabel
@onready var footer_disclaimer: Label = $MainVBox/FooterDisclaimer
@onready var teacher_mode_panel: Control = $TeacherModePanel
@onready var manual_button: Button = $MainVBox/TopBar/VBox/HBox/ManualButton
@onready var face_preview_popup: PopupPanel = $FacePreviewPopup
#@onready var face_preview_name: Label = $FacePreviewPopup/PanelContainer/VBoxContainer/NameLabel
@onready var face_preview_face: Control = $FacePreviewPopup/PanelContainer/VBoxContainer/FacePreviewContainer/FacePreview
@onready var face_preview_close: Button = $FacePreviewPopup/PanelContainer/VBoxContainer/CloseButton
@onready var tutorial_panel: Control = $TutorialPanel
@onready var manual_popup: PopupPanel = $ManualPopup
@onready var manual_close_button: Button = $ManualPopup/PanelContainer/VBox/Header/CloseButton
@onready var manual_text: RichTextLabel = $ManualPopup/PanelContainer/VBox/Scroll/ManualText

# ============================================================================
# STATE
# ============================================================================

var _teacher_panel_visible: bool = false
var _tutorial_data: Dictionary = {}
var _tutorial_steps: Array = []
var _tutorial_step_index: int = -1
var _tutorial_active: bool = false
var _tutorial_anchors: Dictionary = {}
var _tutorial_parents_filled: Dictionary = {"A": false, "B": false}
var _teacher_panel_allowed: bool = false

const TUTORIAL_STATE_PATH := "user://tutorial_state.json"
const MANUAL_PATH := "res://docs/MANUAL.md"

## Tab order, close_topmost() and the keyboard exit live in KeyboardNav (scripts/ui/KeyboardNav.gd).
var keyboard: KeyboardNav = null
var settings_menu: SettingsMenu = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_connections()
	_populate_level_dropdown()
	_update_teacher_mode_ui()
	_update_footer_disclaimer()
	_apply_teacher_access()
	
	# Initial level: 1, or the one a class settings link names (TeacherModeState.apply_link_settings)
	_start_level(TeacherModeState.get_link_level())
	
	_setup_settings_menu()
	_setup_tutorial_anchors()
	_load_tutorial_data()
	_setup_keyboard()
	call_deferred("_begin_tutorial_flow")


func _setup_keyboard() -> void:
	keyboard = KeyboardNav.new()
	keyboard.name = "KeyboardNav"
	add_child(keyboard)
	keyboard.setup(self)
	manual_text.focus_mode = Control.FOCUS_ALL
	($ManualPopup/PanelContainer/VBox/Scroll as ScrollContainer).follow_focus = true


## Controls that come first in Tab order while visible: the tutorial box, so a keyboard user meets it at once.
func first_stops() -> Array:
	return [tutorial_panel] if tutorial_panel != null else []


func popup_open() -> bool:
	return manual_popup.visible or face_preview_popup.visible or settings_menu.visible


## Escape: closes the innermost open thing and returns true; returns false when nothing is open.
func close_topmost() -> bool:
	for popup: Window in [manual_popup, face_preview_popup, settings_menu]:
		if popup.visible:
			popup.hide()
			return true
	if _teacher_panel_visible:
		_on_teacher_panel_close_requested()
		return true
	var offspring: Node = breeding_area.get_node("%OffspringPreview")
	if offspring.has_method("cancel_naming") and offspring.cancel_naming():
		return true
	if tutorial_panel != null and tutorial_panel.visible:
		_end_tutorial()
		return true
	return false


func _setup_connections() -> void:
	# Level dropdown
	level_dropdown.item_selected.connect(_on_level_selected)
	
	# Teacher mode
	teacher_mode_button.pressed.connect(_on_teacher_mode_button_pressed)
	TeacherModeState.teacher_mode_toggled.connect(_on_teacher_mode_toggled)
	TeacherModeState.constraints_changed.connect(_on_teacher_constraints_changed)
	
	if manual_button:
		manual_button.pressed.connect(_on_manual_button_pressed)
	if manual_close_button:
		manual_close_button.pressed.connect(_on_manual_close_pressed)
	
	# Settings button
	settings_button.pressed.connect(_on_settings_button_pressed)
	
	# Breeding area signals
	if breeding_area:
		breeding_area.offspring_created.connect(_on_offspring_created)
	
	# Library signals
	if library_panel:
		library_panel.human_selected_for_parent.connect(_on_human_selected_for_parent)
		library_panel.face_clicked.connect(_on_library_face_clicked)
		library_panel.generate_pressed.connect(_on_tutorial_generate_pressed)
	
	# Recombination signals
	if breeding_area:
		breeding_area.parent_selected.connect(_on_tutorial_parent_selected)
		breeding_area.allele_dropped.connect(_on_tutorial_allele_dropped)
		breeding_area.recombine_pressed.connect(_on_tutorial_recombine_pressed)
	
	# Teacher mode panel
	if teacher_mode_panel:
		teacher_mode_panel.panel_closed.connect(_on_teacher_panel_close_requested)
		teacher_mode_panel.visible = false
	
	if face_preview_close:
		face_preview_close.pressed.connect(_on_face_preview_close)
	
	if tutorial_panel:
		tutorial_panel.prompt_answered.connect(_on_tutorial_prompt_answered)
		tutorial_panel.not_now_pressed.connect(_on_tutorial_not_now_pressed)
		tutorial_panel.close_pressed.connect(_on_tutorial_close_pressed)


func _populate_level_dropdown() -> void:
	level_dropdown.clear()
	var levels := HumanGeneticsState.get_all_levels()
	for level in levels:
		var level_name: String = level.get("name", "Level %d" % level.get("id", 0))
		level_dropdown.add_item(level_name, level.get("id", 0))
	
	# Select first level
	if level_dropdown.item_count > 0:
		level_dropdown.select(0)


# ============================================================================
# LEVEL MANAGEMENT
# ============================================================================

func _on_level_selected(index: int) -> void:
	var level_id: int = level_dropdown.get_item_id(index)
	HumanGeneticsState.set_level(level_id)
	level_selected.emit(level_id)
	
	# Refresh UI components
	if library_panel:
		library_panel.refresh()
	if breeding_area:
		breeding_area.on_level_changed(level_id)
	_tutorial_reset_parent_flags()


# ============================================================================
# TEACHER MODE UI
# ============================================================================

func _update_teacher_mode_ui() -> void:
	var is_active := TeacherModeState.is_active()
	
	# Update button appearance
	if is_active:
		teacher_mode_button.text = "Teacher Mode [ON]"
		teacher_mode_button.modulate = Color("#4A7C59")
	else:
		teacher_mode_button.text = "Teacher Mode"
		teacher_mode_button.modulate = Color.WHITE
	
	# Show/hide banner
	teacher_mode_banner.visible = is_active
	if is_active:
		teacher_mode_status.text = TeacherModeState.get_status_summary()


func _update_footer_disclaimer() -> void:
	if TeacherModeState.is_active() and TeacherModeState.should_show_modeling_disclaimer():
		footer_disclaimer.visible = true
		footer_disclaimer.text = TeacherModeState.get_footer_disclaimer()
	else:
		footer_disclaimer.visible = false


func _on_teacher_mode_button_pressed() -> void:
	if not _teacher_panel_allowed:
		return
	_teacher_panel_visible = not _teacher_panel_visible
	if teacher_mode_panel:
		if _teacher_panel_visible:
			teacher_mode_panel.show_panel()
		else:
			teacher_mode_panel.hide_panel()


func _on_teacher_panel_close_requested() -> void:
	_teacher_panel_visible = false
	if teacher_mode_panel:
		teacher_mode_panel.visible = false


func _on_teacher_mode_toggled(_active: bool) -> void:
	_update_teacher_mode_ui()
	_update_footer_disclaimer()
	
	# Refresh components
	if library_panel:
		library_panel.refresh()
	if breeding_area:
		breeding_area.refresh()


func _on_teacher_constraints_changed() -> void:
	_update_teacher_mode_ui()
	
	# Refresh components
	if breeding_area:
		breeding_area.refresh()
	_tutorial_reset_parent_flags()


## The in-game Teacher Mode panel is for desktop and editor runs only. Web builds take teacher settings from a
## class settings link (no PIN: anything in the build can be read, and the panel only changed one browser).
func _apply_teacher_access() -> void:
	_teacher_panel_allowed = OS.is_debug_build() and not OS.has_feature("web") and not TeacherModeState.is_from_link()
	if teacher_mode_button:
		teacher_mode_button.visible = _teacher_panel_allowed
	if not _teacher_panel_allowed and teacher_mode_panel:
		teacher_mode_panel.visible = false
		_teacher_panel_visible = false


## Select a level in the dropdown and the state; a link with locklevel=1 keeps students on it.
func _start_level(level_id: int) -> void:
	var index: int = 0
	for i: int in range(level_dropdown.item_count):
		if level_dropdown.get_item_id(i) == level_id:
			index = i
			break
	if level_dropdown.item_count > 0:
		level_dropdown.select(index)
		level_id = level_dropdown.get_item_id(index)
	HumanGeneticsState.set_level(level_id)
	if level_id != 1:
		if library_panel:
			library_panel.refresh()
		if breeding_area:
			breeding_area.on_level_changed(level_id)
	level_dropdown.disabled = TeacherModeState.is_level_locked()
	if level_dropdown.disabled:
		level_dropdown.tooltip_text = "Your teacher's link sets the level."


func _load_manual_text() -> String:
	var file := FileAccess.open(MANUAL_PATH, FileAccess.READ)
	if not file:
		return "Manual not found."
	var text := file.get_as_text()
	file.close()
	return text


func _format_manual_text(source: String) -> String:
	var lines := source.split("\n")
	var formatted: Array[String] = []
	for line in lines:
		if line.begins_with("# "):
			formatted.append("[center][b][font_size=20]%s[/font_size][/b][/center]" % line.substr(2))
		elif line.begins_with("## "):
			formatted.append("[b][font_size=16]%s[/font_size][/b]" % line.substr(3))
		elif line.begins_with("- "):
			formatted.append("• " + line.substr(2))
		elif line.strip_edges().is_empty():
			formatted.append("")
		else:
			formatted.append(line)
	return _bold_markers("\n".join(formatted))


## Turns markdown **bold** pairs into BBCode so the asterisks are not shown.
func _bold_markers(text: String) -> String:
	var parts: PackedStringArray = text.split("**")
	var out: String = parts[0]
	for i: int in range(1, parts.size()):
		out += ("[b]" if i % 2 == 1 else "[/b]") + parts[i]
	return out


# ============================================================================
# SETTINGS
# ============================================================================

func _setup_settings_menu() -> void:
	settings_menu = SettingsMenu.new()
	settings_menu.name = "SettingsMenu"
	settings_menu.visible = false
	add_child(settings_menu)
	settings_menu.new_game_confirmed.connect(_new_game)
	settings_menu.tutorial_requested.connect(_replay_tutorial)
	settings_menu.still_tutorial_changed.connect(_on_still_tutorial_changed)


func _on_settings_button_pressed() -> void:
	var level_id: int = _new_game_level()
	var level_name: String = ""
	for level: Dictionary in HumanGeneticsState.get_all_levels():
		if level.get("id", 0) == level_id:
			level_name = level.get("name", "")
	settings_menu.open("Level %d (%s)" % [level_id, level_name])


## A New game starts on Level 1, or on the level a class settings link names.
func _new_game_level() -> int:
	return TeacherModeState.get_link_level() if TeacherModeState.is_from_link() else 1


## Empties the library and the Recombination Area, goes back to the starting level and offers the tutorial again.
## Text size and the still tutorial box are kept; so are a class settings link's settings.
func _new_game() -> void:
	_end_tutorial()
	var level_id: int = _new_game_level()
	_start_level(level_id)
	TeacherModeState.session_reset()
	if library_panel:
		library_panel.refresh()
	if breeding_area:
		breeding_area.on_level_changed(level_id)
	_tutorial_reset_parent_flags()
	if FileAccess.file_exists(TUTORIAL_STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TUTORIAL_STATE_PATH))
	_begin_tutorial_flow()


func _replay_tutorial() -> void:
	_end_tutorial()
	_start_tutorial()


func _on_still_tutorial_changed(_still: bool) -> void:
	if tutorial_panel != null and tutorial_panel.visible:
		_blink_tutorial()


## The tutorial box fades to draw the eye, unless the player asked for it to stay still.
func _blink_tutorial() -> void:
	tutorial_panel.stop_blink()
	tutorial_panel.modulate = Color(1, 1, 1)
	if not settings_menu.still_tutorial:
		tutorial_panel.start_blink(Color(1, 1, 1), Color(1, 0.85, 0.65))


# ============================================================================
# BREEDING COORDINATION
# ============================================================================

func _on_offspring_created(human_id: int) -> void:
	# Refresh library to show new human
	if library_panel:
		library_panel.refresh()
		library_panel.scroll_to_human(human_id)
	_end_tutorial_if_on_step(6)


func _on_human_selected_for_parent(human_id: int, slot: String) -> void:
	if breeding_area:
		breeding_area.set_parent_from_library(human_id, slot)


func _on_library_face_clicked(human_id: int) -> void:
	var human := HumanGeneticsState.get_human(human_id)
	if human.is_empty():
		return
	
	var genotype := HumanGeneticsState.normalize_genotype(human.get("genotype", {}))
	var phenotype := HumanGeneticsState.calculate_phenotype(genotype)
	
#	if face_preview_name:
#		face_preview_name.text = human.get("name", "Human")
	if face_preview_face and face_preview_face.has_method("render"):
		face_preview_face.render(phenotype)
		face_preview_face.scale = Vector2(3, 3)
		face_preview_face.pivot_offset = face_preview_face.size / 2.0
	
	if face_preview_popup:
		face_preview_popup.popup_centered(Vector2(360, 420))
		face_preview_close.grab_focus()


func _on_face_preview_close() -> void:
	if face_preview_popup:
		face_preview_popup.hide()


func _on_manual_button_pressed() -> void:
	if not manual_popup or not manual_text:
		return
	manual_text.text = _format_manual_text(_load_manual_text())
	manual_popup.popup_centered(Vector2(760, 560))
	manual_text.grab_focus()


func _on_manual_close_pressed() -> void:
	if manual_popup:
		manual_popup.hide()


# ============================================================================
# TUTORIAL
# ============================================================================

func _setup_tutorial_anchors() -> void:
	_tutorial_anchors.clear()
	if library_panel:
		_tutorial_anchors["library_panel"] = library_panel
		_tutorial_anchors["generate_button"] = library_panel.get_node("VBox/GenerateButton")
	if breeding_area:
		_tutorial_anchors["parent_a_slot"] = breeding_area.get_node("%ParentASlot")
		_tutorial_anchors["parent_b_slot"] = breeding_area.get_node("%ParentBSlot")
		_tutorial_anchors["punnett_grid"] = breeding_area.get_node("%PunnettGrid")
		_tutorial_anchors["offspring_preview"] = breeding_area.get_node("%OffspringPreview")


func _load_tutorial_data() -> void:
	var file := FileAccess.open("res://data/tutorial.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK or json.data is not Dictionary:
		push_error("Failed to parse tutorial.json")
		return
	_tutorial_data = json.data
	_tutorial_steps = _tutorial_data.get("steps", [])


func _begin_tutorial_flow() -> void:
	if _should_skip_tutorial():
		return
	if tutorial_panel:
		var prompt: Dictionary = _tutorial_data.get("startup_prompt", {})
		var text: String = prompt.get("text", "Skip Tutorial?")
		var yes_label: String = prompt.get("yes_label", "Yes")
		var no_label: String = prompt.get("no_label", "No")
		var remember_label: String = prompt.get("remember_label", "Remember this")
		tutorial_panel.show_prompt(text, yes_label, no_label, remember_label)
		_center_tutorial_panel()
		_blink_tutorial()


func _should_skip_tutorial() -> bool:
	if not FileAccess.file_exists(TUTORIAL_STATE_PATH):
		return false
	var file := FileAccess.open(TUTORIAL_STATE_PATH, FileAccess.READ)
	if not file:
		return false
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK or json.data is not Dictionary:
		return false
	return json.data.get("skip", false)


func _save_tutorial_skip(skip: bool) -> void:
	var data := {"skip": skip}
	var file := FileAccess.open(TUTORIAL_STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _start_tutorial() -> void:
	_tutorial_active = true
	_tutorial_step_index = 0
	_tutorial_reset_parent_flags()
	_show_current_tutorial_step()


func _end_tutorial() -> void:
	_tutorial_active = false
	_tutorial_step_index = -1
	if tutorial_panel:
		tutorial_panel.stop_blink()
		tutorial_panel.hide()


func _show_current_tutorial_step() -> void:
	if not tutorial_panel:
		return
	if _tutorial_step_index < 0 or _tutorial_step_index >= _tutorial_steps.size():
		_end_tutorial()
		return
	var step: Dictionary = _tutorial_steps[_tutorial_step_index]
	var text: String = step.get("text", "")
	var show_not_now: bool = step.get("show_not_now", false)
	var show_close: bool = step.get("show_close", false)
	tutorial_panel.show_step(text, show_not_now, show_close)
	_blink_tutorial()
	_position_tutorial_panel(step)


func _advance_tutorial_if_step(step_id: int) -> void:
	if not _tutorial_active:
		return
	if _tutorial_step_index < 0 or _tutorial_step_index >= _tutorial_steps.size():
		return
	var current_step: Dictionary = _tutorial_steps[_tutorial_step_index]
	if current_step.get("id", -1) == step_id:
		_tutorial_step_index += 1
		_show_current_tutorial_step()


func _position_tutorial_panel(step: Dictionary) -> void:
	if not tutorial_panel:
		return
	await get_tree().process_frame
	var anchor_key: String = step.get("anchor", "")
	var anchor: Control = _tutorial_anchors.get(anchor_key, null)
	if not anchor:
		return
	var position: String = step.get("position", "above")
	var offset := Vector2(step.get("offset_x", 0), step.get("offset_y", 0))
	var anchor_x_factor: float = float(step.get("anchor_x_factor", 0.5))
	var anchor_y_factor: float = float(step.get("anchor_y_factor", 0.5))
	var anchor_rect := anchor.get_global_rect()
	var panel_size := tutorial_panel.size
	var target := anchor_rect.position
	
	match position:
		"right":
			target = Vector2(
				anchor_rect.position.x + anchor_rect.size.x,
				anchor_rect.position.y + anchor_rect.size.y * anchor_y_factor - panel_size.y * 0.5
			)
		"left":
			target = Vector2(
				anchor_rect.position.x - panel_size.x,
				anchor_rect.position.y + anchor_rect.size.y * anchor_y_factor - panel_size.y * 0.5
			)
		"below":
			target = Vector2(
				anchor_rect.position.x + anchor_rect.size.x * anchor_x_factor - panel_size.x * 0.5,
				anchor_rect.position.y + anchor_rect.size.y
			)
		"above":
			target = Vector2(
				anchor_rect.position.x + anchor_rect.size.x * anchor_x_factor - panel_size.x * 0.5,
				anchor_rect.position.y - panel_size.y
			)
		_:
			target = Vector2(
				anchor_rect.position.x + anchor_rect.size.x * anchor_x_factor - panel_size.x * 0.5,
				anchor_rect.position.y + anchor_rect.size.y * anchor_y_factor - panel_size.y * 0.5
			)
	
	tutorial_panel.global_position = target + offset


func _center_tutorial_panel() -> void:
	await get_tree().process_frame
	if not tutorial_panel:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	var panel_size := tutorial_panel.size
	tutorial_panel.global_position = viewport_rect.position + (viewport_rect.size - panel_size) * 0.5


func _tutorial_reset_parent_flags() -> void:
	_tutorial_parents_filled["A"] = false
	_tutorial_parents_filled["B"] = false


func _on_tutorial_prompt_answered(skip: bool, remember: bool) -> void:
	if remember:
		_save_tutorial_skip(skip)
	tutorial_panel.stop_blink()
	tutorial_panel.hide()
	if not skip:
		_start_tutorial()


func _on_tutorial_not_now_pressed() -> void:
	_advance_tutorial_if_step(4)


func _on_tutorial_close_pressed() -> void:
	_end_tutorial()


func _on_tutorial_generate_pressed() -> void:
	_advance_tutorial_if_step(1)


func _on_tutorial_parent_selected(slot: String, _human_id: int) -> void:
	if slot in ["A", "parent_a"]:
		_tutorial_parents_filled["A"] = true
	if slot in ["B", "parent_b"]:
		_tutorial_parents_filled["B"] = true
	if _tutorial_parents_filled["A"] or _tutorial_parents_filled["B"]:
		_advance_tutorial_if_step(2)
	if _tutorial_parents_filled["A"] and _tutorial_parents_filled["B"]:
		_advance_tutorial_if_step(3)


func _on_tutorial_allele_dropped(_slot: String, _gene_id: String) -> void:
	_advance_tutorial_if_step(4)


func _on_tutorial_recombine_pressed() -> void:
	_advance_tutorial_if_step(5)


func _end_tutorial_if_on_step(step_id: int) -> void:
	if not _tutorial_active:
		return
	if _tutorial_step_index < 0 or _tutorial_step_index >= _tutorial_steps.size():
		return
	var current_step: Dictionary = _tutorial_steps[_tutorial_step_index]
	if current_step.get("id", -1) == step_id:
		_end_tutorial()


# ============================================================================
# KEYBOARD SHORTCUTS
# ============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Ctrl+T: Toggle Teacher Mode panel (Escape is handled by KeyboardNav)
		if event.keycode == KEY_T and event.ctrl_pressed:
			_on_teacher_mode_button_pressed()
