class_name HealthBars
extends Control
## Screen-space health bars above every unit (constant size, never hidden by
## terrain). Full-screen overlay that ignores the mouse.

const WIDTH_TROOP: float = 52.0
const WIDTH_HERO: float = 76.0
const HEIGHT: float = 8.0
const TEAM_STRIPE: float = 4.0
const BACK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.75)
const HIGH_COLOR: Color = Color(0.25, 0.9, 0.3)
const MID_COLOR: Color = Color(1.0, 0.8, 0.2)
const LOW_COLOR: Color = Color(1.0, 0.25, 0.2)
const DOWN_TEXT_COLOR: Color = Color(1.0, 0.9, 0.85)
const DOWN_FONT_SIZE: int = 16

var camera: Camera3D
## Shared with the mission scene (it removes dead units from this array).
var views: Array[UnitView] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


static func bar_color(fraction: float) -> Color:
	if fraction > 0.6:
		return HIGH_COLOR
	if fraction > 0.3:
		return MID_COLOR
	return LOW_COLOR


func _draw() -> void:
	if camera == null:
		return
	for view: UnitView in views:
		if not is_instance_valid(view) or view.unit.dead:
			continue
		var anchor: Vector3 = view.global_position + Vector3(0.0, view.bar_height(), 0.0)
		if camera.is_position_behind(anchor):
			continue
		var p: Vector2 = camera.unproject_position(anchor)
		var w: float = WIDTH_HERO if view.unit.stats.is_hero else WIDTH_TROOP
		var rect: Rect2 = Rect2(p.x - w * 0.5, p.y - HEIGHT, w, HEIGHT)
		draw_rect(rect.grow(1.5), BACK_COLOR)
		var fraction: float = view.unit.hp_fraction()
		draw_rect(Rect2(rect.position, Vector2(w * fraction, HEIGHT)), bar_color(fraction))
		draw_rect(Rect2(rect.position - Vector2(TEAM_STRIPE + 2.0, 0.0), Vector2(TEAM_STRIPE, HEIGHT)),
				UnitView.TEAM_COLORS[view.unit.team])
		if view.unit.downed:
			var font: Font = ThemeDB.fallback_font
			var text: String = "DOWN"
			var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, DOWN_FONT_SIZE)
			draw_string_outline(font, Vector2(p.x - size.x * 0.5, rect.position.y - 4.0), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, DOWN_FONT_SIZE, 4, Color.BLACK)
			draw_string(font, Vector2(p.x - size.x * 0.5, rect.position.y - 4.0), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, DOWN_FONT_SIZE, DOWN_TEXT_COLOR)
