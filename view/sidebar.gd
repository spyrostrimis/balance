class_name Sidebar
extends PanelContainer
## Right-hand sidebar (Dune II style): objective, the hero panel (portrait, HP,
## abilities), what is selected, the command buttons and the minimap.

signal command_pressed(command: StringName)

const WIDTH: float = 400.0

var objective_panel: ObjectivePanel
var minimap: Minimap
var _selection: Label
var _prompt: Label
var _buttons: Dictionary[StringName, Button] = {}
var _hero_slot: VBoxContainer


func setup(world: SimWorld, camera: Camera3D) -> void:
	add_theme_stylebox_override("panel", HudTheme.frame(0))
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	if world.objective != null:
		objective_panel = ObjectivePanel.new()
		box.add_child(objective_panel)
		objective_panel.setup(world.objective)
		objective_panel.add_theme_stylebox_override("panel", HudTheme.well())
	_hero_slot = VBoxContainer.new()
	box.add_child(_hero_slot)
	_selection = HudTheme.make_label("", 20, HudTheme.TEXT_DIM)
	_selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection.custom_minimum_size = Vector2(120.0, 0.0)
	box.add_child(_selection)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for entry: Array in [
		[&"attack", "ATTACK", "Then left click an enemy unit"],
		[&"move", "MOVE", "Then left click the ground"],
		[&"retreat", "RETREAT", "Walk back to the start area without fighting (R)"],
		[&"guard", "GUARD", "Hold this spot: fire at enemies in range, don't chase (G)"],
	]:
		var id: StringName = entry[0] as StringName
		var b: Button = HudTheme.make_button(entry[1] as String, entry[2] as String)
		b.pressed.connect(func() -> void: command_pressed.emit(id))
		grid.add_child(b)
		_buttons[id] = b
	_prompt = HudTheme.make_label("", 18, Color(0.6, 1.0, 0.65))
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size = Vector2(120.0, 0.0)
	box.add_child(_prompt)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	var well: PanelContainer = PanelContainer.new()
	well.add_theme_stylebox_override("panel", HudTheme.well())
	box.add_child(well)
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(WIDTH - 40.0, WIDTH - 40.0)
	well.add_child(minimap)
	minimap.setup(world, camera)
	set_selection_text(0, "")


## Puts the hero panel into the sidebar.
func hold_hero_panel(panel: Control) -> void:
	if panel.get_parent() != null:
		panel.get_parent().remove_child(panel)
	_hero_slot.add_child(panel)


func set_selection_text(count: int, names: String) -> void:
	_selection.text = "Nothing selected" if count == 0 else "Selected: %d   %s" % [count, names]
	for b: Button in _buttons.values():
		b.disabled = count == 0


func set_prompt(text: String) -> void:
	_prompt.text = text
