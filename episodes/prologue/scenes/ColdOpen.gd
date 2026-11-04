extends Node3D
class_name ColdOpen
## PRE-PROLOGUE — "Ki Baratan, Romulus — 2264".
##
## A fully scripted cutscene (no player interaction) that tells the audience
## the Federation peace conference is a Romulan operation. Follows the Cold
## Open in "Prologue MASTER READY FOR IMPLEMENTATION v1.2":
##   1. Aerial flight over Ki Baratan toward the Romulan Security Department.
##   2. The Strategic Operations Centre: holographic map, the Director,
##      the classified Omega file, the five-year countdown.
##   3. "FIVE YEARS LATER" -> hands over to the Bowling Alley prologue.
##
## EVERYTHING VISUAL HERE IS A STAND-IN built from primitives and shaders, so
## the scene works with no art files. Swap in real models later by replacing
## _build_city / _build_room; the timeline in _run() doesn't care.
##
## VOICES: each line plays res://episodes/prologue/audio/speech/romulans/<ID>.mp3
## if that file exists; if not, the subtitle is shown and timed by reading speed.
## The IDs used are listed in the LINES section below (provisional names).
##
## SKIP: press Esc (or Cancel) at any time.

signal _step

const NEXT_SCENE := "res://episodes/prologue/scenes/BowlingAlley.tscn"
const SPEECH_FOLDER := "romulans"
const MUSIC_PATHS: Array[String] = [
	"res://episodes/prologue/audio/music/MUS_PRO_COLDOPEN.mp3",
	"res://episodes/prologue/audio/music/MUS_PRO_COLDOPEN.ogg",
]
const AMBIENCE_CITY_PATHS: Array[String] = [
	"res://episodes/prologue/audio/ambience/AMB_ROMULUS.mp3",
	"res://episodes/prologue/audio/ambience/AMB_ROMULUS.ogg",
]
const AMBIENCE_ROOM_PATHS: Array[String] = [
	"res://episodes/prologue/audio/ambience/AMB_OPSCENTRE.mp3",
	"res://episodes/prologue/audio/ambience/AMB_OPSCENTRE.ogg",
]
const SFX_CONFIRM_PATH := "res://episodes/prologue/audio/sfx/SFX_HOLO_CONFIRM.mp3"
const DIRECTOR_POS := Vector3(0.0, 0.35, 2.4)
const FONT_PATHS: Array[String] = [
	"res://assets/fonts/Microgramma_D_Extended_Medium.otf",
	"res://assets/fonts/Microgramma_D_Extended_Bold.otf",
]

# The ops centre is built far away from the city so the two never overlap.
const ROOM := Vector3(0.0, 600.0, 0.0)
const BAR_H := 56.0   # cinematic letterbox bar height, pixels

const GREEN := Color(0.35, 1.0, 0.72)
const AMBER := Color(1.0, 0.64, 0.22)
const GOLD := Color(0.831, 0.686, 0.216)

# ---- LINES (stable IDs; folder = romulans) ---------------------------------
const L_DIR_1 := ["DIRECTOR", "DIRECTOR_PRO_0001.mp3", "Report."]
const L_OPS_1 := ["OPERATIONS OFFICER", "OPSOFFICER_PRO_0001.mp3", "Phase One has been completed."]
const L_DIR_2 := ["DIRECTOR", "DIRECTOR_PRO_0002.mp3", "The initiative?"]
const L_OPS_2 := ["OPERATIONS OFFICER", "OPSOFFICER_PRO_0002.mp3", "Proceeding according to schedule."]
const L_DIR_3 := ["DIRECTOR", "DIRECTOR_PRO_0003.mp3", "Our projections?"]
const L_ANA_1 := ["ANALYSIS OFFICER", "ANALYST_PRO_0001.mp3", "The probability of Federation acceptance now exceeds ninety-nine point four percent."]
const L_DIR_4 := ["DIRECTOR", "DIRECTOR_PRO_0004.mp3", "And the Vulcans?"]
const L_ANA_2 := ["ANALYSIS OFFICER", "ANALYST_PRO_0002.mp3", "They believe the proposal originated within the Federation."]
const L_DIR_5 := ["DIRECTOR", "DIRECTOR_PRO_0005.mp3", "Excellent."]
const L_DIR_6 := ["DIRECTOR", "DIRECTOR_PRO_0006.mp3", "For generations... the Federation has dreamed of lasting peace."]
const L_DIR_7 := ["DIRECTOR", "DIRECTOR_PRO_0007.mp3", "We shall give them exactly what they desire."]
const L_DIR_8 := ["DIRECTOR", "DIRECTOR_PRO_0008.mp3", "They will spend years preparing it."]
const L_DIR_9 := ["DIRECTOR", "DIRECTOR_PRO_0009.mp3", "They will celebrate it."]
const L_DIR_10 := ["DIRECTOR", "DIRECTOR_PRO_0010.mp3", "They will protect it."]
const L_DIR_11 := ["DIRECTOR", "DIRECTOR_PRO_0011.mp3", "And when the conference finally begins..."]
const L_DIR_12 := ["DIRECTOR", "DIRECTOR_PRO_0012.mp3", "...history will follow the course we have chosen."]

const HOLO_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.3, 1.0, 0.7, 1.0);
uniform float alpha = 0.4;
void fragment() {
	float scan = 0.78 + 0.22 * sin(UV.y * 140.0 + TIME * 2.5);
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = tint.rgb * (0.7 + rim);
	ALPHA = alpha * scan;
}
"""

const WINDOW_SHADER_CODE := """
shader_type spatial;
varying vec3 wpos;
varying vec3 wnorm;
uniform vec3 wall_color = vec3(0.035, 0.045, 0.05);
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float rowf = wpos.y / 3.2;
	float colf = (wpos.x + wpos.z) / 2.6;
	vec2 id = vec2(floor(rowf), floor(colf));
	vec2 f = vec2(fract(rowf), fract(colf));
	float r = fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453);
	float r2 = fract(sin(dot(id, vec2(39.346, 11.135))) * 24634.6345);
	float lit = step(0.58, r);
	float win = step(0.3, f.x) * step(f.x, 0.8) * step(0.2, f.y) * step(f.y, 0.8);
	float side = 1.0 - step(0.5, abs(wnorm.y));
	float height_boost = smoothstep(3.0, 40.0, wpos.y);
	vec3 col = mix(vec3(0.25, 1.0, 0.7), vec3(1.0, 0.7, 0.3), step(0.8, r2));
	ALBEDO = wall_color;
	ROUGHNESS = 0.55;
	METALLIC = 0.3;
	EMISSION = col * lit * win * side * (0.6 + height_boost) * 1.4;
}
"""

const HOLO_PLANET_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0, 0.64, 0.22, 1.0);
uniform sampler2D map_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_map = 0.0;
void fragment() {
	float scan = 0.8 + 0.2 * sin(UV.y * 260.0 + TIME * 2.0);
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 c = texture(map_tex, UV).rgb;
	float l = mix(0.5, dot(c, vec3(0.3, 0.59, 0.11)), use_map);
	ALBEDO = tint.rgb * (0.25 + 1.1 * l + 1.2 * rim);
	ALPHA = clamp((0.16 + 0.5 * l + 0.55 * rim) * scan, 0.0, 1.0);
}
"""

const PLANET_SHADER_CODE := """
shader_type spatial;
render_mode unshaded;
void fragment() {
	vec3 n = normalize(NORMAL);
	float l = clamp(dot(n, normalize(vec3(-0.6, 0.3, 0.8))) * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = mix(vec3(0.02, 0.03, 0.03), vec3(0.62, 0.55, 0.38), l * l);
}
"""

# ---- state -------------------------------------------------------------------
var _cam: Camera3D
var _look := Vector3.ZERO
var _cam_tween: Tween
var _world_env: WorldEnvironment
var _env_city: Environment
var _env_room: Environment
var _city: Node3D
var _room: Node3D
var _holo: Node3D
var _holo_zoom: Node3D
var _vulcan_local := Vector3(0.75, 0.0, -0.35)
var _director: Node3D
var _director_head: Node3D
var _ops: Node3D
var _analyst: Node3D
var _crowd: Array[Node3D] = []
var _door_left: MeshInstance3D
var _door_right: MeshInstance3D
var _door_spill: SpotLight3D
var _room_lights: Array[Light3D] = []
var _table_screen_mat: StandardMaterial3D
var _font: Font

var _ui: CanvasLayer
var _top_ui: CanvasLayer
var _black: ColorRect
var _bars: Array[ColorRect] = []
var _sub_panel: PanelContainer
var _sub_speaker: Label
var _sub_text: Label
var _sub_serial := 0
var _title_box: VBoxContainer
var _file_panel: PanelContainer
var _file_rows: Array[Control] = []
var _callout_box: VBoxContainer
var _callout_title: Label
var _callout_value: Label
var _five_years: Label
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _look_node: Node3D
var _fed_marker: Node3D
var _vulcan_marker: Node3D
var _planet_holo: Node3D
var _director_arm: Node3D
var _mouth_l: Node3D
var _mouth_r: Node3D

var _skipped := false
var _finished := false


func _ready() -> void:
	AudioSubtitleManager.speech_root = AudioSubtitleManager.SPEECH_ROOT   # REV 77: the Prologue's voice folder (an Episode 1 debug jump had left it pointing at Episode 1's)
	_font = _load_font()
	_build_ui()
	_build_environments()
	_cam = Camera3D.new()
	_cam.far = 8000.0
	_cam.fov = 55.0
	add_child(_cam)
	_cam.current = true
	_build_city()
	_build_room()
	AudioSubtitleManager.subtitle_requested.connect(_on_subtitle_requested)
	_run()


func _exit_tree() -> void:
	if AudioSubtitleManager.subtitle_requested.is_connected(_on_subtitle_requested):
		AudioSubtitleManager.subtitle_requested.disconnect(_on_subtitle_requested)
	if AudioSubtitleManager.line_finished.is_connected(_on_line_done):
		AudioSubtitleManager.line_finished.disconnect(_on_line_done)


func _process(delta: float) -> void:
	if _look_node != null and is_instance_valid(_look_node):
		_look = _look_node.global_position
	if _cam != null and _cam.position.distance_to(_look) > 0.05:
		_cam.look_at(_look, Vector3.UP)
	if _holo != null and _holo.visible:
		_holo.rotation.y += delta * 0.14
	if _planet_holo != null and _planet_holo.visible:
		_planet_holo.rotation.y += delta * 0.12


func _unhandled_input(event: InputEvent) -> void:
	var cancel := false
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		cancel = true
	if event.is_action_pressed("menu_cancel"):
		cancel = true
	if cancel:
		get_viewport().set_input_as_handled()
		_skip()


# ===========================================================================
# THE TIMELINE
# ===========================================================================

func _run() -> void:
	_black.color.a = 1.0
	_world_env.environment = _env_city
	_city.visible = true
	_room.visible = false
	_set_ambience(AMBIENCE_CITY_PATHS)
	await _wait(0.8)

	# ---- SHOTS 1-3: one slow, continuous move ----------------------------------
	# wide establishing -> lower over the city -> low approach to the Security
	# Department. Silence but for city ambience; music enters at the second shot.
	_cut(Vector3(-300, 160, 360), Vector3(0, 70, -420), 55.0)
	_fly([
		[Vector3(-170, 118, 150), Vector3(0, 52, -420), 9.0],
		[Vector3(-80, 64, -100), Vector3(0, 40, -420), 7.0],
		[Vector3(-14, 15, -290), Vector3(0, 46, -420), 6.5],
	])
	_fade_to(0.0, 2.2)
	await _wait(1.8)
	_show_location()
	await _wait(7.4)
	_start_music()
	await _wait(13.6)

	# HARD CUT to the Strategic Operations Centre.
	_black.color.a = 1.0
	await _wait(0.5)

	# ---- SHOT 4: the room, held long enough to examine it -------------------------
	_set_ambience(AMBIENCE_ROOM_PATHS)
	_world_env.environment = _env_room
	_city.visible = false
	_room.visible = true
	_cut(_r(Vector3(2.6, 2.5, 12.4)), _r(Vector3(0, 2.2, -3.0)), 62.0)
	_drift_pos(_r(Vector3(2.1, 2.45, 11.3)), 7.5)
	_black.color.a = 0.0
	await _wait(5.2)
	_open_doors()      # behind the camera: light spills across the floor
	await _wait(1.6)

	# ---- SHOT 5: the Director enters; everyone stands at once ------------------------
	_cut(_r(Vector3(0.6, 2.0, -1.8)), _r(Vector3(0, 2.1, 13.4)), 46.0)
	_drift_pos(_r(Vector3(0.5, 2.0, -0.9)), 6.0)
	var walk := create_tween()
	walk.tween_property(_director, "position", DIRECTOR_POS, 5.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(1.4)
	_stand_crowd()
	await _wait(4.2)
	_shot_director()
	await _wait(0.5)
	await _say(L_DIR_1)

	# ---- SHOT 6: over the Operations Officer's shoulder - the classified file ---------
	_shot_over_ops()
	_show_file()
	await _wait(1.6)
	await _say(L_OPS_1)
	_shot_director()
	await _say(L_DIR_2)

	# ---- SHOT 7: Operations Officer, medium close-up -----------------------------------
	_shot_ops()
	await _say(L_OPS_2)

	# ---- SHOT 8: Director / Analysis Officer ---------------------------------------------
	_hide_file()
	_shot_director()
	var turn := create_tween()
	turn.tween_property(_director, "rotation:y", deg_to_rad(-22.0), 1.0)
	await _wait(0.7)
	await _say(L_DIR_3)
	_shot_analyst()
	var step_fwd := create_tween()
	step_fwd.tween_property(_analyst, "position", Vector3(2.1, 0.35, -1.0), 1.2).set_trans(Tween.TRANS_SINE)
	await _wait(1.3)
	await _say(L_ANA_1)
	_shot_director()
	await _say(L_DIR_4)
	_shot_analyst_tight()
	await _say(L_ANA_2)

	# ---- SHOT 9: the smile -----------------------------------------------------------------
	var face_front := create_tween()
	face_front.tween_property(_director, "rotation:y", 0.0, 0.8)
	_cut(_r(Vector3(-0.55, 2.12, 1.35)), _r(Vector3(0, 2.1, DIRECTOR_POS.z)), 24.0)
	_drift_pos(_r(Vector3(-0.5, 2.12, 1.55)), 3.2)
	await _wait(0.9)
	_smile(true)
	await _wait(2.6)
	_smile(false)

	# ---- SHOT 10: push through the display as it zooms to Vulcan ------------------------------
	_cut(_r(Vector3(0.0, 2.75, 4.2)), _r(Vector3(0, 2.4, 0)), 40.0)
	_drift_pos(_r(Vector3(0.0, 2.55, 2.0)), 8.0)
	_zoom_holo()
	await _wait(4.2)
	_show_callout("PROJECTED COMMENCEMENT", "5 YEARS", AMBER)
	await _wait(3.8)
	_hide_callout()

	# ---- SHOT 11: "Excellent." - his hand comes down on the console -----------------------------
	_cut(_r(Vector3(-1.5, 1.95, 2.2)), _r(Vector3(0.15, 1.75, DIRECTOR_POS.z - 0.5)), 36.0)
	_drift_pos(_r(Vector3(-1.35, 1.95, 2.0)), 5.0)
	await _wait(0.5)
	_hand_on_console(true)
	await _say(L_DIR_5)

	# ---- SHOT 12: status change, with a quiet confirmation tone ---------------------------------
	_cut(_r(Vector3(0.0, 2.7, 3.6)), _r(Vector3(0, 2.4, 0)), 40.0)
	_drift_pos(_r(Vector3(0.0, 2.6, 3.0)), 5.0)
	_play_confirm_tone()
	_show_callout("OPERATION STATUS", "ACTIVE", GREEN)
	await _wait(4.0)
	_hide_callout()
	_hand_on_console(false)

	# ---- SHOT 13: the speech begins - medium shot, officers behind him ----------------------------
	_reset_holo_zoom()
	_cut(_r(Vector3(0.7, 2.0, 0.1)), _r(Vector3(0, 2.1, 4.2)), 44.0)
	_drift_pos(_r(Vector3(0.35, 2.05, 1.0)), 13.0)
	await _wait(0.8)
	await _say(L_DIR_6)
	await _wait(1.0)
	await _say(L_DIR_7)
	await _wait(0.8)

	# ---- SHOT 14: Federation territory ---------------------------------------------------------------
	_cut_track(_r(Vector3(0.3, 2.9, 2.8)), _fed_marker, 36.0)
	_drift_pos(_r(Vector3(0.3, 2.75, 2.2)), 6.0)
	await _say(L_DIR_8)
	await _wait(0.6)

	# ---- SHOT 15: Vulcan rotates ----------------------------------------------------------------------
	_zoom_holo()
	_cut_track(_r(Vector3(0.2, 2.8, 1.9)), _vulcan_marker, 32.0)
	_drift_pos(_r(Vector3(0.2, 2.65, 1.5)), 6.0)
	await _say(L_DIR_9)
	await _wait(0.6)

	# ---- SHOT 16: the Security Department at work - nobody reacts -------------------------------------
	_cut(_r(Vector3(-2.2, 1.85, 0.5)), _r(Vector3(5.0, 1.9, 7.5)), 46.0)
	_drift_pos(_r(Vector3(-2.0, 1.85, 0.7)), 6.0)
	await _say(L_DIR_10)
	await _wait(0.9)

	# ---- SHOT 17: the hero shot - the Director and a huge holographic Vulcan ---------------------------
	_holo.visible = false
	_planet_holo.visible = true
	_director.rotation.y = deg_to_rad(-34.0)
	_cut(_r(Vector3(3.8, 2.15, 1.0)), _r(Vector3(0.2, 2.15, 1.5)), 40.0)
	_drift_pos(_r(Vector3(2.7, 2.15, 1.3)), 16.0)
	await _wait(1.6)
	var look_at_vulcan := create_tween()
	look_at_vulcan.tween_property(_director, "rotation:y", 0.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _say(L_DIR_11)
	await _wait(1.2)
	await _say(L_DIR_12)
	await _wait(2.4)

	# ---- SHOT 18: he touches the control. The hologram dies - a snap, not a fade. --------------------------
	_hand_on_console(true)
	await _wait(0.8)
	_planet_holo.visible = false
	_holo.visible = false
	_room.visible = false   # everything goes dark at once
	_hide_callout()
	_set_ambience([])
	if _music != null:
		_music.stop()
	_set_bars(false)
	await _wait(4.0)   # black, held longer than is comfortable

	# ---- FIVE YEARS LATER ------------------------------------------------------------------------------
	var t := create_tween()
	t.tween_property(_five_years, "modulate:a", 1.0, 1.6)
	t.tween_interval(3.2)
	t.tween_property(_five_years, "modulate:a", 0.0, 1.6)
	if not _skipped:
		await t.finished
	await _wait(1.4)
	if not _skipped:
		_finish()


# ---- camera shots in the ops centre (room-local coordinates) ------------------

func _shot_director() -> void:
	_cut(_r(Vector3(-0.9, 2.0, -1.0)), _r(Vector3(0, 2.05, DIRECTOR_POS.z)), 38.0)
	_drift_pos(_r(Vector3(-0.7, 2.0, -0.6)), 6.0)


func _shot_ops() -> void:
	var y := _ops_eye
	_cut(_r(Vector3(0.8, y, 0.9)), _r(Vector3(-1.9, y, -0.4)), 30.0)
	_drift_pos(_r(Vector3(0.7, y, 0.8)), 6.0)


func _shot_over_ops() -> void:
	_cut(_r(Vector3(-3.6, 2.3, -2.2)), _r(Vector3(0.6, 1.9, 1.4)), 42.0)
	_drift_pos(_r(Vector3(-3.4, 2.3, -2.0)), 7.0)


func _shot_analyst() -> void:
	var y := _analyst_eye
	_cut(_r(Vector3(-1.0, y - 0.05, 1.4)), _r(Vector3(2.4, y, -1.2)), 38.0)
	_drift_pos(_r(Vector3(-0.8, y - 0.05, 1.2)), 6.0)


func _shot_analyst_tight() -> void:
	var y := _analyst_eye
	_cut(_r(Vector3(0.6, y, 0.9)), _r(Vector3(2.1, y, -1.0)), 26.0)
	_drift_pos(_r(Vector3(0.7, y, 0.8)), 5.0)


func _r(v: Vector3) -> Vector3:
	return ROOM + v


# ---- timing helpers (all become no-ops once skipped) -----------------------------------

func _wait(seconds: float) -> void:
	if _skipped:
		return
	var tw := create_tween()
	tw.tween_interval(seconds)
	await tw.finished


func _say(line: Array) -> void:
	if _skipped:
		return
	AudioSubtitleManager.line_finished.connect(_on_line_done, CONNECT_ONE_SHOT)
	AudioSubtitleManager.play_line(SPEECH_FOLDER, String(line[1]), String(line[0]), String(line[2]))
	_director_talks(line, true)     # REV 853: after the sound starts, so the lip sync locks onto this line
	await _step
	_director_talks(line, false)


func _on_line_done(_line_id: String) -> void:
	_step.emit()


func _fade_to(alpha: float, seconds: float) -> Tween:
	if _skipped:
		return null
	var tw := create_tween()
	tw.tween_property(_black, "color:a", alpha, seconds)
	return tw


func _fade(alpha: float, seconds: float) -> void:
	var tw := _fade_to(alpha, seconds)
	if tw != null:
		await tw.finished


func _cut(pos: Vector3, look: Vector3, fov: float = 50.0) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_look_node = null
	_cam.position = pos
	_cam.fov = fov
	_look = look
	_cam.look_at(_look, Vector3.UP)


## A cut whose aim follows a (moving) node, such as a spot on the rotating map.
func _cut_track(pos: Vector3, node: Node3D, fov: float = 40.0) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_look_node = node
	_cam.position = pos
	_cam.fov = fov
	_look = node.global_position
	_cam.look_at(_look, Vector3.UP)


func _drift(pos: Vector3, look: Vector3, seconds: float) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_look_node = null
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true)
	_cam_tween.set_trans(Tween.TRANS_SINE)
	_cam_tween.set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(_cam, "position", pos, seconds)
	_cam_tween.tween_property(self, "_look", look, seconds)


## Slow camera creep that leaves the aim alone (or lets it keep tracking).
func _drift_pos(pos: Vector3, seconds: float) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.set_trans(Tween.TRANS_SINE)
	_cam_tween.set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(_cam, "position", pos, seconds)


## One continuous move through several waypoints: [[position, look_at, seconds], ...].
func _fly(waypoints: Array) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_look_node = null
	_cam_tween = create_tween()
	for i in waypoints.size():
		var wp: Array = waypoints[i]
		_cam_tween.tween_property(_cam, "position", wp[0], float(wp[2]))
		_cam_tween.parallel().tween_property(self, "_look", wp[1], float(wp[2]))


func _skip() -> void:
	if _skipped or _finished:
		return
	_skipped = true
	AudioSubtitleManager.stop_all()
	if AudioSubtitleManager.line_finished.is_connected(_on_line_done):
		AudioSubtitleManager.line_finished.disconnect(_on_line_done)
	_step.emit()
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 0.4)
	if _music != null:
		tw.parallel().tween_property(_music, "volume_db", -60.0, 0.4)
	tw.tween_callback(_finish)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	AudioSubtitleManager.stop_all()
	get_tree().change_scene_to_file(NEXT_SCENE)


# ===========================================================================
# BEATS (small animated moments)
# ===========================================================================

func _open_doors() -> void:
	_director.visible = true
	_director.position = Vector3(0, 0.0, 13.5)
	_door_spill.visible = true
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_door_left, "position:x", -3.4, 1.5)
	tw.tween_property(_door_right, "position:x", 3.4, 1.5)
	tw.tween_property(_door_spill, "light_energy", 7.0, 1.5)


func _stand_crowd() -> void:
	for officer in _crowd:
		var tw := create_tween()
		tw.tween_property(officer, "scale:y", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The faintest smile, and back to neutral.
func _smile(on: bool) -> void:
	if _director_face != null:
		_director_face.set_emotion("amused" if on else "neutral", 0.7)   # REV 756: Varel's own faint smile
		return
	var a := deg_to_rad(15.0) if on else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_mouth_l, "rotation:z", -a, 0.9)
	tw.tween_property(_mouth_r, "rotation:z", a, 0.9)


## His right hand comes down on the command table (and lifts again).
func _hand_on_console(down: bool) -> void:
	if _director_anim != null and down:
		_director_anim.reach_to(_room.to_global(DIRECTOR_TABLE_TOUCH))   # REV 756: his real hand on the table (it comes back by itself)
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_director_arm, "rotation:x", deg_to_rad(52.0) if down else 0.0, 0.8)
	if down:
		tw.chain().tween_property(_table_screen_mat, "emission_energy_multiplier", 3.0, 0.2)
		tw.chain().tween_property(_table_screen_mat, "emission_energy_multiplier", 1.2, 0.7)


func _zoom_holo() -> void:
	var s := 2.7
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_holo_zoom, "scale", Vector3(s, s, s), 5.0)
	tw.tween_property(_holo_zoom, "position", -_vulcan_local * s, 5.0)


func _reset_holo_zoom() -> void:
	_holo_zoom.scale = Vector3.ONE
	_holo_zoom.position = Vector3.ZERO


## A soft two-note confirmation (your own file wins if you add one at SFX_PATH).
func _play_confirm_tone() -> void:
	var player := AudioStreamPlayer.new()
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	player.volume_db = -9.0
	if ResourceLoader.exists(SFX_CONFIRM_PATH):
		player.stream = load(SFX_CONFIRM_PATH)
	else:
		player.stream = _make_confirm_tone()
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _make_confirm_tone() -> AudioStreamWAV:
	var rate := 22050
	var total := int(rate * 0.55)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var t := float(i) / float(rate)
		var freq := 740.0 if t < 0.17 else 988.0
		var local_t := t if t < 0.17 else t - 0.17
		var span := 0.17 if t < 0.17 else 0.38
		var env := minf(1.0, local_t / 0.012) * pow(1.0 - local_t / span, 1.6)
		var v := sin(TAU * freq * t) * env * 0.5
		data.encode_s16(i * 2, int(v * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


# ===========================================================================
# 2D OVERLAYS
# ===========================================================================

func _show_location() -> void:
	var tw := create_tween()
	tw.tween_property(_title_box, "modulate:a", 1.0, 1.4)
	tw.tween_interval(4.6)
	tw.tween_property(_title_box, "modulate:a", 0.0, 1.4)


func _show_file() -> void:
	_file_panel.visible = true
	_file_panel.modulate.a = 0.0
	for row in _file_rows:
		row.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_file_panel, "modulate:a", 1.0, 0.5)
	for row in _file_rows:
		tw.tween_property(row, "modulate:a", 1.0, 0.18)


func _hide_file() -> void:
	if not _file_panel.visible:
		return
	var tw := create_tween()
	tw.tween_property(_file_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _file_panel.visible = false)


func _show_callout(title: String, value: String, color: Color) -> void:
	_callout_title.text = title
	_callout_value.text = value
	_callout_value.add_theme_color_override("font_color", color)
	_callout_title.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.35))
	var tw := create_tween()
	tw.tween_property(_callout_box, "modulate:a", 1.0, 0.7)


func _hide_callout() -> void:
	var tw := create_tween()
	tw.tween_property(_callout_box, "modulate:a", 0.0, 0.5)


func _set_bars(on: bool) -> void:
	for bar in _bars:
		bar.visible = on


func _on_subtitle_requested(speaker: String, text: String, duration: float) -> void:
	if not GameSettings.wants_subtitles():
		return
	_sub_serial += 1
	var mine := _sub_serial
	_sub_speaker.text = speaker
	_sub_text.text = text
	_sub_panel.visible = true
	var tw := create_tween()
	tw.tween_interval(duration + 0.25)
	tw.tween_callback(func():
		if mine == _sub_serial:
			_sub_panel.visible = false)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	_top_ui = CanvasLayer.new()
	_top_ui.layer = 20
	add_child(_top_ui)

	# letterbox
	var top := ColorRect.new()
	top.color = Color.BLACK
	top.anchor_right = 1.0
	top.offset_bottom = BAR_H
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(top)
	var bottom := ColorRect.new()
	bottom.color = Color.BLACK
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -BAR_H
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(bottom)
	_bars = [top, bottom]

	# location title (lower left)
	_title_box = VBoxContainer.new()
	_title_box.anchor_top = 0.64
	_title_box.anchor_bottom = 0.64
	_title_box.offset_left = 90.0
	_title_box.offset_right = 700.0
	_title_box.modulate.a = 0.0
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_title_box)
	_title_box.add_child(_make_label("KI BARATAN, ROMULUS", 28, Color(0.92, 0.96, 0.94)))
	_title_box.add_child(_make_label("2264", 54, Color(0.92, 0.96, 0.94)))

	# classified file (right side)
	_file_panel = PanelContainer.new()
	_file_panel.anchor_left = 1.0
	_file_panel.anchor_right = 1.0
	_file_panel.anchor_top = 0.5
	_file_panel.anchor_bottom = 0.5
	_file_panel.offset_left = -560.0
	_file_panel.offset_right = -60.0
	_file_panel.offset_top = -190.0
	_file_panel.offset_bottom = 190.0
	_file_panel.visible = false
	_file_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color(0.02, 0.07, 0.06, 0.78)
	fstyle.border_color = GREEN
	fstyle.set_border_width_all(2)
	fstyle.set_content_margin_all(18)
	_file_panel.add_theme_stylebox_override("panel", fstyle)
	_ui.add_child(_file_panel)
	var fbox := VBoxContainer.new()
	fbox.add_theme_constant_override("separation", 12)
	_file_panel.add_child(fbox)
	var head := _make_label("CLASSIFIED  //  SECURITY DEPARTMENT", 14, GREEN)
	fbox.add_child(head)
	_file_rows.append(head)
	var rows: Array = [
		["bar", 380], ["text", "OMEGA CLEARANCE"], ["bar", 440], ["bar", 300],
		["text", "PROJECT STATUS: ACTIVE"], ["bar", 410],
		["text", "AUTHORIZATION: SECURITY DEPARTMENT HIGH COMMAND"], ["bar", 350], ["bar", 220],
	]
	for row in rows:
		var node: Control
		if String(row[0]) == "bar":
			var bar := Panel.new()
			bar.custom_minimum_size = Vector2(float(row[1]), 22.0)
			var bstyle := StyleBoxFlat.new()
			bstyle.bg_color = Color(0.0, 0.0, 0.0, 0.95)
			bstyle.border_color = Color(0.2, 0.55, 0.42)
			bstyle.set_border_width_all(1)
			bar.add_theme_stylebox_override("panel", bstyle)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node = bar
		else:
			var lbl := _make_label(String(row[1]), 17, Color(0.7, 1.0, 0.86))
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.custom_minimum_size = Vector2(440.0, 0.0)
			node = lbl
		fbox.add_child(node)
		_file_rows.append(node)

	# centre-top callout
	_callout_box = VBoxContainer.new()
	_callout_box.anchor_left = 0.2
	_callout_box.anchor_right = 0.8
	_callout_box.offset_top = BAR_H + 46.0
	_callout_box.modulate.a = 0.0
	_callout_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_callout_box)
	_callout_title = _make_label("", 22, GREEN)
	_callout_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout_box.add_child(_callout_title)
	_callout_value = _make_label("", 76, AMBER)
	_callout_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout_box.add_child(_callout_value)

	# subtitles
	_sub_panel = PanelContainer.new()
	_sub_panel.anchor_left = 0.14
	_sub_panel.anchor_right = 0.86
	_sub_panel.anchor_top = 1.0
	_sub_panel.anchor_bottom = 1.0
	_sub_panel.offset_top = -(BAR_H + 92.0)
	_sub_panel.offset_bottom = -(BAR_H + 16.0)
	_sub_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sub_panel.visible = false
	_sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sstyle := StyleBoxFlat.new()
	sstyle.bg_color = Color(0.0, 0.0, 0.0, 0.74)
	sstyle.border_color = GOLD
	sstyle.set_border_width_all(2)
	sstyle.content_margin_left = 16
	sstyle.content_margin_right = 16
	sstyle.content_margin_top = 8
	sstyle.content_margin_bottom = 8
	_sub_panel.add_theme_stylebox_override("panel", sstyle)
	_ui.add_child(_sub_panel)
	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 2)
	_sub_panel.add_child(svbox)
	_sub_speaker = _make_label("", 15, GOLD)
	svbox.add_child(_sub_speaker)
	_sub_text = _make_label("", 19, Color(0.97, 0.97, 0.95))
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	svbox.add_child(_sub_text)

	# skip hint
	var hint := _make_label("ESC  -  SKIP", 12, Color(1, 1, 1, 0.38))
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -150.0
	hint.offset_right = -24.0
	hint.offset_top = -(BAR_H * 0.5 + 10.0)
	hint.offset_bottom = -(BAR_H * 0.5 - 10.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(hint)

	# above-the-black layer: the closing card, and the fade itself
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_ui.add_child(_black)
	_five_years = _make_label("FIVE YEARS LATER", 38, Color(0.96, 0.96, 0.94))
	_five_years.set_anchors_preset(Control.PRESET_FULL_RECT)
	_five_years.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_five_years.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_five_years.modulate.a = 0.0
	_top_ui.add_child(_five_years)


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _load_font() -> Font:
	for path in FONT_PATHS:
		if ResourceLoader.exists(path):
			var f: Font = load(path)
			if f != null:
				return f
	return null


## Music is held back until the second shot (the opening is city ambience only).
func _start_music() -> void:
	if _music != null:
		return
	_music = _make_player(MUSIC_PATHS, false)
	if _music != null:
		_music.volume_db = -40.0
		_music.play()
		create_tween().tween_property(_music, "volume_db", 0.0, 3.0)


func _set_ambience(paths: Array) -> void:
	if _ambience != null:
		_ambience.queue_free()
		_ambience = null
	if paths.is_empty():
		return
	_ambience = _make_player(paths, true, "Ambient")
	if _ambience != null:
		_ambience.play()


func _make_player(paths: Array, loop: bool, bus_name: String = "Music") -> AudioStreamPlayer:
	for path in paths:
		if ResourceLoader.exists(String(path)):
			var stream: AudioStream = load(String(path))
			if stream != null:
				if loop and "loop" in stream:
					stream.set("loop", true)
				var p := AudioStreamPlayer.new()
				p.bus = bus_name if AudioServer.get_bus_index(bus_name) >= 0 else "Master"
				p.stream = stream
				add_child(p)
				return p
	return null


# ===========================================================================
# WORLD: environments
# ===========================================================================

func _build_environments() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.015, 0.04, 0.055)
	sky_mat.sky_horizon_color = Color(0.16, 0.34, 0.3)
	sky_mat.ground_horizon_color = Color(0.08, 0.17, 0.16)
	sky_mat.ground_bottom_color = Color(0.01, 0.03, 0.03)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env_city = Environment.new()
	_env_city.background_mode = Environment.BG_SKY
	_env_city.sky = sky
	_env_city.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env_city.ambient_light_energy = 0.6
	_env_city.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env_city.glow_enabled = true
	_env_city.glow_intensity = 0.9
	_env_city.fog_enabled = true
	_env_city.fog_light_color = Color(0.07, 0.17, 0.15)
	_env_city.fog_density = 0.0011

	_env_room = Environment.new()
	_env_room.background_mode = Environment.BG_COLOR
	_env_room.background_color = Color.BLACK
	_env_room.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env_room.ambient_light_color = Color(0.35, 0.55, 0.52)
	_env_room.ambient_light_energy = 0.9
	_env_room.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env_room.glow_enabled = true
	_env_room.glow_intensity = 1.0
	_env_room.glow_bloom = 0.1

	_world_env = WorldEnvironment.new()
	_world_env.environment = _env_city
	add_child(_world_env)


# ===========================================================================
# WORLD: Ki Baratan
# ===========================================================================

func _build_city() -> void:
	_city = Node3D.new()
	_city.name = "KiBaratan"
	add_child(_city)

	var rng := RandomNumberGenerator.new()
	rng.seed = 2264

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-8.0, 30.0, 0.0)
	sun.light_color = Color(0.45, 0.8, 0.7)
	sun.light_energy = 0.6
	_city.add_child(sun)

	# sea
	var water_mat := _mat(Color(0.02, 0.06, 0.07), 0.7, 0.12)
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(9000.0, 9000.0)
	_mesh(_city, water_mesh, water_mat, Vector3.ZERO)

	# land
	var land_mesh := BoxMesh.new()
	land_mesh.size = Vector3(3200.0, 6.0, 1700.0)
	_mesh(_city, land_mesh, _mat(Color(0.05, 0.06, 0.06), 0.1, 0.8), Vector3(0, 0, -1000))

	# the shoreline, picked out in soft lights
	var shore := BoxMesh.new()
	shore.size = Vector3(3200.0, 0.6, 2.0)
	_mesh(_city, shore, _glow(Color(0.9, 0.75, 0.5), 0.5), Vector3(0, 3.2, -151))

	# Remus hangs in the sky
	var planet_shader := Shader.new()
	planet_shader.code = PLANET_SHADER_CODE
	var planet_mat := ShaderMaterial.new()
	planet_mat.shader = planet_shader
	var remus := SphereMesh.new()
	remus.radius = 150.0
	remus.height = 300.0
	_mesh(_city, remus, planet_mat, Vector3(520, 250, -1500))

	# towers: one MultiMesh for every tower in every circular district
	var window_shader := Shader.new()
	window_shader.code = WINDOW_SHADER_CODE
	var window_mat := ShaderMaterial.new()
	window_mat.shader = window_shader
	var tower_mesh := BoxMesh.new()
	tower_mesh.size = Vector3.ONE
	var transforms: Array[Transform3D] = []
	var districts: Array = [
		[Vector3(-300, 0, -520), 120.0], [Vector3(310, 0, -560), 130.0],
		[Vector3(-130, 0, -900), 140.0], [Vector3(360, 0, -900), 110.0],
		[Vector3(-520, 0, -820), 110.0], [Vector3(130, 0, -1250), 150.0],
		[Vector3(-420, 0, -1200), 120.0],
	]
	for d in districts:
		var centre: Vector3 = d[0]
		var radius: float = d[1]
		# the district's circular plaza
		var plaza := CylinderMesh.new()
		plaza.top_radius = radius
		plaza.bottom_radius = radius
		plaza.height = 0.8
		_mesh(_city, plaza, _glow(Color(0.1, 0.35, 0.28), 0.25), centre + Vector3(0, 3.2, 0))
		var rings: Array = [[0.35, 10, 45.0, 85.0], [0.65, 18, 28.0, 62.0], [0.92, 26, 16.0, 40.0]]
		for ring in rings:
			var count: int = ring[1]
			for i in count:
				var ang := TAU * float(i) / float(count) + rng.randf() * 0.1
				var h := rng.randf_range(float(ring[2]), float(ring[3]))
				var w := rng.randf_range(5.0, 9.0)
				var pos := centre + Vector3(sin(ang), 0.0, cos(ang)) * radius * float(ring[0])
				pos.y = 3.6 + h * 0.5
				var tower_basis := Basis(Vector3.UP, ang) * Basis.from_scale(Vector3(w, h, w))
				transforms.append(Transform3D(tower_basis, pos))
		var spire_h := rng.randf_range(120.0, 170.0)
		var spire_basis := Basis.from_scale(Vector3(11.0, spire_h, 11.0))
		transforms.append(Transform3D(spire_basis, centre + Vector3(0, 3.6 + spire_h * 0.5, 0)))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = tower_mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var multi_node := MultiMeshInstance3D.new()
	multi_node.multimesh = multi
	multi_node.material_override = window_mat
	_city.add_child(multi_node)

	_build_complex(Vector3(0, 0, -420))


## The Romulan Security Department: a stepped, circular government complex.
func _build_complex(centre: Vector3) -> void:
	var stone := _mat(Color(0.07, 0.085, 0.085), 0.4, 0.5)
	var ring_glow := _glow(Color(0.55, 0.95, 0.8), 0.9)
	var tiers: Array = [[78.0, 16.0], [58.0, 14.0], [40.0, 26.0]]
	var y := 3.6
	for t in tiers:
		var radius: float = t[0]
		var height: float = t[1]
		var c := CylinderMesh.new()
		c.top_radius = radius
		c.bottom_radius = radius
		c.height = height
		_mesh(_city, c, stone, centre + Vector3(0, y + height * 0.5, 0))
		var band := CylinderMesh.new()
		band.top_radius = radius + 0.4
		band.bottom_radius = radius + 0.4
		band.height = 0.9
		_mesh(_city, band, ring_glow, centre + Vector3(0, y + height - 0.6, 0))
		y += height
	# dome and needle
	var dome := SphereMesh.new()
	dome.radius = 26.0
	dome.height = 30.0
	_mesh(_city, dome, stone, centre + Vector3(0, y, 0))
	var needle := CylinderMesh.new()
	needle.top_radius = 0.6
	needle.bottom_radius = 2.2
	needle.height = 70.0
	_mesh(_city, needle, _mat(Color(0.08, 0.1, 0.1), 0.6, 0.4), centre + Vector3(0, y + 40.0, 0))
	_mesh(_city, SphereMesh.new(), _glow(Color(1.0, 0.8, 0.5), 2.5), centre + Vector3(0, y + 76.0, 0))
	# pylons around the outside
	for i in 12:
		var ang := TAU * float(i) / 12.0
		var pylon := BoxMesh.new()
		pylon.size = Vector3(4.0, 52.0, 4.0)
		var p := centre + Vector3(sin(ang), 0, cos(ang)) * 98.0 + Vector3(0, 3.6 + 26.0, 0)
		_mesh(_city, pylon, stone, p)
		var tip := BoxMesh.new()
		tip.size = Vector3(4.4, 1.2, 4.4)
		_mesh(_city, tip, ring_glow, p + Vector3(0, 26.0, 0))
	# forecourt
	var court := CylinderMesh.new()
	court.top_radius = 125.0
	court.bottom_radius = 125.0
	court.height = 0.8
	_mesh(_city, court, _glow(Color(0.12, 0.3, 0.25), 0.22), centre + Vector3(0, 3.3, 0))
	# tiny figures on the forecourt, for scale
	var fig_rng := RandomNumberGenerator.new()
	fig_rng.seed = 7
	var fig_mesh := CapsuleMesh.new()
	fig_mesh.radius = 0.35
	fig_mesh.height = 1.7
	var fig_mat := _mat(Color(0.04, 0.045, 0.05), 0.0, 0.9)
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.2
	lamp_mesh.height = 0.4
	var lamp_mat := _glow(Color(1.0, 0.75, 0.4), 3.0)
	for i in 34:
		var a := fig_rng.randf() * TAU
		var d := fig_rng.randf_range(84.0, 120.0)
		var fp := centre + Vector3(sin(a) * d, 4.6, cos(a) * d)
		_mesh(_city, fig_mesh, fig_mat, fp)
		_mesh(_city, lamp_mesh, lamp_mat, fp + Vector3(0.5, 0.6, 0.0))
	# a few vehicles gliding between districts
	var veh_mesh := BoxMesh.new()
	veh_mesh.size = Vector3(4.0, 0.8, 1.6)
	var veh_mat := _glow(Color(1.0, 0.85, 0.6), 2.2)
	for i in 16:
		var v := _mesh(_city, veh_mesh, veh_mat, Vector3.ZERO)
		var from := Vector3(fig_rng.randf_range(-450.0, 450.0), fig_rng.randf_range(18.0, 70.0), fig_rng.randf_range(-1100.0, -260.0))
		var to := from + Vector3(fig_rng.randf_range(-260.0, 260.0), fig_rng.randf_range(-6.0, 6.0), fig_rng.randf_range(-160.0, 160.0))
		v.position = from
		v.look_at_from_position(from, to, Vector3.UP)
		var vt := v.create_tween()
		vt.set_loops()
		vt.tween_property(v, "position", to, fig_rng.randf_range(40.0, 70.0))
		vt.tween_property(v, "position", from, 0.01)
	# glow on the nearby surfaces
	for off in [Vector3(0, 40, 110), Vector3(-90, 30, 40), Vector3(90, 30, 40)]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.6, 0.95, 0.85)
		l.light_energy = 1.2
		l.omni_range = 170.0
		l.position = centre + off
		_city.add_child(l)


# ===========================================================================
# WORLD: the Strategic Operations Centre
# ===========================================================================

func _build_room() -> void:
	_room = Node3D.new()
	_room.name = "OperationsCentre"
	_room.position = ROOM
	add_child(_room)

	var dark := _mat(Color(0.11, 0.13, 0.14), 0.3, 0.55)
	var floor_mat := _mat(Color(0.06, 0.08, 0.09), 0.5, 0.4)
	var green_dim := _glow(Color(0.12, 0.5, 0.36), 0.7)

	# floor, wall, ceiling
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 14.0
	floor_mesh.bottom_radius = 14.0
	floor_mesh.height = 0.2
	_mesh(_room, floor_mesh, floor_mat, Vector3(0, -0.1, 0))
	var wall := CylinderMesh.new()
	wall.top_radius = 14.0
	wall.bottom_radius = 14.0
	wall.height = 9.0
	var wall_mat := _mat(Color(0.09, 0.11, 0.12), 0.2, 0.6)
	wall_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_mesh(_room, wall, wall_mat, Vector3(0, 4.5, 0))
	var ceiling := CylinderMesh.new()
	ceiling.top_radius = 14.0
	ceiling.bottom_radius = 14.0
	ceiling.height = 0.2
	_mesh(_room, ceiling, dark, Vector3(0, 9.1, 0))

	# wall light slits and a light band (skipping the doorway at +Z)
	for i in 44:
		var ang := TAU * float(i) / 44.0
		if absf(wrapf(ang + PI, 0.0, TAU) - PI) < 0.3:
			continue
		var slit := BoxMesh.new()
		slit.size = Vector3(0.12, 4.0, 0.1)
		var p := Vector3(sin(ang), 0.0, cos(ang)) * 13.85 + Vector3(0, 4.6, 0)
		var m := _mesh(_room, slit, green_dim, p)
		m.rotation.y = ang
	var band := CylinderMesh.new()
	band.top_radius = 13.9
	band.bottom_radius = 13.9
	band.height = 0.12
	band.cap_top = false
	band.cap_bottom = false
	var band_mat := _glow(Color(0.1, 0.45, 0.32), 1.0)
	band_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_mesh(_room, band, band_mat, Vector3(0, 7.4, 0))

	# central dais, command table, table screen
	var dais := CylinderMesh.new()
	dais.top_radius = 3.2
	dais.bottom_radius = 3.3
	dais.height = 0.35
	_mesh(_room, dais, _mat(Color(0.03, 0.04, 0.045), 0.7, 0.3), Vector3(0, 0.175, 0))
	var dais_rim := CylinderMesh.new()
	dais_rim.top_radius = 3.3
	dais_rim.bottom_radius = 3.3
	dais_rim.height = 0.05
	dais_rim.cap_top = false
	dais_rim.cap_bottom = false
	_mesh(_room, dais_rim, _glow(GREEN, 1.6), Vector3(0, 0.36, 0))
	var base := CylinderMesh.new()
	base.top_radius = 0.9
	base.bottom_radius = 1.1
	base.height = 0.8
	_mesh(_room, base, dark, Vector3(0, 0.75, 0))
	var top := CylinderMesh.new()
	top.top_radius = 1.8
	top.bottom_radius = 1.8
	top.height = 0.15
	_mesh(_room, top, dark, Vector3(0, 1.225, 0))
	_table_screen_mat = _glow(Color(0.15, 0.7, 0.5), 1.2)
	var screen := CylinderMesh.new()
	screen.top_radius = 1.62
	screen.bottom_radius = 1.62
	screen.height = 0.02
	_mesh(_room, screen, _table_screen_mat, Vector3(0, 1.31, 0))

	# station consoles around the ring, and the officers behind them
	var station_count := 22
	var crowd_every := 2
	for i in station_count:
		var ang := TAU * float(i) / float(station_count)
		if absf(wrapf(ang + PI, 0.0, TAU) - PI) < 0.6:
			continue   # leave the doorway clear
		var desk := BoxMesh.new()
		desk.size = Vector3(2.4, 0.9, 0.8)
		var dp := Vector3(sin(ang), 0.0, cos(ang)) * 9.2 + Vector3(0, 0.45, 0)
		var desk_node := _mesh(_room, desk, dark, dp)
		desk_node.rotation.y = ang
		var scr := BoxMesh.new()
		scr.size = Vector3(2.0, 0.03, 0.55)
		var screen_node := _mesh(_room, scr, _glow(Color(0.1, 0.55, 0.4) if i % 3 != 0 else Color(0.7, 0.45, 0.15), 1.1), dp + Vector3(sin(ang), 0.0, cos(ang)) * -0.02 + Vector3(0, 0.48, 0))
		screen_node.rotation.y = ang
		if i % crowd_every == 0:
			var officer := _make_officer(false)
			officer.position = Vector3(sin(ang), 0.0, cos(ang)) * 10.3
			_room.add_child(officer)
			_face(officer, Vector3.ZERO)
			officer.scale.y = 0.62   # seated until the Director arrives
			_crowd.append(officer)

	# the three speaking characters
	_ops = _make_real_ops()
	if _ops == null:
		_ops = _make_officer(false)
	_ops.position = Vector3(-1.9, 0.35, -0.4)
	_room.add_child(_ops)
	_face(_ops, Vector3(0, 0, 1.2))
	_analyst = _make_real_analyst()
	if _analyst == null:
		_analyst = _make_officer(false)
	_analyst.position = Vector3(3.2, 0.35, -2.6)
	_room.add_child(_analyst)
	_face(_analyst, Vector3(0, 0, 0))
	_director = _make_real_director()
	if _director == null:
		_director = _make_officer(true)
	_director.position = Vector3(0, 0, 13.5)
	_director.visible = false
	_room.add_child(_director)
	_director_head = _director.get_node("Head")
	_director_arm = _director.get_node("ArmR")
	_mouth_l = _director_head.get_node("MouthL")
	_mouth_r = _director_head.get_node("MouthR")

	# the doors, and the bright corridor behind them
	var corridor := QuadMesh.new()
	corridor.size = Vector2(2.6, 4.3)
	var corridor_node := _mesh(_room, corridor, _glow(Color(0.55, 0.85, 0.75), 1.6), Vector3(0, 2.15, 13.84))
	corridor_node.rotation.y = PI
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.4, 4.3, 0.3)
	var door_mat := _mat(Color(0.04, 0.05, 0.055), 0.6, 0.35)
	_door_left = _mesh(_room, door_mesh, door_mat, Vector3(-0.7, 2.15, 13.7))
	_door_right = _mesh(_room, door_mesh, door_mat, Vector3(0.7, 2.15, 13.7))
	var edge := BoxMesh.new()
	edge.size = Vector3(0.06, 4.0, 0.32)
	var el := _mesh(_door_left, edge, _glow(GREEN, 2.0), Vector3(0.67, 0, 0))
	var er := _mesh(_door_right, edge, _glow(GREEN, 2.0), Vector3(-0.67, 0, 0))
	el.name = "EdgeL"
	er.name = "EdgeR"
	_door_spill = SpotLight3D.new()
	_door_spill.position = Vector3(0, 3.8, 13.4)
	_door_spill.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	_door_spill.light_color = Color(0.82, 1.0, 0.92)
	_door_spill.light_energy = 0.0
	_door_spill.spot_range = 24.0
	_door_spill.spot_angle = 38.0
	_door_spill.visible = false
	_room.add_child(_door_spill)

	# lighting over the table
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 8.6, 0)
	spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	spot.light_color = Color(0.7, 1.0, 0.9)
	spot.light_energy = 3.2
	spot.spot_range = 14.0
	spot.spot_angle = 24.0
	_room.add_child(spot)
	_room_lights.append(spot)
	var holo_light := OmniLight3D.new()
	holo_light.position = Vector3(0, 2.4, 0)
	holo_light.light_color = Color(0.3, 1.0, 0.7)
	holo_light.light_energy = 1.5
	holo_light.omni_range = 9.0
	_room.add_child(holo_light)
	_room_lights.append(holo_light)
	_room_lights.append(_door_spill)

	_build_holo_map()


## The rotating holographic map above the command table.
func _build_holo_map() -> void:
	_holo = Node3D.new()
	_holo.position = Vector3(0, 2.35, 0)
	_room.add_child(_holo)
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	_holo.add_child(tilt)
	_holo_zoom = Node3D.new()
	tilt.add_child(_holo_zoom)

	var rng := RandomNumberGenerator.new()
	rng.seed = 64

	var disc := CylinderMesh.new()
	disc.top_radius = 1.75
	disc.bottom_radius = 1.75
	disc.height = 0.01
	_mesh(_holo_zoom, disc, _holo_mat(GREEN, 0.10), Vector3.ZERO)
	for r in [0.6, 1.2, 1.74]:
		var ring := TorusMesh.new()
		ring.inner_radius = float(r) - 0.006
		ring.outer_radius = float(r) + 0.006
		_mesh(_holo_zoom, ring, _holo_mat(GREEN, 0.5), Vector3.ZERO)

	_holo_cluster(Vector3(-1.0, 0.0, -0.15), Vector2(0.55, 0.5), 16, Color(0.35, 1.0, 0.65), "ROMULAN STAR EMPIRE", rng)
	_holo_cluster(Vector3(1.0, 0.0, 0.1), Vector2(0.7, 0.6), 24, Color(0.35, 0.8, 1.0), "THE FEDERATION", rng)

	var zone := BoxMesh.new()
	zone.size = Vector3(0.05, 0.02, 1.3)
	_mesh(_holo_zoom, zone, _holo_mat(AMBER, 0.6), Vector3(-0.1, 0.0, 0.0))
	_holo_label("NEUTRAL ZONE", Vector3(-0.1, 0.1, 0.78), AMBER, 0.0012)

	var vulcan := SphereMesh.new()
	vulcan.radius = 0.06
	vulcan.height = 0.12
	_mesh(_holo_zoom, vulcan, _holo_mat(AMBER, 1.0), _vulcan_local)
	var vring := TorusMesh.new()
	vring.inner_radius = 0.12
	vring.outer_radius = 0.126
	_mesh(_holo_zoom, vring, _holo_mat(AMBER, 0.9), _vulcan_local)
	_holo_label("VULCAN", _vulcan_local + Vector3(0, 0.12, 0.0), AMBER, 0.0014)
	_vulcan_marker = Node3D.new()
	_vulcan_marker.position = _vulcan_local
	_holo_zoom.add_child(_vulcan_marker)
	_build_holo_planet()


## The big holographic Vulcan for the Director's closing shot. Uses our own
## topography map (drawn as amber light) when it exists.
func _build_holo_planet() -> void:
	_planet_holo = Node3D.new()
	_planet_holo.position = Vector3(0, 2.4, 0)
	_planet_holo.rotation_degrees = Vector3(0.0, 0.0, 10.0)
	_planet_holo.visible = false
	_room.add_child(_planet_holo)
	var shader := Shader.new()
	shader.code = HOLO_PLANET_SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("tint", AMBER)
	if ResourceLoader.exists("res://assets/textures/vulcan_topography.png"):
		var tex: Texture2D = load("res://assets/textures/vulcan_topography.png")
		if tex != null:
			m.set_shader_parameter("map_tex", tex)
			m.set_shader_parameter("use_map", 1.0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	sphere.radial_segments = 64
	sphere.rings = 32
	_mesh(_planet_holo, sphere, m, Vector3.ZERO)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.12
	ring.outer_radius = 1.125
	_mesh(_planet_holo, ring, _holo_mat(AMBER, 0.7), Vector3.ZERO)
	var pl := OmniLight3D.new()
	pl.light_color = Color(1.0, 0.7, 0.35)
	pl.light_energy = 1.2
	pl.omni_range = 7.0
	_planet_holo.add_child(pl)


func _holo_cluster(centre: Vector3, spread: Vector2, count: int, color: Color, label: String, rng: RandomNumberGenerator) -> void:
	var haze := SphereMesh.new()
	haze.radius = spread.x * 0.95
	haze.height = spread.x * 1.9
	var haze_node := _mesh(_holo_zoom, haze, _holo_mat(color, 0.16), centre)
	haze_node.scale = Vector3(1.0, 0.18, spread.y / spread.x)
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf())
		var p := centre + Vector3(cos(a) * spread.x * d, rng.randf_range(-0.03, 0.05), sin(a) * spread.y * d)
		var s := SphereMesh.new()
		var rad := rng.randf_range(0.015, 0.04)
		s.radius = rad
		s.height = rad * 2.0
		_mesh(_holo_zoom, s, _holo_mat(color, 0.9), p)
	_holo_label(label, centre + Vector3(0, 0.15, spread.y + 0.12), color, 0.0012)
	if label == "THE FEDERATION":
		_fed_marker = Node3D.new()
		_fed_marker.position = centre
		_holo_zoom.add_child(_fed_marker)


func _holo_label(text: String, pos: Vector3, color: Color, pixel_size: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = pixel_size
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = color
	l.outline_size = 4
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.position = pos
	if _font != null:
		l.font = _font
	_holo_zoom.add_child(l)


## REV 756 (Glen): the Director IS Varel (same voice - REV 342) - his real Genesis 9 model, in his Romulan
## commander's uniform, when it's in the project (CharacterKit.REAL_MODELS["varel"]); else the stand-in below.
## The timeline moves the Director by hand (position, turns, a hand on the table, mouth halves); the real
## figure rides inside a pivot that keeps those moves: the animator sees the pivot move and walks, turns
## become real turns, the hand goes down on the table by arm IK, his mouth follows his own lines, the smile
## is his face's. The Head / ArmR / MouthL / MouthR nodes the timeline tweens are kept as empty markers.
const DIRECTOR_KEY := "varel"
const DIRECTOR_TABLE_TOUCH := Vector3(0.0, 1.31, 1.72)   # the command table's near edge, in front of him (room space)
const DIRECTOR_SPEECH_DIR := "res://episodes/prologue/audio/speech/romulans/"
var _director_fig: Node3D = null      # the real figure (null with the stand-in)
var _director_face: CharacterFace = null
var _director_anim: CharacterAnimator = null


func _make_real_director() -> Node3D:
	var path := String(CharacterKit.REAL_MODELS.get(DIRECTOR_KEY, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var fig := CharacterKit.make_named(DIRECTOR_KEY, {"solid": false})
	if fig == null:
		return null
	var pivot := Node3D.new()
	pivot.name = "Director"
	# the timeline's markers (empty - the real figure does these itself)
	var head := Node3D.new()
	head.name = "Head"
	pivot.add_child(head)
	for nm in ["MouthL", "MouthR"]:
		var m := Node3D.new()
		m.name = nm
		head.add_child(m)
	var arm := Node3D.new()
	arm.name = "ArmR"
	pivot.add_child(arm)
	# the stand-in looks toward -Z; Daz figures face +Z
	fig.rotation.y = PI
	pivot.add_child(fig)
	_director_fig = fig
	_director_face = CharacterFace.face_of(fig)
	_director_anim = CharacterKit.animator_of(fig)
	return pivot


## His mouth follows his own lines only (other voices share the Dialogue bus); no recording yet -> he mimes it.
func _director_talks(line: Array, on: bool) -> void:
	if String(line[0]) == "ANALYSIS OFFICER" and _analyst_face != null:
		_talk(_analyst_face, line, on)
		return
	if String(line[0]) == "OPERATIONS OFFICER" and _ops_face != null:
		_talk(_ops_face, line, on)
		return
	if _director_face == null or String(line[0]) != "DIRECTOR":
		return
	_talk(_director_face, line, on)


## REV 845: the Analysis Officer IS Kovek (same voice - REV 342): her real Genesis 9 model in her lieutenant's uniform
## when it's in the project (CharacterKit.REAL_MODELS["kovek"]); else the stand-in. Inside a pivot like the Director's,
## so the timeline's step forward (it moves the pivot) becomes a real walk, and her own face follows her lines.
const ANALYST_KEY := "kovek"
const ANALYST_HEIGHT_EYE := 1.57   # her eyes above her feet (she's 1.67 m); the dais adds 0.35
var _analyst_face: CharacterFace = null
var _analyst_eye := 2.05             # where the analyst shots look (the stand-in's eyes)


func _make_real_analyst() -> Node3D:
	var path := String(CharacterKit.REAL_MODELS.get(ANALYST_KEY, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var fig := CharacterKit.make_named(ANALYST_KEY, {"solid": false})
	if fig == null:
		return null
	var pivot := Node3D.new()
	pivot.name = "Analyst"
	fig.rotation.y = PI   # the stand-in looks toward -Z; Daz figures face +Z
	pivot.add_child(fig)
	_analyst_face = CharacterFace.face_of(fig)
	_analyst_eye = 0.35 + ANALYST_HEIGHT_EYE
	return pivot


## REV 847: the Operations Officer IS Tovan (Matt 9 in the same lieutenant's blue as Kovek, Mavick hair added from
## the Daz library) - his real model when it's in the project, else the stand-in. Same pivot set-up as the analyst.
const OPS_KEY := "tovan"
const OPS_HEIGHT_EYE := 1.62       # his eyes above his feet (he's 1.73 m); the dais adds 0.35
var _ops_face: CharacterFace = null
var _ops_eye := 2.05


func _make_real_ops() -> Node3D:
	var path := String(CharacterKit.REAL_MODELS.get(OPS_KEY, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var fig := CharacterKit.make_named(OPS_KEY, {"solid": false})
	if fig == null:
		return null
	var pivot := Node3D.new()
	pivot.name = "OpsOfficer"
	fig.rotation.y = PI
	pivot.add_child(fig)
	_ops_face = CharacterFace.face_of(fig)
	_ops_eye = 0.35 + OPS_HEIGHT_EYE
	return pivot


## A real figure's mouth on its own line. REV 853 (Glen): the line's lip-sync file (<id>.json beside the mp3,
## made REV 245 - the Romulans never used them until now) drives Daz's mouth shapes sound by sound; a recording
## without one -> the mouth listens to the voice; no recording -> mimed.
func _talk(face: CharacterFace, line: Array, on: bool) -> void:
	if not on:
		face.stop_lipsync()
		face.talk_from_bus("")
		face.talk_mime(false)
		return
	var mp3 := DIRECTOR_SPEECH_DIR + String(line[1])   # every cold-open voice is in there
	var cues: Array = CharacterFace.load_rhubarb(mp3.get_basename() + ".json")
	if not cues.is_empty() and AudioSubtitleManager.voice_player().playing:
		face.play_lipsync(cues, AudioSubtitleManager.voice_player())
	elif ResourceLoader.exists(mp3):
		face.talk_from_bus("Dialogue")
	else:
		face.talk_mime(true, false)


## A stand-in Romulan: dark uniform, pointed ears, gold insignia. The Director is
## taller and wears a long cloak with a mantle.
func _make_officer(is_director: bool) -> Node3D:
	var root := Node3D.new()
	var k := 1.08 if is_director else 1.0
	var uniform := _mat(Color(0.13, 0.16, 0.15) if not is_director else Color(0.08, 0.1, 0.1), 0.2, 0.65)
	var skin := _mat(Color(0.52, 0.5, 0.42), 0.0, 0.7)
	var trim := _glow(AMBER, 1.6)
	if is_director:
		var cloak := CylinderMesh.new()
		cloak.top_radius = 0.26
		cloak.bottom_radius = 0.52
		cloak.height = 1.6 * k
		_mesh(root, cloak, uniform, Vector3(0, 0.8 * k, 0))
		var mantle := BoxMesh.new()
		mantle.size = Vector3(0.74, 0.16, 0.42)
		_mesh(root, mantle, uniform, Vector3(0, 1.52 * k, 0))
		var collar := BoxMesh.new()
		collar.size = Vector3(0.76, 0.03, 0.44)
		_mesh(root, collar, trim, Vector3(0, 1.45 * k, 0))
	else:
		var body := CapsuleMesh.new()
		body.radius = 0.25
		body.height = 1.55
		_mesh(root, body, uniform, Vector3(0, 0.78, 0))
		var badge := BoxMesh.new()
		badge.size = Vector3(0.12, 0.08, 0.02)
		_mesh(root, badge, trim, Vector3(0.1, 1.2, -0.24))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.72 * k, 0)
	root.add_child(head)
	var skull := SphereMesh.new()
	skull.radius = 0.16
	skull.height = 0.34
	_mesh(head, skull, skin, Vector3.ZERO)
	var hair := SphereMesh.new()
	hair.radius = 0.17
	hair.height = 0.18
	_mesh(head, hair, _mat(Color(0.02, 0.02, 0.02), 0.0, 0.9), Vector3(0, 0.07, 0.03))
	# face (the character looks toward -Z): eyes, Romulan brows, a mouth in two halves
	var eye_mat := _mat(Color(0.015, 0.015, 0.015), 0.0, 0.4)
	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.017
		eye.height = 0.034
		_mesh(head, eye, eye_mat, Vector3(0.055 * side, 0.02, -0.145))
		var brow := BoxMesh.new()
		brow.size = Vector3(0.07, 0.012, 0.012)
		var b := _mesh(head, brow, eye_mat, Vector3(0.058 * side, 0.058, -0.14))
		b.rotation_degrees = Vector3(0.0, 0.0, 16.0 * side)
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(0.04, 0.009, 0.01)
	var mouth_l := _mesh(head, mouth_mesh, eye_mat, Vector3(-0.02, -0.075, -0.143))
	mouth_l.name = "MouthL"
	var mouth_r := _mesh(head, mouth_mesh, eye_mat, Vector3(0.02, -0.075, -0.143))
	mouth_r.name = "MouthR"
	if is_director:
		var arm := Node3D.new()
		arm.name = "ArmR"
		arm.position = Vector3(0.3, 1.52 * k, 0.0)
		root.add_child(arm)
		var sleeve := CylinderMesh.new()
		sleeve.top_radius = 0.07
		sleeve.bottom_radius = 0.055
		sleeve.height = 0.94
		_mesh(arm, sleeve, uniform, Vector3(0, -0.47, 0))
		var hand := SphereMesh.new()
		hand.radius = 0.065
		hand.height = 0.13
		_mesh(arm, hand, skin, Vector3(0, -0.98, 0))
	for side in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.035
		ear.height = 0.12
		var e := _mesh(head, ear, skin, Vector3(0.16 * side, 0.03, 0.0))
		e.rotation_degrees = Vector3(0.0, 0.0, -75.0 * side)
	return root


## Turn a character (built facing -Z) to face a point, ignoring height.
func _face(node: Node3D, target: Vector3) -> void:
	var d := target - node.position
	node.rotation.y = atan2(-d.x, -d.z)


# ===========================================================================
# material / mesh helpers
# ===========================================================================

func _mat(color: Color, metallic: float = 0.0, rough: float = 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color * 0.25
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _holo_mat(color: Color, alpha: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = HOLO_SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("alpha", alpha)
	return m


func _mesh(parent: Node, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
