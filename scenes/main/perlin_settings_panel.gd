extends Panel

signal seed_changed(value: int)
signal octaves_changed(value: int)

@onready var toggle_button: Button = get_node("ToggleButton")
@onready var sliders: VBoxContainer = get_node("Sliders")
@onready var seed_spin: SpinBox = get_node("Sliders/SeedRow/Seed")
@onready var octaves_slider: HSlider = get_node("Sliders/OctavesRow/Octaves")

var panel_style: StyleBoxFlat = null


func _ready() -> void:
	panel_style = get_theme_stylebox("panel") as StyleBoxFlat
	sliders.visible = false
	_update_panel_color(false)

	toggle_button.pressed.connect(_on_toggle_button_pressed)
	seed_spin.value_changed.connect(_on_seed_value_changed)
	octaves_slider.value_changed.connect(_on_octaves_value_changed)


func set_values(seed_value: int, octaves: int) -> void:
	seed_spin.value = seed_value
	octaves_slider.value = octaves


func _update_panel_color(is_open: bool) -> void:
	if panel_style == null:
		return

	if is_open:
		panel_style.bg_color = Color("#396751")
	else:
		panel_style.bg_color = Color("#00000000")


func _on_toggle_button_pressed() -> void:
	sliders.visible = not sliders.visible
	_update_panel_color(sliders.visible)

	if sliders.visible:
		toggle_button.text = "hide sliders"
	else:
		toggle_button.text = "show sliders"


func _on_seed_value_changed(value: float) -> void:
	seed_changed.emit(int(value))


func _on_octaves_value_changed(value: float) -> void:
	octaves_changed.emit(int(value))
