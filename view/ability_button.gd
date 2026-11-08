class_name AbilityButton
extends Button
## One slot of the hero's ability bar: a placeholder icon, the hotkey, a cooldown
## wipe with seconds left, and a tooltip built from the ability data. Auras are
## shown as passive (not clickable); the tooltip is the only place the player
## learns what they do (they are invisible on the map).
## Read-only buttons (an enemy hero the player is looking at) only show the
## tooltip: no hotkey, no cooldown.

const SIZE: float = 88.0
const BACK_COLOR: Color = Color(0.08, 0.09, 0.12, 0.92)
const BORDER_COLOR: Color = Color(0.55, 0.58, 0.65)
const HOVER_BORDER_COLOR: Color = Color(1.0, 1.0, 1.0)
const ARMED_BORDER_COLOR: Color = Color(0.3, 1.0, 0.35)
const COOLDOWN_COLOR: Color = Color(0.0, 0.0, 0.0, 0.68)
const DISABLED_TINT: Color = Color(0.45, 0.45, 0.45)
const ICON_COLORS: Dictionary[StringName, Color] = {
	&"heal": Color(0.35, 0.95, 0.45),
	&"damage": Color(1.0, 0.55, 0.15),
	&"damage_bonus": Color(1.0, 0.35, 0.2),
	&"damage_reduction": Color(0.45, 0.75, 1.0),
	&"speed": Color(1.0, 0.85, 0.3),
}

var ability: AbilityStats
var hotkey: String = ""
var unit: SimUnit
var index: int = -1
var read_only: bool = false
## Drawn with a green border while the player is choosing its target.
var armed: bool = false:
	set(value):
		armed = value
		queue_redraw()


func setup(sim_unit: SimUnit, ability_index: int, key: String, is_read_only: bool = false) -> void:
	unit = sim_unit
	index = ability_index
	read_only = is_read_only
	ability = unit.ability(index)
	hotkey = key if ability.is_active() and not read_only else ""
	custom_minimum_size = Vector2(SIZE, SIZE)
	focus_mode = Control.FOCUS_NONE
	flat = true
	text = ""
	var clickable: bool = ability.is_active() and not read_only
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_PASS
	tooltip_text = tooltip_for(ability, hotkey)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()


## Name, hotkey, description and the numbers, straight from the data.
static func tooltip_for(stats: AbilityStats, key: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if stats.is_active():
		lines.append("%s  [%s]" % [stats.display_name, key] if key != "" else stats.display_name)
	else:
		lines.append("%s  (passive aura)" % stats.display_name)
	if stats.description != "":
		lines.append(stats.description)
	var facts: PackedStringArray = PackedStringArray()
	if stats.is_active():
		match stats.effect:
			AbilityStats.Effect.HEAL:
				facts.append("Heals %d HP" % roundi(stats.amount))
			AbilityStats.Effect.DAMAGE:
				facts.append("%d damage" % roundi(stats.amount))
				if stats.splash_radius > 0.0 and stats.splash_fraction > 0.0:
					facts.append("%d%% to enemies within %s cells" % [roundi(stats.splash_fraction * 100.0), _num(stats.splash_radius)])
		facts.append("Range %s cells" % _num(stats.cast_range))
		facts.append("Cooldown %s s" % _num(stats.cooldown))
		lines.append(" · ".join(facts))
	else:
		if stats.aura_damage_bonus > 0.0:
			facts.append("+%s%% attack damage" % _num(stats.aura_damage_bonus * 100.0))
		if stats.aura_damage_reduction > 0.0:
			facts.append("%s%% less damage taken" % _num(stats.aura_damage_reduction * 100.0))
		if stats.aura_attack_speed_bonus > 0.0:
			facts.append("+%s%% attack speed" % _num(stats.aura_attack_speed_bonus * 100.0))
		if stats.aura_move_speed_bonus > 0.0:
			facts.append("+%s%% move speed" % _num(stats.aura_move_speed_bonus * 100.0))
		var who: String = "Own units within %s cells" % _num(stats.aura_radius)
		if not stats.aura_affects_self:
			who += " (not the hero itself)"
		lines.append("%s: %s" % [who, ", ".join(facts)])
	return "\n".join(lines)


static func _num(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


## Icon kinds for an ability: its effect for actives, one per modified stat for auras.
static func icon_kinds_for(stats: AbilityStats) -> Array[StringName]:
	var kinds: Array[StringName] = []
	if stats.is_active():
		kinds.append(&"heal" if stats.effect == AbilityStats.Effect.HEAL else &"damage")
		return kinds
	if stats.aura_damage_bonus > 0.0:
		kinds.append(&"damage_bonus")
	if stats.aura_damage_reduction > 0.0:
		kinds.append(&"damage_reduction")
	if stats.aura_attack_speed_bonus > 0.0 or stats.aura_move_speed_bonus > 0.0:
		kinds.append(&"speed")
	return kinds


## Debug overlay: which aura effects are on a unit right now.
static func aura_icon_kinds_on_unit(sim_unit: SimUnit) -> Array[StringName]:
	var kinds: Array[StringName] = []
	if sim_unit.aura_damage_bonus > 0.0:
		kinds.append(&"damage_bonus")
	if sim_unit.aura_damage_reduction > 0.0:
		kinds.append(&"damage_reduction")
	if sim_unit.aura_attack_speed_bonus > 0.0 or sim_unit.aura_move_speed_bonus > 0.0:
		kinds.append(&"speed")
	return kinds


func _draw() -> void:
	if ability == null:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var usable: bool = unit != null and unit.can_act()
	var tint: Color = Color.WHITE if usable else DISABLED_TINT
	draw_rect(rect, BACK_COLOR)
	var kinds: Array[StringName] = icon_kinds_for(ability)
	if not kinds.is_empty():
		draw_icon(self, kinds[0], rect.get_center(), size.x * 0.3, ICON_COLORS[kinds[0]] * tint)
	var font: Font = get_theme_default_font()
	if hotkey != "":
		draw_string_outline(font, Vector2(6.0, 20.0), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.BLACK)
		draw_string(font, Vector2(6.0, 20.0), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE * tint)
	if not ability.is_active():
		var label: String = "PASSIVE"
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2((size.x - w) * 0.5, size.y - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(0.8, 0.8, 0.85) * tint)
	elif unit != null and not read_only:
		var fraction: float = unit.ability_cooldown_fraction(index, SimWorld.TICKS_PER_SECOND)
		if fraction > 0.0:
			# The dark part shrinks from the top as the ability recharges.
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * fraction)), COOLDOWN_COLOR)
			var seconds: String = str(ceili(unit.ability_cooldowns[index] / float(SimWorld.TICKS_PER_SECOND)))
			var sw: Vector2 = font.get_string_size(seconds, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
			var pos: Vector2 = Vector2((size.x - sw.x) * 0.5, size.y * 0.5 + 11.0)
			draw_string_outline(font, pos, seconds, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color.BLACK)
			draw_string(font, pos, seconds, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	var border: Color = BORDER_COLOR
	if armed:
		border = ARMED_BORDER_COLOR
	elif is_hovered() and ability.is_active() and usable and not read_only:
		border = HOVER_BORDER_COLOR
	draw_rect(rect, border, false, 3.0 if armed else 2.0)


## Placeholder icons: plus (heal), burst (damage), chevrons (damage bonus),
## shield (damage reduction), double arrow (speed).
static func draw_icon(canvas: CanvasItem, kind: StringName, c: Vector2, r: float, color: Color) -> void:
	match kind:
		&"heal":
			var t: float = r * 0.36
			canvas.draw_rect(Rect2(c.x - t, c.y - r, t * 2.0, r * 2.0), color)
			canvas.draw_rect(Rect2(c.x - r, c.y - t, r * 2.0, t * 2.0), color)
		&"damage":
			var points: PackedVector2Array = PackedVector2Array()
			for i: int in 16:
				var a: float = TAU * i / 16.0 - PI * 0.5
				var rr: float = r if i % 2 == 0 else r * 0.45
				points.append(c + Vector2(cos(a), sin(a)) * rr)
			canvas.draw_colored_polygon(points, color)
		&"damage_bonus":
			for k: int in 2:
				var y: float = c.y - r * 0.15 + k * r * 0.75
				canvas.draw_colored_polygon(PackedVector2Array([
					Vector2(c.x - r, y), Vector2(c.x, y - r * 0.8), Vector2(c.x + r, y),
					Vector2(c.x + r, y + r * 0.35), Vector2(c.x, y - r * 0.45), Vector2(c.x - r, y + r * 0.35)]), color)
		&"damage_reduction":
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - r * 0.85, c.y - r * 0.85), Vector2(c.x + r * 0.85, c.y - r * 0.85),
				Vector2(c.x + r * 0.85, c.y), Vector2(c.x, c.y + r), Vector2(c.x - r * 0.85, c.y)]), color)
		&"speed":
			for k: int in 2:
				var x: float = c.x - r * 0.6 + k * r * 0.75
				canvas.draw_colored_polygon(PackedVector2Array([
					Vector2(x, c.y - r), Vector2(x + r * 0.8, c.y), Vector2(x, c.y + r),
					Vector2(x - r * 0.35, c.y + r), Vector2(x + r * 0.45, c.y), Vector2(x - r * 0.35, c.y - r)]), color)
