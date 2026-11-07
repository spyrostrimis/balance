extends GdUnitTestSuite
## Proves the gdUnit4 runner works, and covers the App helpers.

const AppScript: GDScript = preload("res://view/app.gd")


func test_runner_works() -> void:
	assert_int(1 + 1).is_equal(2)


func test_fullscreen_toggle_mode() -> void:
	assert_int(AppScript.next_window_mode(Window.MODE_WINDOWED)).is_equal(Window.MODE_FULLSCREEN)
	assert_int(AppScript.next_window_mode(Window.MODE_MAXIMIZED)).is_equal(Window.MODE_FULLSCREEN)
	assert_int(AppScript.next_window_mode(Window.MODE_FULLSCREEN)).is_equal(Window.MODE_WINDOWED)
	assert_int(AppScript.next_window_mode(Window.MODE_EXCLUSIVE_FULLSCREEN)).is_equal(Window.MODE_WINDOWED)


func test_parse_user_args() -> void:
	var args: Dictionary = AppScript.parse_user_args(PackedStringArray(["--selftest", "--frames=60", "junk"]))
	assert_bool(args.has("selftest")).is_true()
	assert_str(str(args["frames"])).is_equal("60")
	assert_bool(args.has("junk")).is_false()
