extends PanelContainer
class_name AllelePalette
## Displays all possible allele pairs for active genes
## Users drag chips from here to ParentSlots for genotype construction

signal punnett_genes_changed(selected_genes: Array)

@onready var vbox: VBoxContainer = $ScrollContainer/VBox
@onready var scroll_container: ScrollContainer = $ScrollContainer

const AlleleChipScene := preload("res://scenes/ui/AlleleChip.tscn")

var _gene_selection: Dictionary = {}
var _selection_initialized: bool = false


func _ready() -> void:
	HumanGeneticsState.level_changed.connect(_on_level_changed)
	TeacherModeState.gene_visibility_changed.connect(_on_gene_visibility_changed)
	
	# Initial population
	call_deferred("_populate_palette")


func _populate_palette() -> void:
	# Clear existing
	for child in vbox.get_children():
		child.queue_free()
	
	var active_genes: Array = TeacherModeState.get_active_genes()
	_sync_gene_selection(active_genes)
	
	for gene_id in active_genes:
		if not TeacherModeState.is_gene_visible(gene_id):
			continue
		
		var gene_info: Dictionary = HumanGeneticsState.get_gene_info(gene_id)
		if gene_info.is_empty():
			continue
		
		# Create gene section
		var section := _create_gene_section(gene_id, gene_info)
		vbox.add_child(section)
	
	_emit_selection()


func _create_gene_section(gene_id: String, gene_info: Dictionary) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = gene_id + "_Section"
	
	# Gene header row with checkbox, label, and allele chips in one line
	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	header_row.add_theme_constant_override("separation", 6)
	section.add_child(header_row)
	
	var check := CheckBox.new()
	check.button_pressed = _gene_selection.get(gene_id, false)
	check.toggled.connect(func(pressed: bool) -> void:
		_gene_selection[gene_id] = pressed
		_emit_selection()
	)
	header_row.add_child(check)
	
	var header := Label.new()
	header.text = gene_info.get("name", gene_id)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header_row.add_child(header)
	
	# var spacer := Control.new()
	# spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# header_row.add_child(spacer)
	
	var dom: String = gene_info.get("dom", "A")
	var rec: String = gene_info.get("rec", "a")
	# Use model-aware pairs (e.g., hide TYR aa when albinism is disabled).
	var combinations := HumanGeneticsState.get_allele_pairs(gene_id)
	
	for alleles in combinations:
		var chip: AlleleChip = AlleleChipScene.instantiate()
		header_row.add_child(chip)
		chip.setup(gene_id, alleles, true, false)  # Draggable, no remove button
	
	# Add separator
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	section.add_child(separator)
	
	return section


func _sync_gene_selection(active_genes: Array) -> void:
	# Remove genes that are no longer active.
	for gene_id in _gene_selection.keys():
		if gene_id not in active_genes:
			_gene_selection.erase(gene_id)
	
	var max_genes: int = TeacherModeState.get_max_genes_per_cross()
	
	if not _selection_initialized:
		for i in range(active_genes.size()):
			_gene_selection[active_genes[i]] = i < max_genes
		_selection_initialized = true
		return
	
	# Add newly active genes, keep selection count within max.
	var selected_count := 0
	for gene_id in _gene_selection.keys():
		if _gene_selection[gene_id]:
			selected_count += 1
	
	for gene_id in active_genes:
		if not _gene_selection.has(gene_id):
			var should_select := selected_count < max_genes
			_gene_selection[gene_id] = should_select
			if should_select:
				selected_count += 1


func _emit_selection() -> void:
	var active_genes: Array = TeacherModeState.get_active_genes()
	var selected: Array = []
	for gene_id in active_genes:
		if _gene_selection.get(gene_id, false):
			selected.append(gene_id)
	punnett_genes_changed.emit(selected)


func _on_level_changed(_level_id: int) -> void:
	_populate_palette()


func _on_gene_visibility_changed() -> void:
	_populate_palette()


## Refresh the palette (called when Teacher Mode settings change)
func refresh() -> void:
	_populate_palette()
