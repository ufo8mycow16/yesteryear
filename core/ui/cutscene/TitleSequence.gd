extends Control
class_name TitleSequence
## SEQ_PRO_TITLES — the one-minute opening-titles sequence that plays after
## the Prologue's Uhura hand-off (strike -> intercom -> exchange -> TITLES ->
## end-of-Prologue card). Same contract as the placeholder it replaces:
## add to the tree, call play(), listen for sequence_finished.
##
## HOW IT WORKS
## A private 3D world (SubViewport, own World3D — nothing in the Prologue
## scene can leak into it) holds a procedural starfield/nebula sky, the
## Enterprise, Vulcan, one sun and one warm "planet glow" light. A single
## timeline clock drives everything: each entry in SHOTS below is one
## storyboard panel, with from/to values that are eased across the shot.
## Nothing here is hand-animated, so TUNING IS JUST EDITING NUMBERS IN SHOTS.
##
## The clock follows the music when the fanfare file exists (so picture can't
## drift from audio) and free-runs otherwise.
##
## TUNING WHILE PLAYING (debug builds only): a timecode shows top-left.
## Space pauses/resumes (read exact times off the timecode), Up/Down jump
## 2 seconds, Right/Left jump to the next/previous shot, , and . step a tenth
## of a second (Shift: a whole second). Enter or Esc skips the whole sequence.
##
## SHOT EDITOR (debug builds; REV 205, rebuilt REV 219): F1 pauses and opens
## it, F1 again closes it. The full key list is on screen (_te_update_label()
## writes it - that is the one true list); REV 293 updated this summary, which
## still described REV 205's Tab start/end and R undo:
##   1 ship  2 camera  3 Vulcan  4 T'Khut - pick what the move keys move
##   A/D Q/E W/S move it (Shift faster, Ctrl finer); J/L, I/K, U/O turn/tilt
##   (ship: turn, nose, bank; camera: look, zoom); -/= T'Khut's size
##   PATHS: Tab / Shift+Tab next/previous waypoint, , and . step through time,
##   Ctrl+K waypoint here, X delete waypoint (moving something between two
##   waypoints makes a new one there), Shift+R remove this shot's waypoints
##   SHOTS: N cut a new shot here, Delete remove this shot, [ ] move this
##   shot's start (Shift = 1 s), Left/Right other shot; H / G / T ship, Vulcan,
##   T'Khut on/off; F straight cut or dip to black
##   Enter loop this shot, V view from above, F5 SAVE
## F5 saves the whole cut (layout version 2) to TITLES_LAYOUT_PATH (or the
## opening's own file); a saved cut replaces SHOTS every time the titles play -
## no code changes. Older version-1 files (per-shot edits) still load.
##
## THE ENTERPRISE: drop the model into assets/models/enterprise/ (see
## ENTERPRISE_MODEL_PATHS). It's used automatically in place of the primitive
## stand-in, rotated/scaled by the ENTERPRISE_MODEL_* constants. Its
## deflector and bussard glows are restyled by node name in
## _style_model_materials() and animated like the stand-in's.

signal sequence_finished

const MUSIC_PATH := "res://episodes/prologue/audio/music/MUS_PRO_FANFARE.mp3"
const VO_PATH := "res://episodes/prologue/audio/music/VO_PRO_TITLES_KIRK.mp3"
## REV 117: the theme may also be .ogg or .wav; and a recording that doesn't start exactly on the
## first note, or runs a little faster or slower than the original, is lined up by a small text
## file next to it (see TIMING_PATH) - no code changes when the real recording arrives.
const MUSIC_ALTERNATIVES := ["res://episodes/prologue/audio/music/MUS_PRO_FANFARE.ogg",
	"res://episodes/prologue/audio/music/MUS_PRO_FANFARE.wav"]
const TIMING_PATH := "res://episodes/prologue/audio/music/fanfare_timing.txt"
var _music_offset := 0.0     # seconds into the recording where the titles' 0:00 falls
var _music_stretch := 1.0    # recording seconds per titles second (1.1 = the recording is 10% slower)
## Seconds into the sequence at which the voiceover file starts playing.
const VO_START_SECONDS := 0.0
## First one that exists is used. Drop the .gltf (with its .bin and PNG
## textures beside it) or a .glb into assets/models/enterprise/.
const ENTERPRISE_MODEL_PATHS: Array[String] = [
	"res://assets/models/enterprise/ENTERPRISE_TOS_BLENDER_v01.gltf",
	"res://assets/models/enterprise/ENTERPRISE_TOS_BLENDER_v01.glb",
	"res://assets/models/enterprise/enterprise.glb",
]
## Worked out from ENTERPRISE_TOS_BLENDER_v01.gltf: the model is Y-up, ~3.4
## units long with its NOSE ON +Z. The sequence wants the nose on -Z, so
## turn it half way round, and scale it up to ~10 units long.
const ENTERPRISE_MODEL_YAW_DEG := 180.0
const ENTERPRISE_MODEL_SCALE := 2.94
## Shifts the model so its middle sits near the origin (it is ~2.4 units
## tall after scaling, standing on y = 0).
const ENTERPRISE_MODEL_OFFSET := Vector3(0, -1.2, 0)
const SKY_SHADER_PATH := "res://assets/shaders/space_sky.gdshader"
const PLANET_SHADER_PATH := "res://assets/shaders/vulcan_planet.gdshader"
## Vulcan's surface map (equirectangular). If the file is missing, the planet
## falls back to the procedural desert look.
const PLANET_MAP_PATH := "res://assets/textures/vulcan_topography.png"
const PLANET_BUMP := 0.6           # relief from the map (0 = flat, higher = craggier)
const PLANET_GRAIN := 0.35        # fine rocky grain on top of the map
const PLANET_SPIN_DEG_PER_SECOND := 0.2   # slow turn; the map's seam stays on the far side

## Widescreen frame, matching the storyboard panels. Set to 0 to fill the
## whole window instead of letterboxing.
const FRAME_ASPECT := 2.39
const DURATION := 60.0
const DEFAULT_EASE := 0.6         # 0 = constant speed, 1 = full ease in/out
const ENTRANCE_FADE_SECONDS := 0.7   # fade-in of the whole sequence over the game
const SKIP_FADE_SECONDS := 0.45      # quick dip to black when the player skips

# ---------------------------------------------------------------------------
# PRESENTATION TUNING — art-direction knobs, all in one place. Adjust these
# after watching the sequence; nothing else needs touching.
# ---------------------------------------------------------------------------
const STAR_BRIGHTNESS := 1.15      # overall star brightness
const STAR_DENSITY := 2.4          # multiplier on how many stars there are
const NEBULA_STRENGTH := 0.7       # nebula brightness (0 = no nebula, pure black space)
const PLANET_EXPOSURE := 0.72      # how bright Vulcan's surface is
const PLANET_ATMOSPHERE := 0.45    # strength of Vulcan's orange rim glow
const AMBIENT_ENERGY := 0.5        # general fill; lower = deeper shadows on the ship
const FILL_ENERGY := 0.55          # soft light from the camera side, ship only, so no part is lost in shadow
const RIM_ENERGY := 0.45           # cool edge-light that outlines the ship
const BLOOM_INTENSITY := 0.5       # glow around bright lights
const BLOOM_THRESHOLD := 1.3       # how bright something must be to bloom
const ENGINE_GLOW_SCALE := 0.8     # multiplier on nacelle/deflector glow
const FLARE_STRENGTH := 0.6        # peak brightness of the sunrise flare

# Performance knobs. If playback is still choppy, lower RENDER_SCALE first
# (0.75 is a big saving and still looks clean), then MAX_RENDER_WIDTH.
const RENDER_SCALE := 1.0          # fraction of the window's pixels to render
const MAX_RENDER_WIDTH := 2560     # never render wider than this, even on 4K
const SHADOW_BIAS := 0.06          # raise if the hull shows ripples/speckles
const SHADOW_NORMAL_BIAS := 2.5    # raise further if ripples remain (too high detaches shadows)
const SENSOR_DISH_REPAINT := true  # false = keep the model's own colour for the dish
const SENSOR_DISH_COLOR := Color(0.5, 0.42, 0.34)   # dull bronze; the sensor dish never glows
const SHADOW_DISTANCE := 80.0      # how far from the camera shadows are drawn
const PREWARM_FRAMES := 4          # frames spent drawing everything once, hidden
const PLANET_RADIUS := 20.0
## T'Khut (REV 200): Vulcan's sister world, a dull volcanic brown-grey.
const TKHUT_RADIUS := 14.0
const TKHUT_COLOR_DARK := Color(0.16, 0.12, 0.1)
const TKHUT_COLOR_LIGHT := Color(0.55, 0.43, 0.33)
## Vulcan's companion stars, seen from Vulcan's system as two very bright
## stars a few degrees apart: B a hot white dwarf, C a dim red dwarf.
const TWINS_DISTANCE := 1500.0
const TWIN_B_SIZE := 90.0          # glow width at that distance (about 3.4 degrees, mostly soft halo)
const TWIN_C_SIZE := 60.0
const TWIN_C_OFFSET_DEG := Vector2(4.5, -2.0)   # C sits this far right/up of B
const REFERENCE_FRAME_HEIGHT := 536.0   # frame height at 1280x720, for text sizing

## Optional custom face for the big "STAR TREK" line. Drop the font file at
## this path (.ttf or .otf, then name it to match, or change the path) and it
## is used automatically; until then the Microgramma bold fallback is used.
const LOGO_FONT_PATHS: Array[String] = [
	"res://assets/fonts/StarTrek_BT_Regular.ttf",
	"res://assets/fonts/StarTrek_Logo.ttf",
	"res://assets/fonts/StarTrek_Logo.otf",
]

const TITLE_GOLD := Color(0.37, 0.75, 0.97)   # the logo's light blue
const TITLE_BLUE := Color(0.38, 0.64, 0.92)
const TITLE_TEXT := Color(0.92, 0.92, 0.9)

# ---------------------------------------------------------------------------
# THE SHOT LIST. One entry per storyboard panel. Coordinates: +X is screen
# right when looking down -Z; +Y up. The ship is ~10 units long and faces +X
# when ship_yaw is -90. Vulcan's radius is PLANET_RADIUS.
#
# Keys (the *_from/_to pairs ease across the shot; give only _from for a
# value that stays put):
#   start, dur            seconds on the timeline
#   cam_*, look_*         camera position and the point it looks at
#   fov_*                 vertical field of view, degrees (lower = longer lens)
#   ship_*, ship_yaw      ship position, heading in degrees; ship (bool)
#   ship_yaw_from/_to     the heading can also turn across a shot
#   ship_roll_*           bank in degrees (+ = the ship's right side dips)
#   ship_pitch_*          nose up (+) / down (-) in degrees
#   ship_shadow           false = the ship casts no shadow (over a planet it
#                         would look like it was skimming the surface)
#   planet_*, planet      Vulcan position; planet (bool) shows it
#   planet_lon            turns Vulcan's map this many degrees (keep within
#                         about +-30 or the map's seam creeps into view)
#   sun_pos, sun_*        where the sun sits, and its brightness
#   glow_*                ship engine/deflector glow multiplier
#   warm_*                orange "light from the planet" brightness
#   flare_*               sunrise flare at Vulcan's limb (0-1)
#   neb                   nebula visibility this shot (0 = hidden, 1 = full)
#   neb_az, neb_el        where the nebula sits relative to where the camera
#                         starts looking: degrees right (+) / left (-), up (+) / down (-)
#   neb_size              nebula angular radius in degrees (default 24)
#   twins                 Vulcan's companion stars (40 Eridani B and C), 0-1
#   twins_az, twins_el    where they sit, measured like neb_az / neb_el
#   tkhut                 (bool) shows T'Khut, Vulcan's big sister world
#   tkhut_*               its position (from/to), like planet_*
#   tkhut_size            its radius (default TKHUT_RADIUS)
#   ease                  0-1, see DEFAULT_EASE
#   fade_in, fade_out     dip-to-black seconds at the start/end of the shot
# ---------------------------------------------------------------------------
## Glen's edits from the shot editor (F1), saved with F5: per shot, values
## that replace the ones in SHOTS below.
const TITLES_LAYOUT_PATH := "res://episodes/prologue/titles_layout.json"
const TITLES_LAYOUT_USER_PATH := "user://titles_layout.json"   # when res:// can't be written (exported game)

const SHOTS: Array[Dictionary] = [
	# REV 200 (Glen): TOS at the start, growing into a TNG-style journey through
	# Vulcan's system. Pure stars until the ship's name is spoken; then every
	# shot shows the Enterprise from a new side, with the system's sights
	# behind it, ending in orbit and the original "behind Vulcan" finish.
	# Shot times follow the narration subtitles (SUBTITLES below).
	# ===== MOVEMENT ONE: 0:00-0:31, Kirk's five narration beats ==========
	{
		# 0:00-0:15.6 — SPACE... THE FINAL FRONTIER. Pure TOS: stars only,
		# no ship, no planet, no nebula, the calmest drift.
		"name": "1 — SPACE", "start": 0.0, "dur": 15.6,
		"cam_from": Vector3(0, 0, 0), "cam_to": Vector3(0, 0, -5),
		"look_from": Vector3(-3, 1, -100), "look_to": Vector3(-1, 0.5, -100),
		"ship": false, "planet": false, "neb": 0.0,
		"ease": 0.0, "fade_in": 3.0, "fade_out": 0.4,
	},
	{
		# 0:15.6-0:20.5 — THESE ARE THE VOYAGES: the Enterprise appears on its
		# own name. Glen's reference (the classic underside view): camera low
		# and ahead, looking up at the saucer's underside as the ship slides
		# across the frame, close enough to read the hull detail.
		"name": "2 — VOYAGES (SAUCER UNDERSIDE)", "start": 15.6, "dur": 4.9,
		"cam_from": Vector3(-0.6, -2.0, 8.4), "cam_to": Vector3(0.6, -1.9, 8.6),
		"look_from": Vector3(-2.2, 2.5, 0.2), "look_to": Vector3(1.4, 2.7, 2.6),
		"fov_from": 34.0, "fov_to": 33.0,
		"ship_from": Vector3(-7.2, 3.0, -3.2), "ship_to": Vector3(0.4, 3.0, 1.6),
		"ship_yaw": -122.0, "ship_roll_from": -16.0, "ship_roll_to": -14.0, "ship_pitch": 0.0,
		"sun_pos": Vector3(-6, -9, 12), "sun_from": 0.9, "sun_to": 1.05,
		"glow_from": 1.3, "glow_to": 1.5,
		"neb": 0.15, "neb_az": -30.0, "neb_el": 20.0, "neb_size": 14.0,
		"ease": 0.15, "fade_in": 0.5, "fade_out": 0.3,
	},
	{
		# 0:20.5-0:23.5 — ITS MISSION... STRANGE NEW WORLDS: a close skim past
		# the starboard nacelle's glowing cap, Vulcan's two companion stars
		# (40 Eridani B and C) shining beyond.
		"name": "3 — NEW WORLDS (NACELLE SKIM)", "start": 20.5, "dur": 3.0,
		"cam_from": Vector3(1.8, 1.9, 4.6), "cam_to": Vector3(2.2, 1.9, 4.4),
		"look_from": Vector3(-1.6, 1.2, 1.7), "look_to": Vector3(1.4, 1.2, 1.4),
		"fov_from": 40.0, "fov_to": 44.0,
		"ship_from": Vector3(-1.6, 0, 0), "ship_to": Vector3(1.8, 0, 0), "ship_yaw": -90.0,
		"sun_pos": Vector3(-14, 10, 16), "sun_from": 1.4,
		"glow_from": 1.5, "glow_to": 1.8,
		"twins": 1.0, "twins_az": -22.0, "twins_el": 6.0,
		"neb": 0.3, "neb_az": 30.0, "neb_el": 4.0, "neb_size": 14.0,
		"ease": 0.2, "fade_in": 0.35, "fade_out": 0.3,
	},
	{
		# 0:23.5-0:27.5 — NEW LIFE, NEW CIVILISATIONS: rear three-quarter
		# view (impulse deck, shuttle bay, nacelle backs) as the ship sails
		# on toward T'Khut, Vulcan's big sister world.
		"name": "4 — NEW LIFE (REAR THREE-QUARTER)", "start": 23.5, "dur": 4.0,
		"cam_from": Vector3(-13, 2.8, 4.5), "cam_to": Vector3(-12, 2.4, 3.6),
		"look_from": Vector3(-1, 0.4, 0), "look_to": Vector3(3, 0.3, -1),
		"fov_from": 29.0, "fov_to": 27.0,
		"ship_from": Vector3(-3, 0, 0), "ship_to": Vector3(3.5, 0, -1.6), "ship_yaw_from": -96.0, "ship_yaw_to": -100.0,
		"ship_roll_from": 0.0, "ship_roll_to": -5.0,
		"tkhut": true, "tkhut_from": Vector3(170, 26, -60), "tkhut_to": Vector3(168, 26, -62), "tkhut_size": 22.0,
		"sun_pos": Vector3(-20, 14, -10), "sun_from": 1.4,
		"glow_from": 1.4,
		"twins": 0.7, "twins_az": 26.0, "twins_el": -8.0,
		"neb": 0.45, "neb_az": 20.0, "neb_el": -6.0, "neb_size": 16.0,
		"fade_in": 0.35, "fade_out": 0.3,
	},
	{
		# 0:27.5-0:31.5 — TO BOLDLY GO: side profile, the ship banks and turns
		# toward Vulcan, whose red disc looms ahead as the music peaks.
		"name": "5 — BOLDLY GO (BANK TOWARD VULCAN)", "start": 27.5, "dur": 4.0,
		"cam_from": Vector3(-3, 0.8, 15.5), "cam_to": Vector3(1.5, 0.6, 14.0),
		"look_from": Vector3(-1.5, 0, 0), "look_to": Vector3(4, -0.4, -2),
		"fov_from": 34.0, "fov_to": 34.0,
		"ship_from": Vector3(-3, 0, 0), "ship_to": Vector3(3.5, -0.4, -2.2),
		"ship_yaw_from": -90.0, "ship_yaw_to": -74.0,
		"ship_roll_from": 0.0, "ship_roll_to": 22.0,
		"planet": true, "planet_from": Vector3(52, -8, -84), "planet_to": Vector3(44, -7, -66), "planet_lon": -14.0,
		"tkhut": true, "tkhut_from": Vector3(-70, 22, -220), "tkhut_size": 12.0,
		"sun_pos": Vector3(-26, 12, 14), "sun_from": 1.4,
		"warm_from": 0.6, "warm_to": 1.4, "glow_from": 1.5, "glow_to": 1.8,
		"neb": 0.3, "neb_az": -30.0, "neb_el": 10.0, "neb_size": 15.0,
		"fade_in": 0.35, "fade_out": 0.3,
	},
	# ===== MOVEMENT TWO: 0:31 onward, studio card, title, credits =========
	{
		# 0:31.5-0:39.5 — THIRD MOON INTERACTIVE: arrival. The Enterprise
		# levels out of its turn and settles into orbit high over Vulcan,
		# the surface sliding slowly beneath it.
		"name": "6 — ORBIT (THIRD MOON INTERACTIVE)", "start": 31.5, "dur": 8.0,
		"cam_from": Vector3(-9, 2.6, 17), "cam_to": Vector3(-6, 2.2, 15),
		"look_from": Vector3(0, -2.5, -2), "look_to": Vector3(3, -3, -3),
		"fov_from": 36.0, "fov_to": 34.0,
		"ship_from": Vector3(-6, 0.6, 0), "ship_to": Vector3(3, 0, -1.2),
		"ship_yaw_from": -84.0, "ship_yaw_to": -96.0,
		"ship_roll_from": 14.0, "ship_roll_to": 0.0, "ship_pitch_from": 3.0, "ship_pitch_to": 0.0,
		"ship_shadow": false,
		"planet": true, "planet_from": Vector3(4, -27, -14), "planet_lon": 6.0,
		"tkhut": true, "tkhut_from": Vector3(150, 6, -260), "tkhut_size": 14.0,
		"sun_pos": Vector3(-26, 12, 14), "sun_from": 1.4,
		"warm_from": 1.3, "glow_from": 1.3,
		"twins": 0.5, "twins_az": 30.0, "twins_el": 18.0,
		"neb": 0.4, "neb_az": -28.0, "neb_el": 8.0, "neb_size": 14.0, "fade_in": 0.5, "fade_out": 0.3,
	},
	{
		# 0:39.5-1:00 — STAR TREK / THE SECRET OF VULCAN FURY.
		"name": "7 — MAIN TITLE", "start": 39.5, "dur": 20.5,
		"cam_from": Vector3(0, 0, 30), "cam_to": Vector3(0, 0.5, 28),
		"look_from": Vector3(0, 0, -10),
		"ship_from": Vector3(14, 1, -2), "ship_to": Vector3(-20, 0, -26), "ship_yaw": 50.0,
		"planet": true, "planet_from": Vector3(-27, -2, -10),
		"sun_pos": Vector3(22, 4, -6), "sun_from": 1.7,
		"glow_from": 1.3, "flare_from": 0.0, "flare_to": 1.0,
		"neb": 0.2, "neb_az": 34.0, "neb_el": 3.0, "neb_size": 14.0, "ease": 0.6, "fade_in": 0.35, "fade_out": 1.5,
	},
]

## On-screen titles. start/fade in absolute timeline seconds; "end" hides the
## line again. Sizes are for a 1280x720 window and scale with the window.
## "area": "bottom" = low in the frame (stacked); "credit" = a single lower-third
## line that overlaps others, so credits can follow one another in place.
const TITLE_LINES: Array[Dictionary] = [
	# Studio card, after Kirk finishes.
	{"text": "THIRD MOON INTERACTIVE", "start": 32.5, "end": 39.0, "fade": 1.4, "size": 15, "color": TITLE_TEXT, "bold": false, "area": "credit", "tracking": 5},
	# Main title.
	{"text": "STAR TREK", "start": 41.5, "fade": 1.2, "size": 72, "color": TITLE_GOLD, "bold": true, "logo_font": true},
	{"text": "THE SECRET OF", "start": 43.5, "fade": 1.0, "size": 20, "color": TITLE_BLUE, "bold": false},
	{"text": "VULCAN FURY", "start": 43.5, "fade": 1.0, "size": 38, "color": TITLE_BLUE, "bold": true},
	{"text": "AN UNOFFICIAL FAN PRODUCTION", "start": 46.5, "fade": 0.8, "size": 10, "color": TITLE_TEXT, "bold": false, "gap_before": 14},
]

## SUBTITLES — shown in the black bar under the picture (or low in the frame
## if the window has no bar). Times are seconds on the timeline, same clock as
## the shots. Add one entry per line of narration, e.g.:
##   {"start": 4.0, "end": 8.5, "text": "Your subtitle text here."},
const SUBTITLES: Array[Dictionary] = [
	{"start": 7.0, "end": 10.0, "text": "Space... the final frontier."},
	{"start": 16.0, "end": 19.0, "text": "These are the voyages of the Starship Enterprise."},
	{"start": 21.0, "end": 23.0, "text": "Its mission... to explore strange new worlds..."},
	{"start": 24.0, "end": 27.0, "text": "To seek out new life, and new civilisations..."},
	{"start": 28.0, "end": 31.0, "text": "To boldly go where no-one has gone before."},
]
const SUBTITLE_FONT_SIZE := 15         # at 1280x720; scales with the window
const SUBTITLE_FADE_SECONDS := 0.25

var _viewport: SubViewport
var _view: TextureRect
var _camera: Camera3D
var _sun: DirectionalLight3D
var _warm_light: OmniLight3D
var _environment: Environment
var _sky_material: ShaderMaterial
var _nebula_shot: int = -1
var _ship: Node3D
var _glow_materials: Array[StandardMaterial3D] = []
## REV 201: animated nacelle caps and the blinking running lights.
const BUSSARD_SHADER_PATH := "res://core/ui/shaders/bussard_glow.gdshader"
const BUSSARD_SPIN_SPEED := 0.3        # turns per second (REV 217: was 0.55, Glen: too fast)
const NAV_LIGHT_SIZE := 0.9           # glow width (the ship is ~10 units long)
const NAV_LIGHT_PERIOD := 1.6          # seconds per blink
const NAV_LIGHT_ON := 0.35             # fraction of each blink spent lit
const NAV_LIGHT_STRENGTH := 1.0
var _bussard_materials: Array[ShaderMaterial] = []
var _nav_lights: Array[MeshInstance3D] = []
var _nav_bulb_materials: Array[StandardMaterial3D] = []   # the model's own red/green bulb glass
var _planet: MeshInstance3D
var _flare: MeshInstance3D
var _flare_material: StandardMaterial3D
var _tkhut: MeshInstance3D
var _twin_b: MeshInstance3D
var _twin_c: MeshInstance3D
var _twin_b_material: StandardMaterial3D
var _twin_c_material: StandardMaterial3D
var _twins_dir_b := Vector3(0, 0, -1)
var _twins_dir_c := Vector3(0, 0, -1)
var _fade: ColorRect
var _titles_root: Control
var _bg: ColorRect
var _rim: DirectionalLight3D
var _fill: DirectionalLight3D
var _skipping: bool = false
## Main-menu backdrop mode: the same Enterprise/Vulcan world, but no titles,
## no music and no timeline: one slow, endlessly drifting beauty shot. Set
## BEFORE adding the node to the tree, then call play_menu().
var menu_mode: bool = false

## REV 227: OTHER SPACE SEQUENCES. Left empty, this is the one-minute opening titles. Set before
## adding to the tree to play a different sequence in the same world (the same Enterprise, Vulcan,
## sky and lights) - an episode's opening shot, say. Keys (all optional except "shots"):
##   "shots":      Array of shot Dictionaries, same format as SHOTS
##   "duration":   seconds the whole sequence runs
##   "titles":     on-screen titles, same format as TITLE_LINES ("area": "lower" = episode title)
##   "subtitles":  [{"start", "end", "text", "voice": res:// path of that line's recording}]; a line
##                 with a recording plays it at "start" (and stays up at least as long as it lasts)
##   "music":      res:// path of a music track (none = silence)
##   "layout":     res:// path the F1 shot editor saves this sequence's own cut to
##   "aspect":     picture shape (2.39 = the titles' wide bars; 0 = fill the window)
##   "edit_note":  REV 293: a Callable returning a line of text (or "") shown at the bottom of the F1
##                 shot editor's panel - the teaser uses it to warn when a re-cut no longer matches the
##                 times its dive, bridge shots and log are written for
## episodes/episode1/scenes/Ep1Opening.gd is the first user.
var opening: Dictionary = {}
var _line_player: AudioStreamPlayer
var _lines_played: Dictionary = {}     # subtitle index -> true once its recording has started


func _base_shots() -> Array:
	return opening.get("shots", SHOTS)


func _duration() -> float:
	return float(opening.get("duration", DURATION))


func _title_lines() -> Array:
	return opening.get("titles", TITLE_LINES)


func _subtitles() -> Array:
	return opening.get("subtitles", SUBTITLES)


func _music_path() -> String:
	return String(opening.get("music", MUSIC_PATH))


func _layout_path() -> String:
	return String(opening.get("layout", TITLES_LAYOUT_PATH))


func _layout_user_path() -> String:
	if opening.has("layout"):
		return "user://" + String(opening["layout"]).get_file()
	return TITLES_LAYOUT_USER_PATH


## Starts the recording of any subtitle line whose time has come (opening sequences only).
func _play_due_lines() -> void:
	if opening.is_empty():
		return
	var list := _subtitles()
	for i in list.size():
		var entry: Dictionary = list[i]
		if _lines_played.has(i) or _time < float(entry.get("start", 0.0)):
			continue
		_lines_played[i] = true
		if _time > float(entry.get("start", 0.0)) + 0.5:
			continue       # jumped past it (debug seek): don't start a line half-way through
		var path := String(entry.get("voice", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		if _line_player == null:
			_line_player = AudioStreamPlayer.new()
			_line_player.bus = "Dialogue" if AudioServer.get_bus_index("Dialogue") >= 0 else "Master"
			add_child(_line_player)
		_line_player.stream = load(path)
		_line_player.play()


var _voice_lengths: Dictionary = {}

## How long a subtitle's recording lasts (0 without one).
func _voice_length(entry: Dictionary) -> float:
	var path := String(entry.get("voice", ""))
	if path == "":
		return 0.0
	if not _voice_lengths.has(path):
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
		_voice_lengths[path] = stream.get_length() if stream != null else 0.0
	return float(_voice_lengths[path])


## REV 229: an opening can say when what comes next is ready ("ready_check": a Callable returning
## true). Until then the last shot holds just before its fade to black - the ship stays on screen
## instead of the screen going black with LOADING in the corner (slow computers).
func _hold_for_next_part() -> void:
	if not opening.has("ready_check") or _skipping:
		return
	var last: Dictionary = _shots()[-1]
	var hold_at := _duration() - float(last.get("fade_out", 0.35)) - 0.05
	if _time > hold_at and not bool((opening["ready_check"] as Callable).call()):
		_time = hold_at


## REV 229: SPACE WORLD PRELOAD. Start reading the Enterprise, Vulcan's map and the sky and planet
## shaders in the background before a space scene is needed (the end of the Prologue, starting
## Episode One from the menu), so the scene starts at once. The next TitleSequence built takes them.
const WORLD_FILES := [SKY_SHADER_PATH, PLANET_SHADER_PATH, PLANET_MAP_PATH]

static func preload_world() -> void:
	var files: Array = WORLD_FILES.duplicate()
	for p in ENTERPRISE_MODEL_PATHS:
		if ResourceLoader.exists(p):
			files.append(p)
			break
	for p in files:
		if ResourceLoader.exists(p) and ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(p, "", true)


## A file, from the background preload if it was started (waits for it if still reading), else read now.
static func _take(path: String) -> Resource:
	var st := ResourceLoader.load_threaded_get_status(path)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS or st == ResourceLoader.THREAD_LOAD_LOADED:
		var r := ResourceLoader.load_threaded_get(path)
		if r != null:
			return r
	return load(path) if ResourceLoader.exists(path) else null


## After a debug seek: lines from here on can play again.
func _reset_lines_after(t: float) -> void:
	var list := _subtitles()
	for i in list.size():
		if float((list[i] as Dictionary).get("start", 0.0)) >= t:
			_lines_played.erase(i)
	if _line_player != null:
		_line_player.stop()
var _paused: bool = false
## REV 218 (Glen): in the shot editor, Enter plays the current shot over and over (it used to run on
## into the next shots). -1 = not looping.
var _te_loop: int = -1
var _subtitle_label: Label
var _timecode_label: Label
var _prewarm_left: int = 0
var _skip_time: float = 0.0
var _credit_box: VBoxContainer
var _title_labels: Array[Label] = []
var _music_player: AudioStreamPlayer
var _vo_player: AudioStreamPlayer
var _vo_started: bool = false
var _time: float = 0.0
var _running: bool = false
var _finished: bool = false

static var _flare_texture: GradientTexture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Sized explicitly in _layout(): a Control under a CanvasLayer has no
	# parent rect for anchors to resolve against, which is what left the game
	# world showing above and below the picture.
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_build_world()
	# REV 237 (teaser): an opening may add its own things to the space world (the warp tunnel)
	if opening.has("on_world"):
		(opening["on_world"] as Callable).call(_viewport, _camera, _ship)

	_view = TextureRect.new()
	_view.texture = _viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

	_titles_root = Control.new()
	_titles_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_titles_root)
	if not menu_mode:
		_build_titles()

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_label.add_theme_color_override("font_color", TITLE_TEXT)
	_add_text_backing(_subtitle_label)
	if UITheme.font_regular != null:
		_subtitle_label.add_theme_font_override("font", UITheme.font_regular)
	_subtitle_label.modulate.a = 0.0
	add_child(_subtitle_label)

	if OS.is_debug_build() and not menu_mode and not bool(opening.get("hide_timecode", false)):     # REV 237: not in a recording
		_timecode_label = Label.new()
		_timecode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_timecode_label.position = Vector2(10, 6)
		_timecode_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		_timecode_label.add_theme_font_size_override("font_size", 12)
		add_child(_timecode_label)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "FanfarePlayer"
	_music_player.bus = "Music"
	add_child(_music_player)
	_vo_player = AudioStreamPlayer.new()
	_vo_player.name = "NarrationPlayer"
	_vo_player.bus = "Dialogue"
	add_child(_vo_player)

	get_viewport().size_changed.connect(_layout)
	_layout()
	if menu_mode:
		# The ship must not throw a shadow onto Vulcan: at this distance it
		# would look like it was skimming the surface.
		_start_clouds()
		for node in _ship.find_children("*", "GeometryInstance3D", true, false):
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_apply_menu(0.0)
	else:
		_apply_time(0.0)


## Starts the endless menu backdrop. Call once, after adding this node to the tree.
func play_menu() -> void:
	menu_mode = true
	_prewarm_left = PREWARM_FRAMES
	modulate.a = 0.0
	_time = 0.0
	_running = true


## fanfare_timing.txt, e.g.
##     offset = 1.35      # the first note is 1.35 s into the recording
##     stretch = auto     # fit the whole picture to the recording's length (or a number, 1.0 = same)
## Lines starting with # are ignored. Missing file = offset 0, stretch 1.
func _read_timing(stream: AudioStream) -> void:
	_music_offset = 0.0
	_music_stretch = 1.0
	if not FileAccess.file_exists(TIMING_PATH):
		return
	var stretch_text := "1"
	for raw in FileAccess.get_file_as_string(TIMING_PATH).split("\n"):
		var line := raw.get_slice("#", 0).strip_edges()
		if not line.contains("="):
			continue
		var key := line.get_slice("=", 0).strip_edges().to_lower()
		var val := line.get_slice("=", 1).strip_edges()
		if key == "offset":
			_music_offset = maxf(val.to_float(), 0.0)
		elif key == "stretch":
			stretch_text = val.to_lower()
	if stretch_text == "auto":
		var length := stream.get_length()
		if length > _music_offset + 1.0:
			_music_stretch = (length - _music_offset) / _duration()
	else:
		_music_stretch = stretch_text.to_float()
	_music_stretch = clampf(_music_stretch if _music_stretch > 0.0 else 1.0, 0.7, 1.4)
	print("TitleSequence: fanfare offset %.2f s, stretch %.3f" % [_music_offset, _music_stretch])


## Call once, after adding this node to the tree.
func play() -> void:
	if opening.is_empty():
		Chapters.reach("titles")      # REV 117: watched them once - replayable from CHAPTERS
	var music_file := _music_path()
	for alt in (MUSIC_ALTERNATIVES if opening.is_empty() else []):
		if not ResourceLoader.exists(music_file) and ResourceLoader.exists(alt):
			music_file = alt
	if ResourceLoader.exists(music_file):
		var stream: AudioStream = load(music_file)
		if stream != null:
			_music_player.stream = stream
			_read_timing(stream)
	else:
		if opening.is_empty():
			push_warning("TitleSequence: fanfare track missing (%s) — titles will play in silence until it's added." % MUSIC_PATH)

	if opening.is_empty() and ResourceLoader.exists(VO_PATH):
		var vo_stream: AudioStream = load(VO_PATH)
		if vo_stream != null:
			_vo_player.stream = vo_stream
	else:
		if opening.is_empty():
			push_warning("TitleSequence: narration track missing (%s) — playing without it." % VO_PATH)

	# The Prologue's 3D world is hidden behind us anyway, so stop drawing it
	# for the duration (restored in _exit_tree). REV 237: unless the opening cuts between this world and
	# the room's own (the teaser's bridge shots) - "keep_3d".
	if not bool(opening.get("keep_3d", false)):
		get_viewport().disable_3d = true

	# Draw every object once, off-screen under black, before the picture
	# starts: the first time Godot draws a material it compiles it, which is
	# a visible hitch if that happens mid-shot (planet at 0:22, flare at 0:52).
	_prewarm_left = PREWARM_FRAMES
	modulate.a = 0.0

	_time = 0.0
	_running = true


func _process(delta: float) -> void:
	if not _running or _finished:
		return
	if _prewarm_left > 0:
		_prewarm()
		_prewarm_left -= 1
		if _prewarm_left == 0:
			_start_playback()
		return
	if menu_mode:
		_time += delta
		if menu_edit:
			_edit_poll(delta)
		_apply_menu(_time)
		return
	if _paused:
		if titles_edit:
			_te_poll(delta)
		return
	if _skipping:
		_skip_time += delta
		var skip_u := clampf(_skip_time / SKIP_FADE_SECONDS, 0.0, 1.0)
		_fade.color.a = maxf(_fade.color.a, skip_u)
		_music_player.volume_db = linear_to_db(maxf(1.0 - skip_u, 0.0001))
		_vo_player.volume_db = linear_to_db(maxf(1.0 - skip_u, 0.0001))
		if _line_player != null:
			_line_player.volume_db = linear_to_db(maxf(1.0 - skip_u, 0.0001))
		if skip_u >= 1.0:
			_finish()
		return
	# Free-run on the frame clock (smooth), and only nudge toward the music's
	# position. Reading the audio clock directly moves in chunks, which makes
	# camera moves judder even at a high frame rate.
	_time += delta / (_music_stretch if _music_player.playing else 1.0)
	if _music_player.playing:
		var audio_time: float = (_music_player.get_playback_position() + AudioServer.get_time_since_last_mix() - _music_offset) / _music_stretch
		var drift: float = audio_time - _time
		if absf(drift) > 0.25:
			_time = audio_time
		else:
			_time += drift * minf(delta * 4.0, 1.0)

	if not _vo_started and _vo_player.stream != null and _time >= VO_START_SECONDS:
		_vo_started = true
		_vo_player.play()

	if titles_edit and _te_loop >= 0 and _te_loop < _shots().size():
		var loop_end: float = float(_shots()[_te_loop + 1].start) if _te_loop + 1 < _shots().size() else _duration() - 0.05
		if _time >= loop_end:
			_seek_to(float(_shots()[_te_loop].start))      # REV 218: round again
			return
	_play_due_lines()
	_hold_for_next_part()
	if _time >= _duration():
		_finish()
		return
	_apply_time(_time)


func _unhandled_input(event: InputEvent) -> void:
	if menu_mode:
		if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
			if _edit_key(event):
				get_viewport().set_input_as_handled()
		return
	# Debug-build timing keys come first, so Space can pause without also
	# counting as "confirm = skip" (Space is a confirm key in the input map).
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and _te_key(event):
		get_viewport().set_input_as_handled()
		return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode in [KEY_COMMA, KEY_PERIOD]:
		# Fine stepping (REV 205): a tenth of a second, Shift = a second; holds repeat.
		var step := 1.0 if event.shift_pressed else 0.1
		_set_paused(true)
		_seek_to(_time + (step if event.keycode == KEY_PERIOD else -step))
		_te_update_label()
		get_viewport().set_input_as_handled()
		return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		if event.keycode == KEY_RIGHT:
			_seek_shot(1)
		elif event.keycode == KEY_LEFT:
			_seek_shot(-1)
		elif event.keycode == KEY_UP:
			_seek_to(_time + 2.0)
		elif event.keycode == KEY_DOWN:
			_seek_to(_time - 2.0)
		elif event.keycode == KEY_SPACE:
			_set_paused(not _paused)
		elif event.keycode == KEY_M:
			_drop_marker()
		else:
			handled = false
		if handled:
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_navigate_confirm") or event.is_action_pressed("menu_cancel"):
		# Short dip to black instead of a hard cut; _finish() then ends
		# everything the same way a full viewing does.
		if _running and not _finished:
			_skipping = true
		return


## Puts the ship, planet, flare and every light in front of the camera for a
## few hidden frames so all materials/shadow pipelines compile up front.
func _prewarm() -> void:
	_camera.position = Vector3.ZERO
	_camera.fov = 60.0
	_camera.look_at(Vector3(0, 0, -30), Vector3.UP)
	_ship.visible = true
	_ship.position = Vector3(0, 0, -16)
	_ship.rotation.y = deg_to_rad(-60.0)
	_planet.visible = true
	_planet.position = Vector3(18, 0, -70)
	_flare.visible = true
	_flare.position = Vector3(-6, 3, -30)
	_tkhut.visible = true
	_tkhut.position = Vector3(-30, 0, -90)
	_twin_b.visible = true
	_twin_b.position = Vector3(6, 4, -60)
	_twin_c.visible = true
	_twin_c.position = Vector3(9, 4, -60)
	_sun.light_energy = 1.0
	_sun.look_at_from_position(Vector3(-26, 12, 14), Vector3.ZERO, Vector3.UP)
	_rim.light_energy = RIM_ENERGY
	_fill.light_energy = FILL_ENERGY
	_warm_light.light_energy = 1.0
	_warm_light.position = Vector3(0, 0, -30)
	_fade.color.a = 1.0


func _start_playback() -> void:
	_time = 0.0
	if menu_mode:
		_apply_menu(0.0)
		create_tween().tween_property(self, "modulate:a", 1.0, ENTRANCE_FADE_SECONDS)
		return
	# REV 594: an opening can start part-way in (Episode 3 plays the teaser from the nebula, without the logo)
	_time = float(opening.get("start_at", 0.0))
	_apply_time(_time)
	create_tween().tween_property(self, "modulate:a", 1.0, ENTRANCE_FADE_SECONDS)
	if _music_player.stream != null:
		_music_player.play(_music_offset)
	if _vo_player.stream != null and VO_START_SECONDS <= 0.0:
		_vo_started = true
		_vo_player.play()


func _exit_tree() -> void:
	if is_inside_tree() and get_viewport() != null:
		get_viewport().disable_3d = false


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_running = false
	_music_player.stop()
	_vo_player.stop()
	if _line_player != null:
		_line_player.stop()
	sequence_finished.emit()


# ---------------------------------------------------------------- timeline --

func _shot_index(t: float) -> int:
	var found := 0
	var list := _shots()
	for i in range(list.size()):
		if t >= float(list[i].start):
			found = i
	return found


func _update_subtitles(t: float) -> void:
	var text := ""
	var alpha := 0.0
	for entry in _subtitles():
		var start: float = float(entry.start)
		var finish: float = maxf(float(entry.end), start + _voice_length(entry) + 0.3)
		if t >= start and t < finish:
			text = String(entry.text)
			alpha = clampf(minf(t - start, finish - t) / SUBTITLE_FADE_SECONDS, 0.0, 1.0)
			break
	if text != "":
		_subtitle_label.text = text
	_subtitle_label.modulate.a = alpha


## Debug helper: jump to the start of the next/previous shot.
func _seek_shot(direction: int) -> void:
	var current := _shot_index(_time)
	# Pressing "previous" late in a shot restarts it; early in a shot goes back one.
	if direction < 0 and _time - float(_shots()[current].start) > 1.0:
		direction = 0
	var target := clampi(current + direction, 0, _shots().size() - 1)
	_seek_to(float(_shots()[target].start))


func _seek_to(t: float) -> void:
	_time = clampf(t, 0.0, _duration() - 0.05)
	_reset_lines_after(_time)
	if _music_player.playing or _music_player.stream_paused:
		_music_player.seek(_music_offset + _time * _music_stretch)
	if _vo_player.stream != null:
		if _time >= VO_START_SECONDS:
			_vo_started = true
			_vo_player.play(_time - VO_START_SECONDS)
			_vo_player.stream_paused = _paused
		else:
			_vo_started = false
			_vo_player.stop()
	_apply_time(_time)


# ------------------------------------------------------------ shot editor --
# REV 205, rebuilt REV 219 (Glen: "I'd like to be able to define my own shots and my own paths").
# The titles play from a working list of shots (_cut), which starts as SHOTS (plus any REV 205-style
# edits) or, once Glen has saved his own cut, is loaded whole from titles_layout.json.
#
# A shot can carry "keys": waypoints, each {"at": seconds into the shot, cam, look, fov, ship,
# ship_yaw, ship_pitch, ship_roll, planet, tkhut}. When a shot has keys, the camera, ship and
# planets travel a smooth curve through every waypoint (Catmull-Rom), at the shot's real clock; a
# shot without keys still eases from its _from to its _to values as before. Editing anything turns
# the shot into waypoints (its start and end become the first and last), so nothing jumps.
#
# The music, narration and on-screen titles keep their own times: shots are cut and re-cut inside
# the same 60 seconds.

const TE_KEY_PROPS := ["cam", "look", "fov", "ship", "ship_yaw", "ship_pitch", "ship_roll", "planet", "tkhut"]
const TE_SNAP := 0.06           # seconds: this close to a waypoint counts as standing on it
const TE_MIN_SHOT := 0.4        # seconds: shortest a shot can be

var _cut: Array = []            # the working list of shots (Dictionaries)
var _layout_loaded: bool = false
var titles_edit: bool = false
var _te_target: int = 0          # 0 ship, 1 camera, 2 planet, 3 T'Khut
var _te_label: Label
var _te_status: String = ""
var _te_overview: bool = false
var _te_overview_cam: Camera3D
var _te_paths: MeshInstance3D


## The shots as they play now.
func _shots() -> Array:
	if not _layout_loaded:
		_load_titles_layout()
	return _cut


## One shot as it plays.
func _shot(index: int) -> Dictionary:
	var list := _shots()
	return list[clampi(index, 0, list.size() - 1)]


func _load_titles_layout() -> void:
	_layout_loaded = true
	_cut.clear()
	for s in _base_shots():
		_cut.append(s.duplicate(true))
	for path in [_layout_user_path(), _layout_path()]:
		if not FileAccess.file_exists(path):
			continue
		var data: Variant = _te_from_json(JSON.parse_string(FileAccess.get_file_as_string(path)))
		if not (data is Dictionary):
			push_warning("TitleSequence: %s isn't readable - ignored." % path)
			continue
		if int(data.get("version", 1)) >= 2 and data.get("shots") is Array and not (data["shots"] as Array).is_empty():
			# Glen's own cut: replaces the built-in shots entirely
			_cut.clear()
			for s in data["shots"]:
				if s is Dictionary:
					_cut.append(s)
			_te_normalise()
		else:
			# REV 205 format: edits laid over the built-in shots, matched by name
			for shot_name in data:
				var index := _shot_index_by_name(String(shot_name))
				if index >= 0 and data[shot_name] is Dictionary:
					_cut[index].merge(data[shot_name], true)
		print("TitleSequence: shots loaded from ", path)
		return


## JSON gives numbers as floats and positions as [x, y, z] lists; turn the lists back into positions.
func _te_from_json(v: Variant) -> Variant:
	if v is Array:
		var arr: Array = v
		if arr.size() == 3 and (arr[0] is float or arr[0] is int) and (arr[1] is float or arr[1] is int) and (arr[2] is float or arr[2] is int):
			return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		var out: Array = []
		for x in arr:
			out.append(_te_from_json(x))
		return out
	if v is Dictionary:
		var d: Dictionary = {}
		for k in v:
			d[String(k)] = _te_from_json(v[k])
		return d
	return v


func _te_to_json(v: Variant) -> Variant:
	if v is Vector3:
		return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]
	if v is float:
		return snappedf(v, 0.001)
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_te_to_json(x))
		return out
	if v is Dictionary:
		var d: Dictionary = {}
		for k in v:
			d[k] = _te_to_json(v[k])
		return d
	return v


## Shots end to end from 0 to DURATION, in order, waypoints in time order.
func _te_normalise() -> void:
	var t := 0.0
	for i in _cut.size():
		var s: Dictionary = _cut[i]
		s["start"] = t
		if i == _cut.size() - 1:
			s["dur"] = maxf(_duration() - t, TE_MIN_SHOT)
		t += float(s["dur"])
		if s.has("keys"):
			var keys: Array = s["keys"]
			keys.sort_custom(func(a, b): return float(a["at"]) < float(b["at"]))


func _shot_index_by_name(shot_name: String) -> int:
	for i in _base_shots().size():
		if String(_base_shots()[i].get("name", "")) == shot_name:
			return i
	# Names are matched by their number too, so renaming a shot keeps its edits.
	var number := shot_name.get_slice(" ", 0)
	for i in _base_shots().size():
		if String(_base_shots()[i].get("name", "")).get_slice(" ", 0) == number:
			return i
	return -1


func _save_titles_layout() -> void:
	var text := JSON.stringify({"version": 2, "shots": _te_to_json(_cut)}, "\t", false)
	for path in [_layout_path(), _layout_user_path()]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(text)
			file.close()
			_te_status = "SAVED to " + ProjectSettings.globalize_path(path)
			print("TitleSequence: ", _te_status)
			return
	_te_status = "COULD NOT SAVE (see Output)"
	push_warning("TitleSequence: could not write the shots.")


# ---- paths through waypoints ----

## The value of `prop` at `lt` seconds into a shot that has waypoints; null if no waypoint sets it.
func _path_value(keys: Array, prop: String, lt: float) -> Variant:
	var pts: Array = []
	for k in keys:
		if (k as Dictionary).has(prop):
			pts.append(k)
	if pts.is_empty():
		return null
	if pts.size() == 1 or lt <= float(pts[0]["at"]):
		return pts[0][prop]
	if lt >= float(pts[-1]["at"]):
		return pts[-1][prop]
	var i := 0
	while i < pts.size() - 2 and lt > float(pts[i + 1]["at"]):
		i += 1
	var t0 := float(pts[i]["at"])
	var t1 := float(pts[i + 1]["at"])
	var s := clampf((lt - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
	var p1: Variant = pts[i][prop]
	var p2: Variant = pts[i + 1][prop]
	var p0: Variant = pts[i - 1][prop] if i > 0 else p1
	var p3: Variant = pts[i + 2][prop] if i + 2 < pts.size() else p2
	# Catmull-Rom: a smooth curve through every waypoint
	var s2 := s * s
	var s3 := s2 * s
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * s + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * s2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * s3)


## Everything the waypoints hold, as the shot shows it at `lt` seconds in.
func _te_snapshot(shot: Dictionary, lt: float) -> Dictionary:
	var e := clampf(lt / maxf(float(shot.dur), 0.001), 0.0, 1.0)
	if not shot.has("keys") or (shot["keys"] as Array).is_empty():
		e = _eased(e, float(shot.get("ease", DEFAULT_EASE)))
	return {
		"at": lt,
		"cam": _mix(shot, "cam", e, Vector3.ZERO),
		"look": _mix(shot, "look", e, Vector3(0, 0, -10)),
		"fov": float(_mix(shot, "fov", e, 30.0)),
		"ship": _mix(shot, "ship", e, Vector3.ZERO),
		"ship_yaw": float(_mix(shot, "ship_yaw", e, float(shot.get("ship_yaw", -90.0)))),
		"ship_pitch": float(_mix(shot, "ship_pitch", e, 0.0)),
		"ship_roll": float(_mix(shot, "ship_roll", e, 0.0)),
		"planet": _mix(shot, "planet", e, Vector3.ZERO),
		"tkhut": _mix(shot, "tkhut", e, Vector3(0, 0, -200)),
	}


## Gives a shot waypoints at its start and end (as it plays now), if it has none yet.
func _te_make_keys(index: int) -> void:
	var shot: Dictionary = _cut[index]
	if shot.has("keys") and not (shot["keys"] as Array).is_empty():
		return
	var a := _te_snapshot(shot, 0.0)
	var b := _te_snapshot(shot, float(shot.dur))
	shot["keys"] = [a, b]


## Seconds into the current shot, and the waypoint there (index) or -1.
func _te_local() -> float:
	return _time - float(_shot(_shot_index(_time)).start)


func _te_key_here(shot: Dictionary) -> int:
	if not shot.has("keys"):
		return -1
	var lt := _te_local()
	var keys: Array = shot["keys"]
	for i in keys.size():
		if absf(float(keys[i]["at"]) - lt) <= TE_SNAP:
			return i
	return -1


## The waypoint to edit: the one here, or a new one made here from what's on screen.
func _te_edit_key() -> Dictionary:
	var index := _shot_index(_time)
	_te_make_keys(index)
	var shot: Dictionary = _cut[index]
	var k := _te_key_here(shot)
	if k >= 0:
		return shot["keys"][k]
	var snap := _te_snapshot(shot, _te_local())
	(shot["keys"] as Array).append(snap)
	_te_normalise()
	_te_status = "New waypoint at %.1f s" % _te_local()
	return snap


func _te_nudge(prop: String, amount: Variant) -> void:
	var key := _te_edit_key()
	key[prop] = key[prop] + amount


# ---- editor on/off, keys, overview ----

func _set_titles_edit(on: bool) -> void:
	titles_edit = on
	_te_loop = -1
	if on:
		_set_paused(true)
		_shots()
		if _te_label == null:
			_te_label = Label.new()
			_te_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_te_label.position = Vector2(14, 30)
			_te_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
			_te_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			_te_label.add_theme_constant_override("outline_size", 4)
			_te_label.add_theme_font_size_override("font_size", 13)
			add_child(_te_label)
		_apply_time(_time)
	else:
		_te_set_overview(false)
	if _te_label != null:
		_te_label.visible = on
	_te_update_label()


## Jump to the next (+1) or previous (-1) waypoint in this shot (its start/end if it has none).
func _te_jump_key(dir: int) -> void:
	var shot := _shot(_shot_index(_time))
	var times: Array = []
	if shot.has("keys") and not (shot["keys"] as Array).is_empty():
		for k in shot["keys"]:
			times.append(float(k["at"]))
	else:
		times = [0.0, float(shot.dur)]
	var lt := _te_local()
	var target: float = times[0] if dir > 0 else times[-1]
	if dir > 0:
		for t in times:
			if t > lt + TE_SNAP:
				target = t
				break
	else:
		for i in range(times.size() - 1, -1, -1):
			if times[i] < lt - TE_SNAP:
				target = times[i]
				break
	# never quite on the boundary, so the time stays inside this shot
	target = clampf(target, 0.001, float(shot.dur) - 0.001)
	_seek_to(float(shot.start) + target)


## N: cut the current shot in two here. Both halves keep the path they had; the new shot starts
## with a straight cut (F turns the dip to black on or off).
func _te_split() -> void:
	var index := _shot_index(_time)
	var lt := _te_local()
	var shot: Dictionary = _cut[index]
	if lt < TE_MIN_SHOT or float(shot.dur) - lt < TE_MIN_SHOT:
		_te_status = "Too close to the start or end of the shot to cut here."
		return
	_te_make_keys(index)
	var here := _te_snapshot(shot, lt)
	var first: Dictionary = shot.duplicate(true)
	var second: Dictionary = shot.duplicate(true)
	var k1: Array = []
	var k2: Array = []
	for k in shot["keys"]:
		if float(k["at"]) < lt - 0.001:
			k1.append(k.duplicate())
		elif float(k["at"]) > lt + 0.001:
			var moved: Dictionary = k.duplicate()
			moved["at"] = float(k["at"]) - lt
			k2.append(moved)
	var end_a: Dictionary = here.duplicate()
	end_a["at"] = lt
	var start_b: Dictionary = here.duplicate()
	start_b["at"] = 0.0
	k1.append(end_a)
	k2.push_front(start_b)
	first["keys"] = k1
	first["dur"] = lt
	first["fade_out"] = 0.0
	second["keys"] = k2
	second["dur"] = float(shot.dur) - lt
	second["fade_in"] = 0.0
	second["name"] = "%d — NEW SHOT" % (index + 2)
	_cut[index] = first
	_cut.insert(index + 1, second)
	_te_renumber()
	_te_normalise()
	_seek_to(float(second.start) + 0.001)
	_te_status = "Cut made: this is a new shot. Move the camera and ship to make it your own."


## Delete: remove the current shot; the shot before it (or after, for the first) takes its time.
func _te_delete_shot() -> void:
	if _cut.size() <= 1:
		_te_status = "Can't delete the only shot."
		return
	var index := _shot_index(_time)
	var gone: Dictionary = _cut[index]
	var keeper := index - 1 if index > 0 else 1
	var k: Dictionary = _cut[keeper]
	_te_make_keys(keeper)
	k["dur"] = float(k["dur"]) + float(gone["dur"])
	if keeper > index:
		# the next shot starts earlier: its waypoints keep their place in the timeline
		for key in k["keys"]:
			key["at"] = float(key["at"]) + float(gone["dur"])
		k["fade_in"] = float(gone.get("fade_in", k.get("fade_in", 0.35)))
	_cut.remove_at(index)
	_te_renumber()
	_te_normalise()
	_seek_to(float(_cut[mini(index, _cut.size() - 1) if keeper > index else keeper].start) + 0.001)
	_te_status = "Shot deleted."


## [ / ]: move the cut at the START of this shot earlier or later (the shot before gives or takes the time).
func _te_move_cut(amount: float) -> void:
	var index := _shot_index(_time)
	if index == 0:
		_te_status = "The first shot always starts at 0:00."
		return
	var prev: Dictionary = _cut[index - 1]
	var shot: Dictionary = _cut[index]
	amount = clampf(amount, TE_MIN_SHOT - float(prev.dur), float(shot.dur) - TE_MIN_SHOT)
	if absf(amount) < 0.0001:
		return
	_te_make_keys(index)
	_te_make_keys(index - 1)
	prev["dur"] = float(prev.dur) + amount
	shot["dur"] = float(shot.dur) - amount
	# this shot's waypoints stay where they are in the timeline
	for key in shot["keys"]:
		key["at"] = maxf(float(key["at"]) - amount, 0.0)
	_te_normalise()
	_seek_to(float(shot.start) + 0.001)
	_te_status = "Cut now at %.1f s" % float(shot.start)


func _te_renumber() -> void:
	for i in _cut.size():
		var n := String(_cut[i].get("name", ""))
		var rest := n.substr(n.find(" ") + 1) if n.find(" ") >= 0 else n
		_cut[i]["name"] = "%d %s" % [i + 1, rest]


## V: look down on the scene from above with the ship's path (orange) and the camera's (blue) drawn in.
func _te_set_overview(on: bool) -> void:
	if not on and _te_overview_cam == null:
		_te_overview = false
		return
	_te_overview = on
	if _te_overview_cam == null:
		_te_overview_cam = Camera3D.new()
		_te_overview_cam.fov = 50.0
		_te_overview_cam.far = 4000.0
		_viewport.add_child(_te_overview_cam)
		_te_paths = MeshInstance3D.new()
		_te_paths.mesh = ImmediateMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.no_depth_test = true
		_te_paths.material_override = m
		_te_paths.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_viewport.add_child(_te_paths)
	_te_paths.visible = on
	if on:
		_te_draw_paths()
		_te_overview_cam.make_current()
	else:
		_camera.make_current()


func _te_draw_paths() -> void:
	if _te_paths == null or not _te_overview:
		return
	var shot := _shot(_shot_index(_time))
	var dur := float(shot.dur)
	var keyed: bool = shot.has("keys") and not (shot["keys"] as Array).is_empty()
	var im := _te_paths.mesh as ImmediateMesh
	im.clear_surfaces()
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var tracks := [["ship", Color(1.0, 0.55, 0.15), Vector3.ZERO], ["cam", Color(0.35, 0.75, 1.0), Vector3.ZERO]]
	for tr in tracks:
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in 61:
			var lt := dur * i / 60.0
			var e := lt / dur if keyed else _eased(lt / dur, float(shot.get("ease", DEFAULT_EASE)))
			var p: Vector3 = _mix(shot, String(tr[0]), e, tr[2])
			im.surface_set_color(tr[1])
			im.surface_add_vertex(p)
			lo = lo.min(p)
			hi = hi.max(p)
		im.surface_end()
	# waypoints as small crosses; where the ship and camera are right now as bigger ones
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var marks: Array = []
	if keyed:
		for k in shot["keys"]:
			marks.append([k["ship"], Color(1, 0.85, 0.5), 0.35])
			marks.append([k["cam"], Color(0.7, 0.9, 1.0), 0.35])
	marks.append([_ship.position, Color(1, 1, 1), 0.8])
	marks.append([_camera.position, Color(1, 1, 1), 0.8])
	for mk in marks:
		var p: Vector3 = mk[0]
		var r: float = mk[2]
		for ax in [Vector3.RIGHT, Vector3.FORWARD]:
			im.surface_set_color(mk[1])
			im.surface_add_vertex(p - ax * r)
			im.surface_set_color(mk[1])
			im.surface_add_vertex(p + ax * r)
	# the camera's line of sight, so you can see which way it looks
	var look: Vector3 = _camera.position + (-_camera.global_transform.basis.z) * 4.0
	im.surface_set_color(Color(0.7, 0.9, 1.0))
	im.surface_add_vertex(_camera.position)
	im.surface_set_color(Color(0.7, 0.9, 1.0))
	im.surface_add_vertex(look)
	im.surface_end()
	var mid := (lo + hi) * 0.5
	var span := maxf(maxf(hi.x - lo.x, hi.z - lo.z), 8.0)
	_te_overview_cam.position = mid + Vector3(0, span * 1.2 + 6.0, 0.01)
	_te_overview_cam.look_at(mid, Vector3.FORWARD)


## Called every frame while the shot editor is paused (keys held = smooth moves).
func _te_poll(delta: float) -> void:
	var speed := 1.0
	if Input.is_key_pressed(KEY_SHIFT):
		speed = 4.0
	elif Input.is_key_pressed(KEY_CTRL):
		speed = 0.2
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_key_pressed(KEY_D): move.x += 1.0
	if Input.is_key_pressed(KEY_Q): move.y -= 1.0
	if Input.is_key_pressed(KEY_E): move.y += 1.0
	if Input.is_key_pressed(KEY_W): move.z -= 1.0
	if Input.is_key_pressed(KEY_S): move.z += 1.0
	var a := 0.0
	var b := 0.0
	var c := 0.0
	if Input.is_key_pressed(KEY_J): a -= 1.0
	if Input.is_key_pressed(KEY_L): a += 1.0
	if Input.is_key_pressed(KEY_I): b += 1.0
	if Input.is_key_pressed(KEY_K) and not Input.is_key_pressed(KEY_CTRL): b -= 1.0
	if Input.is_key_pressed(KEY_U): c -= 1.0
	if Input.is_key_pressed(KEY_O): c += 1.0
	var size := 0.0
	if Input.is_key_pressed(KEY_EQUAL): size += 1.0
	if Input.is_key_pressed(KEY_MINUS): size -= 1.0
	if move == Vector3.ZERO and a == 0.0 and b == 0.0 and c == 0.0 and size == 0.0:
		return
	var step: float = speed * delta
	var index := _shot_index(_time)
	var shot := _shot(index)
	# Moves follow the camera's own directions: A/D = screen left/right,
	# Q/E = up/down, W/S = away/closer, whichever way the camera faces.
	var view := _camera.global_transform.basis
	var flat_fwd := Vector3(view.z.x, 0.0, view.z.z).normalized() if Vector3(view.z.x, 0.0, view.z.z).length() > 0.01 else Vector3(0, 0, 1)
	var screen_move := view.x * move.x + Vector3.UP * move.y + flat_fwd * move.z
	match _te_target:
		0:
			if move != Vector3.ZERO: _te_nudge("ship", screen_move * 4.0 * step)
			if a != 0.0: _te_nudge("ship_yaw", -a * 45.0 * step)
			if b != 0.0: _te_nudge("ship_pitch", b * 30.0 * step)
			if c != 0.0: _te_nudge("ship_roll", c * 30.0 * step)
		1:
			if move != Vector3.ZERO:
				# camera and what it looks at move together: a dolly, not a turn
				_te_nudge("cam", screen_move * 4.0 * step)
				_te_nudge("look", screen_move * 4.0 * step)
			if a != 0.0 or b != 0.0:
				var key := _te_edit_key()
				var cam: Vector3 = key["cam"]
				var look: Vector3 = key["look"]
				var dir := look - cam
				var turned := dir.rotated(Vector3.UP, deg_to_rad(-a * 25.0 * step))
				var side := turned.cross(Vector3.UP).normalized()
				turned = turned.rotated(side, deg_to_rad(b * 20.0 * step))
				key["look"] = cam + turned
			if c != 0.0: _te_nudge("fov", c * 12.0 * step)
		2:
			if bool(shot.get("planet", false)):
				_te_nudge("planet", screen_move * 12.0 * step)
		3:
			if bool(shot.get("tkhut", false)):
				if move != Vector3.ZERO:
					_te_nudge("tkhut", screen_move * 20.0 * step)
				if size != 0.0:
					_cut[index]["tkhut_size"] = maxf(1.0, float(shot.get("tkhut_size", TKHUT_RADIUS)) + size * 6.0 * step)
	_apply_time(_time)
	_te_draw_paths()
	_te_update_label()


func _te_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_F1:
		_set_titles_edit(not titles_edit)
		return true
	if not titles_edit:
		return false
	var index := _shot_index(_time)
	var shot: Dictionary = _shot(index)
	match event.keycode:
		KEY_1: _te_target = 0
		KEY_2: _te_target = 1
		KEY_3: _te_target = 2
		KEY_4: _te_target = 3
		KEY_TAB:
			_te_loop = -1
			_set_paused(true)
			_te_jump_key(-1 if event.shift_pressed else 1)
		KEY_LEFT, KEY_RIGHT:
			_te_loop = -1
			_set_paused(true)
			_seek_shot(-1 if event.keycode == KEY_LEFT else 1)
			_seek_to(_time + 0.001)
		KEY_K:
			if event.ctrl_pressed:
				_set_paused(true)
				_te_edit_key()
				_te_status = "Waypoint here (%.1f s into the shot)" % _te_local()
			else:
				return true      # K alone is "look down" / "nose down" while held (_te_poll)
		KEY_X:
			_set_paused(true)
			var k := _te_key_here(shot)
			if k < 0:
				_te_status = "No waypoint here - Tab jumps to one."
			elif (shot["keys"] as Array).size() <= 1:
				_te_status = "A shot needs at least one waypoint."
			else:
				(shot["keys"] as Array).remove_at(k)
				_te_status = "Waypoint deleted."
		KEY_N:
			_set_paused(true)
			_te_split()
		KEY_DELETE:
			_set_paused(true)
			_te_delete_shot()
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			_set_paused(true)
			var amount := (1.0 if event.shift_pressed else 0.1) * (-1.0 if event.keycode == KEY_BRACKETLEFT else 1.0)
			_te_move_cut(amount)
		KEY_H:
			shot["ship"] = not bool(shot.get("ship", true))
			_te_status = "Ship %s in this shot" % ("ON" if shot["ship"] else "OFF")
		KEY_G:
			shot["planet"] = not bool(shot.get("planet", false))
			_te_status = "Vulcan %s in this shot" % ("ON" if shot["planet"] else "OFF")
		KEY_T:
			shot["tkhut"] = not bool(shot.get("tkhut", false))
			_te_status = "T'Khut %s in this shot" % ("ON" if shot["tkhut"] else "OFF")
		KEY_F:
			# the cut INTO this shot: straight cut <-> quick dip to black
			if float(shot.get("fade_in", 0.0)) > 0.0:
				shot["fade_in"] = 0.0
				if index > 0: _cut[index - 1]["fade_out"] = 0.0
				_te_status = "Straight cut into this shot."
			else:
				shot["fade_in"] = 0.35
				if index > 0: _cut[index - 1]["fade_out"] = 0.3
				_te_status = "Dip to black into this shot."
		KEY_V:
			_te_set_overview(not _te_overview)
			_te_status = "Looking down from above: orange = ship's path, blue = camera's. V to go back." if _te_overview else ""
		KEY_F5: _save_titles_layout()
		KEY_R:
			# this shot back to how it was: no waypoints (its original start and end)
			if event.shift_pressed:
				_cut[index].erase("keys")
				_te_status = "This shot's waypoints removed (F5 to save that)."
			else:
				return false
		KEY_ENTER, KEY_KP_ENTER:
			# REV 218: Enter plays this shot from its start, round and round (never into the next
			# shot); Enter again stops it. Space pauses where it is.
			if _te_loop >= 0:
				_te_loop = -1
				_set_paused(true)
				_te_status = "Stopped."
			else:
				_te_loop = index
				_seek_to(float(shot.start))
				_set_paused(false)
				_te_status = "LOOPING THIS SHOT - Enter to stop, Space to pause"
		_:
			return event.keycode in [KEY_A, KEY_D, KEY_Q, KEY_E, KEY_W, KEY_S, KEY_J, KEY_L, KEY_I, KEY_U, KEY_O, KEY_MINUS, KEY_EQUAL]
	_apply_time(_time)
	_te_draw_paths()
	_te_update_label()
	return true


func _te_update_label() -> void:
	if _te_label == null or not titles_edit:
		return
	var index := _shot_index(_time)
	var shot := _shot(index)
	var what: String = ["SHIP", "CAMERA", "VULCAN", "T'KHUT"][_te_target]
	var keys: Array = shot.get("keys", [])
	var k := _te_key_here(shot)
	var where := ("on waypoint %d of %d" % [k + 1, keys.size()]) if k >= 0 else ("between waypoints (%d in this shot)" % keys.size() if not keys.is_empty() else "no waypoints yet - editing makes them")
	var text := "SHOT EDITOR (F1 = close)   shot %d of %d: %s   %.1f s of %.1f   [%s]\n" % [index + 1, _cut.size(), String(shot.get("name", "")), _te_local(), float(shot.dur), what]
	text += "%s\n" % where
	text += "1 ship  2 camera  3 Vulcan  4 T'Khut     A/D Q/E W/S move (Shift faster, Ctrl finer)\n"
	match _te_target:
		0: text += "J/L turn   I/K nose up/down   U/O bank\n"
		1: text += "J/L look left/right   I/K look up/down   U/O zoom\n"
		3: text += "-/= size\n"
	text += "PATHS: Tab / Shift+Tab next/previous waypoint   , . step through time   Ctrl+K waypoint here   X delete waypoint\n"
	text += "       moving something between waypoints makes a new one there   Shift+R remove this shot's waypoints\n"
	text += "SHOTS: N cut a new shot here   Delete remove this shot   [ ] move this shot's start (Shift = 1 s)   Left/Right other shot\n"
	text += "       H ship on/off   G Vulcan on/off   T T'Khut on/off   F straight cut / dip to black\n"
	text += "Enter loop this shot   V view from above   F5 SAVE\n"
	if _te_status != "":
		text += _te_status + "\n"
	# REV 293: the sequence's own warning, if it has one (the teaser: "this cut no longer matches ...")
	if opening.get("edit_note") is Callable:
		var note := String((opening["edit_note"] as Callable).call())
		if note != "":
			text += note + "\n"
	_te_label.text = text


## Debug helper: press M while the sequence plays (or paused) to log the current
## time. Tap it at each moment you want something to happen (a cut, a title, a
## music hit); every marker is printed in Godot's Output panel, numbered, so the
## whole list can be copied out afterwards.
var _markers: Array[float] = []


func _drop_marker() -> void:
	_markers.append(_time)
	var line := "MARKER %d: %d:%05.2f  (%.2f s)" % [_markers.size(), int(_time) / 60, fposmod(_time, 60.0), _time]
	print("[TitleSequence] ", line)
	if _timecode_label != null:
		_timecode_label.text = line


func _set_paused(paused: bool) -> void:
	_paused = paused
	_music_player.stream_paused = paused
	_vo_player.stream_paused = paused
	_apply_time(_time)


func _eased(u: float, amount: float) -> float:
	return lerpf(u, u * u * (3.0 - 2.0 * u), clampf(amount, 0.0, 1.0))


## Reads a from/to pair out of a shot and blends it.
func _mix(shot: Dictionary, key: String, e: float, default: Variant) -> Variant:
	# REV 219: a shot with waypoints follows the path through them (e = share of the shot's time)
	if shot.has("keys") and not (shot["keys"] as Array).is_empty() and key in TE_KEY_PROPS:
		var v: Variant = _path_value(shot["keys"], key, e * float(shot.get("dur", 1.0)))
		if v != null:
			return v
	var a: Variant = shot.get(key + "_from", default)
	var b: Variant = shot.get(key + "_to", a)
	return lerp(a, b, e)


## Points the sky's nebula at a spot relative to the shot's opening view.
## Done once per shot (not per frame) so the sky is never re-rendered mid-shot;
## the change lands under the dip-to-black between shots.
func _place_nebula(shot: Dictionary) -> void:
	var cam0: Vector3 = _mix(shot, "cam", 0.0, Vector3.ZERO)
	var look0: Vector3 = _mix(shot, "look", 0.0, Vector3(0, 0, -10))
	var forward := (look0 - cam0).normalized()
	if forward.length() < 0.5:
		forward = Vector3(0, 0, -1)
	var right := forward.cross(Vector3.UP).normalized()
	var dir := forward.rotated(Vector3.UP, deg_to_rad(-float(shot.get("neb_az", 20.0))))
	dir = dir.rotated(right, deg_to_rad(float(shot.get("neb_el", 5.0))))
	_sky_material.set_shader_parameter("nebula_dir", dir.normalized())
	_sky_material.set_shader_parameter("nebula_size", deg_to_rad(float(shot.get("neb_size", 24.0))))
	_sky_material.set_shader_parameter("nebula_amount", float(shot.get("neb", 0.8)))
	# Companion stars: same "relative to the opening view" placement as the nebula.
	var b_dir := forward.rotated(Vector3.UP, deg_to_rad(-float(shot.get("twins_az", 0.0))))
	b_dir = b_dir.rotated(right, deg_to_rad(float(shot.get("twins_el", 8.0))))
	_twins_dir_b = b_dir.normalized()
	var b_right := _twins_dir_b.cross(Vector3.UP).normalized()
	var c_dir := _twins_dir_b.rotated(Vector3.UP, deg_to_rad(-TWIN_C_OFFSET_DEG.x))
	_twins_dir_c = c_dir.rotated(b_right, deg_to_rad(TWIN_C_OFFSET_DEG.y)).normalized()


func _apply_time(t: float) -> void:
	var shot: Dictionary = _shot(_shot_index(t))
	var local_t: float = t - float(shot.start)
	var duration: float = float(shot.dur)
	var u: float = clampf(local_t / duration, 0.0, 1.0)
	var e: float = _eased(u, float(shot.get("ease", DEFAULT_EASE)))
	if shot.has("keys") and not (shot["keys"] as Array).is_empty():
		e = u      # REV 219: waypoints are placed on the real clock

	var cam_pos: Vector3 = _mix(shot, "cam", e, Vector3.ZERO)
	var look_at_pos: Vector3 = _mix(shot, "look", e, Vector3(0, 0, -10))
	_camera.position = cam_pos
	if not cam_pos.is_equal_approx(look_at_pos):
		_camera.look_at(look_at_pos, Vector3.UP)
	_camera.fov = _mix(shot, "fov", e, 30.0)

	var shot_index := _shot_index(t)
	if shot_index != _nebula_shot:
		_nebula_shot = shot_index
		_place_nebula(shot)
		var shadows: bool = bool(shot.get("ship_shadow", true))
		for node in _ship.find_children("*", "GeometryInstance3D", true, false):
			if String(node.name).begins_with("NavLight"):
				continue      # glow cards never cast shadows
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_ship.visible = bool(shot.get("ship", true))
	_ship.position = _mix(shot, "ship", e, Vector3.ZERO)
	# Heading, pitch and bank; each may ease across the shot (REV 200).
	var yaw: float = _mix(shot, "ship_yaw", e, float(shot.get("ship_yaw", -90.0)))
	var pitch: float = _mix(shot, "ship_pitch", e, 0.0)
	var roll: float = _mix(shot, "ship_roll", e, 0.0)
	_ship.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(-roll))
	var glow: float = _mix(shot, "glow", e, 1.0)
	for material in _glow_materials:
		material.emission_energy_multiplier = glow * ENGINE_GLOW_SCALE * float(material.get_meta("base_energy", 2.2))
	for material in _bussard_materials:
		material.set_shader_parameter("energy", glow * ENGINE_GLOW_SCALE * float(material.get_meta("base_energy", 2.2)))
	_update_nav_lights()

	var planet_visible: bool = bool(shot.get("planet", false))
	_planet.visible = planet_visible
	var planet_pos: Vector3 = _mix(shot, "planet", e, Vector3.ZERO)
	_planet.position = planet_pos
	# Face the map's middle toward the camera so the seam is always round the
	# back, then add the shot's own turn plus a very slow spin.
	var to_cam := _camera.position - planet_pos
	_planet.rotation.y = atan2(to_cam.x, to_cam.z) + deg_to_rad(float(shot.get("planet_lon", 0.0)) + local_t * PLANET_SPIN_DEG_PER_SECOND)

	_sun.look_at_from_position(shot.get("sun_pos", Vector3(10, 12, 8)), Vector3.ZERO, Vector3.UP)
	var sun_energy: float = _mix(shot, "sun", e, 1.4)
	_sun.light_energy = sun_energy
	var sun_position: Vector3 = shot.get("sun_pos", Vector3(10, 12, 8))
	_rim.look_at_from_position(Vector3(-sun_position.x, absf(sun_position.y) * 0.5 + 4.0, -sun_position.z), Vector3.ZERO, Vector3.UP)
	_rim.light_energy = RIM_ENERGY * clampf(sun_energy / 1.2, 0.0, 1.0)

	_warm_light.light_energy = _mix(shot, "warm", e, 0.0)
	_warm_light.position = planet_pos + Vector3(-10, 0, 25)

	var tkhut_visible: bool = bool(shot.get("tkhut", false))
	_tkhut.visible = tkhut_visible
	if tkhut_visible:
		var tkhut_pos: Vector3 = _mix(shot, "tkhut", e, Vector3(0, 0, -200))
		_tkhut.position = tkhut_pos
		_tkhut.scale = Vector3.ONE * (float(shot.get("tkhut_size", TKHUT_RADIUS)) / TKHUT_RADIUS)
		_tkhut.rotation.y = deg_to_rad(40.0 + local_t * PLANET_SPIN_DEG_PER_SECOND)

	var twins: float = _mix(shot, "twins", e, float(shot.get("twins", 0.0)))
	_twin_b.visible = twins > 0.001
	_twin_c.visible = twins > 0.001
	if twins > 0.001:
		_twin_b.position = _camera.position + _twins_dir_b * TWINS_DISTANCE
		_twin_c.position = _camera.position + _twins_dir_c * TWINS_DISTANCE
		_twin_b_material.albedo_color = Color(0.85, 0.92, 1.0, clampf(twins, 0.0, 1.0))
		_twin_c_material.albedo_color = Color(1.0, 0.42, 0.25, clampf(twins, 0.0, 1.0) * 0.8)

	var flare: float = _mix(shot, "flare", e, 0.0)
	_flare.visible = planet_visible and flare > 0.001
	_flare.position = planet_pos + Vector3(19, 3, -6)
	_flare_material.albedo_color = Color(1.0, 0.8, 0.5, clampf(flare, 0.0, 1.0) * FLARE_STRENGTH)

	var fade_in: float = float(shot.get("fade_in", 0.35))
	var fade_out: float = float(shot.get("fade_out", 0.35))
	var black := 0.0
	if fade_in > 0.0:
		black = maxf(black, 1.0 - local_t / fade_in)
	if fade_out > 0.0:
		black = maxf(black, 1.0 - (duration - local_t) / fade_out)
	if titles_edit and _paused:
		black = 0.0      # shot editor: always show the frame being edited, not the dip to black
	_fade.color.a = clampf(black, 0.0, 1.0)

	_update_subtitles(t)
	_fill.basis = _camera.basis * Basis(Vector3.UP, deg_to_rad(28.0)) * Basis(Vector3.RIGHT, deg_to_rad(-30.0))
	if _timecode_label != null:
		_timecode_label.text = "%d:%04.1f   %s%s" % [int(t) / 60, fposmod(t, 60.0), String(shot.get("name", "")), "   [PAUSED]" if _paused else ""]

	for label in _title_labels:
		var start: float = float(label.get_meta("start"))
		var fade: float = maxf(float(label.get_meta("fade")), 0.01)
		var visible_now: bool = t < float(label.get_meta("end"))
		label.modulate.a = clampf((t - start) / fade, 0.0, 1.0) if visible_now else 0.0

	# REV 237 (teaser): the opening's own per-frame work (warp tunnel, its own camera moves)
	if opening.has("on_frame"):
		(opening["on_frame"] as Callable).call(t, shot, local_t, e)


## REV 237: the clock (seconds since the sequence started) - an opening that drives other things in step.
func current_time() -> float:
	return _time


## REV 237: the space world's camera and ship, for an opening that moves them itself.
func space_camera() -> Camera3D:
	return _camera


func space_ship() -> Node3D:
	return _ship


# -------------------------------------------------------------- menu shot --

# THE MAIN-MENU SHOT. Everything is a number you can nudge. The left third of
# the picture is kept clear for the title and menu: Vulcan fills the right,
# the Enterprise sits centre-right. Coordinates work as in the SHOTS list
# (+X is screen right, the ship is ~10 units long, Vulcan's radius is
# PLANET_RADIUS).
const MENU_CAM_POS := Vector3(-2.0, -1.0, 30.0)
const MENU_CAM_LOOK := Vector3(3.0, -2.2, -6.0)
const MENU_FOV := 30.0
# Vulcan sits far behind the ship (so it reads as a world, not a wall) and is
# scaled up so it still fills the same part of the picture.
const MENU_PLANET_POS := Vector3(43.0, -22.4, -40.0)
const MENU_PLANET_SCALE := 1.667
# Negative = the surface slides backwards under the ship, which is what sells
# "orbiting". Degrees per second.
const MENU_PLANET_SPIN := -0.3
const MENU_PLANET_LON := 14.0
const MENU_SHIP_POS := Vector3(4.1, 1.0, 4.0)
const MENU_SHIP_SCALE := 1.37           # the ship is small against a whole world
const MENU_SHIP_YAW := -175.0           # -90 = nose points right; -180 = nose points straight at the camera. -135 is a three-quarter view
const MENU_SHIP_ROLL := 10.4            # banks the ship a little, like a ship in a turn
const MENU_SHIP_PITCH := -7.0            # nose slightly up
const MENU_SUN_POS := Vector3(-26.0, 12.0, 14.0)
const MENU_SUN_ENERGY := 1.4
const MENU_WARM := 1.3
const MENU_GLOW := 1.3
# How far the picture drifts, and how long one slow swing takes (seconds).
const MENU_DRIFT_PERIOD := 140.0
const MENU_SHIP_DRIFT := Vector3(0.0, 0.25, 0.0)    # ship bobs this far each way (it never flies backwards)
const MENU_SHIP_YAW_DRIFT := 3.0                   # degrees
const MENU_CAM_DRIFT := Vector3(1.2, 0.35, 0.8)    # camera wanders this far each way
const MENU_GLOW_FLUTTER := 0.08                   # engine glow breathes by this much

var _menu_nebula_done: bool = false
var _planet_material: ShaderMaterial

# Cloud layer (menu only), painted into Vulcan's own surface shader. The look
# is tuned by these (coverage = how cloudy, amount = how solid, scale = size of
# the cloud banks; higher scale = smaller clouds).
const MENU_CLOUDS_ENABLED := false         # clouds are switched off; set true to bring them back
const MENU_CLOUD_AMOUNT := 0.85
const MENU_CLOUD_COVERAGE := 0.30
const MENU_CLOUD_SOFTNESS := 0.22
const MENU_CLOUD_SCALE := 4.5
const MENU_CLOUD_SPIN := -0.12            # degrees per second, on top of the planet's own turn

# The live values (start from the constants above; the layout editor changes them).
var _m_cam_pos: Vector3 = MENU_CAM_POS
var _m_cam_look: Vector3 = MENU_CAM_LOOK
var _m_fov: float = MENU_FOV
var _m_planet_pos: Vector3 = MENU_PLANET_POS
var _m_planet_scale: float = MENU_PLANET_SCALE
var _m_ship_pos: Vector3 = MENU_SHIP_POS
var _m_ship_scale: float = MENU_SHIP_SCALE
var _m_ship_yaw: float = MENU_SHIP_YAW
var _m_ship_pitch: float = MENU_SHIP_PITCH
var _m_ship_roll: float = MENU_SHIP_ROLL

## Debug-only layout editor (press F1 on the main menu). While it is on, the
## menu hides, the drift stops, and keys move things; the numbers show on
## screen so you can screenshot them. See _edit_help().
var menu_edit: bool = false
var _edit_target: int = 0     # 0 = ship, 1 = camera, 2 = planet
var _edit_label: Label


func _apply_menu(t: float) -> void:
	var drift: float = 0.0 if menu_edit else 1.0
	var swing: float = sin(t * TAU / MENU_DRIFT_PERIOD) * drift
	var swing2: float = sin(t * TAU / (MENU_DRIFT_PERIOD * 0.73) + 1.3) * drift

	var cam_pos: Vector3 = _m_cam_pos + MENU_CAM_DRIFT * Vector3(swing, swing2, swing)
	_camera.position = cam_pos
	_camera.look_at(_m_cam_look, Vector3.UP)
	_camera.fov = _m_fov

	if not _menu_nebula_done:
		_menu_nebula_done = true
		_place_nebula({
			"cam_from": MENU_CAM_POS, "look_from": MENU_CAM_LOOK,
			"neb": 0.4, "neb_az": -28.0, "neb_el": 8.0, "neb_size": 14.0,
		})

	_ship.visible = true
	_ship.scale = Vector3.ONE * _m_ship_scale
	_ship.position = _m_ship_pos + MENU_SHIP_DRIFT * Vector3(swing, swing2, swing)
	_ship.rotation = Vector3(deg_to_rad(_m_ship_pitch), deg_to_rad(_m_ship_yaw + MENU_SHIP_YAW_DRIFT * swing2), deg_to_rad(_m_ship_roll))
	_tkhut.visible = false      # titles-only scenery (REV 200)
	_twin_b.visible = false
	_twin_c.visible = false
	var glow: float = MENU_GLOW + MENU_GLOW_FLUTTER * sin(t * 0.9) + MENU_GLOW_FLUTTER * 0.5 * sin(t * 2.3)
	for material in _glow_materials:
		material.emission_energy_multiplier = glow * ENGINE_GLOW_SCALE * float(material.get_meta("base_energy", 2.2))
	for material in _bussard_materials:
		material.set_shader_parameter("energy", glow * ENGINE_GLOW_SCALE * float(material.get_meta("base_energy", 2.2)))
	_update_nav_lights()

	_planet.visible = true
	_planet.position = _m_planet_pos
	_planet.scale = Vector3.ONE * _m_planet_scale
	if _planet_material != null:
		_planet_material.set_shader_parameter("cloud_rot", deg_to_rad(t * MENU_CLOUD_SPIN))
	var to_cam := _camera.position - _m_planet_pos
	_planet.rotation.y = atan2(to_cam.x, to_cam.z) + deg_to_rad(MENU_PLANET_LON + t * MENU_PLANET_SPIN)

	_sun.look_at_from_position(MENU_SUN_POS, Vector3.ZERO, Vector3.UP)
	_sun.light_energy = MENU_SUN_ENERGY
	_rim.look_at_from_position(Vector3(-MENU_SUN_POS.x, absf(MENU_SUN_POS.y) * 0.5 + 4.0, -MENU_SUN_POS.z), Vector3.ZERO, Vector3.UP)
	_rim.light_energy = RIM_ENERGY * clampf(MENU_SUN_ENERGY / 1.2, 0.0, 1.0)
	_warm_light.light_energy = MENU_WARM
	_warm_light.position = _m_planet_pos + Vector3(-10, 0, 25)
	_flare.visible = false
	_fade.color.a = 0.0
	_subtitle_label.modulate.a = 0.0
	_fill.basis = _camera.basis * Basis(Vector3.UP, deg_to_rad(28.0)) * Basis(Vector3.RIGHT, deg_to_rad(-30.0))
	if menu_edit:
		_update_edit_label()


## Turns the cloud layer on in Vulcan's surface shader.
func _start_clouds() -> void:
	_planet_material = _planet.material_override as ShaderMaterial
	if _planet_material == null or not MENU_CLOUDS_ENABLED:
		_planet_material = null
		return
	_planet_material.set_shader_parameter("cloud_amount", MENU_CLOUD_AMOUNT)
	_planet_material.set_shader_parameter("cloud_coverage", MENU_CLOUD_COVERAGE)
	_planet_material.set_shader_parameter("cloud_softness", MENU_CLOUD_SOFTNESS)
	_planet_material.set_shader_parameter("cloud_scale", MENU_CLOUD_SCALE)


# ------------------------------------------------------ layout editor (F1) --

func _set_menu_edit(on: bool) -> void:
	menu_edit = on
	if on and _edit_label == null:
		_edit_label = Label.new()
		_edit_label.position = Vector2(14, 10)
		_edit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edit_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
		_edit_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_edit_label.add_theme_constant_override("outline_size", 4)
		_edit_label.add_theme_font_size_override("font_size", 13)
		add_child(_edit_label)
	if _edit_label != null:
		_edit_label.visible = on
	if not on:
		_apply_menu(_time)


func _edit_help() -> String:
	return "LAYOUT EDITOR  (F1 = exit)\n" \
		+ "1 = ship   2 = camera   3 = planet     [now: %s]\n" % ["SHIP", "CAMERA", "PLANET"][_edit_target] \
		+ "A/D = left/right    Q/E = down/up    W/S = away/toward camera\n" \
		+ "ship:   J/L = turn   I/K = nose up/down   U/O = bank   -/= = size\n" \
		+ "camera: J/L = look left/right   I/K = look up/down   U/O = zoom\n" \
		+ "planet: -/= = size\n" \
		+ "Hold SHIFT = faster, CTRL = finer.   R = reset all.   P = print values.\n"


func _update_edit_label() -> void:
	if _edit_label == null:
		return
	var text := _edit_help() + "\n"
	text += "MENU_SHIP_POS = Vector3(%.2f, %.2f, %.2f)\n" % [_m_ship_pos.x, _m_ship_pos.y, _m_ship_pos.z]
	text += "MENU_SHIP_YAW = %.1f    MENU_SHIP_PITCH = %.1f    MENU_SHIP_ROLL = %.1f    MENU_SHIP_SCALE = %.2f\n" % [_m_ship_yaw, _m_ship_pitch, _m_ship_roll, _m_ship_scale]
	text += "MENU_CAM_POS = Vector3(%.2f, %.2f, %.2f)\n" % [_m_cam_pos.x, _m_cam_pos.y, _m_cam_pos.z]
	text += "MENU_CAM_LOOK = Vector3(%.2f, %.2f, %.2f)    MENU_FOV = %.1f\n" % [_m_cam_look.x, _m_cam_look.y, _m_cam_look.z, _m_fov]
	text += "MENU_PLANET_POS = Vector3(%.2f, %.2f, %.2f)    MENU_PLANET_SCALE = %.3f\n" % [_m_planet_pos.x, _m_planet_pos.y, _m_planet_pos.z, _m_planet_scale]
	_edit_label.text = text


func _edit_reset() -> void:
	_m_cam_pos = MENU_CAM_POS
	_m_cam_look = MENU_CAM_LOOK
	_m_fov = MENU_FOV
	_m_planet_pos = MENU_PLANET_POS
	_m_planet_scale = MENU_PLANET_SCALE
	_m_ship_pos = MENU_SHIP_POS
	_m_ship_scale = MENU_SHIP_SCALE
	_m_ship_yaw = MENU_SHIP_YAW
	_m_ship_pitch = MENU_SHIP_PITCH
	_m_ship_roll = MENU_SHIP_ROLL


## Called every frame while the editor is on.
func _edit_poll(delta: float) -> void:
	var speed := 1.0
	if Input.is_key_pressed(KEY_SHIFT):
		speed = 4.0
	elif Input.is_key_pressed(KEY_CTRL):
		speed = 0.2
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_key_pressed(KEY_D): move.x += 1.0
	if Input.is_key_pressed(KEY_Q): move.y -= 1.0
	if Input.is_key_pressed(KEY_E): move.y += 1.0
	if Input.is_key_pressed(KEY_W): move.z -= 1.0
	if Input.is_key_pressed(KEY_S): move.z += 1.0
	move *= 6.0 * speed * delta
	var turn_a := 0.0   # J/L
	var turn_b := 0.0   # I/K
	var turn_c := 0.0   # U/O
	if Input.is_key_pressed(KEY_J): turn_a -= 1.0
	if Input.is_key_pressed(KEY_L): turn_a += 1.0
	if Input.is_key_pressed(KEY_I): turn_b += 1.0
	if Input.is_key_pressed(KEY_K): turn_b -= 1.0
	if Input.is_key_pressed(KEY_U): turn_c -= 1.0
	if Input.is_key_pressed(KEY_O): turn_c += 1.0
	var grow := 0.0
	if Input.is_key_pressed(KEY_EQUAL): grow += 1.0
	if Input.is_key_pressed(KEY_MINUS): grow -= 1.0
	var scale_factor: float = 1.0 + grow * 0.6 * speed * delta

	match _edit_target:
		0:
			_m_ship_pos += move
			_m_ship_yaw += turn_a * 60.0 * speed * delta
			_m_ship_pitch += turn_b * 40.0 * speed * delta
			_m_ship_roll += turn_c * 40.0 * speed * delta
			_m_ship_scale *= scale_factor
		1:
			_m_cam_pos += move
			_m_cam_look += Vector3(turn_a, turn_b, 0.0) * 8.0 * speed * delta
			_m_fov = clampf(_m_fov + turn_c * 15.0 * speed * delta, 8.0, 90.0)
		2:
			_m_planet_pos += move
			_m_planet_scale *= scale_factor


func _edit_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_F1:
			_set_menu_edit(not menu_edit)
			return true
	if not menu_edit:
		return false
	match event.keycode:
		KEY_1: _edit_target = 0
		KEY_2: _edit_target = 1
		KEY_3: _edit_target = 2
		KEY_R: _edit_reset()
		KEY_P:
			print("---- MENU LAYOUT ----")
			print(_edit_label.text.substr(_edit_label.text.find("MENU_SHIP_POS")))
		_:
			return event.keycode in [KEY_A, KEY_D, KEY_Q, KEY_E, KEY_W, KEY_S, KEY_J, KEY_L, KEY_I, KEY_K, KEY_U, KEY_O, KEY_MINUS, KEY_EQUAL]
	return true


# ------------------------------------------------------------------ layout --

func _layout() -> void:
	var window_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = window_size
	_bg.position = Vector2.ZERO
	_bg.size = window_size
	_fade.position = Vector2.ZERO
	_fade.size = window_size
	var frame := window_size
	var aspect := float(opening.get("aspect", FRAME_ASPECT))
	if aspect > 0.0 and not menu_mode:
		frame.y = minf(window_size.y, window_size.x / aspect)
	var origin: Vector2 = (window_size - frame) / 2.0

	# Render the 3D at real window resolution, not at the 1280x720 UI
	# coordinate size, so it stays sharp on 1440p/4K.
	var pixel_scale := 1.0
	if get_window() != null and window_size.x > 0.0:
		pixel_scale = maxf(float(get_window().size.x) / window_size.x, 1.0)
	var render_size: Vector2 = frame * pixel_scale * RENDER_SCALE
	if render_size.x > MAX_RENDER_WIDTH:
		render_size *= MAX_RENDER_WIDTH / render_size.x
	_viewport.size = Vector2i(maxi(int(render_size.x), 2), maxi(int(render_size.y), 2))

	_view.position = origin
	_view.size = frame
	_titles_root.position = origin
	_titles_root.size = frame

	# Subtitles live in the black bar under the picture. With no real bar
	# (window narrower than the frame aspect) they sit low inside the picture.
	var bar_height: float = window_size.y - (origin.y + frame.y)
	var window_text_scale: float = window_size.y / 720.0
	_subtitle_label.add_theme_font_size_override("font_size", maxi(int(SUBTITLE_FONT_SIZE * window_text_scale), 8))
	var subtitle_width: float = window_size.x * 0.7
	if bar_height >= 40.0 * window_text_scale:
		_subtitle_label.size = Vector2(subtitle_width, bar_height * 0.8)
		_subtitle_label.position = Vector2((window_size.x - subtitle_width) / 2.0, origin.y + frame.y + bar_height * 0.1)
	else:
		_subtitle_label.size = Vector2(subtitle_width, 60.0 * window_text_scale)
		_subtitle_label.position = Vector2((window_size.x - subtitle_width) / 2.0, window_size.y - 80.0 * window_text_scale)

	var text_scale: float = frame.y / REFERENCE_FRAME_HEIGHT
	for label in _title_labels:
		label.add_theme_font_size_override("font_size", maxi(int(float(label.get_meta("base_size")) * text_scale), 6))


# ------------------------------------------------------------------ titles --

## A soft dark outline and drop shadow so titles stay readable over the bright
## nebula and the planet's edge.
func _add_text_backing(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _build_titles() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.anchor_left = 0.5
	box.anchor_right = 0.97
	box.anchor_top = 0.0
	box.anchor_bottom = 1.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titles_root.add_child(box)

	_credit_box = VBoxContainer.new()
	_credit_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_credit_box.anchor_left = 0.2
	_credit_box.anchor_right = 0.8
	_credit_box.anchor_top = 0.78
	_credit_box.anchor_bottom = 0.93
	_credit_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titles_root.add_child(_credit_box)

	for line in _title_lines():
		if line.has("gap_before"):
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, float(line.gap_before))
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(gap)
		var label := Label.new()
		label.text = line.text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", line.color)
		_add_text_backing(label)
		var font: Font = UITheme.font_bold if bool(line.bold) else UITheme.font_regular
		if line.has("logo_font"):
			var logo_font: Font = _load_logo_font()
			if logo_font != null:
				font = logo_font
		if line.has("tracking") and font != null:
			var spaced := FontVariation.new()
			spaced.base_font = font
			spaced.spacing_glyph = int(line["tracking"])
			font = spaced
		if font != null:
			label.add_theme_font_override("font", font)
		label.modulate.a = 0.0
		label.set_meta("start", line.start)
		label.set_meta("fade", line.fade)
		label.set_meta("end", line.get("end", 1.0e9))
		label.set_meta("base_size", line["size"])
		if line.get("area", "main") == "credit":
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.anchor_left = 0.1
			label.anchor_right = 0.9
			label.anchor_top = 0.8
			label.anchor_bottom = 0.92
			label.offset_left = 0.0
			label.offset_right = 0.0
			label.offset_top = 0.0
			label.offset_bottom = 0.0
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_titles_root.add_child(label)
		elif line.get("area", "main") == "lower":
			# REV 227: an episode title, centred in the lower third of the picture (TOS style)
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.anchor_left = 0.05
			label.anchor_right = 0.95
			label.anchor_top = 0.66
			label.anchor_bottom = 0.82
			label.offset_left = 0.0
			label.offset_right = 0.0
			label.offset_top = 0.0
			label.offset_bottom = 0.0
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_titles_root.add_child(label)
		elif line.get("area", "main") == "bottom":
			_credit_box.add_child(label)
		else:
			box.add_child(label)
		_title_labels.append(label)


## How far the logo font leans to the right (0 = upright). The TOS wordmark
## is strongly italic; this fakes it by skewing the glyphs, since the font
## file has no italic style of its own.
const LOGO_ITALIC_SKEW := 0.0
const LOGO_STRETCH_X := 1.1
const LOGO_EMBOLDEN := 0.55


func _load_logo_font() -> Font:
	for path in LOGO_FONT_PATHS:
		if ResourceLoader.exists(path):
			var font: Font = load(path)
			if font != null:
				var slanted := FontVariation.new()
				slanted.base_font = font
				slanted.variation_transform = Transform2D(Vector2(LOGO_STRETCH_X, 0.0), Vector2(LOGO_ITALIC_SKEW, 1.0), Vector2.ZERO)
				slanted.variation_embolden = LOGO_EMBOLDEN
				return slanted
	return null


# ------------------------------------------------------------------- world --

func _build_world() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "TitlesWorld"
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = Vector2i(1280, 536)
	add_child(_viewport)

	# Sky + glow. Warm/cool contrast comes from the sky's violet-blue nebula
	# versus the orange planet light; ambient is deliberately very low so the
	# ship is revealed by the sun, as the storyboard asks.
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = _take(SKY_SHADER_PATH)
	_sky_material.set_shader_parameter("nebula_strength", NEBULA_STRENGTH)
	_sky_material.set_shader_parameter("star_density_scale", STAR_DENSITY)
	_sky_material.set_shader_parameter("star_brightness", STAR_BRIGHTNESS)
	sky.sky_material = _sky_material
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.5, 0.52, 0.62)
	_environment.ambient_light_energy = AMBIENT_ENERGY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.glow_enabled = true
	_environment.glow_intensity = BLOOM_INTENSITY
	_environment.glow_bloom = 0.02
	_environment.glow_hdr_threshold = BLOOM_THRESHOLD
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var world_env := WorldEnvironment.new()
	world_env.environment = _environment
	_viewport.add_child(world_env)

	_camera = Camera3D.new()
	_camera.near = 0.1
	_camera.far = 3000.0
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_camera.current = true

	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(1.0, 0.95, 0.86)
	_sun.shadow_enabled = true
	# Default is four shadow passes over a ~1.5M-triangle ship; two is plenty
	# for a subject this size and roughly halves that cost.
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = SHADOW_DISTANCE
	# The near split covers the ship in most shots, so its shadow map is
	# sharp; the bias values stop the wavy "acne" ripples on the hull.
	_sun.directional_shadow_split_1 = 0.3
	_sun.shadow_bias = SHADOW_BIAS
	_sun.shadow_normal_bias = SHADOW_NORMAL_BIAS
	_sun.shadow_blur = 1.5
	_viewport.add_child(_sun)

	# Cool edge-light opposite the sun: outlines the hull without filling in
	# its shadows.
	_rim = DirectionalLight3D.new()
	_rim.light_color = Color(0.55, 0.65, 1.0)
	_rim.shadow_enabled = false
	_viewport.add_child(_rim)

	# Soft fill that follows the camera and touches ONLY the ship (layer 2), so
	# the shaded sides stay readable without brightening the planet or sky.
	_fill = DirectionalLight3D.new()
	_fill.light_color = Color(0.9, 0.93, 1.0)
	_fill.light_energy = FILL_ENERGY
	_fill.shadow_enabled = false
	_fill.light_cull_mask = 2
	_viewport.add_child(_fill)

	_warm_light = OmniLight3D.new()
	_warm_light.light_color = Color(1.0, 0.55, 0.25)
	_warm_light.omni_range = 120.0
	_warm_light.light_energy = 0.0
	_viewport.add_child(_warm_light)

	_ship = Node3D.new()
	_ship.name = "Enterprise"
	_viewport.add_child(_ship)
	_build_ship()

	_planet = MeshInstance3D.new()
	_planet.name = "Vulcan"
	var sphere := SphereMesh.new()
	sphere.radius = PLANET_RADIUS
	sphere.height = PLANET_RADIUS * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	_planet.mesh = sphere
	var planet_material := ShaderMaterial.new()
	planet_material.shader = _take(PLANET_SHADER_PATH)
	var planet_map: Texture2D = _load_planet_map()
	if planet_map != null:
		planet_material.set_shader_parameter("topography", planet_map)
		planet_material.set_shader_parameter("use_map", true)
		planet_material.set_shader_parameter("bump_strength", PLANET_BUMP)
		planet_material.set_shader_parameter("detail_bump", PLANET_GRAIN)
	planet_material.set_shader_parameter("exposure", PLANET_EXPOSURE)
	planet_material.set_shader_parameter("atmosphere_strength", PLANET_ATMOSPHERE)
	_planet.material_override = planet_material
	_planet.visible = false
	_viewport.add_child(_planet)

	_flare = MeshInstance3D.new()
	_flare.name = "SunriseFlare"
	var quad := QuadMesh.new()
	quad.size = Vector2(11, 11)
	_flare.mesh = quad
	_flare_material = StandardMaterial3D.new()
	_flare_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flare_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flare_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flare_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flare_material.albedo_texture = _get_flare_texture()
	_flare.material_override = _flare_material
	_flare.visible = false
	_viewport.add_child(_flare)

	_build_tkhut()
	_twin_b_material = _make_star_material()
	_twin_b = _make_star(TWIN_B_SIZE, _twin_b_material, "Eridani_B")
	_twin_c_material = _make_star_material()
	_twin_c = _make_star(TWIN_C_SIZE, _twin_c_material, "Eridani_C")


## T'Khut (REV 200): a second sphere with its own mottled volcanic surface,
## lit by the same sun as Vulcan. Hidden unless a shot asks for it.
func _build_tkhut() -> void:
	_tkhut = MeshInstance3D.new()
	_tkhut.name = "TKhut"
	var sphere := SphereMesh.new()
	sphere.radius = TKHUT_RADIUS
	sphere.height = TKHUT_RADIUS * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	_tkhut.mesh = sphere
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	noise.seed = 2269
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([TKHUT_COLOR_DARK, TKHUT_COLOR_LIGHT.darkened(0.25), TKHUT_COLOR_LIGHT, TKHUT_COLOR_DARK.lightened(0.15)])
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 0.62, 1.0])
	var surface := NoiseTexture2D.new()
	surface.width = 1024
	surface.height = 512
	surface.seamless = true
	surface.noise = noise
	surface.color_ramp = ramp
	var bumps := NoiseTexture2D.new()
	bumps.width = 1024
	bumps.height = 512
	bumps.seamless = true
	bumps.as_normal_map = true
	bumps.bump_strength = 6.0
	bumps.noise = noise
	var material := StandardMaterial3D.new()
	material.albedo_texture = surface
	material.normal_enabled = true
	material.normal_texture = bumps
	material.roughness = 1.0
	material.metallic = 0.0
	_tkhut.material_override = material
	_tkhut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tkhut.visible = false
	_viewport.add_child(_tkhut)


func _make_star_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _get_flare_texture()
	return material


func _make_star(width: float, material: StandardMaterial3D, star_name: String) -> MeshInstance3D:
	var star := MeshInstance3D.new()
	star.name = star_name
	var quad := QuadMesh.new()
	quad.size = Vector2(width, width)
	star.mesh = quad
	star.material_override = material
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.visible = false
	_viewport.add_child(star)
	return star


## Loads Vulcan's map. Normally Godot has imported the PNG and it loads as a
## resource; if that hasn't worked (the import is stale or missing), the PNG
## is read straight from disk instead. Says what happened in the Output panel.
func _load_planet_map() -> Texture2D:
	if ResourceLoader.exists(PLANET_MAP_PATH):
		var imported: Variant = _take(PLANET_MAP_PATH)
		if imported is Texture2D:
			print("[TitleSequence] Vulcan map loaded (imported resource), size ", imported.get_size())
			return imported
	var disk_path := ProjectSettings.globalize_path(PLANET_MAP_PATH)
	if FileAccess.file_exists(PLANET_MAP_PATH) or FileAccess.file_exists(disk_path):
		var image := Image.load_from_file(disk_path)
		if image != null and not image.is_empty():
			image.generate_mipmaps()
			print("[TitleSequence] Vulcan map loaded straight from the PNG file.")
			return ImageTexture.create_from_image(image)
	push_warning("[TitleSequence] Vulcan map NOT found at %s - using the procedural planet." % PLANET_MAP_PATH)
	return null


func _build_ship() -> void:
	for path in ENTERPRISE_MODEL_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = _take(path)
		if scene == null:
			push_warning("TitleSequence: %s exists but couldn't load; trying the next option." % path)
			continue
		var model: Node3D = scene.instantiate()
		model.rotation_degrees.y = ENTERPRISE_MODEL_YAW_DEG
		model.scale = Vector3.ONE * ENTERPRISE_MODEL_SCALE
		model.position = ENTERPRISE_MODEL_OFFSET
		_ship.add_child(model)
		_style_model_materials(model)
		_add_nav_lights()
		_tag_ship_layers(_ship)
		return
	_build_stand_in_ship()
	_add_nav_lights()
	_tag_ship_layers(_ship)


## Puts every ship mesh on layers 1 and 2: layer 1 is lit by everything, layer 2
## is what the ship-only fill light looks at.
func _tag_ship_layers(root: Node) -> void:
	for node in root.find_children("*", "VisualInstance3D", true, false):
		node.layers = 3


## The exported Enterprise carries no glow/glass information the way Godot
## wants it (its dome material is plain white emission; the three "glass"
## materials are untextured and would render as opaque white), so those parts
## are restyled by node name. Everything else keeps its own textured materials.
func _style_model_materials(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node
		var key: String = String(mesh_instance.name).to_upper()
		if key.begins_with("TOS_ANIMATED_DOME"):
			# The glowing bussard cores.
			mesh_instance.material_override = _make_bussard_material(mesh_instance, 2.2)
		elif key.find("GLASS") != -1:
			mesh_instance.material_override = _make_glass_material(key)
		elif key.find("BUSSARD_CAPS") != -1:
			var cap := StandardMaterial3D.new()
			cap.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cap.albedo_color = Color(1.0, 0.45, 0.2, 0.5)
			cap.roughness = 0.2
			mesh_instance.material_override = cap
		elif key == "TOS_CONNIE_DEFLECTOR":
			# Pre-refit ship: this is the SENSOR dish, a dull metal disc that
			# does not glow (only the refit's deflector did). Strip any glow
			# and repaint it a muted bronze so no blue is left.
			var source: Material = mesh_instance.get_active_material(0)
			if source is StandardMaterial3D:
				var dish: StandardMaterial3D = source.duplicate()
				dish.emission_enabled = false
				if SENSOR_DISH_REPAINT:
					dish.albedo_texture = null
					dish.albedo_color = SENSOR_DISH_COLOR
					dish.metallic = 0.6
					dish.roughness = 0.45
				mesh_instance.set_surface_override_material(0, dish)


func _make_glass_material(key: String) -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.albedo_color = Color(1, 1, 1, 0.15)
	if key.find("RED") != -1:
		glass.albedo_color = Color(1.0, 0.25, 0.15, 0.45)
	elif key.find("GREEN") != -1:
		glass.albedo_color = Color(0.2, 1.0, 0.4, 0.25)
	if key.find("RED") != -1 or key.find("GREEN") != -1:
		# REV 203: the model's own running-light bulbs blink with the halos.
		glass.emission_enabled = true
		glass.emission = Color(glass.albedo_color.r, glass.albedo_color.g, glass.albedo_color.b)
		glass.emission_energy_multiplier = 0.0
		_nav_bulb_materials.append(glass)
	return glass


## Crude primitive Enterprise so timing and framing can be judged before the
## real model is dropped in. Nose points down -Z, ~10 units long.
func _build_stand_in_ship() -> void:
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.62, 0.64, 0.68)
	hull.metallic = 0.5
	hull.roughness = 0.45

	var saucer := CylinderMesh.new()
	saucer.top_radius = 2.2
	saucer.bottom_radius = 2.4
	saucer.height = 0.3
	saucer.radial_segments = 48
	_add_part(saucer, hull, Vector3(0, 0.6, -2.6), Vector3.ZERO)

	var dome := SphereMesh.new()
	dome.radius = 0.55
	dome.height = 0.5
	_add_part(dome, hull, Vector3(0, 0.8, -2.6), Vector3.ZERO)

	var secondary := CylinderMesh.new()
	secondary.top_radius = 0.5
	secondary.bottom_radius = 0.4
	secondary.height = 3.4
	_add_part(secondary, hull, Vector3(0, -0.3, 0.3), Vector3(90, 0, 0))

	var neck := BoxMesh.new()
	neck.size = Vector3(0.5, 0.7, 1.0)
	_add_part(neck, hull, Vector3(0, 0.3, -1.0), Vector3.ZERO)

	var pylon := BoxMesh.new()
	pylon.size = Vector3(0.15, 1.3, 1.4)
	var nacelle := CylinderMesh.new()
	nacelle.top_radius = 0.26
	nacelle.bottom_radius = 0.26
	nacelle.height = 4.4
	var bussard := SphereMesh.new()
	bussard.radius = 0.27
	bussard.height = 0.54

	for side in [-1.0, 1.0]:
		_add_part(pylon, hull, Vector3(0.9 * side, 0.2, 1.6), Vector3(0, 0, -35.0 * side))
		_add_part(nacelle, hull, Vector3(1.7 * side, 1.1, 2.4), Vector3(90, 0, 0))
		var cap := MeshInstance3D.new()
		cap.mesh = bussard
		cap.position = Vector3(1.7 * side, 1.1, 0.2)
		_ship.add_child(cap)
		cap.material_override = _make_bussard_material(cap, 3.0)

	var deflector := SphereMesh.new()
	deflector.radius = 0.4
	deflector.height = 0.8
	_add_part(deflector, _make_glow_material(Color(0.3, 0.55, 1.0), 4.0), Vector3(0, -0.35, -1.35), Vector3.ZERO)


func _add_part(mesh: Mesh, material: Material, pos: Vector3, rot_degrees: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation_degrees = rot_degrees
	_ship.add_child(instance)


## REV 201: a nacelle cap with the swirling TOS glow (bussard_glow.gdshader).
## Works out the cap's middle, size and the nacelle's direction in the mesh's
## own space; port and starboard caps turn in opposite directions.
func _make_bussard_material(cap: MeshInstance3D, base_energy: float) -> Material:
	var shader: Shader = load(BUSSARD_SHADER_PATH)
	if shader == null:
		return _make_glow_material(Color(1.0, 0.42, 0.12), base_energy)
	var material := ShaderMaterial.new()
	material.shader = shader
	var box: AABB = cap.mesh.get_aabb() if cap.mesh != null else AABB(Vector3.ZERO, Vector3.ONE)
	var to_ship: Transform3D = _ship.global_transform.affine_inverse() * cap.global_transform
	# The ship's length runs along its own Z (nose on -Z), so that is the
	# nacelle direction; carry it into the cap mesh's space.
	var axis: Vector3 = (to_ship.basis.inverse() * Vector3(0, 0, 1)).normalized()
	var size: Vector3 = box.size
	var across: float = maxf(size.x, maxf(size.y, size.z))
	material.set_shader_parameter("center", box.get_center())
	material.set_shader_parameter("axis", axis)
	material.set_shader_parameter("radius", across * 0.5)
	var side_x: float = (to_ship * box.get_center()).x
	material.set_shader_parameter("spin_dir", 1.0 if side_x >= 0.0 else -1.0)
	material.set_shader_parameter("speed", BUSSARD_SPIN_SPEED)
	material.set_shader_parameter("energy", base_energy)
	material.set_meta("base_energy", base_energy)
	_bussard_materials.append(material)
	return material


## REV 201: red (port) and green (starboard) running lights on the saucer rim,
## blinking. Placed at the ship's widest points, worked out from every mesh's
## bounds in the ship's own space (the saucer is the widest part of a TOS
## Enterprise), so they land on the real model's rim without hand placing.
func _add_nav_lights() -> void:
	var inverse_ship: Transform3D = _ship.global_transform.affine_inverse()
	var widest_l := INF
	var widest_r := -INF
	var left_part: MeshInstance3D = null
	var right_part: MeshInstance3D = null
	for node in _ship.find_children("*", "MeshInstance3D", true, false):
		var part: MeshInstance3D = node
		if part.mesh == null:
			continue
		var box: AABB = (inverse_ship * part.global_transform) * part.mesh.get_aabb()
		if box.position.x < widest_l:
			widest_l = box.position.x
			left_part = part
		if box.end.x > widest_r:
			widest_r = box.end.x
			right_part = part
	if left_part == null or right_part == null:
		return
	var port: Vector3 = _outermost_point(left_part, -1.0)
	var starboard: Vector3 = _outermost_point(right_part, 1.0)
	# REV 203: Marc Bell's model has its own green rim bulb; when it's there,
	# sit the halos on it (and its mirror image to port) instead.
	for node in _ship.find_children("*", "MeshInstance3D", true, false):
		var bulb: MeshInstance3D = node
		if bulb.mesh != null and String(bulb.name).to_upper().ends_with("GLASS_GREEN"):
			var centre: Vector3 = (inverse_ship * bulb.global_transform) * bulb.mesh.get_aabb().get_center()
			if absf(centre.x) > 0.5:
				starboard = Vector3(absf(centre.x), centre.y, centre.z)
				port = Vector3(-absf(centre.x), centre.y, centre.z)
			break
	_nav_lights.append(_make_nav_light(port, Color(1.0, 0.12, 0.08), "NavLight_Port_Red"))
	_nav_lights.append(_make_nav_light(starboard, Color(0.15, 1.0, 0.3), "NavLight_Starboard_Green"))


## The point of a mesh furthest to the ship's port (-1) or starboard (+1),
## in the ship's own space. Reads the real vertices, so it finds the saucer's
## rim even when the saucer is merged into one mesh with the rest of the hull.
## Where several points tie (a flat edge), it takes their middle.
func _outermost_point(part: MeshInstance3D, side: float) -> Vector3:
	var to_ship: Transform3D = _ship.global_transform.affine_inverse() * part.global_transform
	var dir: Vector3 = (to_ship.basis.inverse() * Vector3(side, 0, 0)).normalized()
	var best := -INF
	var sum := Vector3.ZERO
	var count := 0
	var tolerance: float = part.mesh.get_aabb().size.length() * 0.002
	for surface in part.mesh.get_surface_count():
		var arrays: Array = part.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in points:
			var d: float = v.dot(dir)
			if d > best + tolerance:
				best = d
				sum = v
				count = 1
			elif d >= best - tolerance:
				sum += v
				count += 1
	if count == 0:
		return to_ship * part.mesh.get_aabb().get_center()
	# Sit the light a hair outside the hull so it never sinks into it.
	return to_ship * (sum / count + dir * tolerance * 2.0)


func _make_nav_light(at: Vector3, color: Color, light_name: String) -> MeshInstance3D:
	var light := MeshInstance3D.new()
	light.name = light_name
	var quad := QuadMesh.new()
	quad.size = Vector2(NAV_LIGHT_SIZE, NAV_LIGHT_SIZE)
	light.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _get_flare_texture()
	material.albedo_color = color
	light.material_override = material
	light.set_meta("color", color)
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.position = at
	_ship.add_child(light)
	return light


## Blinks the running lights: a quick fade up, held, a quick fade down.
## Port and starboard blink together.
func _update_nav_lights() -> void:
	var phase: float = fmod(Time.get_ticks_msec() / 1000.0, NAV_LIGHT_PERIOD) / NAV_LIGHT_PERIOD
	var lit: float = 0.0
	if phase < NAV_LIGHT_ON:
		lit = clampf(phase / 0.06, 0.0, 1.0) * clampf((NAV_LIGHT_ON - phase) / 0.08, 0.0, 1.0)
	for light in _nav_lights:
		var c: Color = light.get_meta("color")
		(light.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, lit * NAV_LIGHT_STRENGTH)
	for bulb in _nav_bulb_materials:
		bulb.emission_energy_multiplier = 0.15 + lit * 3.0


func _make_glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color * 0.4
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.set_meta("base_energy", energy)
	_glow_materials.append(material)
	return material


static func _get_flare_texture() -> GradientTexture2D:
	if _flare_texture == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0)])
		gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.5, 1.0])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 128
		texture.height = 128
		_flare_texture = texture
	return _flare_texture
