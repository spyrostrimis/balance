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
	assert_str(text).contains("Own units within 5 cells (not the hero itself): +10% attack damage")
	var encouragement: AbilityStats = load("res://data/abilities/encouragement.tres") as AbilityStats
	assert_str(AbilityButton.tooltip_for(encouragement, "")).contains("+5% attack speed, +5% move speed")


func test_aura_icons_follow_the_modified_stats() -> void:
	var dominion: AbilityStats = load("res://data/abilities/dominion.tres") as AbilityStats
	var encouragement: AbilityStats = load("res://data/abilities/encouragement.tres") as AbilityStats
	var expected_dominion: Array[StringName] = [&"damage_bonus"]
	var expected_encouragement: Array[StringName] = [&"speed"]
	assert_array(AbilityButton.icon_kinds_for(dominion)).is_equal(expected_dominion)
	assert_array(AbilityButton.icon_kinds_for(encouragement)).is_equal(expected_encouragement)
