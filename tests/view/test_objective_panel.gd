extends GdUnitTestSuite
## The objective panel's status line follows the capture objective's state.

const TPS: int = SimWorld.TICKS_PER_SECOND


func _objective() -> CaptureObjective:
	var grid: MapGrid = MapGrid.new()
	assert_str(grid.load_rows(PackedStringArray(["......", "..OO..", "..OO..", "......"]))).is_empty()
	var rules: ObjectiveRules = ObjectiveRules.new()
	rules.zone_radius = 1
	return CaptureObjective.new(grid, grid.deposits[0], rules)


func test_unclaimed() -> void:
	assert_str(ObjectivePanel.describe(_objective())["text"] as String).starts_with("Unclaimed")


func test_capturing_counts_down() -> void:
	var obj: CaptureObjective = _objective()
	obj.capture_team = SimUnit.Team.BLUE
	obj.capture_ticks = 4 * TPS
	var state: Dictionary = ObjectivePanel.describe(obj)
	assert_str(state["text"] as String).is_equal("Blue capturing: 6 s")
	assert_float(state["fraction"] as float).is_equal_approx(0.4, 0.001)


func test_holding_and_reset_by_enemy() -> void:
	var obj: CaptureObjective = _objective()
	obj.owner_team = SimUnit.Team.RED
	obj.hold_ticks = 15 * TPS
	assert_str(ObjectivePanel.describe(obj)["text"] as String).is_equal("Red holds the rock: 45 s left")
	obj.present[SimUnit.Team.BLUE] = 1
	assert_str(ObjectivePanel.describe(obj)["text"] as String).contains("hold reset")


func test_contested() -> void:
	var obj: CaptureObjective = _objective()
	obj.present[SimUnit.Team.BLUE] = 2
	obj.present[SimUnit.Team.RED] = 1
	assert_str(ObjectivePanel.describe(obj)["text"] as String).is_equal("Contested!")
