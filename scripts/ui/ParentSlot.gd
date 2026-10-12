# ParentSlot.gd
# Drop zone for parent selection with in-place genotype editing
# Supports drag-drop from library and allele palette
# Educational purpose: Allow students to construct parental genotypes

extends PanelContainer

# ============================================================================
# SIGNALS
# ============================================================================

signal human_dropped(human_id: int)
signal genotype_changed(new_genotype: Dictionary)
signal cleared()
signal allele_dropped(gene_id: String)

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var face_display: Control = $VBox/FaceContainer/FaceDisplay
@onready var name_label: Label = $VBox/NameLabel
@onready var genotype_container: VBoxContainer = %GenotypeContainer
@onready var drop_hint: Label = $VBox/FaceContainer/DropHint
@onready var clear_button: Button = $VBox/ClearButton
@onready var root_vbox: VBoxContainer = $VBox
@onready var face_container: Control = $VBox/FaceContainer

# ============================================================================
# CONSTANTS
# ============================================================================

const AlleleChipScene := preload("res://scenes/ui/AlleleChip.tscn")

# ============================================================================
# STATE
# ============================================================================

var _human_id: int = -1
var _current_genotype: Dictionary = {}
var _is_modified: bool = false
var _is_drop_target: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_connections()
	_update_display()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_configure_drop_passthrough()


func _setup_connections() -> void:
	($VBox/ScrollContainer as ScrollContainer).follow_focus = true
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)


func _configure_drop_passthrough() -> void:
	var passthrough_controls: Array = [
		root_vbox,
		face_container,
		face_display,
		drop_hint,
		name_label
	]
	for control in passthrough_controls:
		if control:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

## Set the human for this slot
func set_human(human_id: int, genotype: Dictionary) -> void:
	_human_id = human_id
	_current_genotype = genotype.duplicate(true)
	_is_modified = false
	_update_display()


## Clear the slot
func clear() -> void:
	_human_id = -1
	_current_genotype = {}
	_is_modified = false
	_update_display()
	cleared.emit()


## Refresh display
func refresh() -> void:
	_update_display()


## Get current genotype
func get_genotype() -> Dictionary:
	return _current_genotype


## Check if slot has a human
func has_human() -> bool:
	return not _current_genotype.is_empty()


# ============================================================================
# DISPLAY
# ============================================================================

func _update_display() -> void:
	if _current_genotype.is_empty():
		_show_empty_state()
	else:
		_show_human_state()


func _show_empty_state() -> void:
	if drop_hint:
		drop_hint.visible = true
		drop_hint.text = "Drop human\nor alleles here"
	
	if face_display:
		face_display.visible = false
	
	if name_label:
		name_label.text = "Parent"
	
	if clear_button:
		clear_button.visible = false
	
	_clear_genotype_display()


func _show_human_state() -> void:
	if drop_hint:
		drop_hint.visible = false
	
	# Show face
	if face_display:
		face_display.visible = true
		var phenotype := HumanGeneticsState.calculate_phenotype(_current_genotype)
		face_display.render(phenotype)
	
	# Show name
	if name_label:
		if _human_id > 0:
			var human := HumanGeneticsState.get_human(_human_id)
			var base_name: String = human.get("name", "Parent")
			if _is_modified:
				name_label.text = base_name + " (modified)"
			else:
				name_label.text = base_name
		else:
			if _is_modified:
				name_label.text = "Custom Genotype (modified)"
			else:
				name_label.text = "Custom Genotype"
	
	if clear_button:
		clear_button.visible = true
	
	_update_genotype_display()


func _clear_genotype_display() -> void:
	if not genotype_container:
		return
	
	for child in genotype_container.get_children():
		child.queue_free()


func _update_genotype_display() -> void:
	_clear_genotype_display()
	
	if not genotype_container:
		return
	
	# Only show genotype if Teacher Mode allows
	if not TeacherModeState.should_show_genotype():
		return
	# GenotypeContainer sits in a ScrollContainer to handle long allele lists.
	
	var active_genes := HumanGeneticsState.get_active_genes()
	
	for gene_id in active_genes:
		if not _current_genotype.has(gene_id):
			continue
		
		var chip: Control = AlleleChipScene.instantiate()
		genotype_container.add_child(chip)
		chip.setup(gene_id, _current_genotype[gene_id])
		chip.allele_changed.connect(_on_allele_changed)
		chip.allele_removed.connect(_on_allele_removed)


# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_clear_pressed() -> void:
	clear()


func _on_allele_changed(gene_id: String, new_alleles: Array) -> void:
	_current_genotype[gene_id] = new_alleles
	_is_modified = true
	_update_display()
	genotype_changed.emit(_current_genotype)


func _on_allele_removed(gene_id: String) -> void:
	# Reset to convenience genotype
	_current_genotype[gene_id] = HumanGeneticsState.CONVENIENCE_GENOTYPES.get(gene_id, ["A", "a"])
	_is_modified = true
	_update_display()
	genotype_changed.emit(_current_genotype)


# ============================================================================
# DRAG AND DROP
# ============================================================================

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if data is not Dictionary:
		_is_drop_target = false
		queue_redraw()
		return false
	
	# Check if parents are locked
	if TeacherModeState.are_parents_locked() and has_human():
		_is_drop_target = false
		queue_redraw()
		return false
	
	var data_type: String = data.get("type", "")
	var can_drop := data_type in ["human", "allele_pair", "allele_chip"]
	_is_drop_target = can_drop
	queue_redraw()
	return can_drop


func _drop_data(_position: Vector2, data: Variant) -> void:
	if data is not Dictionary:
		return
	
	var data_type: String = data.get("type", "")
	
	match data_type:
		"human":
			var id: int = data.get("id", -1)
			if id > 0:
				human_dropped.emit(id)
		"allele_pair", "allele_chip":
			_handle_allele_drop(data)
	
	_is_drop_target = false
	queue_redraw()


func _handle_allele_drop(data: Dictionary) -> void:
	apply_allele(data.get("gene_id", ""), data.get("alleles", []))


## Puts an allele pair on this parent. The drop and the keyboard route (A / B on an Allele Bank chip) both use it.
func apply_allele(gene_id: String, alleles: Array) -> void:
	if TeacherModeState.are_parents_locked() and has_human():
		return
	if gene_id.is_empty() or alleles.size() < 2:
		return
	
	# If slot is empty, initialize with convenience genotypes
	if _current_genotype.is_empty():
		_current_genotype = HumanGeneticsState.CONVENIENCE_GENOTYPES.duplicate(true)
	
	# Update the specific gene
	_current_genotype[gene_id] = alleles.duplicate()
	_is_modified = true
	_human_id = -1  # Detach from any saved human
	
	_update_display()
	genotype_changed.emit(_current_genotype)
	allele_dropped.emit(gene_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_is_drop_target = false
		queue_redraw()


func _draw() -> void:
	if _is_drop_target:
		# Draw highlight border
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.3, 0.7, 0.3, 0.3), true)
		draw_rect(rect, Color(0.3, 0.9, 0.3), false, 3.0)
