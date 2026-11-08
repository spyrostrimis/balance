class_name PauseMenu
extends Control
## Options overlay: the game pauses while it is open. Resume, controls, restart, quit.

signal resume_pressed
signal restart_pressed
signal quit_pressed

const CONTROLS: String = """Pan: WASD / arrows / screen edges / middle-drag      Zoom: mouse wheel
Select: left click / drag a box (Shift adds)      Deselect: Esc
Move: right click the ground      Attack: right click an enemy
Sidebar: ATTACK / MOVE (then left click), RETREAT (R), GUARD (G)
Hero ability: Q or its button, then left click the target (Repair: the portrait = your Leader)
Minimap: left click / drag to look, right click to move the selection
Full screen: F11 / Alt+Enter (Esc leaves)      Options: F10"""


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HudTheme.frame())
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title: Label = HudTheme.make_label("OPTIONS", 40, HudTheme.BRASS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(HudTheme.make_label(CONTROLS, 20, HudTheme.TEXT))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	for entry: Array in [["RESUME", resume_pressed], ["RESTART", restart_pressed], ["QUIT", quit_pressed]]:
		var b: Button = HudTheme.make_button(entry[0] as String)
		var sig: Signal = entry[1] as Signal
		b.pressed.connect(func() -> void: sig.emit())
		buttons.add_child(b)
