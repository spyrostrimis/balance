extends GdUnitTestSuite
## The low-HP warning fires once when crossing below the threshold and re-arms
## only after the hero is healed back above it.


func test_fires_once_when_crossing_below() -> void:
	var warning: LowHpWarning = LowHpWarning.new(0.3)
	assert_bool(warning.update(1.0, true)).is_false()
	assert_bool(warning.update(0.31, true)).is_false()
	assert_bool(warning.update(0.29, true)).is_true()
	assert_bool(warning.active).is_true()
	assert_bool(warning.update(0.2, true)).is_false()  # no repeat while still low
	assert_bool(warning.update(0.1, true)).is_false()


func test_rearms_after_healing() -> void:
	var warning: LowHpWarning = LowHpWarning.new(0.3)
	assert_bool(warning.update(0.2, true)).is_true()
	assert_bool(warning.update(0.6, true)).is_false()  # repaired
	assert_bool(warning.active).is_false()
	assert_bool(warning.update(0.25, true)).is_true()


func test_quiet_when_hero_is_down() -> void:
	var warning: LowHpWarning = LowHpWarning.new(0.3)
	assert_bool(warning.update(0.0, false)).is_false()
	assert_bool(warning.active).is_false()


func test_warning_sound_is_built() -> void:
	var stream: AudioStreamWAV = Sounds.warning()
	assert_int(stream.data.size()).is_greater(1000)
	assert_float(stream.get_length()).is_between(0.5, 1.5)
