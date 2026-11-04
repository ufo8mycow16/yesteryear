extends Control
class_name TricorderPanel
## REV 593 (Episode 3, EPISODE3_SCRIPT.md 3.08 / 3.22 / 3.34): THE TRICORDER CLOSE-UP - the TOS tricorder
## face itself, as a hands-on puzzle screen. Glen (27 Oct): "blur the background out, show an animation of
## the top flipping open, and then put it right in the player's face. Render the mini puzzle on the
## screen... put little four-way arrows around each of those knobs."
##
## What the player sees: the game behind goes soft and dark; the REV 590 close-up tricorder
## (tricorder_tos_closeup.glb) rises into view with its hood shut, the hood flips open, and the camera
## pushes in on the face: the screen on the left (the puzzle is drawn ON it, a live picture on a glass
## quad laid over the kit's own screen), the grille, the three blue jewels and the three polished knobs.
## The knobs are the controls (Glen's idea), each marked on screen:
##   LEFT knob   four arrows round it - moves the cursor on the screen (d-pad / either stick / arrow keys /
##               WASD; the mouse clicks an arrow)
##   MIDDLE knob green ring - A / ENTER        (the puzzle names it: BRIDGE, READ ...)
##   RIGHT knob  red ring   - B / BACKSPACE    (BREAK, CUT, CLEAR ...)
##   the JEWELS  amber      - X / L            (LISTEN)
##   Y / ESC puts it away (if the puzzle allows - nothing is ever lost by putting it away).
## Works pad-only (Nikki), keyboard only, or mouse only.
##
## The ROOM drives the puzzle (like InstrumentPanel's pick mode): it opens the panel with a draw Callable
## and loops on `var e: Array = await panel.event` - e = ["move", Vector2i] / ["a"] / ["b"] / ["x"] /
## ["leave"]. While the room is talking (say) it sets `busy = true`; input is ignored until it's false.
## After changing its state the room calls refresh(). Finally `await panel.close()`.
##
## cfg:
##   draw      Callable(ctl: Control, rect: Rect2) - draws the screen picture (512 x 410) with ctl.draw_*
##   labels    {"a": "BRIDGE", "b": "BREAK", "x": "LISTEN"} - words beside the knobs ("" hides one)
##   can_leave true (default)
##   title     tiny caption along the top of the screen (optional)
##   mode      "cursor" (default, as above) or "knobs" (REV 638, the 3.08 signal match): the three knobs are the
##             controls themselves. Left/right (d-pad, stick, arrow keys) picks a knob - it rings amber; up/down
##             TURNS it (hold to keep turning). Mouse: click the little turn arrows under a knob, or hover it and
##             scroll. Events: ["select", i] / ["turn", i, +1|-1] / ["leave"] / ["tick"] (every `tick` seconds).
##             The room sets knob_angle[i] (radians, the pointer drawn on each knob), knob_done[i] (green ring,
##             no more turning) and knob_icon[i] ("height" / "spacing" / "slide" - the little picture above it).
##   tick      seconds between ["tick"] events while open and idle (0 = none) - for hints when nobody touches it

signal event(e: Array)

const MODEL := "res://assets/models/props/tricorder_tos/tricorder_tos_closeup.glb"
const SCREEN_W := 512
const SCREEN_H := 410
const LAYER := 33     # above a room's black fade (30), under the subtitles (34) and the dialogue UI (35)

## Positions on the hood, in the hood's own metres (open: +Z = out of the face, +Y = up). From the model:
## the screen glass x -47.1..9.6 mm, y -19.6..25.7 mm, its dome peak at z 22.0 mm; the three knobs
## (tools/props/tricorder/assemble.py knob_holes) at x 16.7 / 29.0 / 40.9 mm, y -15 mm; the jewels above
## them at y -5 mm.
const SCREEN_CENTRE := Vector3(-0.01875, 0.00305, 0.0223)
const SCREEN_SIZE := Vector2(0.0545, 0.0430)
const KNOBS := [Vector3(0.0167, -0.0150, 0.0215), Vector3(0.0290, -0.0150, 0.0215), Vector3(0.0409, -0.0150, 0.0215)]
const JEWELS := Vector3(0.0290, -0.0050, 0.0225)
const HOOD_CLOSED := 90.0      # HoodPivot rotation.x (how the model loads)
const HOOD_OPEN := 0.0

## Colours on the screen (dark green glass, bright phosphor lines).
const SCR_BG := Color(0.015, 0.05, 0.03)
const SCR_LINE := Color(0.45, 1.0, 0.55)
const SCR_DIM := Color(0.20, 0.50, 0.28)
const SCR_HOT := Color(1.0, 0.78, 0.30)
const SCR_ALARM := Color(1.0, 0.30, 0.25)
const GREEN := Color(0.35, 0.95, 0.45)
const RED := Color(1.0, 0.35, 0.30)
const AMBER := Color(1.0, 0.75, 0.25)

var cfg: Dictionary = {}
var busy := false
var _closing := false
var _ready_for_input := false
var _blur: ColorRect
var _vpc: SubViewportContainer
var _vp: SubViewport
var _cam: Camera3D
var _rig: Node3D            # the tricorder (moved / turned for the entrance)
var _hood: Node3D           # HoodPivot
var _hood_mesh: Node3D      # Hood (the screen quad is its child)
var _screen_vp: SubViewport
var _screen_draw: Control
var _overlay: Control
var _font: Font
var _hot := ""              # what the mouse is over: "up"/"down"/"left"/"right"/"a"/"b"/"x"
var _flash := {}            # control -> seconds left of its press flash
var _cam_far := Transform3D()
var _cam_near := Transform3D()
# REV 638: knob mode
var knob_sel := 0
var knob_angle: Array = [0.0, 0.0, 0.0]
var knob_done: Array = [false, false, false]
var knob_icon: Array = ["", "", ""]
var _hold_dir := 0           # up/down held in knob mode: +1 / -1 (turns repeat while held)
var _hold_t := 0.0
var _tick_t := 0.0
const HOLD_DELAY := 0.32
const HOLD_EVERY := 0.07


func knobs_mode() -> bool:
	return String(cfg.get("mode", "cursor")) == "knobs"


## Opens the close-up on a CanvasLayer of its own under `host` (the room). Await `opened` is not needed -
## input starts once the hood is open.
static func open(host: Node, c: Dictionary) -> TricorderPanel:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	layer.name = "TricorderCloseUp"
	host.add_child(layer)
	var p := TricorderPanel.new()
	p.cfg = c
	layer.add_child(p)
	return p


func pad_menu_active() -> bool:
	return not _closing


func _ready() -> void:
	add_to_group(PadNav.MENU_GROUP)
	# REV 634: a Control straight under a CanvasLayer got no size from its anchors (Glen: the close-up never showed,
	# but it took the keys) - it is sized to the screen here and kept so in _process.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_screen()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = UITheme.font_bold if UITheme.font_bold != null else ThemeDB.fallback_font
	_build_blur()
	_build_world()
	_build_overlay()
	_enter()


# ---- the blurred game behind ---------------------------------------------------------------------

func _build_blur() -> void:
	_blur = ColorRect.new()
	_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * (2.0 + 10.0 * amount);
	vec3 c = vec3(0.0);
	float w = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float k = exp(-float(x * x + y * y) / 8.0);
			c += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px, 2.0 * amount).rgb * k;
			w += k;
		}
	}
	c /= w;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(l), 0.35 * amount) * (1.0 - 0.55 * amount);
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - amount * 0.6 * dot(d, d) * 2.0;
	COLOR = vec4(c, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_blur.material = m
	add_child(_blur)


func _set_blur(v: float) -> void:
	(_blur.material as ShaderMaterial).set_shader_parameter("amount", v)


# ---- the tricorder in its own little world --------------------------------------------------------

func _build_world() -> void:
	_vpc = SubViewportContainer.new()
	_vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vpc.stretch = true
	_vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vpc)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(get_viewport_rect().size)
	_vpc.add_child(_vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.55, 0.60, 0.70)
	sm.sky_horizon_color = Color(0.75, 0.72, 0.68)
	sm.ground_bottom_color = Color(0.12, 0.11, 0.10)
	sm.ground_horizon_color = Color(0.45, 0.42, 0.40)
	sm.energy_multiplier = 0.72      # REV 741 (Glen: "could be a tad darker") - the silver face mirrors the sky
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.30     # REV 637 (Glen: "a bit bright"): was 0.55; REV 741 ("a tad darker"): 0.38
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	key.light_energy = 0.82           # REV 637: was 1.35; REV 741: 1.0
	key.light_color = Color(1.0, 0.96, 0.90)
	_vp.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.18, 0.20, 0.28)
	fill.omni_range = 1.0
	fill.light_energy = 0.30          # REV 637: was 0.55; REV 741: 0.4
	fill.light_color = Color(0.80, 0.88, 1.0)
	_vp.add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.10, 0.32, -0.12)
	rim.omni_range = 0.8
	rim.light_energy = 0.5            # REV 741: was 0.7
	_vp.add_child(rim)

	_rig = Node3D.new()
	_vp.add_child(_rig)
	var scene: PackedScene = load(MODEL) if ResourceLoader.exists(MODEL) else null
	var model: Node3D = scene.instantiate() as Node3D if scene != null else null
	if model == null:
		model = _stand_in_model()
	_rig.add_child(model)
	_hood = model.find_child("HoodPivot", true, false) as Node3D
	_hood_mesh = model.find_child("Hood", true, false) as Node3D
	if _hood != null:
		_hood.rotation_degrees.x = HOOD_CLOSED
	_build_screen()

	_cam = Camera3D.new()
	_cam.fov = 28.0
	_cam.near = 0.005
	_cam.far = 5.0
	_vp.add_child(_cam)
	# the hood face, open: centre about (0, 0.1665) in the tricorder's metres, the face at z ~0.02
	# REV 636 (Glen: "perfectly centered"): the model measures dead centre left-right (body and hood x -0.068..+0.068),
	# so the camera looks at x 0 - it was 6 mm to the right, which put the tricorder left of centre
	var face := Vector3(0.0, 0.1650, 0.020)
	# REV 635 (Glen's picture: the tricorder ran off both sides of a 16:10 screen): 0.138 -> 0.17 back from the face;
	# REV 636 (Glen: "zoom out just a little"): 0.19
	_cam_near = Transform3D(Basis(), face + Vector3(0.0, 0.0, 0.19))
	_cam_far = Transform3D(Basis().rotated(Vector3.RIGHT, deg_to_rad(-6.0)), Vector3(0.0, 0.135, 0.42))
	_cam.transform = _cam_far
	_cam.current = true


## Without the model (an unimported project): a plain box with a hood, so the puzzle still works.
func _stand_in_model() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.136, 0.165, 0.056)
	body.mesh = bm
	body.position = Vector3(0.0, 0.0825, 0.0)
	root.add_child(body)
	var pivot := Node3D.new()
	pivot.name = "HoodPivot"
	pivot.position = Vector3(0.0, 0.1635, -0.00225)
	root.add_child(pivot)
	var hood := MeshInstance3D.new()
	hood.name = "Hood"
	var hm := BoxMesh.new()
	hm.size = Vector3(0.112, 0.054, 0.036)
	hood.mesh = hm
	hood.position = Vector3(0.0, 0.003, 0.002)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.06)
	hood.material_override = mat
	body.material_override = mat
	pivot.add_child(hood)
	return root


## The live screen: a 512 x 410 picture (the room draws it) on a glass quad laid over the kit's screen,
## a hair proud of its dome, with a little CRT glow and rounded corners.
func _build_screen() -> void:
	_screen_vp = SubViewport.new()
	_screen_vp.size = Vector2i(SCREEN_W, SCREEN_H)
	_screen_vp.transparent_bg = false
	_screen_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_screen_vp.disable_3d = true
	add_child(_screen_vp)
	_screen_draw = _ScreenDraw.new()
	(_screen_draw as _ScreenDraw).panel = self
	_screen_draw.size = Vector2(SCREEN_W, SCREEN_H)
	_screen_vp.add_child(_screen_draw)

	var quad := MeshInstance3D.new()
	quad.name = "LiveScreen"
	var qm := QuadMesh.new()
	qm.size = SCREEN_SIZE
	quad.mesh = qm
	quad.position = SCREEN_CENTRE
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
uniform sampler2D screen_tex : source_color, filter_linear;
uniform float glow = 1.15;
void fragment() {
	vec2 uv = UV;
	float r = 0.07;
	vec2 q = abs(uv - 0.5) - vec2(0.5 - r);
	float dist = length(max(q, vec2(0.0))) - r;
	float corner = 1.0 - smoothstep(-0.012, 0.0, dist);
	vec3 c = texture(screen_tex, uv).rgb;
	float scan = 0.94 + 0.06 * sin(uv.y * 410.0 * 3.14159);
	float vig = 1.0 - 0.35 * dot(uv - 0.5, uv - 0.5) * 2.0;
	ALBEDO = c * glow * scan * vig;
	ALPHA = corner;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("screen_tex", _screen_vp.get_texture())
	m.render_priority = 1
	quad.material_override = m
	if _hood_mesh != null:
		_hood_mesh.add_child(quad)


## Redraw the screen (the room changed something).
func refresh() -> void:
	if _screen_draw != null:
		_screen_draw.queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()


# ---- entrance and exit ----------------------------------------------------------------------------

func _enter() -> void:
	SfxManager.ui("open")
	_rig.position = Vector3(0.0, -0.20, 0.0)
	_rig.rotation_degrees = Vector3(18.0, -14.0, 0.0)
	var t := create_tween().set_parallel(true)
	t.tween_method(_set_blur, 0.0, 1.0, UITheme.dur(0.45))
	t.tween_property(_rig, "position", Vector3.ZERO, UITheme.dur(0.55)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_rig, "rotation_degrees", Vector3.ZERO, UITheme.dur(0.65)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished
	# the hood flips open (with a little overshoot, like the real hinge), then the camera pushes in
	SfxManager.ui("confirm", -4.0, 0.8)
	var h := create_tween()
	if _hood != null:
		h.tween_property(_hood, "rotation_degrees:x", HOOD_OPEN - 6.0, UITheme.dur(0.42)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		h.tween_property(_hood, "rotation_degrees:x", HOOD_OPEN, UITheme.dur(0.16)).set_trans(Tween.TRANS_SINE)
	h.parallel().tween_method(_cam_lerp, 0.0, 1.0, UITheme.dur(0.85)).set_delay(UITheme.dur(0.12)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await h.finished
	_ready_for_input = true
	refresh()


func _cam_lerp(v: float) -> void:
	_cam.transform = _cam_far.interpolate_with(_cam_near, v)


## Puts it away: the camera pulls back, the hood shuts, it drops out of view, the game comes back sharp.
func close() -> void:
	if _closing:
		return
	_closing = true
	_ready_for_input = false
	SfxManager.ui("close")
	var t := create_tween()
	t.tween_method(_cam_lerp, 1.0, 0.0, UITheme.dur(0.45)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if _hood != null:
		t.parallel().tween_property(_hood, "rotation_degrees:x", HOOD_CLOSED, UITheme.dur(0.40)).set_delay(UITheme.dur(0.15))
	t.tween_property(_rig, "position", Vector3(0.0, -0.22, 0.0), UITheme.dur(0.35)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(_set_blur, 1.0, 0.0, UITheme.dur(0.40))
	await t.finished
	var layer := get_parent()
	if layer != null:
		layer.queue_free()
	else:
		queue_free()


# ---- the knobs: arrows, rings, labels (drawn over the 3D, where the knobs are on screen) ----------

func _build_overlay() -> void:
	_overlay = _KnobOverlay.new()
	(_overlay as _KnobOverlay).panel = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


## Where a point on the hood is on screen (pixels), and how many pixels a millimetre is there.
func _on_screen(local: Vector3) -> Vector2:
	if _hood_mesh == null or _cam == null:
		return Vector2.ZERO
	var world := _hood_mesh.global_transform * local
	var p := _cam.unproject_position(world)
	var k := size / Vector2(_vp.size) if _vp.size.x > 0 else Vector2.ONE
	return p * k


func _mm_px() -> float:
	return (_on_screen(KNOBS[0] + Vector3(0.001, 0.0, 0.0)) - _on_screen(KNOBS[0])).length()


## Hit areas for the mouse: name -> [centre, radius] in pixels.
func _controls() -> Dictionary:
	var out := {}
	if not _ready_for_input:
		return out
	var mm := _mm_px()
	if knobs_mode():
		for i in KNOBS.size():
			var kc := _on_screen(KNOBS[i])
			out["k%d" % i] = [kc, 4.4 * mm]
			out["k%d-" % i] = [kc + Vector2(-3.4 * mm, 7.0 * mm), 2.3 * mm]
			out["k%d+" % i] = [kc + Vector2(3.4 * mm, 7.0 * mm), 2.3 * mm]
		return out
	var k0 := _on_screen(KNOBS[0])
	var r := 6.2 * mm
	out["up"] = [k0 + Vector2(0.0, -r), 2.6 * mm]
	out["down"] = [k0 + Vector2(0.0, r), 2.6 * mm]
	out["left"] = [k0 + Vector2(-r, 0.0), 2.6 * mm]
	out["right"] = [k0 + Vector2(r, 0.0), 2.6 * mm]
	var labels: Dictionary = cfg.get("labels", {})
	if String(labels.get("a", "")) != "":
		out["a"] = [_on_screen(KNOBS[1]), 4.2 * mm]
	if String(labels.get("b", "")) != "":
		out["b"] = [_on_screen(KNOBS[2]), 4.2 * mm]
	if String(labels.get("x", "")) != "":
		out["x"] = [_on_screen(JEWELS), 5.0 * mm]
	return out


## The button glyph for a control, for the device in use.
func glyph(control: String) -> String:
	var pad := InputHints.using_gamepad
	match control:
		"a":
			return "A" if pad else "ENTER"
		"b":
			return "B" if pad else "BKSP"
		"x":
			return "X" if pad else "L"
		"leave":
			return ("B" if knobs_mode() else "Y") if pad else "ESC"
	return ""


func _fit_screen() -> void:
	var r := get_viewport_rect()
	if position != Vector2.ZERO or size != r.size:
		position = Vector2.ZERO
		size = r.size


func _process(delta: float) -> void:
	_fit_screen()
	if _vp != null and Vector2i(size) != _vp.size and size.x > 8.0:
		_vp.size = Vector2i(size)
	for k in _flash.keys():
		_flash[k] = float(_flash[k]) - delta
		if float(_flash[k]) <= 0.0:
			_flash.erase(k)
	if _overlay != null:
		_overlay.queue_redraw()
	if _screen_draw != null:
		_screen_draw.queue_redraw()      # REV 638: live pictures (the signal waves scroll)
	if knobs_mode() and _ready_for_input and not _closing:
		if _hold_dir != 0 and not busy:
			_hold_t += delta
			while _hold_t >= HOLD_DELAY + HOLD_EVERY:
				_hold_t -= HOLD_EVERY
				_turn(_hold_dir)
		var every := float(cfg.get("tick", 0.0))
		if every > 0.0 and not busy:
			_tick_t += delta
			if _tick_t >= every:
				_tick_t = 0.0
				event.emit(["tick"])


# ---- input ----------------------------------------------------------------------------------------

func _input(ev: InputEvent) -> void:
	if _closing:
		return
	# everything goes to the tricorder while it's up (nothing reaches the room behind)
	if ev is InputEventMouseMotion:
		_hot = _hit((ev as InputEventMouseMotion).position)
		return
	if not _ready_for_input or busy:
		if ev is InputEventKey or ev is InputEventJoypadButton or ev is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		_hold_dir = 0
		return
	if knobs_mode():
		_knob_input(ev)
		return
	var out: Array = []
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var h := _hit(mb.position)
			match h:
				"up": out = ["move", Vector2i(0, -1)]
				"down": out = ["move", Vector2i(0, 1)]
				"left": out = ["move", Vector2i(-1, 0)]
				"right": out = ["move", Vector2i(1, 0)]
				"a", "b", "x": out = [h]
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			out = ["b"] if _controls().has("b") else []
		get_viewport().set_input_as_handled()
	elif ev is InputEventJoypadButton and (ev as InputEventJoypadButton).pressed:
		var jb := ev as InputEventJoypadButton
		match jb.button_index:
			JOY_BUTTON_A: out = ["a"]
			JOY_BUTTON_B: out = ["b"]
			JOY_BUTTON_X: out = ["x"]
			JOY_BUTTON_Y, JOY_BUTTON_START: out = ["leave"]
			JOY_BUTTON_DPAD_UP: out = ["move", Vector2i(0, -1)]
			JOY_BUTTON_DPAD_DOWN: out = ["move", Vector2i(0, 1)]
			JOY_BUTTON_DPAD_LEFT: out = ["move", Vector2i(-1, 0)]
			JOY_BUTTON_DPAD_RIGHT: out = ["move", Vector2i(1, 0)]
		get_viewport().set_input_as_handled()
	elif ev is InputEventJoypadMotion:
		var jm := ev as InputEventJoypadMotion
		if jm.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			var pushed := absf(jm.axis_value) > 0.6
			var was := bool(_stick.get(jm.axis, false))
			_stick[jm.axis] = absf(jm.axis_value) > 0.35 and (was or pushed)
			if pushed and not was:
				var horiz := jm.axis == JOY_AXIS_LEFT_X or jm.axis == JOY_AXIS_RIGHT_X
				var s := 1 if jm.axis_value > 0.0 else -1
				out = ["move", Vector2i(s, 0) if horiz else Vector2i(0, s)]
		get_viewport().set_input_as_handled()
	elif ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		match (ev as InputEventKey).physical_keycode:
			KEY_UP, KEY_W: out = ["move", Vector2i(0, -1)]
			KEY_DOWN, KEY_S: out = ["move", Vector2i(0, 1)]
			KEY_LEFT, KEY_A: out = ["move", Vector2i(-1, 0)]
			KEY_RIGHT, KEY_D: out = ["move", Vector2i(1, 0)]
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: out = ["a"]
			KEY_BACKSPACE, KEY_DELETE: out = ["b"]
			KEY_L: out = ["x"]
			KEY_ESCAPE: out = ["leave"]
		get_viewport().set_input_as_handled()
	if out.is_empty():
		return
	var kind := String(out[0])
	if kind == "leave" and not bool(cfg.get("can_leave", true)):
		SfxManager.ui("invalid", -6.0)
		return
	if kind in ["a", "b", "x"] and not _controls().has(kind):
		return
	if kind == "move":
		var d: Vector2i = out[1]
		_flash["up" if d.y < 0 else ("down" if d.y > 0 else ("left" if d.x < 0 else "right"))] = 0.18
		SfxManager.ui("move")
	elif kind != "leave":
		_flash[kind] = 0.25
		SfxManager.ui("confirm", -3.0)
	event.emit(out)


var _stick := {}


## REV 638: knob mode input - pick a knob (left/right), turn it (up/down, held = keeps turning), mouse arrows/wheel.
func _knob_input(ev: InputEvent) -> void:
	var pick := 0
	var turn := 0
	var release := false
	var leave := false
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		get_viewport().set_input_as_handled()
		if not mb.pressed:
			return
		var h := _hit(mb.position)
		if h == "" or not h.begins_with("k"):
			return
		var i := int(h.substr(1, 1))
		var wheel := 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else (-1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0)
		if mb.button_index == MOUSE_BUTTON_LEFT or wheel != 0:
			if i != knob_sel:
				_select(i)
			var d := wheel if wheel != 0 else (1 if h.ends_with("+") else (-1 if h.ends_with("-") else 0))
			if d != 0:
				_turn(d)
		return
	if ev is InputEventJoypadButton:
		var jb := ev as InputEventJoypadButton
		get_viewport().set_input_as_handled()
		match jb.button_index:
			JOY_BUTTON_DPAD_LEFT: pick = -1
			JOY_BUTTON_DPAD_RIGHT: pick = 1
			JOY_BUTTON_DPAD_UP: turn = 1
			JOY_BUTTON_DPAD_DOWN: turn = -1
			JOY_BUTTON_LEFT_SHOULDER: pick = -1
			JOY_BUTTON_RIGHT_SHOULDER: pick = 1
			JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_START: leave = true
		if not jb.pressed:
			release = turn != 0
			pick = 0
			turn = 0
			leave = false
	elif ev is InputEventJoypadMotion:
		var jm := ev as InputEventJoypadMotion
		get_viewport().set_input_as_handled()
		if jm.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X]:
			var pushed := absf(jm.axis_value) > 0.6
			var was := bool(_stick.get(jm.axis, false))
			_stick[jm.axis] = absf(jm.axis_value) > 0.35 and (was or pushed)
			if pushed and not was:
				pick = 1 if jm.axis_value > 0.0 else -1
		elif jm.axis in [JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y]:
			if absf(jm.axis_value) > 0.6:
				var d2 := -1 if jm.axis_value > 0.0 else 1
				if _hold_dir != d2:
					_turn(d2)
					_hold_dir = d2
					_hold_t = 0.0
			elif absf(jm.axis_value) < 0.35 and _hold_dir != 0:
				_hold_dir = 0
			return
	elif ev is InputEventKey:
		var k := ev as InputEventKey
		get_viewport().set_input_as_handled()
		if k.echo:
			return
		match k.physical_keycode:
			KEY_LEFT, KEY_A: pick = -1
			KEY_RIGHT, KEY_D: pick = 1
			KEY_UP, KEY_W: turn = 1
			KEY_DOWN, KEY_S: turn = -1
			KEY_ESCAPE, KEY_BACKSPACE: leave = true
		if not k.pressed:
			release = turn != 0
			pick = 0
			turn = 0
			leave = false
	if release:
		_hold_dir = 0
		return
	if leave:
		if not bool(cfg.get("can_leave", true)):
			SfxManager.ui("invalid", -6.0)
			return
		event.emit(["leave"])
		return
	if pick != 0:
		_select(wrapi(knob_sel + pick, 0, KNOBS.size()))
	if turn != 0:
		_turn(turn)
		_hold_dir = turn
		_hold_t = 0.0


func _select(i: int) -> void:
	if i == knob_sel:
		return
	knob_sel = i
	_tick_t = 0.0
	SfxManager.ui("move", -4.0)
	event.emit(["select", i])


func _turn(d: int) -> void:
	if busy or bool(knob_done[knob_sel]):
		return
	_tick_t = 0.0
	_flash["k%d%s" % [knob_sel, "+" if d > 0 else "-"]] = 0.15
	event.emit(["turn", knob_sel, d])


func _hit(at: Vector2) -> String:
	var best := ""
	for k in _controls().keys():
		var c: Array = _controls()[k]
		if at.distance_to(c[0]) <= float(c[1]):
			best = String(k)
	return best


# ---- the two drawing layers -----------------------------------------------------------------------

class _ScreenDraw:
	extends Control
	var panel: TricorderPanel

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, TricorderPanel.SCR_BG)
		# faint graticule, like the TOS readouts
		for i in range(1, 8):
			var x := rect.size.x * i / 8.0
			draw_line(Vector2(x, 0), Vector2(x, rect.size.y), Color(TricorderPanel.SCR_DIM, 0.18), 1.0)
		for i in range(1, 6):
			var y := rect.size.y * i / 6.0
			draw_line(Vector2(0, y), Vector2(rect.size.x, y), Color(TricorderPanel.SCR_DIM, 0.18), 1.0)
		var title := String(panel.cfg.get("title", ""))
		if title != "":
			draw_string(panel._font, Vector2(14, 26), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TricorderPanel.SCR_DIM)
		var f: Callable = panel.cfg.get("draw", Callable())
		if f.is_valid():
			f.call(self, rect.grow(-10.0))


class _KnobOverlay:
	extends Control
	var panel: TricorderPanel

	func _draw() -> void:
		var ctl: Dictionary = panel._controls()
		if ctl.is_empty():
			return
		var mm := panel._mm_px()
		var labels: Dictionary = panel.cfg.get("labels", {})
		var font := panel._font
		var fs := int(clampf(mm * 2.6, 12.0, 26.0))
		if panel.knobs_mode():
			_draw_knobs(mm, fs, font)
			_draw_leave(font)
			return
		# four arrows round the left knob
		for dir in ["up", "down", "left", "right"]:
			var c: Vector2 = ctl[dir][0]
			var r: float = float(ctl[dir][1]) * 0.75
			var lit: bool = panel._flash.has(dir) or panel._hot == dir
			var col := Color(1, 1, 1, 0.95) if lit else Color(0.92, 0.88, 0.70, 0.75)
			var pts: PackedVector2Array
			match dir:
				"up": pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.9, r * 0.6), c + Vector2(-r * 0.9, r * 0.6)])
				"down": pts = PackedVector2Array([c + Vector2(0, r), c + Vector2(-r * 0.9, -r * 0.6), c + Vector2(r * 0.9, -r * 0.6)])
				"left": pts = PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r * 0.6, -r * 0.9), c + Vector2(r * 0.6, r * 0.9)])
				"right": pts = PackedVector2Array([c + Vector2(r, 0), c + Vector2(-r * 0.6, r * 0.9), c + Vector2(-r * 0.6, -r * 0.9)])
			draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
			var inner := PackedVector2Array()
			var ctr := (pts[0] + pts[1] + pts[2]) / 3.0
			for p in pts:
				inner.append(ctr + (p - ctr) * 0.78)
			draw_colored_polygon(inner, col)
		# rings + words on the other controls
		for k in [["a", TricorderPanel.GREEN], ["b", TricorderPanel.RED], ["x", TricorderPanel.AMBER]]:
			var key := String(k[0])
			if not ctl.has(key):
				continue
			var c: Vector2 = ctl[key][0]
			var r: float = float(ctl[key][1])
			var lit: bool = panel._flash.has(key) or panel._hot == key
			var col: Color = k[1]
			draw_arc(c, r, 0.0, TAU, 48, Color(0, 0, 0, 0.5), 5.0, true)
			draw_arc(c, r, 0.0, TAU, 48, col if lit else Color(col, 0.75), 2.5 if not lit else 4.0, true)
			# REV 635 (Glen's picture: "ENTER BRIDGE" and "BKSP BREAK" ran into each other): the action word centred
			# on its button, the key in smaller letters under it (above the button for the top one)
			var action := String(labels.get(key, ""))
			var keyname := panel.glyph(key)
			var ks := int(fs * 0.72)
			var below := key != "x"
			var y1 := c.y + r + fs * 1.15 if below else c.y - r - ks * 1.5
			var y2 := y1 + ks * 1.15
			for line in [[action, fs, y1], [keyname, ks, y2]]:
				var txt := String(line[0])
				if txt == "":
					continue
				var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(line[1])).x
				var at := Vector2(c.x - w * 0.5, float(line[2]))
				draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(line[1]), 5, Color(0, 0, 0, 0.85))
				draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(line[1]), col if line[0] == action else Color(0.92, 0.9, 0.82, 0.85))
		_draw_leave(font)

	func _draw_leave(font: Font) -> void:
		# put it away
		if bool(panel.cfg.get("can_leave", true)):
			var w := "%s  PUT IT AWAY" % panel.glyph("leave")
			var at2 := Vector2(24.0, 36.0)      # REV 635: top left - at the bottom it sat under the subtitles
			draw_string_outline(font, at2, w, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
			draw_string(font, at2, w, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.88, 0.8, 0.8))
		if panel.knobs_mode():
			var how := ("D-PAD LEFT / RIGHT: PICK A KNOB     UP / DOWN: TURN IT" if InputHints.using_gamepad
					else "LEFT / RIGHT: PICK A KNOB     UP / DOWN: TURN IT     (OR CLICK THE ARROWS, OR SCROLL)")
			var at3 := Vector2(24.0, 60.0)
			draw_string_outline(font, at3, how, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
			draw_string(font, at3, how, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.88, 0.8, 0.65))

	## REV 638: the three knobs as controls - a ring (amber = picked, green = matched and locked), a pointer that
	## turns with the setting, two turn arrows under it and a little picture above it of what it does.
	func _draw_knobs(mm: float, fs: int, font: Font) -> void:
		var t := Time.get_ticks_msec() / 1000.0
		for i in TricorderPanel.KNOBS.size():
			var c := panel._on_screen(TricorderPanel.KNOBS[i])
			var r := 4.6 * mm
			var done := bool(panel.knob_done[i])
			var picked := i == panel.knob_sel and not done
			var col := TricorderPanel.GREEN if done else (TricorderPanel.AMBER if picked else Color(0.92, 0.9, 0.82, 0.45))
			draw_arc(c, r, 0.0, TAU, 48, Color(0, 0, 0, 0.5), 6.0, true)
			var pulse := 0.75 + 0.25 * sin(t * 5.0) if picked else 1.0
			draw_arc(c, r, 0.0, TAU, 48, Color(col, col.a * pulse), 4.0 if (picked or done) else 2.0, true)
			# the pointer (angle 0 = straight up, clockwise positive)
			var a := float(panel.knob_angle[i])
			var dir := Vector2(sin(a), -cos(a))
			draw_line(c + dir * r * 0.15, c + dir * r * 0.85, Color(0, 0, 0, 0.7), 5.0, true)
			draw_line(c + dir * r * 0.15, c + dir * r * 0.85, col if (picked or done) else Color(1, 1, 1, 0.8), 2.5, true)
			draw_circle(c + dir * r * 0.85, 2.6, col if (picked or done) else Color(1, 1, 1, 0.8))
			# turn arrows under it (not once it's locked)
			if not done:
				for side: int in [-1, 1]:
					var key := "k%d%s" % [i, "+" if side > 0 else "-"]
					var ac := c + Vector2(3.4 * mm * side, 7.0 * mm)
					var ar := 1.5 * mm
					# REV 741 (item 21): a dark button behind each arrow - over the face's lower lip the bare arcs read as cut off
					draw_circle(ac + Vector2(0.0, -0.3 * mm), ar * 1.55, Color(0, 0, 0, 0.55))
					var lit: bool = panel._flash.has(key) or panel._hot == key
					var acol := Color(1, 1, 1, 0.95) if lit else (Color(TricorderPanel.AMBER, 0.85) if picked else Color(0.92, 0.88, 0.70, 0.55))
					# a curved arrow: an arc and a head (left = anticlockwise, right = clockwise)
					var a0 := PI * 0.95 if side < 0 else PI * 0.05
					var a1 := PI * 0.25 if side < 0 else PI * 0.75
					draw_arc(ac, ar, -a0, -a1, 12, Color(0, 0, 0, 0.6), 5.0, true)
					draw_arc(ac, ar, -a0, -a1, 12, acol, 2.5, true)
					var tip := ac + Vector2(cos(-a1), sin(-a1)) * ar
					var tangent := Vector2(-sin(-a1), cos(-a1)) * (1.0 if side < 0 else -1.0)
					var head := PackedVector2Array([tip + tangent * 0.9 * mm, tip + tangent.rotated(2.3) * 0.9 * mm, tip + tangent.rotated(-2.3) * 0.9 * mm])
					draw_colored_polygon(head, acol)
			# what it does, as a tiny picture above it
			_draw_icon(String(panel.knob_icon[i]), c + Vector2(0.0, -6.6 * mm), 2.3 * mm, col if (picked or done) else Color(0.92, 0.9, 0.82, 0.7))

	func _draw_icon(kind: String, at: Vector2, s: float, col: Color) -> void:
		var pts := PackedVector2Array()
		match kind:
			"height":      # a wave with an up-down arrow
				for k in 17:
					var u := float(k) / 16.0
					pts.append(at + Vector2((u - 0.5) * s * 2.0, -sin(u * TAU) * s * 0.55))
				draw_polyline(pts, col, 2.0, true)
				draw_line(at + Vector2(s * 1.25, -s * 0.8), at + Vector2(s * 1.25, s * 0.8), col, 2.0, true)
				draw_colored_polygon(PackedVector2Array([at + Vector2(s * 1.25, -s * 1.0), at + Vector2(s * 1.05, -s * 0.65), at + Vector2(s * 1.45, -s * 0.65)]), col)
				draw_colored_polygon(PackedVector2Array([at + Vector2(s * 1.25, s * 1.0), at + Vector2(s * 1.05, s * 0.65), at + Vector2(s * 1.45, s * 0.65)]), col)
			"spacing":     # a tight wave between two inward arrows
				for k in 25:
					var u := float(k) / 24.0
					pts.append(at + Vector2((u - 0.5) * s * 1.4, -sin(u * TAU * 2.0) * s * 0.5))
				draw_polyline(pts, col, 2.0, true)
				for sd: float in [-1.0, 1.0]:
					var x := sd * s * 1.25
					draw_colored_polygon(PackedVector2Array([at + Vector2(x - sd * s * 0.35, 0.0), at + Vector2(x, -s * 0.3), at + Vector2(x, s * 0.3)]), col)
			"slide":       # a wave with an arrow along it
				for k in 17:
					var u := float(k) / 16.0
					pts.append(at + Vector2((u - 0.5) * s * 2.0, -sin(u * TAU) * s * 0.5))
				draw_polyline(pts, col, 2.0, true)
				draw_line(at + Vector2(-s * 0.9, s * 0.95), at + Vector2(s * 0.9, s * 0.95), col, 2.0, true)
				draw_colored_polygon(PackedVector2Array([at + Vector2(s * 1.15, s * 0.95), at + Vector2(s * 0.8, s * 0.7), at + Vector2(s * 0.8, s * 1.2)]), col)
				draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 1.15, s * 0.95), at + Vector2(-s * 0.8, s * 0.7), at + Vector2(-s * 0.8, s * 1.2)]), col)
