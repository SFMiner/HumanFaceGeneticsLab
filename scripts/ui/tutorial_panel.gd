extends PanelContainer

# ============================================================================
# SIGNALS
# ============================================================================

signal prompt_answered(skip: bool, remember: bool)
signal not_now_pressed()
signal close_pressed()

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var text_label: Label = $VBox/TextLabel
@onready var remember_check: CheckBox = $VBox/RememberCheck
@onready var yes_button: Button = $VBox/ButtonRow/YesButton
@onready var no_button: Button = $VBox/ButtonRow/NoButton
@onready var not_now_button: Button = $VBox/ButtonRow/NotNowButton
@onready var close_button: Button = $VBox/TopRow/CloseButton

# ============================================================================
# STATE
# ============================================================================

var _blink_tween: Tween

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_connections()
	_hide_optional_controls()


func _setup_connections() -> void:
	if yes_button:
		yes_button.pressed.connect(_on_yes_pressed)
	if no_button:
		no_button.pressed.connect(_on_no_pressed)
	if not_now_button:
		not_now_button.pressed.connect(_on_not_now_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)


func _hide_optional_controls() -> void:
	remember_check.visible = false
	not_now_button.visible = false
	close_button.visible = false


# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

func show_prompt(text: String, yes_label: String, no_label: String, remember_label: String) -> void:
	_set_text(text)
	remember_check.text = remember_label
	remember_check.visible = true
	yes_button.text = yes_label
	no_button.text = no_label
	yes_button.visible = true
	no_button.visible = true
	not_now_button.visible = false
	close_button.visible = false
	remember_check.button_pressed = false
	_refresh_size() 
	show()


func show_step(text: String, show_not_now: bool, show_close: bool) -> void:
	_set_text(text)
	remember_check.visible = false
	yes_button.visible = false
	no_button.visible = false
	not_now_button.visible = show_not_now
	close_button.visible = show_close
	_refresh_size() 
	show()


func _refresh_size() -> void:
	custom_minimum_size = Vector2.ZERO
	call_deferred("_apply_shrink")

func _apply_shrink() -> void:
	queue_sort()
	await get_tree().process_frame
	size = get_combined_minimum_size()

func start_blink(color_a: Color, color_b: Color, duration: float = 0.6) -> void:
	stop_blink()
	modulate = color_a
	_blink_tween = create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_property(self, "modulate", color_b, duration)
	_blink_tween.tween_property(self, "modulate", color_a, duration)


func stop_blink() -> void:
	if _blink_tween and _blink_tween.is_running():
		_blink_tween.kill()
	modulate = Color.WHITE


# ============================================================================
# HELPERS
# ============================================================================

func _set_text(text: String) -> void:
	if text_label:
		text_label.text = text


# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_yes_pressed() -> void:
	prompt_answered.emit(true, remember_check.button_pressed)


func _on_no_pressed() -> void:
	prompt_answered.emit(false, remember_check.button_pressed)


func _on_not_now_pressed() -> void:
	not_now_pressed.emit()


func _on_close_pressed() -> void:
	close_pressed.emit()
