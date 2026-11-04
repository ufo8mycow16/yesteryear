extends Node
## LookEnhancer (REV 99): one place that gives every scene a more finished look, without editing the
## scenes themselves. Whatever WorldEnvironment a scene uses, this adds on top of it:
##   - filmic tone mapping (bright lights roll off instead of clipping to flat white),
##   - a gentle glow on genuinely bright things (lit panels, lamps, displays),
##   - soft ambient shadowing where surfaces meet (SSAO), and on HIGH, bounced light (SSIL),
##   - a very slight lift in contrast and colour.
## Scene-specific choices (background, ambient colour, fog) are left alone. Settings > Graphics >
## LIGHTING switches it off ("CLASSIC" = exactly as authored). Debug builds: F7 flips it to compare.
## The quality preset decides how much is used: LOW = tone mapping and grade only; MEDIUM adds glow
## and SSAO; HIGH adds SSIL.
##
## REV 293 - who owns which look (so two things never fight over the same Environment):
##   - LookEnhancer only ever adds on top of what the scene itself set (its "own" values, snapshotted
##     the first time it sees the Environment).
##   - A scene that changes its own look later (ModelRoom's polish, the debug [P] key) first calls
##     take_back(env) - which puts the scene's own values back and forgets them - then writes its look,
##     then calls refresh(). LookEnhancer then treats the new values as the scene's own and adds on top.
##   - An Environment marked "_vf_modern" (ModernLighting, REV 170) is left alone completely.
##   - Keys: F7 = enhanced/classic (this file). Shift+F7 = ModernLighting's before/after pictures, so
##     F7 here ignores Shift (before, it relied on ModernLighting catching Shift+F7 first).

## Tuning (all in one place).
const EXPOSURE := 1.12          # filmic tone mapping darkens mid-tones a little; this brings them back
const WHITE := 6.0
const GLOW_INTENSITY := 0.45
const GLOW_BLOOM := 0.02
const GLOW_THRESHOLD := 1.05    # only things brighter than "white" glow
const SSAO_RADIUS := 1.1
const SSAO_INTENSITY := 1.6
const SSAO_POWER := 1.6
const SSIL_INTENSITY := 0.55
const CONTRAST := 1.05
const SATURATION := 1.06

## REV 640 (Glen: "the enterprise in enhanced lighting looks like it always has fluorescent lights on now... could we
## just lower the ambient lighting by a little?"): ship map rooms (env meta _vf_ship, set by EpisodeRoom for ModelRooms)
## get a little less of the even, everywhere light in ENHANCED - the scene's ambient light and the overall exposure.
const SHIP_AMBIENT := 0.78      # x the room's own ambient light energy
const SHIP_EXPOSURE := 0.92     # x the enhanced exposure

const ORIGINAL := "_vf_look_original"   # meta: the scene's own values, to put back for CLASSIC
const APPLIED := "_vf_look_applied"     # meta: which version of the look is on this Environment

var _check_t := 0.0
## REV 681 (performance pass): the WorldEnvironments in the game, kept as they're added - searching the whole scene
## four times a second for them made a small hitch every quarter second on the big decks.
var _envs: Array[WorldEnvironment] = []
var _scanned := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is WorldEnvironment and not _envs.has(n):
		_envs.append(n as WorldEnvironment)
		_check_t = 0.0          # look at it straight away


## Re-apply to the current scene (after a settings change).
func refresh() -> void:
	_check_t = 0.0
	_apply_all(true)


func _process(delta: float) -> void:
	# Scenes build or swap their environments at different times (the cold open swaps between two),
	# so look a few times a second; anything already done is skipped cheaply.
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.25
	_apply_all(false)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	# REV 293: plain F7 only - Shift+F7 belongs to ModernLighting (and does nothing in rooms without it)
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F7 and not k.shift_pressed and OS.is_debug_build():
		GameSettings.set_enhanced_lighting(not GameSettings.enhanced_lighting)
		MissionLog.notification_requested.emit("LIGHTING: " + ("ENHANCED" if GameSettings.enhanced_lighting else "CLASSIC"))
		get_viewport().set_input_as_handled()


## REV 293: a scene is about to change its own look on this Environment (ModelRoom's polish). Put the
## scene's own values back and forget them, so the next pass snapshots whatever the scene writes now
## as its own and adds the enhanced look on top of that. Call refresh() after writing.
func take_back(env: Environment) -> void:
	if env == null:
		return
	if env.has_meta(ORIGINAL):
		_restore(env, env.get_meta(ORIGINAL))
		env.remove_meta(ORIGINAL)
	if env.has_meta(APPLIED):
		env.remove_meta(APPLIED)


func _apply_all(force: bool) -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if not _scanned:
		_scanned = true
		for n in tree.root.find_children("*", "WorldEnvironment", true, false):
			if not _envs.has(n):
				_envs.append(n as WorldEnvironment)
	for i in range(_envs.size() - 1, -1, -1):
		var we := _envs[i]
		if not is_instance_valid(we):
			_envs.remove_at(i)
			continue
		if we.is_inside_tree() and we.environment != null:
			_apply(we.environment, force)
	# a Camera3D may carry its own environment too
	var cam := tree.root.get_viewport().get_camera_3d()
	if cam != null and cam.environment != null:
		_apply(cam.environment, force)


func _wanted_key() -> String:
	if not GameSettings.enhanced_lighting:
		return "classic"
	return "enhanced_%d" % _tier()


## 0 = LOW, 1 = MEDIUM, 2 = HIGH (custom counts as high).
func _tier() -> int:
	return clampi(GameSettings.quality_preset, 0, 2) if GameSettings.quality_preset < 3 else 2


func _apply(env: Environment, force: bool) -> void:
	if env.has_meta("_vf_modern"):
		return      # REV 170: a room with the modern look (ModernLighting) runs its own environment
	var want := _wanted_key()
	if not force and env.has_meta(APPLIED) and String(env.get_meta(APPLIED)) == want:
		return
	if not env.has_meta(ORIGINAL):
		env.set_meta(ORIGINAL, _snapshot(env))
	var orig: Dictionary = env.get_meta(ORIGINAL)
	_restore(env, orig)
	if want != "classic":
		_enhance(env, _tier(), orig)
	env.set_meta(APPLIED, want)


const KEYS := ["tonemap_mode", "tonemap_exposure", "tonemap_white", "glow_enabled", "glow_intensity",
	"glow_bloom", "glow_hdr_threshold", "glow_blend_mode", "ssao_enabled", "ssao_radius", "ssao_intensity",
	"ssao_power", "ssil_enabled", "ssil_intensity", "adjustment_enabled", "adjustment_contrast",
	"adjustment_saturation", "ambient_light_energy"]


func _snapshot(env: Environment) -> Dictionary:
	var d := {}
	for key in KEYS:
		d[key] = env.get(key)
	return d


func _restore(env: Environment, orig: Dictionary) -> void:
	for key in orig.keys():
		env.set(key, orig[key])


func _enhance(env: Environment, tier: int, orig: Dictionary) -> void:
	# a scene that already chose its own tone mapping / glow keeps it
	if int(orig["tonemap_mode"]) == Environment.TONE_MAPPER_LINEAR:
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = float(orig["tonemap_exposure"]) * EXPOSURE
		env.tonemap_white = WHITE
	if not bool(orig["adjustment_enabled"]):
		env.adjustment_enabled = true
		env.adjustment_contrast = CONTRAST
		env.adjustment_saturation = SATURATION
	if tier >= 1:
		if not bool(orig["glow_enabled"]):
			env.glow_enabled = true
			env.glow_intensity = GLOW_INTENSITY
			env.glow_bloom = GLOW_BLOOM
			env.glow_hdr_threshold = GLOW_THRESHOLD
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		if not bool(orig["ssao_enabled"]):
			env.ssao_enabled = true
			env.ssao_radius = SSAO_RADIUS
			env.ssao_intensity = SSAO_INTENSITY
			env.ssao_power = SSAO_POWER
	if env.has_meta("_vf_ship"):
		env.ambient_light_energy = float(orig.get("ambient_light_energy", env.ambient_light_energy)) * SHIP_AMBIENT
		env.tonemap_exposure = env.tonemap_exposure * SHIP_EXPOSURE
	if tier >= 2 and not bool(orig["ssil_enabled"]):
		env.ssil_enabled = true
		env.ssil_intensity = SSIL_INTENSITY
