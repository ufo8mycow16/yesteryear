extends PanelContainer
class_name ConsoleBar
## REV 301 (Glen picked "Option D - Combined" from the HUD mockups, 24 Oct 2026): the bottom bar.
## A full-width TOS console strip that replaces the old bottom-left NOW PLAYING card and the
## bottom-right button rail. Nikki never found the Case File in her playtest, so it is the biggest,
## brightest key on the bar, with a count of clues found since it was last opened.
##
##   [lamp strip: amber / red / green / blue indicator lights along the top edge]
##   PARTY: big portrait of who you play + name, small portraits of the rest (pick one = switch)
##          PARTY / SOLO switch (in a party the others follow you; solo, they stay put)
##   QUICK ITEMS: the played character's kit and the backpack, the one in hand lit up
##   CASE FILE (amber, "2 NEW CLUES")   INVENTORY  LOG  MAP  CARDS  SYSTEM
##
## Every key shows its keyboard key or pad button (InputHints / ButtonGlyph) and follows rebinding.
## The scene answers who is in the party: EpisodeRoom (party_members(), switch_to(), party mode);
## anywhere else (the Prologue) it's just the one character the HUD reports, no switch.
## No portrait pictures exist yet: a tile in the person's division colour with their initials.
## Drop res://assets/portraits/<who>.png in and it is used instead (same as the subtitle portraits).

const Glyph := preload("res://core/ui/ButtonGlyph.gd")
## REV 319 (Glen: "the hud is too big... it takes a lot of room"): half the height it was (122), and it
## tucks itself away below the screen while you walk - see "tucking away" at the bottom.
const BAR_HEIGHT := 66.0
const PORTRAITS_DIR := "res://assets/portraits/"
const BIG := Vector2(50, 50)
const SMALL := Vector2(26, 26)
const AMBER := Color(0.88, 0.65, 0.15)
const AMBER_BRIGHT := Color(0.965, 0.81, 0.42)
const AMBER_TEXT := Color(0.10, 0.075, 0.02)
const KEY_COLOURS := {
	"INVENTORY": [Color(0.18, 0.43, 0.66), Color(0.37, 0.62, 0.84)],
	"LOG": [Color(0.18, 0.48, 0.29), Color(0.36, 0.69, 0.49)],
	"MAP": [Color(0.165, 0.173, 0.19), Color(0.29, 0.30, 0.33)],
	"COLLECTION": [Color(0.165, 0.173, 0.19), Color(0.29, 0.30, 0.33)],
	"SYSTEM": [Color(0.165, 0.173, 0.19), Color(0.29, 0.30, 0.33)],
}
## Division colours for the placeholder portraits (command gold, sciences blue, operations red).
const DIVISION := {
	"kirk": Color(0.80, 0.66, 0.26), "sulu": Color(0.80, 0.66, 0.26), "chekov": Color(0.80, 0.66, 0.26),
	"mccoy": Color(0.36, 0.55, 0.74), "spock": Color(0.36, 0.55, 0.74), "chapel": Color(0.36, 0.55, 0.74),
	"uhura": Color(0.70, 0.25, 0.22), "scotty": Color(0.70, 0.25, 0.22), "kyle": Color(0.70, 0.25, 0.22),
}

signal key_pressed(name: String)       # INVENTORY / LOG / MAP / COLLECTION / SYSTEM / CASE FILE

var who_label: Label
var big_portrait: Control              # named "McCoyPortrait" (EpisodeRoom looks for it by name)
var buttons: Dictionary = {}           # label -> Button (HUD lights the open screen's key)
var _small_row: HBoxContainer
var _switch_hint: Control
var _party_btn: Button
var _solo_btn: Button
var _party_box: Control
var _items_row: HBoxContainer
var _case_btn: Button
var _case_count_label: Label
var _new_clues := 0
var _taught := false
var _pulse: Tween
var _party_sig := ""
var _items_sig := ""


func _ready() -> void:
	name = "ConsoleBar"
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = -BAR_HEIGHT
	offset_bottom = 0.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN   # if its contents ever need more room, it grows upward, not off the screen
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.051, 0.067, 0.96)
	sb.border_color = Color(0.184, 0.227, 0.282)
	sb.border_width_top = 2
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(_lamp_strip())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	row.add_child(_build_party())
	row.add_child(_divider())
	row.add_child(_build_items())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	row.add_child(_build_case_key())
	row.add_child(_build_small_keys())

	MissionLog.notification_requested.connect(_on_notice)
	InteractionManager.held_source_changed.connect(func(_id: String) -> void: _items_sig = "")
	if GameSettings.has_signal("accessibility_changed"):
		GameSettings.accessibility_changed.connect(_refresh_case_key)
	_refresh_case_key()


func _process(delta: float) -> void:
	_refresh_party()
	_refresh_items()
	_update_tuck(delta)


# ---- tucking away (REV 319) ------------------------------------------------------------------------
## While you walk, the bar slides down out of sight; it comes back up when you stop (STILL_AFTER), when
## the mouse goes to the bottom of the screen, when a pad button or a menu key is pressed, and when
## something new turns up (a clue, a notice) - then stays a few seconds (WAKE_SECONDS).

const STILL_AFTER := 0.6
const WAKE_SECONDS := 4.0
const TUCK_SPEED := 5.0          # bar heights a second
var _tuck := 0.0                 # 0 = up, 1 = out of sight below the screen
var _still := 99.0
var _wake_left := 0.0


## How much of the bar is on screen now, in pixels (HUD keeps the subtitle box just above it).
func shown_height() -> float:
	return BAR_HEIGHT * (1.0 - _tuck)


## Bring the bar up for a few seconds (new clue, notice, a menu key).
func wake(seconds: float = WAKE_SECONDS) -> void:
	_wake_left = maxf(_wake_left, seconds)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		wake()
	elif event is InputEventKey and event.pressed and not event.echo:
		for a in ["inventory_open", "mission_log_open", "map_open", "collection_open", "system_menu_open",
				"case_file_open", "switch_character", "party_toggle"]:
			if InputMap.has_action(a) and event.is_action(a):
				wake()
				break


func _walking() -> bool:
	var v := Vector2.ZERO
	if InputMap.has_action("move_left") and InputMap.has_action("move_forward"):
		v = Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.2)
	if v.length() > 0.2:
		return true
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _mouse_at_bottom() -> bool:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		return false
	var vp := get_viewport()
	if vp == null:
		return false
	return vp.get_mouse_position().y > vp.get_visible_rect().size.y - BAR_HEIGHT - 24.0


func _update_tuck(delta: float) -> void:
	_still = 0.0 if _walking() else _still + delta
	_wake_left = maxf(0.0, _wake_left - delta)
	var up := _still > STILL_AFTER or _wake_left > 0.0 or _mouse_at_bottom()
	var target := 0.0 if up else 1.0
	if GameSettings.reduced_motion:
		_tuck = target
	else:
		_tuck = move_toward(_tuck, target, delta * TUCK_SPEED)
	var drop := (BAR_HEIGHT + 4.0) * _tuck
	offset_top = -BAR_HEIGHT + drop
	offset_bottom = drop


# ---- lamps --------------------------------------------------------------------------------------

## A thin row of coloured indicator lamps along the top edge, like the TOS bridge consoles.
func _lamp_strip() -> Control:
	var strip := HBoxContainer.new()
	strip.custom_minimum_size = Vector2(0, 4)
	strip.add_theme_constant_override("separation", 4)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lamps := [[60, AMBER], [18, AMBER], [18, Color(0.78, 0.29, 0.23)], [90, Color(0.23, 0.165, 0.04)],
		[18, Color(0.25, 0.68, 0.42)], [40, AMBER], [0, Color(0, 0, 0, 0)],
		[18, Color(0.78, 0.29, 0.23)], [70, AMBER], [18, Color(0.25, 0.56, 0.82)]]
	for l in lamps:
		var r := ColorRect.new()
		r.color = l[1]
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if int(l[0]) == 0:
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			r.custom_minimum_size = Vector2(float(l[0]), 4)
		strip.add_child(r)
	return strip


func _divider() -> Control:
	var d := ColorRect.new()
	d.color = Color(0.184, 0.227, 0.282)
	d.custom_minimum_size = Vector2(1, 44)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


# ---- party ---------------------------------------------------------------------------------------

func _build_party() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_box = box

	big_portrait = Control.new()
	big_portrait.name = "McCoyPortrait"     # (EpisodeRoom._update_who_label finds it by this name)
	big_portrait.custom_minimum_size = BIG
	big_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	big_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(big_portrait)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	who_label = Label.new()
	who_label.name = "WhoLabel"
	UITheme.style_title(who_label)
	who_label.add_theme_font_size_override("font_size", 18)
	who_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	col.add_child(who_label)
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 6)
	small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(small)
	_small_row = HBoxContainer.new()
	_small_row.add_theme_constant_override("separation", 6)
	small.add_child(_small_row)
	_switch_hint = _key_hint("{switch_character}", "switch_character")
	small.add_child(_switch_hint)

	# PARTY / SOLO
	var mode := VBoxContainer.new()
	mode.add_theme_constant_override("separation", 2)
	mode.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(mode)
	_party_btn = _mode_button("PARTY", 3)
	_solo_btn = _mode_button("SOLO", 1)
	_party_btn.pressed.connect(func() -> void: _set_mode("party"))
	_solo_btn.pressed.connect(func() -> void: _set_mode("solo"))
	var pair := HBoxContainer.new()          # REV 319: side by side, not stacked
	pair.add_theme_constant_override("separation", 4)
	pair.add_child(_party_btn)
	pair.add_child(_solo_btn)
	mode.add_child(pair)
	mode.add_child(_key_hint("{party_toggle}", "party_toggle"))
	return box


func _mode_button(text: String, people: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(76, 24)
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_font_size_override("font_size", 11)
	b.tooltip_text = "Your crew follow you" if people > 1 else "Your crew stay where they are"
	var icon := _PeopleIcon.new()
	icon.people = people
	icon.position = Vector2(6, 5)
	icon.size = Vector2(20, 14)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	return b


func _scene() -> Node:
	return get_tree().current_scene if is_inside_tree() else null


## Who is in the party right now: [main person, the others...] (people ids, e.g. "mccoy").
func _party() -> Array:
	var scene := _scene()
	if scene != null and scene.has_method("party_members"):
		return scene.call("party_members")
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if hud != null and hud.has_method("_current_lead_id"):
		return [String(hud.call("_current_lead_id"))]
	return ["mccoy"]


func _refresh_party() -> void:
	var members := _party()
	var scene := _scene()
	var mode := party_mode()
	var sig := ",".join(members) + "|" + mode
	if sig == _party_sig:
		return
	_party_sig = sig
	var main := String(members[0]) if not members.is_empty() else "mccoy"
	who_label.text = GameNames.character(main)
	_fill_portrait(big_portrait, main, BIG, UITheme.GOLD)
	for c in _small_row.get_children():
		c.queue_free()
	var can := scene != null and scene.has_method("switch_to") and bool(scene.get("allow_switching")) \
		and (not scene.has_method("can_switch") or bool(scene.call("can_switch")))
	for i in range(1, members.size()):
		var who := String(members[i])
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.custom_minimum_size = SMALL
		b.tooltip_text = "Switch to " + GameNames.character(who)
		b.disabled = not can
		var frame := Control.new()
		frame.custom_minimum_size = SMALL
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(frame)
		_fill_portrait(frame, who, SMALL, UITheme.ACCENT_SCIENCE_BLUE)
		b.pressed.connect(func() -> void:
			var sc := _scene()
			if sc != null and sc.has_method("switch_to") and sc.has_method("other_character"):
				sc.call("switch_to", String(sc.call("other_character"))))
		_small_row.add_child(b)
	_switch_hint.visible = members.size() > 1 and can
	var has_party := members.size() > 1
	_party_btn.get_parent().visible = has_party
	_style_mode(_party_btn, mode == "party")
	_style_mode(_solo_btn, mode == "solo")


func _style_mode(b: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2 if on else 1)
	sb.border_color = Color(0.25, 0.68, 0.42) if on else Color(0.29, 0.30, 0.33)
	sb.bg_color = Color(0.07, 0.20, 0.13) if on else Color(0.08, 0.09, 0.105)
	sb.content_margin_right = 10
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(0.62, 0.88, 0.71) if on else Color(0.58, 0.58, 0.56))
	b.add_theme_color_override("font_hover_color", Color(0.85, 0.95, 0.88))


## REV 309: the same pictures the dialogue box uses (HUD._portrait_for): <id>.png ("kirk"), then the
## on-screen name in full ("captain_kirk"), then its last word. "" when there is none.
func _portrait_path(who: String) -> String:
	var base := GameNames.character(who).strip_edges().to_lower().replace(".", "")
	for c in [who.to_lower(), base.replace(" ", "_"), base.get_slice(" ", base.get_slice_count(" ") - 1)]:
		var path := PORTRAITS_DIR + String(c) + ".png"
		if String(c) != "" and ResourceLoader.exists(path):
			return path
	return ""


## A portrait: res://assets/portraits/<who>.png if there is one, else a division-coloured tile with
## the person's initials. Rebuilds the frame's children.
func _fill_portrait(frame: Control, who: String, size_px: Vector2, border: Color) -> void:
	for c in frame.get_children():
		c.queue_free()
	var path := _portrait_path(who)
	if path != "":
		var pf := PortraitFrame.new()
		frame.add_child(pf)
		pf.setup(load(path), size_px, border, 10.0, 2.0, 1.5, 0.8, 0.2)
		return
	var tile := PanelContainer.new()
	tile.custom_minimum_size = size_px
	tile.size = size_px
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	var div: Color = DIVISION.get(who, Color(0.45, 0.45, 0.48))
	sb.bg_color = div.darkened(0.55)
	sb.border_color = border
	sb.set_border_width_all(3 if size_px.x > 60 else 2)
	sb.set_corner_radius_all(8)
	tile.add_theme_stylebox_override("panel", sb)
	frame.add_child(tile)
	var initials := Label.new()
	var nm := GameNames.character(who)
	var parts := nm.split(" ", false)
	initials.text = (String(parts[parts.size() - 1]) if parts.size() > 0 else who).substr(0, 2).to_upper()
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.add_theme_font_size_override("font_size", 20 if size_px.x > 40 else 11)
	initials.add_theme_color_override("font_color", div.lightened(0.35))
	tile.add_child(initials)


## "party" (the crew follow you) or "solo" (they stay put). Saved with the game.
static func party_mode() -> String:
	if GameState.has_var("PARTY_MODE"):
		return "solo" if String(GameState.get_var("PARTY_MODE")) == "solo" else "party"
	return "party"


func _set_mode(mode: String) -> void:
	var scene := _scene()
	if scene != null and scene.has_method("set_party_mode"):
		scene.call("set_party_mode", mode)
	else:
		GameState.set_var("PARTY_MODE", mode)
	SfxManager.ui("confirm")
	_party_sig = ""


# ---- quick items ---------------------------------------------------------------------------------

func _build_items() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items_row = HBoxContainer.new()
	_items_row.add_theme_constant_override("separation", 6)
	col.add_child(_items_row)
	return col


## The kit of whoever is played, then the backpack - at most five, the one in hand lit up.
func _item_ids() -> Array:
	var out: Array = []
	for e in EquipmentManager.get_equipment_for(InteractionManager.kit_owner()):
		if e != null:
			out.append([String(e.id), String(e.display_name)])
	for it in InventoryManager.get_all_items():
		if it != null:
			out.append([String(it.id), String(it.display_name)])
	return out.slice(0, 5)


func _refresh_items() -> void:
	var ids := _item_ids()
	var held := InteractionManager.get_held_source()
	var sig := str(ids) + "|" + held
	if sig == _items_sig:
		return
	_items_sig = sig
	for c in _items_row.get_children():
		c.queue_free()
	for pair in ids:
		var id := String(pair[0])
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(42, 42)
		b.tooltip_text = String(pair[1])
		b.expand_icon = true
		b.icon = InventoryEquipmentUI.icon_texture(id)
		if b.icon == null:
			b.text = String(pair[1]).substr(0, 4).to_upper()
			b.add_theme_font_size_override("font_size", 11)
		var on := held == id
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(2 if on else 1)
		sb.border_color = UITheme.GOLD_BRIGHT if on else Color(0.29, 0.30, 0.33)
		sb.bg_color = Color(0.165, 0.13, 0.04) if on else Color(0.08, 0.09, 0.105)
		sb.set_content_margin_all(4)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func() -> void:
			if InteractionManager.is_locked():
				return
			InteractionManager.set_held_source("" if InteractionManager.get_held_source() == id else id))
		_items_row.add_child(b)
	_items_row.add_child(_key_hint("{inventory_open}", "inventory_open"))


# ---- the Case File key ---------------------------------------------------------------------------

func _build_case_key() -> Control:
	_case_btn = Button.new()
	_case_btn.name = "CaseFileKey"
	_case_btn.focus_mode = Control.FOCUS_NONE
	_case_btn.custom_minimum_size = Vector2(160, 50)
	_case_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_case_btn.pivot_offset = Vector2(80, 25)
	_case_btn.tooltip_text = "Everything you've found, and what it might mean"
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 14
	inner.offset_right = -12
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_case_btn.add_child(inner)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(texts)
	var title := Label.new()
	title.text = "CASE FILE"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", AMBER_TEXT)
	texts.add_child(title)
	_case_count_label = Label.new()
	_case_count_label.add_theme_font_size_override("font_size", 11)
	_case_count_label.add_theme_color_override("font_color", AMBER_TEXT)
	texts.add_child(_case_count_label)
	var hint := _key_hint("{case_file_open}", "case_file_open", AMBER_TEXT)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(hint)
	_case_btn.pressed.connect(func() -> void: key_pressed.emit("CASE FILE"))
	return _case_btn


func _refresh_case_key() -> void:
	if _case_btn == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = AMBER
	sb.border_color = AMBER_BRIGHT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(AMBER.r, AMBER.g, AMBER.b, 0.55 if _new_clues > 0 else 0.25)
	sb.shadow_size = 14 if _new_clues > 0 else 6
	if GameSettings.high_contrast:
		sb.bg_color = Color(1.0, 0.8, 0.2)
		sb.border_color = Color.WHITE
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = AMBER_BRIGHT
	_case_btn.add_theme_stylebox_override("normal", sb)
	_case_btn.add_theme_stylebox_override("focus", sb)
	_case_btn.add_theme_stylebox_override("hover", hover)
	_case_btn.add_theme_stylebox_override("pressed", hover)
	if _new_clues == 0:
		_case_count_label.text = "NOTHING NEW"
	elif _new_clues == 1:
		_case_count_label.text = "1 NEW CLUE"
	else:
		_case_count_label.text = "%d NEW CLUES" % _new_clues


## A clue landed ("Case File Updated..." notices): count it and draw the eye to the key.
func _on_notice(message: String) -> void:
	wake()
	if not message.begins_with("Case File Updated"):
		return
	_new_clues += 1
	_refresh_case_key()
	pulse(not _taught)
	_taught = true


## REV 475: the redesigned Prologue has no Case File - its room hides the key (HUD asks the room's
## hud_case_file(); a room without that method keeps it).
func set_case_file_visible(on: bool) -> void:
	if _case_btn != null:
		_case_btn.visible = on


## The Case File was opened: nothing new any more.
func case_file_opened() -> void:
	_new_clues = 0
	_refresh_case_key()
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_case_btn.scale = Vector2.ONE
	_case_btn.modulate = Color.WHITE


## Pulses the key (strong = the first clue of the session: several beats). Reduced Motion: no
## movement - it just stays lit (the glow and the count still say so).
func pulse(strong: bool = false) -> void:
	wake()
	if _case_btn == null:
		return
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_case_btn.scale = Vector2.ONE
	if GameSettings.reduced_motion:
		return
	_pulse = create_tween()
	for i in (5 if strong else 2):
		_pulse.tween_property(_case_btn, "scale", Vector2(1.07, 1.07), 0.22).set_trans(Tween.TRANS_SINE)
		_pulse.parallel().tween_property(_case_btn, "modulate", Color(1.25, 1.2, 1.05), 0.22)
		_pulse.tween_property(_case_btn, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_SINE)
		_pulse.parallel().tween_property(_case_btn, "modulate", Color.WHITE, 0.28)


# ---- the small keys ------------------------------------------------------------------------------

func _build_small_keys() -> Control:
	var grid := GridContainer.new()
	grid.columns = 5     # REV 319: one row (was two rows of three)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var keys := [["INVENTORY", "INVENTORY", "{inventory_open}"], ["LOG", "LOG", "{mission_log_open}"],
		["MAP", "MAP", "{map_open}"], ["COLLECTION", "CARDS", "{collection_open}"], ["SYSTEM", "SYSTEM", "{system_menu_open}"]]
	for k in keys:
		var b := Button.new()
		b.name = String(k[0]).capitalize().replace(" ", "") + "Button"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(80, 44)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var t := Label.new()
		t.text = String(k[1])
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_size_override("font_size", 12)
		t.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
		v.add_child(t)
		var kb := Label.new()
		kb.name = "KeybindLabel"
		kb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kb.add_theme_font_size_override("font_size", 10)
		kb.add_theme_color_override("font_color", Color(0.82, 0.84, 0.86))
		InputHints.bind(kb, String(k[2]))
		v.add_child(kb)
		buttons[String(k[0])] = b
		set_key_active(String(k[0]), false)
		var key_name := String(k[0])
		b.pressed.connect(func() -> void: key_pressed.emit(key_name))
		grid.add_child(b)
	return grid


## Lights the key of the screen that is open (HUD calls it every frame - only restyles on a change).
func set_key_active(key_name: String, active: bool) -> void:
	var b: Button = buttons.get(key_name)
	if b == null:
		return
	if b.has_meta("active") and bool(b.get_meta("active")) == active:
		return
	b.set_meta("active", active)
	var col: Array = KEY_COLOURS.get(key_name, [Color(0.165, 0.173, 0.19), Color(0.29, 0.30, 0.33)])
	var sb := StyleBoxFlat.new()
	sb.bg_color = (col[0] as Color).lightened(0.25) if active else col[0]
	sb.border_color = UITheme.GOLD_BRIGHT if active else col[1]
	sb.set_border_width_all(2 if active else 1)
	sb.set_corner_radius_all(6)
	if GameSettings.high_contrast:
		sb.bg_color = Color.BLACK
		sb.border_color = Color.WHITE
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = (sb.bg_color as Color).lightened(0.15)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)


# ---- helpers -------------------------------------------------------------------------------------

## A key cap (keyboard) or the pad's button picture, whichever is in use.
func _key_hint(template: String, action: String, colour: Color = Color(0.79, 0.79, 0.77)) -> Control:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := Label.new()
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", colour)
	InputHints.bind(cap, template)
	box.add_child(cap)
	var glyph := Glyph.make(action, 20.0, true)
	box.add_child(glyph)
	var sync := func(_g: bool = false) -> void:
		cap.visible = not InputHints.using_gamepad
	InputHints.device_changed.connect(sync)
	sync.call()
	return box


## The PARTY / SOLO pictures: three heads or one, drawn (no emoji, no picture files).
class _PeopleIcon extends Control:
	var people := 3
	func _draw() -> void:
		var c: Color = (get_parent() as Control).get_theme_color("font_color") if get_parent() is Control else Color.WHITE
		var xs: Array = [12.0] if people == 1 else [5.0, 12.0, 19.0]
		for x in xs:
			draw_arc(Vector2(x, 4.5), 2.8, 0.0, TAU, 16, c, 1.6, true)
			draw_arc(Vector2(x, 15.0), 5.0, PI, TAU, 16, c, 1.6, true)
	func _process(_d: float) -> void:
		queue_redraw()

