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
@onready var breeding_area: Control = $MainVBox/MainHBox/BreedingArea
@onready var level_dropdown: OptionButton = $MainVBox/TopBar/VBox/HBox/LevelDropdown
@onready var teacher_mode_button: Button = $MainVBox/TopBar/VBox/HBox/TeacherModeButton
@onready var settings_button: Button = $MainVBox/TopBar/VBox/HBox/SettingsButton
@onready var teacher_mode_banner: PanelContainer = $MainVBox/TopBar/VBox/TeacherModeBanner
@onready var teacher_mode_status: Label = $MainVBox/TopBar/VBox/TeacherModeBanner/StatusLabel
@onready var footer_disclaimer: Label = $MainVBox/FooterDisclaimer
@onready var teacher_mode_panel: Control = $TeacherModePanel

# ============================================================================
# STATE
# ============================================================================

var _teacher_panel_visible: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_connections()
	_populate_level_dropdown()
	_update_teacher_mode_ui()
	_update_footer_disclaimer()
	
	# Initial level
	HumanGeneticsState.set_level(1)


func _setup_connections() -> void:
	# Level dropdown
	level_dropdown.item_selected.connect(_on_level_selected)
	
	# Teacher mode
	teacher_mode_button.pressed.connect(_on_teacher_mode_button_pressed)
	TeacherModeState.teacher_mode_toggled.connect(_on_teacher_mode_toggled)
	TeacherModeState.constraints_changed.connect(_on_teacher_constraints_changed)
	
	# Settings button
	settings_button.pressed.connect(_on_settings_button_pressed)
	
	# Breeding area signals
	if breeding_area:
		breeding_area.offspring_created.connect(_on_offspring_created)
	
	# Library signals
	if library_panel:
		library_panel.human_selected_for_parent.connect(_on_human_selected_for_parent)
	
	# Teacher mode panel
	if teacher_mode_panel:
		teacher_mode_panel.panel_closed.connect(_on_teacher_panel_close_requested)
		teacher_mode_panel.visible = false


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


func _on_human_selected_for_parent(human_id: int, slot: String) -> void:
	if breeding_area:
		breeding_area.set_parent_from_library(human_id, slot)


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
