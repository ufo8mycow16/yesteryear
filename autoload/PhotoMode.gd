extends Node
## PhotoMode — press F12 to pause the game, hide the interface and fly a free
## camera around the scene; ENTER or a click saves a picture.
##
##   WASD / left stick   move          Q / E   down / up       SHIFT   faster
##   hold RIGHT mouse (or right stick)   look     mouse wheel   zoom (field of view)
##   ENTER / LEFT click  take the picture            F12 / ESC   leave photo mode
##
## Pictures are saved as PNG files in the game's user folder, under screenshots/
## (the path is shown on screen after each shot).
##
## REV 118 - STILLS: in photo mode, press C to make a high-quality still for the end credits,
## loading screens or promotion: the shot is drawn at 3840 x 2160 (4K) without any interface and
## saved into assets/credits/ (when run from the Godot editor; from an exported game it goes to
## screenshots/). The camera position is also written to assets/credits/stills.cfg, so every still
## can be re-rendered later (better models, new lighting) with tools/render_stills.gd.

const SAVE_DIR := "user://screenshots/"
const STILLS_DIR := "res://assets/credits/"
const STILLS_LIST := "res://assets/credits/stills.cfg"
const STILL_SIZE := Vector2i(3840, 2160)
const MOVE_SPEED := 3.0
const FAST_MULTIPLIER := 3.5
const LOOK_SENSITIVITY := 0.0035
const PAD_LOOK_SPEED := 2.2

var active: bool = false

var _cam: Camera3D
var _old_cam: Camera3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _overlay: CanvasLayer
var _hint: Label
var _flash: ColorRect
var _saved_label: Label
var _hidden: Array = []        # [{"node": CanvasItem|CanvasLayer, "was": bool}]
var _saving: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 120
	_overlay.visible = false
	add_child(_overlay)

	_hint = Label.new()
	_hint.text = "PHOTO MODE      WASD MOVE   Q / E DOWN / UP   SHIFT FAST   HOLD RIGHT MOUSE TO LOOK   WHEEL ZOOM      ENTER / CLICK  TAKE PICTURE      C  4K STILL      F12 / ESC  LEAVE"
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -40
	_hint.offset_left = 20
	_overlay.add_child(_hint)

	_saved_label = Label.new()
	_saved_label.add_theme_font_size_override("font_size", 13)
	_saved_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.8))
	_saved_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_saved_label.add_theme_constant_override("outline_size", 6)
	_saved_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_saved_label.offset_top = 16
	_saved_label.offset_left = 20
	_overlay.add_child(_saved_label)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_flash)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		if event.is_action_pressed("photo_mode") and _can_start():
			_enter()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("photo_mode") or event.is_action_pressed("menu_cancel"):
		_leave()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		_take_picture()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_take_still()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_take_picture()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.fov = clampf(_cam.fov - 3.0, 15.0, 100.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.fov = clampf(_cam.fov + 3.0, 15.0, 100.0)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		_yaw -= event.relative.x * LOOK_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY, -1.5, 1.5)
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		_take_picture()
	else:
		return
	get_viewport().set_input_as_handled()


func _can_start() -> bool:
	if get_viewport().get_camera_3d() == null:
		return false     # title screens and other 2D scenes
	if InteractionManager.is_locked() or InteractionManager.is_modal_suspended():
		return false     # cutscene or a menu is open
	if AudioSubtitleManager.is_line_active():
		return false     # pausing mid-line would leave the voice and subtitle out of step
	return true


func _enter() -> void:
	_old_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	get_tree().current_scene.add_child(_cam)
	_cam.global_transform = _old_cam.global_transform
	_cam.fov = _old_cam.fov
	_cam.near = _old_cam.near
	_cam.far = _old_cam.far
	_cam.process_mode = Node.PROCESS_MODE_ALWAYS
	_cam.make_current()
	var euler := _cam.global_transform.basis.get_euler()
	_yaw = euler.y
	_pitch = euler.x
	_hide_interface()
	_saved_label.text = ""
	_overlay.visible = true
	active = true
	get_tree().paused = true
	SfxManager.ui("open")


func _leave() -> void:
	active = false
	get_tree().paused = false
	_overlay.visible = false
	_show_interface()
	if is_instance_valid(_old_cam):
		_old_cam.make_current()
	if is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	SfxManager.ui("close")


func _hide_interface() -> void:
	_hidden.clear()
	_collect_interface(get_tree().root)
	for entry in _hidden:
		entry["node"].visible = false


## Everything that draws the interface: the HUD, any CanvasLayer (subtitles, menus)
## except photo mode's own, and the hotspot twinkles.
func _collect_interface(node: Node) -> void:
	for child in node.get_children():
		if child == _overlay:
			continue
		if child is CanvasLayer or child is HotspotHalo or _is_hud(child):
			_hidden.append({"node": child, "was": child.visible})
		_collect_interface(child)


func _is_hud(node: Node) -> bool:
	var script: Script = node.get_script()
	return script != null and String(script.resource_path).ends_with("/HUD.gd")


func _show_interface() -> void:
	for entry in _hidden:
		if is_instance_valid(entry["node"]):
			entry["node"].visible = bool(entry["was"])
	_hidden.clear()


func _process(delta: float) -> void:
	if not active or not is_instance_valid(_cam):
		return
	_yaw -= Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) * PAD_LOOK_SPEED * delta if absf(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)) > 0.2 else 0.0
	_pitch = clampf(_pitch - (Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y) * PAD_LOOK_SPEED * delta if absf(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)) > 0.2 else 0.0), -1.5, 1.5)
	_cam.global_transform.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))

	var move := Vector3(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("camera_orbit_left", "camera_orbit_right"),
		Input.get_axis("move_forward", "move_back"))
	var speed := MOVE_SPEED * (FAST_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var b := _cam.global_transform.basis
	var world_move := b.x * move.x + Vector3.UP * move.y + b.z * move.z
	_cam.global_position += world_move * speed * delta


func _take_picture() -> void:
	if _saving:
		return
	_saving = true
	_hint.visible = false
	_saved_label.visible = false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_hint.visible = true
	_saved_label.visible = true

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var t := Time.get_datetime_dict_from_system()
	var file_name := "VulcanFury_%04d%02d%02d_%02d%02d%02d.png" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	var path := SAVE_DIR + file_name
	var err := image.save_png(path)
	if err == OK:
		_saved_label.text = "SAVED: " + ProjectSettings.globalize_path(path)
	else:
		_saved_label.text = "COULD NOT SAVE THE PICTURE (error %d)" % err
	SfxManager.play("shutter", -2.0)
	_flash.color = Color(1, 1, 1, 0.8)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.35)
	await tween.finished
	_saving = false


# ---- stills (REV 118) ------------------------------------------------------------------------

func _take_still() -> void:
	if _saving or not is_instance_valid(_cam):
		return
	_saving = true
	_saved_label.text = "RENDERING 4K STILL..."
	var in_editor := OS.has_feature("editor")
	var dir := STILLS_DIR if in_editor else SAVE_DIR
	DirAccess.make_dir_recursive_absolute(dir)
	var scene := get_tree().current_scene
	var stem := scene.scene_file_path.get_file().get_basename().to_lower() if scene != null else "still"
	var path := dir + "%02d_%s.png" % [_next_still_number(dir), stem]
	var err := await render_still(get_viewport(), _cam.global_transform, _cam.fov, path, STILL_SIZE)
	if err == OK and in_editor:
		_remember_still(scene.scene_file_path if scene != null else "", _cam.global_transform, _cam.fov, path.get_file())
	_saved_label.text = ("STILL SAVED: " + ProjectSettings.globalize_path(path)) if err == OK else "COULD NOT SAVE THE STILL (error %d)" % err
	SfxManager.play("shutter", -2.0)
	_saving = false


## Draw the 3D world from a camera into an off-screen picture of any size - no interface, no
## hotspot twinkles (they're hidden by photo mode / the stills tool) - and save it as PNG.
static func render_still(vp: Viewport, xf: Transform3D, fov: float, path: String, size: Vector2i) -> int:
	var sv := SubViewport.new()
	sv.size = size
	sv.world_3d = vp.world_3d
	sv.msaa_3d = Viewport.MSAA_4X
	sv.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	var src := vp.get_camera_3d()
	if src != null:
		cam.near = src.near
		cam.far = src.far
		cam.attributes = src.attributes
	cam.fov = fov
	sv.add_child(cam)
	vp.add_child(sv)
	cam.global_transform = xf
	cam.make_current()
	for _i in 3:
		await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	sv.queue_free()
	if img == null or img.is_empty():
		return ERR_CANT_CREATE
	return img.save_png(path)


func _next_still_number(dir: String) -> int:
	var n := 1
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			var num := String(f).get_slice("_", 0)
			if num.is_valid_int():
				n = maxi(n, num.to_int() + 1)
	return n


## stills.cfg: one section per still - scene, camera transform, field of view, file name.
func _remember_still(scene_path: String, xf: Transform3D, fov: float, file_name: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(STILLS_LIST)
	cfg.set_value(file_name, "scene", scene_path)
	cfg.set_value(file_name, "transform", xf)
	cfg.set_value(file_name, "fov", fov)
	cfg.save(STILLS_LIST)

