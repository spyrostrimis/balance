class_name EndScreen
extends Control
## Mission end overlay: Victory / Defeat, why, a few numbers, Restart / Quit.
## Dims the game and blocks clicks on it.

signal restart_pressed
signal quit_pressed

const VICTORY_COLOR: Color = Color(1.0, 0.82, 0.3)
const DEFEAT_COLOR: Color = Color(1.0, 0.3, 0.25)

var victory: bool = false


func setup(is_victory: bool, reason: String, details: PackedStringArray) -> void:
	victory = is_victory
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	box.add_child(_label("VICTORY" if victory else "MISSION FAILED", 72,
			VICTORY_COLOR if victory else DEFEAT_COLOR, 12))
	box.add_child(_label(reason, 30, Color.WHITE, 6))
	for line: String in details:
		box.add_child(_label(line, 22, Color(0.85, 0.85, 0.9), 4))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	buttons.add_child(_button("Restart", restart_pressed))
	buttons.add_child(_button("Quit", quit_pressed))


func _label(text: String, size: int, color: Color, outline: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", outline)
	return label


func _button(text: String, sig: Signal) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200.0, 60.0)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(func() -> void: sig.emit())
	return button
