extends Node
# (Code from "Four Games" on ytb)

@onready var sounds := {
	&"ui_hover": AudioStreamPlayer.new(),
	&"ui_click": AudioStreamPlayer.new(),
}

func _ready() -> void:
	for key in sounds.keys():
		sounds[key].stream = load("res://assets/ui/sounds/%s.mp3" % String(key))
		sounds[key].bus = "Sfx"
		add_child(sounds[key])

func install_sounds(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			child.mouse_entered.connect(ui_sfx_play.bind(&"ui_hover"))
			child.button_down.connect(ui_sfx_play.bind(&"ui_click"))
		elif child is OptionButton:
			child.mouse_entered.connect(ui_sfx_play.bind(&"ui_hover"))
			child.button_down.connect(ui_sfx_play.bind(&"ui_click"))
		elif child is TextureButton:
			child.mouse_entered.connect(ui_sfx_play.bind(&"ui_hover"))
			child.button_down.connect(ui_sfx_play.bind(&"ui_click"))
		elif child is TabContainer:
			child.tab_hovered.connect(ui_sfx_play.bind(&"ui_hover"))
			child.tab_clicked.connect(ui_sfx_play.bind(&"ui_click"))

		install_sounds(child)

func ui_sfx_play(sound: StringName) -> void:
	sounds[sound].play()
