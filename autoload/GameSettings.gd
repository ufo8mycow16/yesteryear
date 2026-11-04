extends Node
## GameSettings — user preferences (NOT game/puzzle state). Separate from
## GameState on purpose: GameState is the gameplay-variable registry, only
## persisted as part of a save-slot JSON blob when the player saves. Preferences
## need to survive independent of any save file, load instantly at boot before
## any save is loaded, and never be reset by "New Game" — so they get their own
## small ConfigFile at user://settings.cfg.
##
## What lives here
##   Camera      invert_mouse_y, invert_zoom                      (see OrbitCameraRig.gd)
##   Dialogue    audio_mode: speech + subtitles / subtitles only / speech only
##   Sound       master, speech, music, ambient and effects volumes (0..100)
##   Graphics    display mode, resolution, texture quality, anti-aliasing,
##               vsync, frame-rate limit, quality preset
##   Controls    keyboard and gamepad bindings for the rebindable actions
##
## The System menu (SettingsUI.gd) only calls the set_* functions below; those
## apply the change immediately and save it.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "preferences"
const AUDIO_SECTION := "audio"
const GFX_SECTION := "graphics"
const CTRL_SECTION := "controls"
const ACCESS_SECTION := "accessibility"

# ------------------------------------------------------------------ camera --
var invert_mouse_y: bool = false
## Flips the mouse-wheel zoom: normally wheel-up brings the camera closer.
var invert_zoom: bool = false

# ---------------------------------------------------------------- dialogue --
## How dialogue is presented: speech and subtitles together (default),
## subtitles only (no voice), or speech only (no subtitle box).
enum AudioMode { SPEECH_AND_SUBTITLES, SUBTITLES_ONLY, SPEECH_ONLY }
var audio_mode: int = AudioMode.SPEECH_AND_SUBTITLES
signal audio_mode_changed(mode: int)

# ------------------------------------------------------------------- sound --
## Volume keys -> the audio bus each one controls. "speech" is the Dialogue bus
## (the Intercom bus feeds into it), "ambient" and "sfx" are created at start-up
## if the bus layout doesn't have them.
const VOLUME_BUSES := {
	"master": "Master",
	"speech": "Dialogue",
	"music": "Music",
	"ambient": "Ambient",
	"sfx": "SFX",
	"interface": "UI",       # REV 168: menus, clues, objectives - feeds into SFX, so that slider covers it too
}
var volumes: Dictionary = {"master": 100, "speech": 100, "music": 100, "ambient": 100, "sfx": 100, "interface": 100}
var _bus_base_db: Dictionary = {}

# ---------------------------------------------------------------- graphics --
## REV 293: the ONE list of window modes - DisplayManager reads it (it no longer keeps its own copy).
## SettingsUI's DISPLAY MODE names follow this order.
enum DisplayMode { WINDOWED, BORDERLESS_FULLSCREEN, EXCLUSIVE_FULLSCREEN }
var window_mode: int = DisplayMode.WINDOWED
var resolution: Vector2i = Vector2i(1280, 720)
## 0 = full size textures, 1 = half, 2 = quarter.
var texture_quality: int = 0
## 0 = off, 1 = 2x, 2 = 4x, 3 = FXAA (REV 681: a cheap screen-space smoothing, appended so saved numbers keep
## their meaning; the settings screen shows them in the order OFF, FXAA, 2X, 4X - AA_ORDER).
var antialiasing: int = 1
var vsync: bool = true
## Frame-rate limit; 0 = unlimited.
var fps_limit: int = 60
## 0 = low, 1 = medium, 2 = high, 3 = custom.
var quality_preset: int = 2
## REV 99: true = the enhanced look (tone mapping, glow, soft shadowing; see LookEnhancer.gd),
## false = scenes exactly as authored.
var enhanced_lighting: bool = true
## REV 417 (Glen: "off should be the default.. for the moment. maybe make it a selectable option in the graphics
## menu"): the ship's screens - 0 OFF (the pictures as the room lights them), 1 LCD (flat panels that glow, lamps
## lit), 2 CRT (adds scan lines, phosphor, rolling band, flicker). Settings > Graphics > SCREEN EFFECTS; O in a
## debug build cycles it too.
var screen_effects: int = 0
const SCREEN_EFFECT_NAMES := ["OFF", "LCD", "CRT"]
signal screen_effects_changed()
## REV 456 (Glen: engineering "doesn't actually feel like an Elite Force map anymore"): ROOM MOODS - the TOS
## theatrical lighting on the ship's decks (ModelRoom.ROOM_MOODS: each room's own grade, dark ceilings, coloured
## gel washes). Settings > Graphics > ROOM MOODS; Y in a debug build flips it too. Off = the maps' plain baked light.
var mood_lighting: bool = true
signal mood_lighting_changed()
## REV 102: true = no camera lag and no over-the-shoulder shift (for players who get motion sick).
var reduced_motion: bool = false
## REV 741 (Glen's bug list item 6): the pulsing objective marker on the minimap and the M map (checkbox on the map).
var objective_marker: bool = true
## REV 144: the debug info overlay (room, coordinates, lighting, FPS) - debug builds only; F3 toggles it.
var debug_overlay: bool = true
## REV 103: camera field of view (degrees) and turning speeds (percent).
var camera_fov: int = 75
var camera_speed_mouse: int = 100
var camera_speed_keys: int = 100

const TEXTURE_NAMES := ["FULL", "HALF", "QUARTER"]
## How far textures are pushed to smaller mipmaps for each level (see apply_graphics).
const TEXTURE_MIP_BIAS := [0.0, 1.0, 2.0]
const AA_NAMES := ["OFF", "2X", "4X", "FXAA"]
const AA_ORDER := [0, 3, 1, 2]
## REV 681 (performance pass, Glen: "really quick on all the computers"): DYNAMIC RESOLUTION - when the graphics card
## can't keep up with the frame-rate target, the 3D picture is drawn a little smaller (and sharpened back up with FSR)
## until it can, then grows back. The menus and text are never affected. See PerfGovernor below.
var dynamic_resolution: bool = true
const DYN_MIN_SCALE := 0.6         # never below 60% of the chosen size
const DYN_STEP := 0.05
var _dyn_scale := 1.0              # the governor's current factor (1 = as chosen)
const FPS_CHOICES := [30, 60, 75, 120, 144, 0]
const PRESET_NAMES := ["LOW", "MEDIUM", "HIGH", "CUSTOM"]
## Preset -> [texture_quality, antialiasing].
## REV 681: LOW and MEDIUM use FXAA instead of none / MSAA 2x (MSAA is costly with the hair and see-through cards).
const PRESET_VALUES := [[2, 3], [1, 3], [0, 2]]
const RESOLUTION_CANDIDATES := [
	Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
	Vector2i(1280, 800), Vector2i(1440, 900), Vector2i(1680, 1050), Vector2i(1920, 1200), Vector2i(2560, 1600),
]

# ----------------------------------------------------------- accessibility --
signal accessibility_changed()
## Subtitle text size: 0 normal, 1 large, 2 extra large, 3 huge.
var subtitle_size: int = 0
const SUBTITLE_SIZE_NAMES := ["NORMAL", "LARGE", "EXTRA LARGE", "HUGE"]
const SUBTITLE_FONT_SIZES := [15, 19, 24, 30]
## REV 105: how solid the box behind subtitles is (High Contrast overrides it with solid black).
var subtitle_background: int = 2
const SUBTITLE_BACKGROUND_NAMES := ["NONE", "LIGHT", "STANDARD", "SOLID"]
const SUBTITLE_BACKGROUND_ALPHAS := [0.0, 0.55, 0.88, 1.0]
## REV 105: show who is speaking, and in their own colour (so a glance tells Kirk from Spock).
var speaker_names: bool = true
## REV 112: names over characters' heads: 0 ALWAYS, 1 NEARBY ONLY, 2 OFF.
var name_tags: int = 1
const NAME_TAG_NAMES := ["ALWAYS", "NEARBY ONLY", "OFF"]
var speaker_colours: bool = true
## Each speaker's name colour, chosen to read well on a dark box and to be told apart. Anyone not
## listed gets a steady colour from SPEAKER_FALLBACK_COLOURS picked by their name.
const SPEAKER_COLOURS := {
	"kirk": Color(1.0, 0.82, 0.35),       # command gold
	"spock": Color(0.45, 0.72, 1.0),      # science blue
	"mccoy": Color(0.45, 0.9, 0.78),      # medical teal
	"uhura": Color(1.0, 0.5, 0.45),       # operations red
	"scott": Color(1.0, 0.62, 0.35), "scotty": Color(1.0, 0.62, 0.35),
	"sulu": Color(0.95, 0.9, 0.55), "chekov": Color(0.85, 0.95, 0.5),
	"chapel": Color(0.7, 0.85, 1.0), "computer": Color(0.75, 0.75, 0.82),
}
const SPEAKER_FALLBACK_COLOURS := [Color(0.85, 0.7, 1.0), Color(0.6, 0.95, 0.6), Color(1.0, 0.72, 0.85),
	Color(0.7, 0.9, 0.95), Color(0.95, 0.8, 0.6), Color(0.8, 0.85, 0.65)]
## Solid black panels and subtitle box, brighter borders: easier to read.
var high_contrast: bool = false
## Colour of the hold-to-show hotspot markers. Blue and white are easier to tell
## apart from the scenery for most kinds of colour blindness than the gold.
var marker_palette: int = 0
const MARKER_PALETTE_NAMES := ["GOLD", "BLUE", "WHITE", "MAGENTA"]
const MARKER_PALETTE_COLORS := [Color(1.0, 0.86, 0.4), Color(0.35, 0.7, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 0.35, 0.85)]

# ---------------------------------------------------------------- controls --
## [label, input action]. These are the actions the player can rebind. (Escape,
## the menu navigation keys and the camera mouse buttons are fixed.)
const REBINDABLE_ACTIONS := [
	["MOVE FORWARD", "move_forward"],
	["MOVE BACK", "move_back"],
	["MOVE LEFT", "move_left"],
	["MOVE RIGHT", "move_right"],
	["RUN (HOLD)", "run"],
	["ROTATE CAMERA LEFT", "camera_orbit_left"],
	["ROTATE CAMERA RIGHT", "camera_orbit_right"],
	["INTERACT / CONFIRM", "interact"],
	["SHOW HOTSPOTS + MISSION (HOLD)", "highlight_hotspots"],
	["DIALOGUE HISTORY", "dialogue_history_open"],
	["COLLECTION", "collection_open"],
	["PHOTO MODE", "photo_mode"],
	["MISSION LOG", "mission_log_open"],
	["INVENTORY", "inventory_open"],
	["CASE FILE", "case_file_open"],
	["MAP", "map_open"],
	["SWITCH KIRK / McCOY", "switch_character"],
	["PARTY / SOLO", "party_toggle"],     # REV 301
	["SYSTEM MENU", "system_menu_open"],
	["QUICK SAVE", "quick_save"],
	["QUICK LOAD", "quick_load"],
	["TOGGLE FULLSCREEN", "toggle_fullscreen"],
]
## Gamepad bindings added if the project's input map doesn't have one.
## action -> ["button", index] or ["axis", axis, sign]
const DEFAULT_PAD_BINDINGS := {
	"move_forward": ["axis", 1, -1],
	"move_back": ["axis", 1, 1],
	"mission_log_open": ["button", 3],
	"inventory_open": ["button", 2],
	"system_menu_open": ["button", 6],
	"ui_navigate_up": ["button", 11],
	"ui_navigate_down": ["button", 12],
	"ui_navigate_confirm": ["button", 0],
	# REV 103: these had no gamepad button at all
	"case_file_open": ["button", 14],      # D-pad right
	"switch_character": ["button", 13],    # D-pad left
	"map_open": ["button", 8],             # right stick click
	"party_toggle": ["button", 11],        # REV 301: D-pad up (menus use it only while they are open)
}
const PAD_BUTTON_NAMES := ["A", "B", "X", "Y", "BACK", "GUIDE", "START", "LEFT STICK", "RIGHT STICK", "LB", "RB", "D-PAD UP", "D-PAD DOWN", "D-PAD LEFT", "D-PAD RIGHT"]
const PAD_AXIS_NAMES := ["LEFT STICK", "LEFT STICK", "RIGHT STICK", "RIGHT STICK", "LEFT TRIGGER", "RIGHT TRIGGER"]

signal controls_changed()

var _config: ConfigFile
## action -> {"key": InputEventKey or null, "pad": InputEvent or null}
var _bindings: Dictionary = {}
var _default_bindings: Dictionary = {}


func _ready() -> void:
	_config = ConfigFile.new()
	var err := _config.load(SETTINGS_PATH)
	if err == OK:
		invert_mouse_y = _config.get_value(SECTION, "invert_mouse_y", false)
		invert_zoom = _config.get_value(SECTION, "invert_zoom", false)
		audio_mode = clampi(int(_config.get_value(SECTION, "audio_mode", AudioMode.SPEECH_AND_SUBTITLES)), 0, 2)
		for key in volumes.keys():
			volumes[key] = clampi(int(_config.get_value(AUDIO_SECTION, String(key), 100)), 0, 100)
		window_mode = clampi(int(_config.get_value(GFX_SECTION, "window_mode", DisplayMode.WINDOWED)), 0, 2)
		var res_text: String = String(_config.get_value(GFX_SECTION, "resolution", "1280x720"))
		resolution = _parse_resolution(res_text)
		texture_quality = clampi(int(_config.get_value(GFX_SECTION, "texture_quality", 0)), 0, 2)
		antialiasing = clampi(int(_config.get_value(GFX_SECTION, "antialiasing", 1)), 0, 3)
		vsync = bool(_config.get_value(GFX_SECTION, "vsync", true))
		fps_limit = int(_config.get_value(GFX_SECTION, "fps_limit", 60))
		quality_preset = clampi(int(_config.get_value(GFX_SECTION, "quality_preset", 2)), 0, 3)
		enhanced_lighting = bool(_config.get_value(GFX_SECTION, "enhanced_lighting", true))
		screen_effects = clampi(int(_config.get_value(GFX_SECTION, "screen_effects", 0)), 0, 2)
		mood_lighting = bool(_config.get_value(GFX_SECTION, "mood_lighting", true))
		dynamic_resolution = bool(_config.get_value(GFX_SECTION, "dynamic_resolution", true))
		reduced_motion = bool(_config.get_value(ACCESS_SECTION, "reduced_motion", false))
		objective_marker = bool(_config.get_value(SECTION, "objective_marker", true))
		debug_overlay = bool(_config.get_value(SECTION, "debug_overlay", true))
		camera_fov = clampi(int(_config.get_value(SECTION, "camera_fov", 75)), 55, 95)
		camera_speed_mouse = clampi(int(_config.get_value(SECTION, "camera_speed_mouse", 100)), 25, 200)
		camera_speed_keys = clampi(int(_config.get_value(SECTION, "camera_speed_keys", 100)), 25, 200)
		subtitle_size = clampi(int(_config.get_value(ACCESS_SECTION, "subtitle_size", 0)), 0, 3)
		high_contrast = bool(_config.get_value(ACCESS_SECTION, "high_contrast", false))
		subtitle_background = clampi(int(_config.get_value(ACCESS_SECTION, "subtitle_background", 2)), 0, 3)
		speaker_names = bool(_config.get_value(ACCESS_SECTION, "speaker_names", true))
		speaker_colours = bool(_config.get_value(ACCESS_SECTION, "speaker_colours", true))
		name_tags = clampi(int(_config.get_value(ACCESS_SECTION, "name_tags", 1)), 0, 2)
		marker_palette = clampi(int(_config.get_value(ACCESS_SECTION, "marker_palette", 0)), 0, 3)
	# ERR_FILE_NOT_FOUND is expected on first run (no settings saved yet) —
	# just keep the in-memory defaults above. Any other error is logged but
	# not fatal; settings are a convenience, never load-bearing for gameplay.
	elif err != ERR_FILE_NOT_FOUND:
		push_warning("GameSettings: failed to load %s (error %d); using defaults." % [SETTINGS_PATH, err])

	# REV 740: settings saved before REV 681 kept HIGH with MSAA 2x (Glen's PC) - the hair is drawn with
	# alpha-to-coverage, which at 2x has only two steps of see-through and reads as grain on every strand.
	# Once, move such HIGH settings to HIGH's own 4x.
	if err == OK and not _config.has_section_key(GFX_SECTION, "aa_fix_740"):
		if quality_preset == 2 and antialiasing == 1:
			antialiasing = int(PRESET_VALUES[2][1])
		_config.set_value(GFX_SECTION, "aa_fix_740", true)
		_save.call_deferred()

	# REV 681: the very first launch picks LOW / MEDIUM / HIGH for this computer's graphics card.
	if err != OK or not _config.has_section_key(GFX_SECTION, "quality_preset"):
		var auto := detect_preset()
		quality_preset = auto
		texture_quality = int(PRESET_VALUES[auto][0])
		antialiasing = int(PRESET_VALUES[auto][1])
		print("GameSettings: first launch on '%s' - quality preset %s" % [RenderingServer.get_video_adapter_name(),
			PRESET_NAMES[auto]])
		_save.call_deferred()

	_ensure_buses()
	apply_audio()
	_setup_controls()
	add_child(PerfGovernor.new())
	# The window is not fully ready during autoload _ready(); apply next frame.
	apply_graphics.call_deferred()


# =========================================================================
# Camera and dialogue (unchanged behaviour)
# =========================================================================

func set_invert_mouse_y(value: bool) -> void:
	invert_mouse_y = value
	_save()


func set_invert_zoom(value: bool) -> void:
	invert_zoom = value
	_save()


func set_audio_mode(value: int) -> void:
	audio_mode = clampi(value, 0, 2)
	_save()
	audio_mode_changed.emit(audio_mode)


func set_subtitle_size(value: int) -> void:
	subtitle_size = clampi(value, 0, 3)
	_save()
	accessibility_changed.emit()


func set_high_contrast(value: bool) -> void:
	high_contrast = value
	_save()
	accessibility_changed.emit()


func set_marker_palette(value: int) -> void:
	marker_palette = clampi(value, 0, 3)
	_save()
	accessibility_changed.emit()


func set_subtitle_background(value: int) -> void:
	subtitle_background = clampi(value, 0, 3)
	_save()
	accessibility_changed.emit()


func set_speaker_names(value: bool) -> void:
	speaker_names = value
	_save()
	accessibility_changed.emit()


func set_name_tags(value: int) -> void:
	name_tags = clampi(value, 0, 2)
	_save()
	accessibility_changed.emit()


func set_speaker_colours(value: bool) -> void:
	speaker_colours = value
	_save()
	accessibility_changed.emit()


## How opaque the subtitle box is (1.0 with High Contrast).
func subtitle_background_alpha() -> float:
	return 1.0 if high_contrast else float(SUBTITLE_BACKGROUND_ALPHAS[subtitle_background])


## Text size multiplier matching the subtitle size setting (for text that isn't the subtitle box).
func subtitle_scale() -> float:
	return float(SUBTITLE_FONT_SIZES[subtitle_size]) / float(SUBTITLE_FONT_SIZES[0])


## The colour a speaker's name is shown in: their own colour when Speaker Colours is on, else
## `plain` (gold). "Lt. Uhura" and "Captain Kirk" match by any word of the name.
func speaker_colour(speaker: String, plain: Color) -> Color:
	if not speaker_colours:
		return plain
	var words := speaker.strip_edges().to_lower().replace(".", " ").split(" ", false)
	for w in words:
		if SPEAKER_COLOURS.has(w):
			return SPEAKER_COLOURS[w]
	if words.is_empty():
		return plain
	var key := " ".join(words)
	return SPEAKER_FALLBACK_COLOURS[absi(hash(key)) % SPEAKER_FALLBACK_COLOURS.size()]


func subtitle_font_size() -> int:
	return int(SUBTITLE_FONT_SIZES[subtitle_size])


func marker_color() -> Color:
	return MARKER_PALETTE_COLORS[marker_palette]


func wants_speech() -> bool:
	return audio_mode != AudioMode.SUBTITLES_ONLY


func wants_subtitles() -> bool:
	return audio_mode != AudioMode.SPEECH_ONLY


# =========================================================================
# Sound
# =========================================================================

## Adds the Ambient and SFX buses (routed to Master) if the layout lacks them,
## and remembers each bus's authored volume so 100% always means "as mixed".
func _ensure_buses() -> void:
	for key in VOLUME_BUSES.keys():
		var bus_name: String = String(VOLUME_BUSES[key])
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "SFX" if bus_name == "UI" and AudioServer.get_bus_index("SFX") >= 0 else "Master")
		_bus_base_db[key] = AudioServer.get_bus_volume_db(idx)


func get_volume(key: String) -> int:
	return int(volumes.get(key, 100))


func set_volume(key: String, value: int) -> void:
	if not volumes.has(key):
		return
	volumes[key] = clampi(value, 0, 100)
	_apply_one_volume(key)
	_save()


func apply_audio() -> void:
	for key in volumes.keys():
		_apply_one_volume(String(key))


func _apply_one_volume(key: String) -> void:
	var idx := AudioServer.get_bus_index(String(VOLUME_BUSES[key]))
	if idx < 0:
		return
	var v: float = float(volumes[key]) / 100.0
	if v <= 0.001:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, float(_bus_base_db.get(key, 0.0)) + linear_to_db(v))


# =========================================================================
# Graphics
# =========================================================================

## The resolutions this monitor can show (never larger than the screen), plus the
## current one, smallest first.
func available_resolutions() -> Array:
	var screen_size: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var out: Array = []
	for r in RESOLUTION_CANDIDATES:
		var v: Vector2i = r
		if v.x <= screen_size.x and v.y <= screen_size.y and not out.has(v):
			out.append(v)
	if not out.has(screen_size):
		out.append(screen_size)
	if not out.has(resolution):
		out.append(resolution)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y)
	return out


func monitor_text() -> String:
	var screen := DisplayServer.window_get_current_screen()
	var size: Vector2i = DisplayServer.screen_get_size(screen)
	var hz: float = DisplayServer.screen_get_refresh_rate(screen)
	if hz > 0.0:
		return "YOUR SCREEN: %d x %d @ %d HZ" % [size.x, size.y, int(round(hz))]
	return "YOUR SCREEN: %d x %d" % [size.x, size.y]


func set_window_mode(mode: int) -> void:
	window_mode = clampi(mode, 0, 2)
	DisplayManager.set_mode(window_mode)   # also re-applies the resolution
	_save()


func set_resolution(value: Vector2i) -> void:
	resolution = value
	apply_graphics()
	_save()


func set_texture_quality(value: int) -> void:
	texture_quality = clampi(value, 0, 2)
	quality_preset = _matching_preset()
	apply_graphics()
	_save()


func set_antialiasing(value: int) -> void:
	antialiasing = clampi(value, 0, 3)
	quality_preset = _matching_preset()
	apply_graphics()
	_save()


func set_vsync(value: bool) -> void:
	vsync = value
	apply_graphics()
	_save()


func set_fps_limit(value: int) -> void:
	fps_limit = value
	apply_graphics()
	_save()


## LOW / MEDIUM / HIGH set texture quality and anti-aliasing together. CUSTOM
## (3) just means "the player has mixed their own".
func set_camera_fov(value: int) -> void:
	camera_fov = clampi(value, 55, 95)
	_save()


func set_camera_speed_mouse(value: int) -> void:
	camera_speed_mouse = clampi(value, 25, 200)
	_save()


func set_camera_speed_keys(value: int) -> void:
	camera_speed_keys = clampi(value, 25, 200)
	_save()


func set_debug_overlay(value: bool) -> void:
	debug_overlay = value
	_save()


func set_objective_marker(value: bool) -> void:
	objective_marker = value
	_save()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_save()
	accessibility_changed.emit()     # REV 293: like every other accessibility setting


func set_mood_lighting(value: bool) -> void:
	mood_lighting = value
	_save()
	mood_lighting_changed.emit()


func set_screen_effects(value: int) -> void:
	screen_effects = posmod(value, SCREEN_EFFECT_NAMES.size())
	_save()
	screen_effects_changed.emit()


func set_enhanced_lighting(value: bool) -> void:
	enhanced_lighting = value
	_save()
	LookEnhancer.refresh()


func set_quality_preset(value: int) -> void:
	quality_preset = clampi(value, 0, 3)
	if quality_preset < 3:
		texture_quality = int(PRESET_VALUES[quality_preset][0])
		antialiasing = int(PRESET_VALUES[quality_preset][1])
	apply_graphics()
	_save()


func _matching_preset() -> int:
	for i in PRESET_VALUES.size():
		if int(PRESET_VALUES[i][0]) == texture_quality and int(PRESET_VALUES[i][1]) == antialiasing:
			return i
	return 3


func _parse_resolution(text: String) -> Vector2i:
	var parts := text.split("x")
	if parts.size() == 2 and int(parts[0]) >= 640 and int(parts[1]) >= 360:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i(1280, 720)


## Pushes every graphics setting to the engine. Safe to call at any time.
##
##   Windowed            the window is resized (and centred) to the resolution.
##   Fullscreen          the window covers the screen; the resolution sets the size
##                       the 3D world is drawn at, which is then scaled up (FSR),
##                       so a lower number runs faster on a weak graphics card.
##   Texture quality     textures are read from smaller mipmaps (half / quarter
##                       detail). That lowers the load on the graphics card;
##                       it does not shrink the files on disk.
func apply_graphics() -> void:
	var win: Window = get_window()
	if win == null:
		return
	var screen := DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen)

	var scale := 1.0
	if window_mode == DisplayMode.WINDOWED:
		if win.mode == Window.MODE_WINDOWED:
			win.size = resolution
			var origin: Vector2i = DisplayServer.screen_get_position(screen)
			win.position = origin + (screen_size - win.size) / 2
	else:
		scale = clampf(float(resolution.y) / float(maxi(screen_size.y, 1)), 0.35, 1.0)
	# REV 120 (low-end check): LOW also draws the 3D scene at 77% size and sharpens it back up
	# (FSR) - the biggest single saving on a modest graphics card - and uses smaller, harder
	# shadows. MEDIUM uses medium shadows. HIGH / CUSTOM are as before.
	if quality_preset == 0:
		scale = minf(scale, 0.77)
	_base_scale = scale
	_apply_scale()
	# HIGH / CUSTOM: exactly the project's own shadow settings
	var proj_size := int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096))
	var proj_soft := int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2))
	var shadow_size := 1024 if quality_preset == 0 else (2048 if quality_preset == 1 else proj_size)
	RenderingServer.directional_shadow_atlas_set_size(shadow_size, true)
	win.positional_shadow_atlas_size = mini(shadow_size, int(ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/atlas_size", 4096)))
	var soft: int = RenderingServer.SHADOW_QUALITY_HARD if quality_preset == 0 else (mini(proj_soft, RenderingServer.SHADOW_QUALITY_SOFT_LOW) if quality_preset == 1 else proj_soft)
	RenderingServer.directional_soft_shadow_filter_set_quality(soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft)

	match antialiasing:
		0, 3: win.msaa_3d = Viewport.MSAA_DISABLED
		1: win.msaa_3d = Viewport.MSAA_2X
		_: win.msaa_3d = Viewport.MSAA_4X
	win.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if antialiasing == 3 else Viewport.SCREEN_SPACE_AA_DISABLED

	# Not every Godot 4 version has this property, so only set it if it exists.
	for p in win.get_property_list():
		if String(p["name"]) == "texture_mipmap_bias":
			win.set("texture_mipmap_bias", float(TEXTURE_MIP_BIAS[texture_quality]))
			break

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_limit


var _base_scale := 1.0


## REV 681: the 3D picture size = what the settings chose x the dynamic-resolution factor.
func _apply_scale() -> void:
	var win: Window = get_window()
	if win == null:
		return
	var s := _base_scale * (_dyn_scale if dynamic_resolution else 1.0)
	win.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if s < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	win.scaling_3d_scale = s


func set_dynamic_resolution(value: bool) -> void:
	dynamic_resolution = value
	_dyn_scale = 1.0
	_apply_scale()
	_save()


## REV 681: the dynamic-resolution factor right now (1.0 = full), for the F3 overlay.
func dynamic_scale() -> float:
	return _dyn_scale if dynamic_resolution else 1.0


## REV 681: a sensible starting preset for this computer, from its graphics card. Built-in graphics -> LOW; older or
## entry-level cards (GTX 900/1000/1600 series, MX, RTX 2050/3050, Radeon RX 400/500/5500/6500, Arc A3xx) -> MEDIUM;
## everything else -> HIGH. The player can change it any time; this only runs on the very first launch.
static func detect_preset() -> int:
	var kind := RenderingServer.get_video_adapter_type()
	var card := RenderingServer.get_video_adapter_name().to_lower()
	if kind == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU or kind == RenderingDevice.DEVICE_TYPE_CPU \
			or card.contains("intel(r) uhd") or card.contains("intel(r) hd") or card.contains("iris") \
			or card.contains("radeon(tm) graphics") or card.contains("radeon graphics") or card.contains("vega") \
			or card.contains("llvmpipe") or card.contains("swiftshader") or card.contains("microsoft basic"):
		return 0
	var mid := RegEx.create_from_string(
		"gtx (9\\d\\d|10[0-9]0|16[0-9]0)|\\bmx ?\\d|gt \\d|rtx (2050|3050)|rx (4\\d\\d|5\\d\\d|5500|6400|6500)|arc a3")
	if mid.search(card) != null:
		return 1
	return 2


## REV 681: watches how long the graphics card takes per frame and nudges the 3D picture size so the game keeps its
## frame rate (GameSettings.dynamic_resolution). Down quickly when it's struggling, back up slowly when there's room.
## Only works where Godot can time the graphics card (Forward+ / Mobile); otherwise it does nothing.
class PerfGovernor extends Node:
	var _t := 0.0
	var _calm := 0.0
	var _sum := 0.0
	var _n := 0
	var _rid: RID

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_rid = get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_rid, true)

	func _process(delta: float) -> void:
		if not GameSettings.dynamic_resolution or get_tree().paused:
			_sum = 0.0
			_n = 0
			return
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_rid)
		if gpu <= 0.0:
			return
		_sum += gpu
		_n += 1
		_t += delta
		if _t < 0.5:
			return
		var avg := _sum / maxf(1.0, float(_n))
		_t = 0.0
		_sum = 0.0
		_n = 0
		var target_fps := float(GameSettings.fps_limit) if GameSettings.fps_limit > 0 else 60.0
		var budget := 1000.0 / target_fps
		var old := GameSettings._dyn_scale
		var now := old
		if avg > budget * 0.92:
			now = maxf(GameSettings.DYN_MIN_SCALE, old - GameSettings.DYN_STEP * (2.0 if avg > budget * 1.3 else 1.0))
			_calm = 0.0
		elif avg < budget * 0.65:
			_calm += 0.5
			if _calm >= 3.0:
				now = minf(1.0, old + GameSettings.DYN_STEP)
				_calm = 0.0
		else:
			_calm = 0.0
		if not is_equal_approx(old, now):
			GameSettings._dyn_scale = now
			GameSettings._apply_scale()


# =========================================================================
# Controls
# =========================================================================

## Reads the project's input map (the defaults), fills in any missing gamepad
## bindings, then applies the player's saved bindings on top.
func _setup_controls() -> void:
	for action in DEFAULT_PAD_BINDINGS.keys():
		if InputMap.has_action(String(action)) and _first_event(String(action), false) == null:
			InputMap.action_add_event(String(action), _event_from_spec(DEFAULT_PAD_BINDINGS[action]))
	for entry in REBINDABLE_ACTIONS:
		var action: String = String(entry[1])
		if not InputMap.has_action(action):
			continue
		_default_bindings[action] = {"key": _first_event(action, true), "pad": _first_event(action, false)}
		_bindings[action] = {"key": _default_bindings[action]["key"], "pad": _default_bindings[action]["pad"]}
	if _config != null:
		# REV 158: the hold-to-WALK action became hold-to-RUN; a key the player had rebound for it carries over
		for part in [".key", ".pad"]:
			if _config.has_section_key(CTRL_SECTION, "walk" + part) and not _config.has_section_key(CTRL_SECTION, "run" + part):
				_config.set_value(CTRL_SECTION, "run" + part, _config.get_value(CTRL_SECTION, "walk" + part))
			if _config.has_section_key(CTRL_SECTION, "walk" + part):
				_config.erase_section_key(CTRL_SECTION, "walk" + part)
		for entry in REBINDABLE_ACTIONS:
			var action: String = String(entry[1])
			if not _bindings.has(action):
				continue
			if _config.has_section_key(CTRL_SECTION, action + ".key"):
				_bindings[action]["key"] = _event_from_text(String(_config.get_value(CTRL_SECTION, action + ".key")))
			if _config.has_section_key(CTRL_SECTION, action + ".pad"):
				_bindings[action]["pad"] = _event_from_text(String(_config.get_value(CTRL_SECTION, action + ".pad")))
			_apply_action(action)


func _first_event(action: String, want_key: bool) -> InputEvent:
	for ev in InputMap.action_get_events(action):
		if want_key and ev is InputEventKey:
			return ev
		if not want_key and (ev is InputEventJoypadButton or ev is InputEventJoypadMotion):
			return ev
	return null


## Replaces the action's keyboard and gamepad events with the current bindings.
## Mouse events (and anything else on the action) are left alone.
func _apply_action(action: String) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			InputMap.action_erase_event(action, ev)
	var b: Dictionary = _bindings[action]
	if b["key"] != null:
		InputMap.action_add_event(action, b["key"])
	if b["pad"] != null:
		InputMap.action_add_event(action, b["pad"])


func get_binding_text(action: String, want_key: bool) -> String:
	if not _bindings.has(action):
		return "-"
	var ev: InputEvent = _bindings[action]["key" if want_key else "pad"]
	return event_text(ev)


func event_text(ev: InputEvent) -> String:
	if ev == null:
		return "NOT SET"
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return (k.as_text_physical_keycode() if k.physical_keycode != 0 else k.as_text_keycode()).to_upper()
	if ev is InputEventJoypadButton:
		var i: int = (ev as InputEventJoypadButton).button_index
		return String(PAD_BUTTON_NAMES[i]) if i >= 0 and i < PAD_BUTTON_NAMES.size() else "BUTTON %d" % i
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		var base: String = String(PAD_AXIS_NAMES[m.axis]) if m.axis >= 0 and m.axis < PAD_AXIS_NAMES.size() else "AXIS %d" % m.axis
		if m.axis >= 4:
			return base
		var horizontal := m.axis % 2 == 0
		var word := ("RIGHT" if m.axis_value > 0.0 else "LEFT") if horizontal else ("DOWN" if m.axis_value > 0.0 else "UP")
		return "%s %s" % [base, word]
	return "?"


## Binds a captured event. If another action already uses it (same device kind),
## that action loses it. Returns the label of the action it was taken from, or "".
func set_binding(action: String, want_key: bool, ev: InputEvent) -> String:
	if not _bindings.has(action):
		return ""
	var slot := "key" if want_key else "pad"
	var taken_from := ""
	for entry in REBINDABLE_ACTIONS:
		var other: String = String(entry[1])
		if other == action or not _bindings.has(other):
			continue
		var existing: InputEvent = _bindings[other][slot]
		if existing != null and _same_input(existing, ev):
			_bindings[other][slot] = null
			_apply_action(other)
			taken_from = String(entry[0])
	_bindings[action][slot] = ev
	_apply_action(action)
	_save()
	controls_changed.emit()
	return taken_from


func clear_binding(action: String, want_key: bool) -> void:
	if not _bindings.has(action):
		return
	_bindings[action]["key" if want_key else "pad"] = null
	_apply_action(action)
	_save()
	controls_changed.emit()


func reset_controls() -> void:
	for entry in REBINDABLE_ACTIONS:
		var action: String = String(entry[1])
		if _default_bindings.has(action):
			_bindings[action] = {"key": _default_bindings[action]["key"], "pad": _default_bindings[action]["pad"]}
			_apply_action(action)
	_save()
	controls_changed.emit()


func _same_input(a: InputEvent, b: InputEvent) -> bool:
	return event_to_text(a) == event_to_text(b)


## Stored as short text: "key:87", "btn:3", "axis:1:-1", or "none".
func event_to_text(ev: InputEvent) -> String:
	if ev == null:
		return "none"
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return "key:%d" % (k.physical_keycode if k.physical_keycode != 0 else k.keycode)
	if ev is InputEventJoypadButton:
		return "btn:%d" % (ev as InputEventJoypadButton).button_index
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		return "axis:%d:%d" % [m.axis, 1 if m.axis_value > 0.0 else -1]
	return "none"


func _event_from_text(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() >= 2 and parts[0] == "key":
		var k := InputEventKey.new()
		k.physical_keycode = int(parts[1]) as Key
		return k
	if parts.size() >= 2 and parts[0] == "btn":
		var b := InputEventJoypadButton.new()
		b.button_index = int(parts[1]) as JoyButton
		return b
	if parts.size() >= 3 and parts[0] == "axis":
		var m := InputEventJoypadMotion.new()
		m.axis = int(parts[1]) as JoyAxis
		m.axis_value = float(int(parts[2]))
		return m
	return null


func _event_from_spec(spec: Array) -> InputEvent:
	if String(spec[0]) == "button":
		var b := InputEventJoypadButton.new()
		b.button_index = int(spec[1]) as JoyButton
		return b
	var m := InputEventJoypadMotion.new()
	m.axis = int(spec[1]) as JoyAxis
	m.axis_value = float(int(spec[2]))
	return m


# =========================================================================
# Saving
# =========================================================================

func _save() -> void:
	_config.set_value(SECTION, "audio_mode", audio_mode)
	_config.set_value(SECTION, "invert_mouse_y", invert_mouse_y)
	_config.set_value(SECTION, "invert_zoom", invert_zoom)
	_config.set_value(SECTION, "debug_overlay", debug_overlay)
	for key in volumes.keys():
		_config.set_value(AUDIO_SECTION, String(key), int(volumes[key]))
	_config.set_value(GFX_SECTION, "window_mode", window_mode)
	_config.set_value(GFX_SECTION, "resolution", "%dx%d" % [resolution.x, resolution.y])
	_config.set_value(GFX_SECTION, "texture_quality", texture_quality)
	_config.set_value(GFX_SECTION, "antialiasing", antialiasing)
	_config.set_value(GFX_SECTION, "vsync", vsync)
	_config.set_value(GFX_SECTION, "fps_limit", fps_limit)
	_config.set_value(GFX_SECTION, "quality_preset", quality_preset)
	_config.set_value(GFX_SECTION, "enhanced_lighting", enhanced_lighting)
	_config.set_value(GFX_SECTION, "screen_effects", screen_effects)
	_config.set_value(GFX_SECTION, "mood_lighting", mood_lighting)
	_config.set_value(GFX_SECTION, "dynamic_resolution", dynamic_resolution)
	_config.set_value(ACCESS_SECTION, "reduced_motion", reduced_motion)
	_config.set_value(SECTION, "objective_marker", objective_marker)
	_config.set_value(SECTION, "camera_fov", camera_fov)
	_config.set_value(SECTION, "camera_speed_mouse", camera_speed_mouse)
	_config.set_value(SECTION, "camera_speed_keys", camera_speed_keys)
	_config.set_value(ACCESS_SECTION, "subtitle_size", subtitle_size)
	_config.set_value(ACCESS_SECTION, "high_contrast", high_contrast)
	_config.set_value(ACCESS_SECTION, "subtitle_background", subtitle_background)
	_config.set_value(ACCESS_SECTION, "speaker_names", speaker_names)
	_config.set_value(ACCESS_SECTION, "speaker_colours", speaker_colours)
	_config.set_value(ACCESS_SECTION, "name_tags", name_tags)
	_config.set_value(ACCESS_SECTION, "marker_palette", marker_palette)
	for entry in REBINDABLE_ACTIONS:
		var action: String = String(entry[1])
		if _bindings.has(action):
			_config.set_value(CTRL_SECTION, action + ".key", event_to_text(_bindings[action]["key"]))
			_config.set_value(CTRL_SECTION, action + ".pad", event_to_text(_bindings[action]["pad"]))
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("GameSettings: failed to save %s (error %d)." % [SETTINGS_PATH, err])
