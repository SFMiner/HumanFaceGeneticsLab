extends PanelContainer
class_name AlleleChip
## Displays a single gene's allele pair (e.g., "TYR: Aa")
## Draggable to/from parent slots for genotype editing

signal chip_removed(gene_id: String)
signal chip_clicked(gene_id: String)

@onready var gene_label: Label = $HBox/GeneLabel
@onready var allele_label: Label = $HBox/AlleleLabel
@onready var remove_button: Button = $HBox/RemoveButton

var gene_id: String = ""
var alleles: Array = []  # ["A", "a"]
var is_draggable: bool = true
var show_remove_button: bool = true

## Color coding for dominance patterns
const COLORS = {
	"homozygous_dom": Color(0.2, 0.5, 0.8, 1.0),    # Blue - both dominant
	"heterozygous": Color(0.5, 0.3, 0.7, 1.0),       # Purple - mixed
	"homozygous_rec": Color(0.7, 0.4, 0.2, 1.0),     # Orange - both recessive
	"default": Color(0.3, 0.3, 0.3, 1.0)
}


func _ready() -> void:
	if remove_button:
		remove_button.pressed.connect(_on_remove_pressed)
		remove_button.visible = show_remove_button
	
	gui_input.connect(_on_gui_input)


func setup(p_gene_id: String, p_alleles: Array, p_draggable: bool = true, p_show_remove: bool = true) -> void:
	gene_id = p_gene_id
	alleles = p_alleles.duplicate()
	is_draggable = p_draggable
	show_remove_button = p_show_remove
	
	_update_display()


func _update_display() -> void:
	if gene_label:
		gene_label.text = gene_id + ":"
	
	if allele_label:
		var allele_str := ""
		if alleles.size() >= 2:
			allele_str = alleles[0] + alleles[1]
		allele_label.text = allele_str
	
	# Color based on dominance pattern
	var gene_info: Dictionary = HumanGeneticsState.get_gene_info(gene_id)
	if gene_info.is_empty():
		self_modulate = COLORS.default
		return
	
	var dom_allele: String = gene_info.get("dom", "")
	var rec_allele: String = gene_info.get("rec", "")
	
	var dom_count := alleles.count(dom_allele)
	
	if dom_count == 2:
		self_modulate = COLORS.homozygous_dom
	elif dom_count == 1:
		self_modulate = COLORS.heterozygous
	else:
		self_modulate = COLORS.homozygous_rec
	
	if remove_button:
		remove_button.visible = show_remove_button


func _on_remove_pressed() -> void:
	chip_removed.emit(gene_id)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			chip_clicked.emit(gene_id)


func _get_drag_data(_position: Vector2) -> Variant:
	if not is_draggable:
		return null
	
	# Create visual preview
	var preview := duplicate() as AlleleChip
	preview.modulate.a = 0.7
	preview.show_remove_button = false
	if preview.has_node("HBox/RemoveButton"):
		preview.get_node("HBox/RemoveButton").visible = false
	set_drag_preview(preview)
	
	return {
		"type": "allele_chip",
		"gene_id": gene_id,
		"alleles": alleles.duplicate()
	}


func get_allele_pair() -> Array:
	return alleles.duplicate()


func set_allele_pair(new_alleles: Array) -> void:
	alleles = new_alleles.duplicate()
	_update_display()
