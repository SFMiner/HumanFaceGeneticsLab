extends PanelContainer
class_name AllelePalette
## Displays all possible allele pairs for active genes
## Users drag chips from here to ParentSlots for genotype construction

@onready var vbox: VBoxContainer = $ScrollContainer/VBox
@onready var scroll_container: ScrollContainer = $ScrollContainer

const AlleleChipScene := preload("res://scenes/ui/AlleleChip.tscn")


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
	
	for gene_id in active_genes:
		if not TeacherModeState.is_gene_visible(gene_id):
			continue
		
		var gene_info: Dictionary = HumanGeneticsState.get_gene_info(gene_id)
		if gene_info.is_empty():
			continue
		
		# Create gene section
		var section := _create_gene_section(gene_id, gene_info)
		vbox.add_child(section)


func _create_gene_section(gene_id: String, gene_info: Dictionary) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = gene_id + "_Section"
	
	# Gene header label
	var header := Label.new()
	header.text = gene_info.get("name", gene_id)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	section.add_child(header)
	
	# Allele chip container
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 4)
	section.add_child(chip_row)
	
	var dom: String = gene_info.get("dom", "A")
	var rec: String = gene_info.get("rec", "a")
	# Use model-aware pairs (e.g., hide TYR aa when albinism is disabled).
	var combinations := HumanGeneticsState.get_allele_pairs(gene_id)
	
	for alleles in combinations:
		var chip: AlleleChip = AlleleChipScene.instantiate()
		chip_row.add_child(chip)
		chip.setup(gene_id, alleles, true, false)  # Draggable, no remove button
	
	# Add separator
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	section.add_child(separator)
	
	return section


func _on_level_changed(_level_id: int) -> void:
	_populate_palette()


func _on_gene_visibility_changed() -> void:
	_populate_palette()


## Refresh the palette (called when Teacher Mode settings change)
func refresh() -> void:
	_populate_palette()
