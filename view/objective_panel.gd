class_name ObjectivePanel
extends PanelContainer
## Top-right HUD for the capture-and-hold objective: who owns the rock, capture
## or hold progress as a bar, and a time left.

const TEAM_NAMES: Dictionary[int, String] = {SimUnit.Team.BLUE: "Blue", SimUnit.Team.RED: "Red"}
const NEUTRAL_COLOR: Color = Color(0.75, 0.75, 0.8)
const CONTESTED_COLOR: Color = Color(1.0, 0.6, 0.15)
const BAR_SIZE: Vector2 = Vector2(360.0, 16.0)

var objective: CaptureObjective

var _title: Label
var _status: Label
var _bar: Control
var _fraction: float = 0.0
var _bar_color: Color = NEUTRAL_COLOR


func setup(capture: CaptureObjective) -> void:
	objective = capture
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.8)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10.0)
	add_theme_stylebox_override("panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = Label.new()
	_title.text = "The Rock"
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	box.add_child(_title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 20)
	box.add_child(_status)
	_bar = Control.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)


func _process(_delta: float) -> void:
	if objective == null:
		return
	var state: Dictionary = describe(objective)
	_status.text = state["text"] as String
	_status.add_theme_color_override("font_color", state["color"] as Color)
	_fraction = state["fraction"] as float
	_bar_color = state["color"] as Color
	_bar.queue_redraw()


## Status line, bar fill (0..1) and colour for the objective's current state.
static func describe(obj: CaptureObjective) -> Dictionary:
	var tps: float = float(SimWorld.TICKS_PER_SECOND)
	if obj.owner_team != CaptureObjective.NO_TEAM:
		var owner_name: String = TEAM_NAMES.get(obj.owner_team, "?")
		var color: Color = UnitView.TEAM_COLORS[obj.owner_team as SimUnit.Team].lightened(0.25)
		var enemy_in: bool = false
		for team: int in obj.present:
			if team != obj.owner_team and obj.present[team] > 0:
				enemy_in = true
		if enemy_in:
			return {"text": "%s owns the rock: enemy in the zone, hold reset!" % owner_name,
					"fraction": 0.0, "color": CONTESTED_COLOR}
		var left: int = ceili((obj.hold_ticks_needed() - obj.hold_ticks) / tps)
		return {"text": "%s holds the rock: %d s left" % [owner_name, left],
				"fraction": float(obj.hold_ticks) / obj.hold_ticks_needed(), "color": color}
	if obj.contested():
		return {"text": "Contested!", "fraction": float(obj.capture_ticks) / obj.capture_ticks_needed(),
				"color": CONTESTED_COLOR}
	if obj.capture_team != CaptureObjective.NO_TEAM:
		var left_c: int = ceili((obj.capture_ticks_needed() - obj.capture_ticks) / tps)
		return {"text": "%s capturing: %d s" % [TEAM_NAMES.get(obj.capture_team, "?"), left_c],
				"fraction": float(obj.capture_ticks) / obj.capture_ticks_needed(),
				"color": UnitView.TEAM_COLORS[obj.capture_team as SimUnit.Team].lightened(0.25)}
	return {"text": "Unclaimed: stand in the zone alone to capture", "fraction": 0.0, "color": NEUTRAL_COLOR}


func _draw_bar() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.7))
	_bar.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(_fraction, 0.0, 1.0), rect.size.y)), _bar_color)
	_bar.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.4), false, 1.0)
