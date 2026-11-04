extends Node
## UITheme — shared "gold-on-black" visual language for every procedurally-
## built UI panel (Mission Log, Inventory, System, HUD function bank, WHO
## card, minimap). One shared place for palette/stylebox/font/animation
## instead of duplicating Color()/StyleBoxFlat setup in every panel file.
##
## Art direction (Glen, Oct 2026): 70% TOS / 30% movie-era refinement,
## KOTOR II informing layout rather than look. NOT LCARS, not a modern
## mobile/web UI, and — the explicit correction — NOT deliberately retro
## either: the quality bar is "a high-budget TOS game released in 2026,"
## so borders are thin rather than thick, corners are very lightly clipped
## rather than sharp or rounded-app-bubble, panels get a little real depth
## (subtle drop shadow) rather than sitting flat on the world, and panel
## opens are a quick, mechanical fade/settle rather than either an instant
## pop or a slow phone-app glide. No CRT/scanline/VHS filtering of any kind.
##
## Typography hierarchy (deliberately NOT "everything bold" — that's what
## made the previous pass start to shout):
##   style_title   — major panel title ("MISSION LOG"): large, bold, bright gold
##   style_heading — section/topic title (an entry's own title, "STANDARD
##                   EQUIPMENT"): medium, bold, gold
##   style_body    — ordinary paragraph text: regular weight, off-white
##   style_hint    — secondary/contextual info: regular weight, muted
##   style_keybind — "[L]"-style suffixes: small, regular weight, muted,
##                   always visually subordinate to whatever label it rides
##                   along with
##
## FONTS: Glen's Microgramma files (D Extended Medium + Bold) live in
## assets/fonts/. Every style_*() helper null-checks font_regular/font_bold
## and falls back to Godot's default font if either is ever missing, so
## nothing breaks — it just silently loses the custom font.

const FONT_REGULAR_PATH := "res://assets/fonts/Microgramma_D_Extended_Medium.otf"
const FONT_BOLD_PATH := "res://assets/fonts/Microgramma_D_Extended_Bold.otf"
## REV 107: Barlow for anything read as sentences or very small - subtitles, dialogue lines, choices,
## descriptions, notes and key hints. Microgramma stays on titles, labels, buttons and names.
## (Free font, SIL Open Font License; put Barlow-Regular.ttf and Barlow-SemiBold.ttf in assets/fonts/.)
## Without the files, those texts simply stay in Microgramma.
const FONT_BODY_PATH := "res://assets/fonts/Barlow-Regular.ttf"
const FONT_BODY_STRONG_PATH := "res://assets/fonts/Barlow-SemiBold.ttf"

# --- Core palette --------------------------------------------------------
const GOLD := Color(0.831, 0.686, 0.216)           # primary accent / active state / titles
const GOLD_BRIGHT := Color(0.95, 0.82, 0.38)        # active/illuminated border & label
const GOLD_DIM := Color(0.46, 0.38, 0.16)           # inactive borders, dim headings
const BEZEL_BG := Color(0.02, 0.02, 0.028, 0.95)    # outer frame layer (minimap bezel, etc.)
const PANEL_BG := Color(0.035, 0.035, 0.045, 0.9)   # panel surface — near-black, translucent
const BUTTON_BG := Color(0.07, 0.07, 0.08, 0.85)
const BUTTON_BG_ACTIVE := Color(0.24, 0.185, 0.05, 0.92)
const BUTTON_BG_DISABLED := Color(0.05, 0.05, 0.055, 0.6)
const TEXT_PRIMARY := Color(0.92, 0.92, 0.9)
const TEXT_DIM := Color(0.58, 0.58, 0.56)
const TEXT_DISABLED := Color(0.4, 0.4, 0.4)
const SEPARATOR_COLOR := Color(0.46, 0.38, 0.16, 0.55)

# --- Restrained TOS accent colours (point-sized use only — a border, a
# small icon, a single word — never a whole panel) -----------------------
const ACCENT_SCIENCE_BLUE := Color(0.45, 0.62, 0.78)
const ACCENT_MEDICAL_TEAL := Color(0.38, 0.68, 0.64)
const ACCENT_WARNING_RED := Color(0.78, 0.28, 0.24)

# --- Shape / depth constants ---------------------------------------------
const BORDER_WIDTH := 1
const PANEL_CORNER_RADIUS := 3
const BUTTON_CORNER_RADIUS := 2
const SHADOW_SIZE := 10
const SHADOW_COLOR := Color(0, 0, 0, 0.35)

const FADE_IN_SECONDS := 0.12
const FADE_SLIDE_PIXELS := 6.0

# --- Shared tokens (tune the whole HUD from here) -------------------------
# Motion: restrained, nonessential. REV 293: Reduced Motion (GameSettings.reduced_motion) makes
# fade_in / fade_out / panel_open / panel_close instant; these tokens themselves stay as they are.
const ANIM_SMALL := 0.12        # small state changes (target text swap, selection)
const ANIM_MODAL := 0.18        # modal / prompt appear-disappear
const ANIM_HUD := 0.22          # HUD group hide/show (conversation, cutscene)
const MODAL_DIM_ALPHA := 0.45   # world dim behind Inventory/Log/System
const HUD_DIMMED_ALPHA := 0.2   # function bank / minimap while a conversation runs
# Spacing
const PADDING_STD := 12
const PADDING_COMPACT := 6
const SPACING_STD := 8
const SCREEN_MARGIN := 20       # safe margin from the screen edge

var font_regular: Font
var font_bold: Font
var font_body: Font          # Barlow (falls back to font_regular)
var font_body_strong: Font   # Barlow SemiBold (falls back to font_bold)
## Barlow is narrower and smaller at the same pixel size than Microgramma Extended, so body text
## set in it is drawn this much bigger to read the same (0 when Barlow isn't installed).
var body_size_bonus := 0


func _ready() -> void:
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		font_regular = load(FONT_REGULAR_PATH)
	if ResourceLoader.exists(FONT_BOLD_PATH):
		font_bold = load(FONT_BOLD_PATH)
	var body := _load_font(FONT_BODY_PATH)
	var strong := _load_font(FONT_BODY_STRONG_PATH)
	font_body = body if body != null else font_regular
	font_body_strong = strong if strong != null else font_bold
	body_size_bonus = 2 if body != null else 0
	if body == null:
		push_warning("UITheme: Barlow not found at %s - body text stays in Microgramma" % FONT_BODY_PATH)
	# REV 297: when High Contrast is switched, panels that are already built restyle themselves
	# (before, only panels built after the change picked it up - "takes effect next scene").
	GameSettings.accessibility_changed.connect(_restyle_all)


# --------------------------------------------------------------------------
# REV 297: style registry. Every style_panel / style_bezel / style_button / style_target_prompt /
# style_dialogue_backing call remembers on the node how it was styled and puts the node in one group;
# when an accessibility setting changes, every live node in that group is styled again the same way,
# so High Contrast reaches panels that are already open or were built earlier in the scene.
# --------------------------------------------------------------------------
const STYLED_GROUP := "ui_theme_styled"
const STYLE_META := "_ui_theme_style"

func _remember_style(node: Control, how: Dictionary) -> void:
	node.set_meta(STYLE_META, how)
	if not node.is_in_group(STYLED_GROUP):
		node.add_to_group(STYLED_GROUP)


func _restyle_all() -> void:
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group(STYLED_GROUP):
		if not is_instance_valid(n) or not n.has_meta(STYLE_META):
			continue
		var how: Dictionary = n.get_meta(STYLE_META)
		match String(how.get("kind", "")):
			"panel":
				if n is PanelContainer:
					style_panel(n as PanelContainer, how.get("border", GOLD))
			"bezel":
				if n is PanelContainer:
					style_bezel(n as PanelContainer)
			"target_prompt":
				if n is PanelContainer:
					style_target_prompt(n as PanelContainer)
			"dialogue_backing":
				if n is PanelContainer:
					style_dialogue_backing(n as PanelContainer)
			"button":
				if n is Button:
					# The button's own disabled state now (code may have changed it since).
					style_button(n as Button, bool(how.get("active", false)), (n as Button).disabled)


## A font file, imported or not (a .ttf dropped in while the editor wasn't looking still works).
func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var f := FontFile.new()
		if f.load_dynamic_font(path) == OK:
			return f
	return null


# --------------------------------------------------------------------------
# Styleboxes
# --------------------------------------------------------------------------

## Dark, slightly translucent surface with a thin gold border and a soft
## shadow — the "panel floats a little above the world" depth cue, kept
## subtle rather than the "huge drop shadow" the brief explicitly warns off.
func panel_stylebox(border_color: Color = GOLD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 1) if GameSettings.high_contrast else PANEL_BG
	sb.border_color = Color.WHITE if GameSettings.high_contrast else border_color
	sb.set_border_width_all(BORDER_WIDTH)
	sb.set_corner_radius_all(PANEL_CORNER_RADIUS)
	sb.set_content_margin_all(12)
	sb.shadow_size = SHADOW_SIZE
	sb.shadow_color = SHADOW_COLOR
	return sb


## Darker, borderless layer for bezel-style frames (minimap outer ring,
## recessed instrument surrounds) — one step further back than panel_stylebox.
func bezel_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BEZEL_BG
	sb.border_color = GOLD_DIM
	if GameSettings.high_contrast:      # REV 297: solid black, white edge
		sb.bg_color = Color(0, 0, 0, 1)
		sb.border_color = Color.WHITE
	sb.set_border_width_all(BORDER_WIDTH)
	sb.set_corner_radius_all(PANEL_CORNER_RADIUS)
	sb.shadow_size = SHADOW_SIZE
	sb.shadow_color = SHADOW_COLOR
	return sb


## Lighter, more translucent surface for the dialogue topic list — "one
## subtle translucent conversation backing region," not a full opaque
## panel, since conversations play out over the live 3D scene and the
## brief explicitly asks for lightweight/cinematic over boxy. Lower bg
## alpha than panel_stylebox, no shadow (it's floating over the world, not
## stacked above other HUD chrome).
func dialogue_backing_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, 0.5)
	sb.border_color = GOLD_DIM
	if GameSettings.high_contrast:      # REV 297: solid black, white edge
		sb.bg_color = Color(0, 0, 0, 1)
		sb.border_color = Color.WHITE
	sb.set_border_width_all(BORDER_WIDTH)
	sb.set_corner_radius_all(PANEL_CORNER_RADIUS)
	sb.set_content_margin_all(14)
	return sb


func style_dialogue_backing(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", dialogue_backing_stylebox())
	_remember_style(panel, {"kind": "dialogue_backing"})


func button_stylebox(active: bool, disabled: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if disabled:
		sb.bg_color = BUTTON_BG_DISABLED
		sb.border_color = GOLD_DIM
	else:
		sb.bg_color = BUTTON_BG_ACTIVE if active else BUTTON_BG
		sb.border_color = GOLD_BRIGHT if active else GOLD_DIM
		if GameSettings.high_contrast:
			sb.bg_color = Color(0.3, 0.22, 0.0, 1) if active else Color(0, 0, 0, 1)
			sb.border_color = Color.WHITE if active else GOLD_BRIGHT
	sb.set_border_width_all(BORDER_WIDTH)
	sb.set_corner_radius_all(BUTTON_CORNER_RADIUS)
	sb.set_content_margin_all(6)
	return sb


# --------------------------------------------------------------------------
# Apply-to-node helpers
# --------------------------------------------------------------------------

## REV 297: `border` lets a panel keep its own edge colour (the backpack tooltip's bright gold)
## while still being restyled when High Contrast changes.
func style_panel(panel: PanelContainer, border: Color = GOLD) -> void:
	panel.add_theme_stylebox_override("panel", panel_stylebox(border))
	_remember_style(panel, {"kind": "panel", "border": border})


func style_bezel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", bezel_stylebox())
	_remember_style(panel, {"kind": "bezel"})


## Major panel title ("MISSION LOG", "SYSTEM") — one per panel, the biggest
## and brightest text on screen. Deliberately distinct from style_heading
## so a panel doesn't read as a flat wall of same-weight gold text.
func style_title(label: Label) -> void:
	label.add_theme_color_override("font_color", GOLD_BRIGHT)
	if font_bold != null:
		label.add_theme_font_override("font", font_bold)
	label.add_theme_font_size_override("font_size", 17)


## Section/topic heading within a panel (an entry's title, a column header).
func style_heading(label: Label) -> void:
	label.add_theme_color_override("font_color", GOLD)
	if font_bold != null:
		label.add_theme_font_override("font", font_bold)
	label.add_theme_font_size_override("font_size", 13)


## Ordinary body text inside a panel.
func style_body(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	if font_body != null:
		label.add_theme_font_override("font", font_body)
	label.add_theme_font_size_override("font_size", 12 + body_size_bonus)


## Secondary/contextual text — "(nothing collected yet)", hints, captions.
func style_hint(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT_DIM)
	if font_body != null:
		label.add_theme_font_override("font", font_body)
	label.add_theme_font_size_override("font_size", 10 + body_size_bonus)


## Deprecated alias for style_hint — kept so existing call sites don't need
## touching every time this file changes; new code should call style_hint.
func style_dim(label: Label) -> void:
	style_hint(label)


## Keybind suffixes ("[I]", "[L]") — always smaller and dimmer than whatever
## label they're attached to. Never used on its own as a primary label.
func style_keybind(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT_DIM)
	if font_body != null:
		label.add_theme_font_override("font", font_body)
	label.add_theme_font_size_override("font_size", 9 + body_size_bonus)


## Gold-bordered box button. active=true gives the restrained "currently
## open/selected" look (brighter border, warm dark-gold fill, brighter
## label) — not a bloom/glow effect, just a measured state change.
func style_button(btn: Button, active: bool = false, disabled: bool = false) -> void:
	btn.disabled = disabled
	_remember_style(btn, {"kind": "button", "active": active})
	btn.add_theme_stylebox_override("normal", button_stylebox(active, disabled))
	btn.add_theme_stylebox_override("hover", button_stylebox(true, disabled))
	btn.add_theme_stylebox_override("pressed", button_stylebox(true, disabled))
	btn.add_theme_stylebox_override("focus", button_stylebox(active, disabled))
	btn.add_theme_stylebox_override("disabled", button_stylebox(false, true))
	var font_color := TEXT_DISABLED if disabled else (GOLD_BRIGHT if active else TEXT_PRIMARY)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	btn.add_theme_color_override("font_focus_color", GOLD_BRIGHT)
	btn.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	if font_bold != null:
		btn.add_theme_font_override("font", font_bold)


## Builds a function-bank-style button with two independently-sized labels
## (a main label and a visually subordinate keybind) instead of one string —
## Button can't mix font sizes within a single text run, so the keybind is a
## second Label stacked underneath via a plain VBoxContainer child rather
## than any manual anchor math. The VBox/Labels are mouse_filter=IGNORE so
## clicks still land on the Button itself; empty keybind_text just omits
## the second line (used for COLLECTION, which has no shortcut yet).
func style_function_button(btn: Button, label_text: String, keybind_text: String, active: bool) -> void:
	btn.text = ""
	style_button(btn, active)

	var vbox := VBoxContainer.new()
	vbox.name = "Labels"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	btn.add_child(vbox)

	var main := Label.new()
	main.name = "MainLabel"
	main.text = label_text
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Microgramma Extended is a deliberately wide display face — at the
	# button widths this bank uses, "INVENTORY"/"COLLECTION" could still
	# run past their own button into the next one (Labels don't clip to
	# their rect by default, they just overflow). clip_text is a safety
	# net on top of sizing the font to actually fit.
	main.clip_text = true
	main.add_theme_color_override("font_color", GOLD_BRIGHT if active else TEXT_PRIMARY)
	if font_bold != null:
		main.add_theme_font_override("font", font_bold)
	main.add_theme_font_size_override("font_size", 8)
	vbox.add_child(main)

	if keybind_text != "":
		var kb := Label.new()
		kb.name = "KeybindLabel"
		kb.text = keybind_text
		kb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		style_keybind(kb)
		vbox.add_child(kb)


## Re-colors an existing style_function_button in place (border/fill via
## style_button, main label brightness) without rebuilding its children —
## called whenever a function-bank button's open/closed state changes.
func set_function_button_active(btn: Button, active: bool) -> void:
	style_button(btn, active)
	var vbox := btn.get_node_or_null("Labels")
	if vbox == null:
		return
	var main: Label = vbox.get_node_or_null("MainLabel")
	if main != null:
		main.add_theme_color_override("font_color", GOLD_BRIGHT if active else TEXT_PRIMARY)


## Thin horizontal divider — used instead of nesting every subsection in
## another bordered box (the brief's explicit preference for Mission Log).
func make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = SEPARATOR_COLOR
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sb)
	return sep


## Lighter-weight backing than a full modal panel — used for transient
## contextual readouts (the world target-identification prompt) that need
## "subtle backing/separation for readability" without looking like a
## panel the player could open/close. Lower-opacity fill, an accent border
## on the bottom edge only rather than all four sides, smaller shadow.
func target_prompt_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, 0.6)
	sb.border_color = GOLD_DIM
	sb.border_width_bottom = 1
	if GameSettings.high_contrast:      # REV 297: solid black, white edge all round
		sb.bg_color = Color(0, 0, 0, 1)
		sb.border_color = Color.WHITE
		sb.set_border_width_all(BORDER_WIDTH)
	sb.set_corner_radius_all(PANEL_CORNER_RADIUS)
	sb.set_content_margin_all(10)
	sb.shadow_size = 6
	sb.shadow_color = SHADOW_COLOR
	return sb


func style_target_prompt(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", target_prompt_stylebox())
	_remember_style(panel, {"kind": "target_prompt"})


## REV 297: a duration that is 0 with Reduced Motion on - for any fade or tween that is only
## decoration (screen fades, line fades, pulses). Use it as `create_tween()...(..., UITheme.dur(0.4))`.
func dur(seconds: float) -> float:
	return 0.0 if GameSettings.reduced_motion else seconds


## Kills whatever fade_in/fade_out tween this control was last given, if
## it's still running — without this, rapidly re-triggering either (e.g.
## sweeping the world target reticle across several hotspots in a row)
## stacks tweens fighting over the same modulate/position properties.
func _kill_tracked_tween(control: Control) -> void:
	var existing: Tween = control.get_meta("_ui_theme_tween") if control.has_meta("_ui_theme_tween") else null
	if existing != null and existing.is_valid():
		existing.kill()


## Quick, mechanical fade/slide for a panel opening — "panels can fade/
## slide a very short distance into place," explicitly not a slow phone-
## app glide. Safe to call repeatedly: kills any tween this control is
## already mid-way through before starting a fresh one.
## REV 293: with Reduced Motion on it simply appears (no fade, no slide), like panel_open.
func fade_in(control: Control, duration: float = FADE_IN_SECONDS, slide_pixels: float = FADE_SLIDE_PIXELS) -> void:
	_kill_tracked_tween(control)
	control.visible = true
	if GameSettings.reduced_motion:
		control.modulate.a = 1.0
		return
	control.modulate.a = 0.0
	var base_position := control.position
	control.position = base_position + Vector2(0, slide_pixels)
	var tween := control.create_tween()
	control.set_meta("_ui_theme_tween", tween)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration)
	tween.tween_property(control, "position", base_position, duration)


## REV 160 (CLAUDE.md item 21): the one shared open/close for panels and screens - the Case File,
## the backpack, computer screens. A quick fade with a slight grow from 97%, 140 ms in and 110 ms out:
## a click into place, not a glide. With Reduced Motion on it's instant.
const PANEL_OPEN_SECONDS := 0.14
const PANEL_CLOSE_SECONDS := 0.11
const PANEL_FROM_SCALE := 0.97

func panel_open(control: Control, sound: bool = true) -> void:
	_kill_tracked_tween(control)
	control.visible = true
	if sound:
		SfxManager.ui("open")      # REV 168: the interface sound family
	if GameSettings.reduced_motion:
		control.modulate.a = 1.0
		control.scale = Vector2.ONE
		return
	control.modulate.a = 0.0
	control.scale = Vector2.ONE * PANEL_FROM_SCALE
	var tween := control.create_tween()
	control.set_meta("_ui_theme_tween", tween)
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_scale_about_centre.bind(control), PANEL_FROM_SCALE, 1.0, PANEL_OPEN_SECONDS)
	tween.tween_property(control, "modulate:a", 1.0, PANEL_OPEN_SECONDS)


## Hides `control` the same way, then calls `done` (e.g. to hide the screen it sits on).
func panel_close(control: Control, done: Callable = Callable(), sound: bool = true) -> void:
	_kill_tracked_tween(control)
	if sound and control.is_visible_in_tree():
		SfxManager.ui("close")
	if GameSettings.reduced_motion or not control.is_visible_in_tree():
		control.scale = Vector2.ONE
		control.modulate.a = 1.0
		if done.is_valid():
			done.call()
		return
	var tween := control.create_tween()
	control.set_meta("_ui_theme_tween", tween)
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_method(_scale_about_centre.bind(control), 1.0, PANEL_FROM_SCALE, PANEL_CLOSE_SECONDS)
	tween.tween_property(control, "modulate:a", 0.0, PANEL_CLOSE_SECONDS)
	tween.chain().tween_callback(func() -> void:
		control.scale = Vector2.ONE
		control.modulate.a = 1.0
		if done.is_valid():
			done.call())


func _scale_about_centre(k: float, control: Control) -> void:
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(k, k)


## Mirror of fade_in for hiding a transient element — tweens out, then sets
## visible = false and resets modulate/position so the next fade_in starts
## clean. Used for the world target-identification prompt (appear/
## disappear are both ~150-200ms per the art direction); the three modal
## panels still close instantly on purpose — only their opening is animated.
func fade_out(control: Control, duration: float = FADE_IN_SECONDS, slide_pixels: float = FADE_SLIDE_PIXELS) -> void:
	_kill_tracked_tween(control)
	if GameSettings.reduced_motion:     # REV 293: instant with Reduced Motion, like panel_close
		control.visible = false
		control.modulate.a = 1.0
		return
	var base_position := control.position
	var tween := control.create_tween()
	control.set_meta("_ui_theme_tween", tween)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(control, "modulate:a", 0.0, duration)
	tween.tween_property(control, "position", base_position + Vector2(0, slide_pixels), duration)
	tween.chain().tween_callback(func():
		control.visible = false
		control.position = base_position
		control.modulate.a = 1.0
	)


# --------------------------------------------------------------------------
# REV 103: menu backdrop - the game blurred and dimmed behind a menu
# --------------------------------------------------------------------------
const BACKDROP_SHADER := "res://core/ui/shaders/menu_backdrop.gdshader"

## A full-screen ColorRect that shows the game behind it softly blurred and dimmed (`darken` 0..1).
## Starts hidden; show/hide it with fade_backdrop().
func make_blur_backdrop(darken: float = MODAL_DIM_ALPHA) -> ColorRect:
	var r := ColorRect.new()
	r.name = "BlurBackdrop"
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(0, 0, 0, darken)      # plain dim if the shader can't load
	var sh: Shader = load(BACKDROP_SHADER) if ResourceLoader.exists(BACKDROP_SHADER) else null
	if sh != null:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("darken", darken)
		m.set_shader_parameter("strength", 0.0)
		r.material = m
		r.color = Color.WHITE
	r.visible = false
	return r


func fade_backdrop(r: ColorRect, on: bool, seconds: float = ANIM_MODAL) -> void:
	if r == null:
		return
	if GameSettings.reduced_motion:     # REV 296: Reduced Motion = instant, like panel_open/close
		seconds = 0.0
	var m := r.material as ShaderMaterial
	if r.has_meta("_bd_tween"):
		var old: Tween = r.get_meta("_bd_tween")
		if old != null and old.is_valid():
			old.kill()
	if on:
		r.visible = true
	var tw := r.create_tween().set_trans(Tween.TRANS_SINE)
	r.set_meta("_bd_tween", tw)
	if m != null:
		tw.tween_property(m, "shader_parameter/strength", 1.0 if on else 0.0, seconds)
	else:
		r.modulate.a = 0.0 if on else r.modulate.a
		tw.tween_property(r, "modulate:a", 1.0 if on else 0.0, seconds)
	if not on:
		tw.tween_callback(func(): r.visible = false)
