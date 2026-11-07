extends Node
## Global app services (autoload "App"): full-screen toggle and the self-test mode.
##
## Self-test: `godot --path . -- --selftest --frames=120 [--shots=3]`
## Runs N frames, saves screenshots + a log to user://selftest/, prints the
## absolute path and quits. Exit code 0 = no engine errors logged, 1 = errors.

const SELFTEST_DIR: String = "user://selftest"
const DEFAULT_FRAMES: int = 120
const DEFAULT_SHOTS: int = 3
## Frames rendered between `selftest_shot` and the capture (lets shadows/cameras settle).
const SHOT_SETTLE_FRAMES: int = 3


## Captures engine errors/warnings so the self-test can report them.
class ErrorCatcher extends Logger:
	var _mutex: Mutex = Mutex.new()
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text: String = "%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function]
		_mutex.lock()
		if error_type == ERROR_TYPE_WARNING:
			warnings.append(text)
		else:
			errors.append(text)
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _catcher: ErrorCatcher = null


## Emitted before each self-test screenshot (1-based), so a scene can pose its
## camera. The shot is taken a few frames later.
signal selftest_shot(index: int, total: int)

## True while running in self-test mode.
var is_selftest: bool = false


func _ready() -> void:
	var args: Dictionary = parse_user_args(OS.get_cmdline_user_args())
	if args.has("selftest"):
		is_selftest = true
		_catcher = ErrorCatcher.new()
		OS.add_logger(_catcher)
		_run_selftest(int(args.get("frames", DEFAULT_FRAMES)), int(args.get("shots", DEFAULT_SHOTS)))


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var is_enter: bool = key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER
	if key.keycode == KEY_F11 or (is_enter and key.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and is_fullscreen(get_window().mode):
		# Esc only leaves full screen; when windowed it passes through to the game.
		get_window().mode = Window.MODE_WINDOWED
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var window: Window = get_window()
	window.mode = next_window_mode(window.mode)


static func is_fullscreen(mode: Window.Mode) -> bool:
	return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN


## Full screen ⇄ windowed. Any non-full-screen mode goes to full screen.
static func next_window_mode(mode: Window.Mode) -> Window.Mode:
	if is_fullscreen(mode):
		return Window.MODE_WINDOWED
	return Window.MODE_FULLSCREEN


## Parses `--key=value` and `--flag` user args (after `--`) into a Dictionary.
static func parse_user_args(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for arg: String in args:
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var eq: int = body.find("=")
		if eq == -1:
			result[body] = true
		else:
			result[body.substr(0, eq)] = body.substr(eq + 1)
	return result


func _run_selftest(frames: int, shots: int) -> void:
	frames = maxi(frames, 1)
	shots = clampi(shots, 0, frames)
	DirAccess.make_dir_recursive_absolute(SELFTEST_DIR)
	var abs_dir: String = ProjectSettings.globalize_path(SELFTEST_DIR)
	_clear_old_output(abs_dir)
	var log_lines: PackedStringArray = PackedStringArray()
	var headless: bool = DisplayServer.get_name() == "headless"
	log_lines.append("Balance self-test")
	log_lines.append("godot: %s" % Engine.get_version_info().string)
	log_lines.append("display server: %s, renderer: %s" % [DisplayServer.get_name(),
			RenderingServer.get_current_rendering_method()])
	log_lines.append("adapter: %s" % RenderingServer.get_video_adapter_name())
	log_lines.append("frames: %d, shots: %d" % [frames, shots])
	if headless:
		log_lines.append("WARNING: headless mode, screenshots are skipped (run without --headless)")

	# Shot frames, evenly spaced, the last one on the final frame.
	var shot_frames: Array[int] = []
	for i: int in range(1, shots + 1):
		shot_frames.append(int(round(float(frames) * float(i) / float(shots))))

	var shot_index: int = 0
	var start_usec: int = Time.get_ticks_usec()
	for frame: int in range(1, frames + 1):
		await get_tree().process_frame
		if frame in shot_frames:
			shot_index += 1
			selftest_shot.emit(shot_index, shots)
			if headless:
				continue
			for _settle: int in SHOT_SETTLE_FRAMES:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			var path: String = abs_dir.path_join("selftest_%d.png" % shot_index)
			var err: Error = image.save_png(path)
			log_lines.append("frame %d: %s (%dx%d) %s" % [frame, path.get_file(), image.get_width(),
					image.get_height(), "ok" if err == OK else "SAVE FAILED: %s" % error_string(err)])

	var window: Window = get_window()
	log_lines.append("window: %s, mode %d; viewport: %s" % [window.size, window.mode,
			get_viewport().get_visible_rect().size])
	var elapsed_sec: float = float(Time.get_ticks_usec() - start_usec) / 1_000_000.0
	log_lines.append("elapsed: %.2f s, avg fps: %.1f (includes screenshot stalls)" % [elapsed_sec,
			float(frames) / maxf(elapsed_sec, 0.001)])
	log_lines.append("errors: %d" % _catcher.errors.size())
	for e: String in _catcher.errors:
		log_lines.append("  ERROR: " + e)
	log_lines.append("warnings: %d" % _catcher.warnings.size())
	for w: String in _catcher.warnings:
		log_lines.append("  WARNING: " + w)

	var log_path: String = abs_dir.path_join("selftest.log")
	var file: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(log_lines) + "\n")
		file.close()
	print("\n".join(log_lines))
	print("SELFTEST OUTPUT: " + abs_dir)
	OS.remove_logger(_catcher)
	get_tree().quit(0 if _catcher.errors.is_empty() else 1)


func _clear_old_output(abs_dir: String) -> void:
	for file_name: String in DirAccess.get_files_at(abs_dir):
		if file_name.begins_with("selftest_") and file_name.ends_with(".png"):
			DirAccess.remove_absolute(abs_dir.path_join(file_name))
