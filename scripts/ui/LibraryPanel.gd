# LibraryPanel.gd
# Left sidebar panel for displaying and managing saved humans
# Supports filtering, searching, and drag-drop to parent slots
# Educational purpose: Organize created humans for breeding experiments

extends PanelContainer

# ============================================================================
# SIGNALS
# ============================================================================

signal human_selected_for_parent(human_id: int, slot: String)
signal human_card_clicked(human_id: int)
signal face_clicked(human_id: int)
signal generate_pressed()

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var search_input: LineEdit = $VBox/SearchBar/SearchInput
@onready var filter_dropdown: OptionButton = $VBox/SearchBar/FilterDropdown
@onready var card_container: VBoxContainer = $VBox/ScrollContainer/CardContainer
@onready var generate_button: Button = $VBox/GenerateButton
@onready var empty_label: Label = $VBox/ScrollContainer/EmptyLabel

# ============================================================================
# CONSTANTS
# ============================================================================

const HumanCardScene := preload("res://scenes/humans/HumanCard.tscn")

# ============================================================================
# STATE
# ============================================================================

var _filter_mode: String = "all"  # "all", "favorites", "generation_X"
var _search_text: String = ""

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_connections()
	_setup_filter_dropdown()
	refresh()


func _setup_connections() -> void:
	($VBox/ScrollContainer as ScrollContainer).follow_focus = true
	search_input.text_changed.connect(_on_search_changed)
	filter_dropdown.item_selected.connect(_on_filter_changed)
	generate_button.pressed.connect(_on_generate_pressed)
	
	HumanGeneticsState.human_added.connect(_on_human_added)
	HumanGeneticsState.human_deleted.connect(_on_human_deleted)
	HumanGeneticsState.human_updated.connect(_on_human_updated)
	HumanGeneticsState.library_loaded.connect(_on_library_loaded)


func _setup_filter_dropdown() -> void:
	filter_dropdown.clear()
	filter_dropdown.add_item("All Humans", 0)
	filter_dropdown.add_item("Favorites", 1)
	filter_dropdown.add_item("Generation P", 2)
	filter_dropdown.add_item("Generation F1", 3)
	filter_dropdown.add_item("Generation F2+", 4)


# ============================================================================
# REFRESH / DISPLAY
# ============================================================================

## Refresh the entire library display
func refresh() -> void:
	_clear_cards()
	
	var all_humans := HumanGeneticsState.get_all_humans()
	var filtered := _apply_filters(all_humans)
	
	if filtered.is_empty():
		empty_label.visible = true
		empty_label.text = _get_empty_message()
	else:
		empty_label.visible = false
		for human_data in filtered:
			_add_card(human_data)
	
	# Update generate button state
	generate_button.disabled = TeacherModeState.is_generation_locked()


## Clear all cards from container
func _clear_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()


## Add a card for a human
func _add_card(human_data: Dictionary) -> void:
	var card: Control = HumanCardScene.instantiate()
	card_container.add_child(card)
	card.setup(human_data)
	card.clicked.connect(_on_card_clicked)
	card.face_clicked.connect(_on_card_face_clicked)
	card.drag_started.connect(_on_card_drag_started)
	card.assign_requested.connect(_on_card_assign_requested)
	card.delete_requested.connect(_on_card_delete_requested)
	card.favorite_toggled.connect(_on_card_favorite_toggled)


## Apply current filters to human list
func _apply_filters(humans: Array) -> Array:
	var result: Array = []
	
	for human in humans:
		# Search filter
		if not _search_text.is_empty():
			var name_lower: String = human.get("name", "").to_lower()
			if _search_text.to_lower() not in name_lower:
				continue
		
		# Category filter
		match _filter_mode:
			"favorites":
				if not HumanGeneticsState.is_favorite(human.get("id", -1)):
					continue
			"generation_0":
				if human.get("generation", 0) != 0:
					continue
			"generation_1":
				if human.get("generation", 0) != 1:
					continue
			"generation_2+":
				if human.get("generation", 0) < 2:
					continue
		
		result.append(human)
	
	# Sort by ID (most recent first)
	result.sort_custom(func(a, b): return a.get("id", 0) > b.get("id", 0))
	
	return result


func _get_empty_message() -> String:
	if _filter_mode == "favorites":
		return "No favorites yet.\nClick the heart icon on a human to favorite them."
	elif not _search_text.is_empty():
		return "No humans match your search."
	else:
		return "No humans in library.\nClick '+ Generate' to create one!"


## Scroll to show a specific human
func scroll_to_human(human_id: int) -> void:
	# Wait for layout/refresh to settle, then find the card with this ID
	await get_tree().process_frame
	if not is_inside_tree():
		return
	
	var scroll_container := $VBox/ScrollContainer as ScrollContainer
	for card in card_container.get_children():
		if card.has_method("get_human_id") and card.get_human_id() == human_id:
			# Avoid stale references by resolving after the refresh frame.
			scroll_container.ensure_control_visible(card)
			if card.has_method("flash"):
				card.flash()
			break


# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_search_changed(new_text: String) -> void:
	_search_text = new_text
	refresh()


func _on_filter_changed(index: int) -> void:
	match index:
		0: _filter_mode = "all"
		1: _filter_mode = "favorites"
		2: _filter_mode = "generation_0"
		3: _filter_mode = "generation_1"
		4: _filter_mode = "generation_2+"
	refresh()


func _on_generate_pressed() -> void:
	generate_pressed.emit()
	if TeacherModeState.is_generation_locked():
		# Show feedback that generation is locked
		generate_button.modulate = Color.RED
		var tween := create_tween()
		tween.tween_property(generate_button, "modulate", Color.WHITE, 0.3)
		return
	
	var new_id := HumanGeneticsState.generate_random_human()
	scroll_to_human(new_id)


func _on_card_clicked(human_id: int) -> void:
	human_card_clicked.emit(human_id)


func _on_card_face_clicked(human_id: int) -> void:
	face_clicked.emit(human_id)


func _on_card_assign_requested(human_id: int, slot: String) -> void:
	human_selected_for_parent.emit(human_id, slot)


func _on_card_drag_started(human_id: int) -> void:
	# Visual feedback that drag started
	pass


func _on_card_delete_requested(human_id: int) -> void:
	HumanGeneticsState.delete_human(human_id)


func _on_card_favorite_toggled(human_id: int) -> void:
	HumanGeneticsState.toggle_favorite(human_id)
	if _filter_mode == "favorites":
		refresh()


func _on_human_added(_human_id: int) -> void:
	refresh()


func _on_human_deleted(_human_id: int) -> void:
	refresh()


func _on_human_updated(_human_id: int) -> void:
	refresh()


func _on_library_loaded() -> void:
	refresh()
