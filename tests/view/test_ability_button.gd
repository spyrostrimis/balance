extends GdUnitTestSuite
## Ability tooltips are built from the ability data (numbers stay in sync).


func test_active_tooltip_lists_hotkey_and_numbers() -> void:
	var repair: AbilityStats = load("res://data/abilities/repair.tres") as AbilityStats
	var text: String = AbilityButton.tooltip_for(repair, "Q")
	assert_str(text).contains("Repair  [Q]")
	assert_str(text).contains("Heals 150 HP")
	assert_str(text).contains("Range 5 cells")
	assert_str(text).contains("Cooldown 20 s")


func test_cannon_tooltip_mentions_splash() -> void:
	var cannon: AbilityStats = load("res://data/abilities/heavy_cannon.tres") as AbilityStats
	var text: String = AbilityButton.tooltip_for(cannon, "Q")
	assert_str(text).contains("100 damage")
	assert_str(text).contains("50% to enemies within 1.5 cells")


func test_aura_tooltip_is_passive_with_radius() -> void:
	var dominion: AbilityStats = load("res://data/abilities/dominion.tres") as AbilityStats
	var text: String = AbilityButton.tooltip_for(dominion, "")
	assert_str(text).contains("(passive aura)")
	assert_str(text).contains("+10% attack damage")
	assert_str(text).contains("Radius 5 cells")
	var encouragement: AbilityStats = load("res://data/abilities/encouragement.tres") as AbilityStats
	assert_str(AbilityButton.tooltip_for(encouragement, "")).contains("take 15% less damage")
