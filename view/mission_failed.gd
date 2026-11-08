class_name MissionFailedScreen
extends Control
## Simple "Mission failed" overlay (the real end screens come in milestone 7):
## dims the game, says why, and offers Restart / Quit.

signal restart_pressed
signal quit_pressed


func setup(reason: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title: Label = Label.new()
	title.text = "MISSION FAILED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)
	var why: Label = Label.new()
	why.text = reason
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.add_theme_font_size_override("font_size", 30)
	box.add_child(why)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	for entry: Array in [["Restart", restart_pressed], ["Quit", quit_pressed]]:
		var button: Button = Button.new()
		button.text = entry[0] as String
		button.custom_minimum_size = Vector2(200.0, 60.0)
		button.add_theme_font_size_override("font_size", 28)
		var sig: Signal = entry[1] as Signal
		button.pressed.connect(func() -> void: sig.emit())
		buttons.add_child(button)
