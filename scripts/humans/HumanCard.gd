# HumanCard.gd
# Library card displaying a human with face, name, and traits
# Supports drag-drop to parent slots and favorite/delete actions
# Educational purpose: Organize created humans for breeding experiments

extends PanelContainer

# ============================================================================
# SIGNALS
# ============================================================================

signal clicked(human_id: int)
signal face_clicked(human_id: int)
signal drag_started(human_id: int)
signal delete_requested(human_id: int)
signal favorite_toggled(human_id: int)

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var face_display: Control = $VBox/FaceContainer/FaceDisplay
@onready var name_label: Label = $VBox/NameLabel
@onready var traits_label: Label = $VBox/TraitsLabel
@onready var favorite_button: Button = $VBox/ButtonRow/FavoriteButton
@onready var delete_button: Button = $VBox/ButtonRow/DeleteButton
@onready var generation_label: Label = $VBox/GenerationLabel
@onready var root_vbox: VBoxContainer = $VBox
@onready var face_container: Control = $VBox/FaceContainer

# ============================================================================
# STATE
# ============================================================================

var _human_id: int = -1
var _human_data: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_connections()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_configure_drag_passthrough()


func _setup_connections() -> void:
	if favorite_button:
		favorite_button.pressed.connect(_on_favorite_pressed)
	if delete_button:
		delete_button.pressed.connect(_on_delete_pressed)
	
	gui_input.connect(_on_gui_input)


func _configure_drag_passthrough() -> void:
	var passthrough_controls: Array = [
		root_vbox,
		face_container,
		face_display,
		name_label,
		traits_label,
		generation_label
	]
	for control in passthrough_controls:
		if control:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ============================================================================
# SETUP
# ============================================================================

## Setup the card with human data
func setup(human_data: Dictionary) -> void:
	_human_data = human_data
	_human_id = human_data.get("id", -1)
	var genotype := HumanGeneticsState.normalize_genotype(human_data.get("genotype", {}))
	# Recalculate phenotype with current level rules for consistent visuals.
	var phenotype := HumanGeneticsState.calculate_phenotype(genotype)
	
	# Render face
	if face_display:
		face_display.render(phenotype)
	
	# Set name
	if name_label:
		name_label.text = human_data.get("name", "Unknown")
	
	# Set traits (visible traits based on level)
	if traits_label:
		traits_label.text = _format_traits(phenotype)
	
	# Set generation
	if generation_label:
		var gen: int = human_data.get("generation", 0)
		if gen == 0:
			generation_label.text = "P"
		else:
			generation_label.text = "F%d" % gen
	
	# Update favorite button
	_update_favorite_button()


func _format_traits(phenotype: Dictionary) -> String:
	var traits := HumanGeneticsState.get_traits_displayed()
	var parts: Array = []
	
	for spec_trait in traits:
		if phenotype.has(spec_trait):
			var value: String = phenotype[spec_trait]
			# Format nicely (capitalize, replace underscores)
			value = value.replace("_", " ").capitalize()
			parts.append(value)
	
	return "\n".join(parts)


func _update_favorite_button() -> void:
	if not favorite_button:
		return
	
	var is_fav := HumanGeneticsState.is_favorite(_human_id)
	favorite_button.text = "❤" if is_fav else "♡"
	favorite_button.modulate = Color.RED if is_fav else Color.WHITE


# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

## Get the human ID
func get_human_id() -> int:
	return _human_id


## Flash the card (visual feedback)
func flash() -> void:
	var original_modulate := modulate
	modulate = Color(1.5, 1.5, 1.5)
	var tween := create_tween()
	tween.tween_property(self, "modulate", original_modulate, 0.3)


# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if face_container and face_container.get_global_rect().has_point(event.global_position):
				face_clicked.emit(_human_id)
				return
			clicked.emit(_human_id)


func _on_favorite_pressed() -> void:
	favorite_toggled.emit(_human_id)
	_update_favorite_button()


func _on_delete_pressed() -> void:
	# Confirm deletion
	delete_requested.emit(_human_id)


# ============================================================================
# DRAG AND DROP
# ============================================================================

func _get_drag_data(_position: Vector2) -> Variant:
	if _human_id < 0:
		return null
	
	# Check if dragging is allowed
	if TeacherModeState.is_generation_locked():
		return null
	
	drag_started.emit(_human_id)
	
	# Create drag preview
	var preview := _create_drag_preview()
	set_drag_preview(preview)
	
	return {
		"type": "human",
		"id": _human_id,
		"genotype": _human_data.get("genotype", {})
	}


func _create_drag_preview() -> Control:
	# Create a simplified preview
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(100, 80)
	preview.modulate.a = 0.7
	
	var vbox := VBoxContainer.new()
	preview.add_child(vbox)
	
	var label := Label.new()
	label.text = _human_data.get("name", "Human")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var traits := Label.new()
	traits.text = _format_traits(_human_data.get("phenotype", {}))
	traits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	traits.add_theme_font_size_override("font_size", 10)
	vbox.add_child(traits)
	
	return preview
