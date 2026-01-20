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
@onready var admin_button: Button = $MainVBox/TopBar/VBox/HBox/AdminButton
@onready var face_preview_popup: PopupPanel = $FacePreviewPopup
#@onready var face_preview_name: Label = $FacePreviewPopup/PanelContainer/VBoxContainer/NameLabel
@onready var face_preview_face: Control = $FacePreviewPopup/PanelContainer/VBoxContainer/FacePreviewContainer/FacePreview
@onready var face_preview_close: Button = $FacePreviewPopup/PanelContainer/VBoxContainer/CloseButton
@onready var tutorial_panel: Control = $TutorialPanel
@onready var admin_pin_popup: PopupPanel = $AdminPinPopup
@onready var admin_pin_input: LineEdit = $AdminPinPopup/PanelContainer/VBox/PinInput
@onready var admin_unlock_button: Button = $AdminPinPopup/PanelContainer/VBox/ButtonRow/UnlockButton
@onready var admin_cancel_button: Button = $AdminPinPopup/PanelContainer/VBox/ButtonRow/CancelButton

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
var _admin_enabled: bool = false

const TUTORIAL_STATE_PATH := "user://tutorial_state.json"
const ADMIN_HASH := "#admin"
const ADMIN_PIN := "1234"

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_connections()
	_populate_level_dropdown()
	_update_teacher_mode_ui()
	_update_footer_disclaimer()
	_apply_admin_access()
	
	# Initial level
	HumanGeneticsState.set_level(1)
	
	_setup_tutorial_anchors()
	_load_tutorial_data()
	call_deferred("_begin_tutorial_flow")


func _setup_connections() -> void:
	# Level dropdown
	level_dropdown.item_selected.connect(_on_level_selected)
	
	# Teacher mode
	teacher_mode_button.pressed.connect(_on_teacher_mode_button_pressed)
	TeacherModeState.teacher_mode_toggled.connect(_on_teacher_mode_toggled)
	TeacherModeState.constraints_changed.connect(_on_teacher_constraints_changed)
	
	# Admin PIN
	if admin_button:
		admin_button.pressed.connect(_on_admin_button_pressed)
	if admin_unlock_button:
		admin_unlock_button.pressed.connect(_on_admin_unlock_pressed)
	if admin_cancel_button:
		admin_cancel_button.pressed.connect(_on_admin_cancel_pressed)
	if admin_pin_input:
		admin_pin_input.text_submitted.connect(_on_admin_pin_submitted)
	
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
	if not _admin_enabled:
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


func _apply_admin_access() -> void:
	_admin_enabled = false
	if OS.get_name() == "Web":
		_admin_enabled = _get_location_hash().findn(ADMIN_HASH) >= 0
	
	if teacher_mode_button:
		teacher_mode_button.visible = _admin_enabled
	if admin_button:
		admin_button.visible = true
	
	if not _admin_enabled and teacher_mode_panel:
		teacher_mode_panel.visible = false
		_teacher_panel_visible = false


func _get_location_hash() -> String:
	var hash_value: String = ""
	if Engine.has_singleton("JavaScriptBridge"):
		var result : String = JavaScriptBridge.eval("window.location.hash", true)
		if result is String:
			hash_value = result
	return hash_value


func _on_admin_button_pressed() -> void:
	if not admin_pin_popup:
		return
	admin_pin_popup.popup_centered(Vector2(360, 160))
	if admin_pin_input:
		admin_pin_input.text = ""
		admin_pin_input.grab_focus()


func _on_admin_unlock_pressed() -> void:
	_try_unlock_admin()


func _on_admin_pin_submitted(_text: String) -> void:
	_try_unlock_admin()


func _on_admin_cancel_pressed() -> void:
	if admin_pin_popup:
		admin_pin_popup.hide()


func _try_unlock_admin() -> void:
	if not admin_pin_input:
		return
	if admin_pin_input.text == ADMIN_PIN:
		_admin_enabled = true
		if teacher_mode_button:
			teacher_mode_button.visible = true
		if admin_pin_popup:
			admin_pin_popup.hide()
	else:
		admin_pin_input.text = ""


# ============================================================================
# SETTINGS
# ============================================================================

func _on_settings_button_pressed() -> void:
	# TODO: Open settings panel
	print("Settings button pressed")


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


func _on_face_preview_close() -> void:
	if face_preview_popup:
		face_preview_popup.hide()


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
		tutorial_panel.start_blink(Color(1, 1, 1), Color(1, 0.85, 0.65))


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
	tutorial_panel.start_blink(Color(1, 1, 1), Color(1, 0.85, 0.65))
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
		# Ctrl+T: Toggle Teacher Mode panel
		if event.keycode == KEY_T and event.ctrl_pressed:
			_on_teacher_mode_button_pressed()
		# Escape: Close Teacher Mode panel
		elif event.keycode == KEY_ESCAPE and _teacher_panel_visible:
			_on_teacher_panel_close_requested()
