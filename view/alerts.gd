class_name Alerts
extends VBoxContainer
## Short messages near the top of the screen that fade out (hero down, recovery,
## low HP, ...). Ignores the mouse.

const SECONDS: float = 4.0
const FADE_SECONDS: float = 0.8
const MAX_LINES: int = 4

## Messages shown so far (the self-test logs them).
var history: PackedStringArray = PackedStringArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN


func show_alert(text: String, color: Color = Color.WHITE) -> void:
	history.append(text)
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	while get_child_count() > MAX_LINES:
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var tween: Tween = label.create_tween()
	tween.tween_interval(SECONDS - FADE_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(label.queue_free)
