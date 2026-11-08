class_name TopBar
extends PanelContainer
## Top strip (Dune II style): Options button, mission name, mission clock, FPS.

signal options_pressed

var _clock: Label
var _fps: Label


func setup(mission_name: String) -> void:
	add_theme_stylebox_override("panel", HudTheme.frame(0))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	var options: Button = HudTheme.make_button("OPTIONS", "Pause, controls, restart, quit (F10)")
	options.custom_minimum_size = Vector2(170.0, 40.0)
	options.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	options.pressed.connect(func() -> void: options_pressed.emit())
	row.add_child(options)
	var title: Label = HudTheme.make_label(mission_name.to_upper(), 24, HudTheme.BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	_clock = HudTheme.make_label("00:00", 26, HudTheme.TEXT)
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_clock)
	_fps = HudTheme.make_label("", 16, HudTheme.TEXT_DIM)
	_fps.custom_minimum_size = Vector2(80.0, 0.0)
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_fps)


func set_time(seconds: int) -> void:
	_clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]


func set_fps(fps: int) -> void:
	_fps.text = "%d FPS" % fps
