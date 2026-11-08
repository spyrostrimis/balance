class_name HudTheme
extends RefCounted
## Dune II-inspired HUD styling, modernised: dark blue-steel panels with a brass
## trim and an accent in the player's team colour. One place for HUD colours.

const PANEL: Color = Color(0.09, 0.11, 0.15, 0.94)
const PANEL_INNER: Color = Color(0.05, 0.06, 0.09, 0.9)
const BRASS: Color = Color(0.83, 0.64, 0.3)
const BRASS_DARK: Color = Color(0.45, 0.33, 0.14)
const TEXT: Color = Color(0.93, 0.9, 0.82)
const TEXT_DIM: Color = Color(0.68, 0.65, 0.58)
const BUTTON: Color = Color(0.17, 0.2, 0.26)
const BUTTON_HOVER: Color = Color(0.24, 0.28, 0.35)
const BUTTON_PRESSED: Color = Color(0.12, 0.14, 0.18)

## Player's team colour (accents).
static var accent: Color = Color(0.92, 0.14, 0.1)


## The outer frame: steel with a brass border and a team-coloured inner line.
static func frame(radius: int = 6) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = BRASS
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10.0)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	s.shadow_size = 6
	return s


## An inset well inside the frame (portrait, minimap, objective).
static func well() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = PANEL_INNER
	s.border_color = accent.darkened(0.35)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6.0)
	return s


static func button_style(color: Color, border: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	return s


## A chunky command button (ATTACK, MOVE, ...).
static func make_button(text: String, tooltip: String = "") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, 52.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", BRASS)
	b.add_theme_stylebox_override("normal", button_style(BUTTON, BRASS_DARK))
	b.add_theme_stylebox_override("hover", button_style(BUTTON_HOVER, BRASS))
	b.add_theme_stylebox_override("pressed", button_style(BUTTON_PRESSED, accent))
	b.add_theme_stylebox_override("disabled", button_style(BUTTON_PRESSED, BRASS_DARK.darkened(0.4)))
	return b


static func make_label(text: String, size: int, color: Color = TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
