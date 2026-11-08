class_name StartScreen
extends Control
## Mission start overlay: title, briefing and objectives. The game waits until
## the player presses Start (or Enter / Space).

signal start_pressed

const TITLE_COLOR: Color = Color(1.0, 0.82, 0.3)


func setup(title: String, briefing: String, objectives: PackedStringArray) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(1000.0, 0.0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	box.add_child(_label(title, 60, TITLE_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	var text: Label = _label(briefing, 24, Color(0.9, 0.9, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	box.add_child(_label("Objectives", 30, TITLE_COLOR, HORIZONTAL_ALIGNMENT_LEFT))
	for line: String in objectives:
		var item: Label = _label("•  " + line, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(item)
	var button: Button = Button.new()
	button.text = "Start"
	button.custom_minimum_size = Vector2(240.0, 64.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 30)
	button.pressed.connect(func() -> void: start_pressed.emit())
	box.add_child(button)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo \
			and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		start_pressed.emit()


func _label(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label
