class_name HeroPanel
extends PanelContainer
## Bottom-left HUD for a hero: a live 3D portrait (own little world), name and
## HP bar, and the ability bar (actives with hotkeys and cooldowns, then passive
## auras). Normally the player's hero; read-only for an enemy hero the player
## clicked on (tooltips only: that's how the player reads its passive).
##   Click the portrait: select the hero (double click: also centre the camera).
##   While targeting a friendly ability (e.g. Repair), clicking the portrait
##   targets the hero itself.

signal portrait_clicked(double_click: bool)
signal ability_pressed(index: int)

const PORTRAIT_SIZE: int = 150
const HP_BAR_HEIGHT: float = 18.0
const PANEL_COLOR: Color = Color(0.05, 0.06, 0.08, 0.82)
const HOTKEYS: PackedStringArray = ["Q", "W", "E", "R"]

var unit: SimUnit
var read_only: bool = false
var buttons: Array[AbilityButton] = []

var _portrait_model: UnitView
var _portrait_box: SubViewportContainer
var _name_label: Label
var _hp_bar: Control
var _time: float = 0.0
var _downed_shown: bool = false


## Builds (or rebuilds) the panel for `hero`. Active abilities get hotkeys
## Q, W, ... in order, unless read-only.
func setup(hero: SimUnit, is_read_only: bool = false) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	_portrait_model = null
	_downed_shown = false
	unit = hero
	read_only = is_read_only
	name = "HeroPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10.0)
	style.border_color = UnitView.TEAM_COLORS[hero.team].darkened(0.2)
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	_portrait_box = _build_portrait(hero)
	column.add_child(_portrait_box)
	_hp_bar = Control.new()
	_hp_bar.custom_minimum_size = Vector2(PORTRAIT_SIZE, HP_BAR_HEIGHT)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.draw.connect(_draw_hp_bar)
	column.add_child(_hp_bar)
	_name_label = Label.new()
	_name_label.text = hero.stats.display_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_name_label)

	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(bar)
	var next_key: int = 0
	for i: int in hero.stats.abilities.size():
		var ability: AbilityStats = hero.ability(i)
		if ability == null:
			continue
		var button: AbilityButton = AbilityButton.new()
		var key: String = ""
		if ability.is_active() and not read_only and next_key < HOTKEYS.size():
			key = HOTKEYS[next_key]
			next_key += 1
		button.setup(hero, i, key, read_only)
		if ability.is_active() and not read_only:
			button.pressed.connect(func() -> void: ability_pressed.emit(i))
		bar.add_child(button)
		buttons.append(button)


## Highlights the button whose target is being chosen (-1 = none).
func set_armed(index: int) -> void:
	for button: AbilityButton in buttons:
		button.armed = button.index == index


func _process(delta: float) -> void:
	if unit == null:
		return
	_time += delta
	if _portrait_model != null and unit.can_act():
		_portrait_model.rotation.y = PI + sin(_time * 0.7) * 0.3
	if unit.downed and not _downed_shown:
		_downed_shown = true
		_portrait_box.modulate = Color(0.55, 0.5, 0.5)
		_name_label.text = "%s — DOWN" % unit.stats.display_name
	_hp_bar.queue_redraw()


func _draw_hp_bar() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _hp_bar.size)
	_hp_bar.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.8))
	var fraction: float = unit.hp_fraction()
	_hp_bar.draw_rect(Rect2(rect.position, Vector2(rect.size.x * fraction, rect.size.y)), HealthBars.bar_color(fraction))
	var font: Font = _hp_bar.get_theme_default_font()
	var label: String = "%d / %d" % [unit.hp, unit.stats.max_hp]
	var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_hp_bar.draw_string_outline(font, Vector2((rect.size.x - w) * 0.5, rect.size.y - 2.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
	_hp_bar.draw_string(font, Vector2((rect.size.x - w) * 0.5, rect.size.y - 2.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _build_portrait(hero: SimUnit) -> SubViewportContainer:
	var box: SubViewportContainer = SubViewportContainer.new()
	box.name = "Portrait"
	box.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	if read_only:
		box.tooltip_text = "%s — double click: go to" % hero.stats.display_name
	else:
		box.tooltip_text = "%s — click: select, double click: go to" % hero.stats.display_name
	box.gui_input.connect(_on_portrait_input)
	var viewport: SubViewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(PORTRAIT_SIZE, PORTRAIT_SIZE)
	viewport.msaa_3d = Viewport.MSAA_4X
	box.add_child(viewport)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UnitView.TEAM_COLORS[hero.team].darkened(0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.9)
	env.ambient_light_energy = 0.6
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	light.light_energy = 1.2
	viewport.add_child(light)

	_portrait_model = UnitView.new()
	viewport.add_child(_portrait_model)
	_portrait_model.setup_display(hero.stats, hero.team)
	_portrait_model.rotation.y = PI  # face the camera (model forward is -Z)

	var cam: Camera3D = Camera3D.new()
	cam.fov = 30.0
	viewport.add_child(cam)
	var eye: Vector3 = Vector3(0.0, 2.1, 4.6)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, 1.5, 0.0) - eye, Vector3.UP), eye)
	return box


func _on_portrait_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		portrait_clicked.emit(mb.double_click)
		accept_event()
