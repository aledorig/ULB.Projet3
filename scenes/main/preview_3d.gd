extends TextureRect

@onready var vp3d = $"../../../../../VP3D"
var dragging_orbit := false
var dragging_pan := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if vp3d == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			vp3d.zoom_in()
			return

		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			vp3d.zoom_out()
			return

		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging_orbit = mb.pressed
			vp3d.set_orbit_dragging(dragging_orbit)
			return

		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			dragging_pan = mb.pressed
			vp3d.set_pan_dragging(dragging_pan)
			return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion

		if dragging_orbit:
			vp3d.orbit_by(motion.relative)
			return

		if dragging_pan:
			vp3d.pan_by(motion.relative)
