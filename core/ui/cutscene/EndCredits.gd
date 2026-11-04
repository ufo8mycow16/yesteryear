extends Control
class_name EndCredits
## EndCredits (REV 104): closing credits in the manner of a TOS episode - one card at a time, centred,
## the role small in gold over the name in large off-white, each fading up and away, over the slowly
## moving Enterprise-over-Vulcan backdrop (the title sequence's endless "menu" view).
##
## The words come from res://CREDITS.txt (see the notes at the top of that file), so names and roles
## can be changed without touching code. If an end-theme file exists (END_MUSIC), the cards are timed
## to fill it and the music fades out at the end; otherwise each card holds for CARD_SECONDS.
## Background (REV 105): stills, like the original game's credits (frames from the show, or rendered
## scenes from the game). Put images (png / jpg / webp) in res://assets/credits/ - they are shown in
## name order, spread evenly over the cards, each slowly drifting and zooming and crossfading into the
## next. A line "@picture.png" in a card of CREDITS.txt pins that picture from that card onward instead.
## With no stills at all, the slowly moving Enterprise-over-Vulcan view is used as before.
## ESC / the cancel button skips. Use:
##     await EndCredits.roll(self, "IN SHEEP'S CLOTHING")      # finishes when the credits end

signal finished

const CREDITS_FILE := "res://CREDITS.txt"
const END_MUSIC := ["res://assets/audio/music/end_credits.ogg", "res://assets/audio/music/end_credits.mp3",
	"res://assets/audio/music/end_credits.wav"]
const CARD_SECONDS := 4.5
const FADE := 0.7
const MIN_CARD := 3.2
const MAX_CARD := 7.0
const LEAD_IN := 1.5       # backdrop alone before the first card
const TAIL := 2.0          # after the last card, before the end
const STILLS_DIR := "res://assets/credits"
const STILL_EXTS := ["png", "jpg", "jpeg", "webp"]
const STILL_FADE := 1.6    # crossfade between stills
const DRIFT_ZOOM := 0.08   # each still grows by this much while it is up
const DRIFT_PAN := 0.025   # and slides by this fraction of the screen

var episode_title := ""
var _cards: Array = []
var _music: AudioStreamPlayer
var _backdrop: Node = null
var _black: ColorRect
var _card: VBoxContainer
var _done := false
var _stills: Array = []          # file names in STILLS_DIR
var _still_rects: Array = []     # two TextureRects, swapped on each crossfade
var _still_front := 0
var _still_now := ""
var _still_tw: Tween


## Roll the credits over `parent` and wait until they end (or are skipped).
static func roll(parent: Node, title: String = "", with_backdrop: bool = true) -> void:
	# on its own screen layer, so it always fills the window whatever it is added to
	var layer := CanvasLayer.new()
	layer.layer = 45
	parent.add_child(layer)
	var c: Control = load("res://core/ui/cutscene/EndCredits.gd").new()   # by path: works before Godot rescans
	c.set("episode_title", title)
	c.set_meta("with_backdrop", with_backdrop)
	layer.add_child(c)
	await c.finished
	layer.queue_free()


## The cards from CREDITS.txt: [{"style": "role"|"title"|"notice", "lines": [...]}].
static func read_cards(title: String = "") -> Array:
	var cards: Array = []
	var text := ""
	if FileAccess.file_exists(CREDITS_FILE):
		text = FileAccess.get_file_as_string(CREDITS_FILE)
	if text.strip_edges() == "":
		text = "*STAR TREK\nTHE SECRET OF VULCAN FURY"
	var block: PackedStringArray = []
	var pending_image := ""
	for raw in (text + "\n\n").split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		if line == "":
			if not block.is_empty():
				var card := _card_from(block, title)
				if card.get("style", "") == "image_only":
					pending_image = String(card["image"])   # a card that is only "@picture" applies to the next card
				elif not card.is_empty():
					if pending_image != "" and String(card.get("image", "")) == "":
						card["image"] = pending_image
					pending_image = ""
					cards.append(card)
				block = PackedStringArray()
			continue
		block.append(line)
	return cards


static func _card_from(block: PackedStringArray, title: String) -> Dictionary:
	var lines: Array = []
	var image := ""
	for l in block:
		var t := String(l)
		if t.begins_with("@"):
			image = t.substr(1).strip_edges()      # "@picture.png" - the still for this card onward
			continue
		lines.append(t.replace("{EPISODE}", title.to_upper()))
	if lines.is_empty():
		return {"style": "image_only", "lines": [], "image": image} if image != "" else {}
	var style := "role"
	var first := String(lines[0])
	if first.begins_with("*"):
		style = "title"
		lines[0] = first.substr(1).strip_edges()
	elif first.begins_with("~"):
		style = "notice"
		lines[0] = first.substr(1).strip_edges()
	var kept: Array = []
	for l in lines:
		if String(l).strip_edges() != "":
			kept.append(l)
	if kept.is_empty():
		return {"style": "image_only", "lines": [], "image": image} if image != "" else {}   # e.g. {EPISODE} with no episode
	return {"style": style, "lines": kept, "image": image}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cards = read_cards(episode_title)

	_stills = list_stills()
	_assign_stills()
	if not _stills.is_empty():
		var under := ColorRect.new()          # stills sit on black (their edges never show, but just in case)
		under.color = Color.BLACK
		under.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		under.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(under)
		for i in 2:
			var r := TextureRect.new()
			r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.modulate.a = 0.0
			add_child(r)
			_still_rects.append(r)

	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _stills.is_empty() and bool(get_meta("with_backdrop", true)):
		_backdrop = TitleSequence.new()
		_backdrop.menu_mode = true
		add_child(_backdrop)
		move_child(_backdrop, 0)
		_backdrop.call("play_menu")
	# (black goes over the backdrop/stills and fades away, so the credits rise out of black)
	add_child(_black)
	# a soft darkening so white text always reads, whatever the backdrop is doing
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_card = VBoxContainer.new()
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.add_theme_constant_override("separation", 6)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	add_child(_card)

	_music = AudioStreamPlayer.new()
	_music.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	add_child(_music)
	for p in END_MUSIC:
		if ResourceLoader.exists(p):
			_music.stream = load(p)
			break
	_run()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("menu_cancel"):
		get_viewport().set_input_as_handled()
		_finish()


func _card_time() -> float:
	if _music.stream != null and _music.stream.get_length() > 0.0 and not _cards.is_empty():
		var usable := _music.stream.get_length() - LEAD_IN - TAIL
		return clampf(usable / float(_cards.size()), MIN_CARD, MAX_CARD)
	return CARD_SECONDS


func _run() -> void:
	# fade up from black onto the backdrop, music starting with it
	if _music.stream != null:
		_music.volume_db = -30.0
		_music.play()
		create_tween().tween_property(_music, "volume_db", 0.0, 1.2)
	if not _stills.is_empty() and not _cards.is_empty():
		_show_still(String(_cards[0].get("image", "")), true)
	if _backdrop != null or not _stills.is_empty():
		create_tween().tween_property(_black, "modulate:a", 0.0, 1.4)   # up from black onto the backdrop
	else:
		_black.modulate.a = 0.0    # over a scene that already has its own backdrop (the main menu)
	await get_tree().create_timer(LEAD_IN).timeout
	var each := _card_time()
	for card in _cards:
		if _done:
			return
		if not _stills.is_empty():
			_show_still(String(card.get("image", "")), false, each)
		_show(card)
		var tw := create_tween()
		tw.tween_property(_card, "modulate:a", 1.0, FADE)
		tw.tween_interval(maxf(each - FADE * 2.0, 0.6))
		tw.tween_property(_card, "modulate:a", 0.0, FADE)
		await tw.finished
	if _done:
		return
	await get_tree().create_timer(TAIL * 0.5).timeout
	_finish()


func _show(card: Dictionary) -> void:
	for c in _card.get_children():
		_card.remove_child(c)
		c.queue_free()
	var style := String(card["style"])
	var lines: Array = card["lines"]
	for i in lines.size():
		var l := Label.new()
		l.text = String(lines[i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 900.0
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 6)
		var big := style == "title" or (style == "role" and i > 0)
		var font: Font = UITheme.font_bold if big else (UITheme.font_body if style == "notice" else UITheme.font_regular)
		if font != null:
			l.add_theme_font_override("font", font)
		match style:
			"title":
				l.add_theme_font_size_override("font_size", 40 if i == 0 else 30)
				l.add_theme_color_override("font_color", UITheme.GOLD)
			"notice":
				l.add_theme_font_size_override("font_size", 13)
				l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
			_:
				if i == 0:
					l.add_theme_font_size_override("font_size", 15 if lines.size() > 1 else 20)
					l.add_theme_color_override("font_color", UITheme.GOLD)
				else:
					l.add_theme_font_size_override("font_size", 34)
					l.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
		_card.add_child(l)
		if style == "role" and i == 0 and lines.size() > 1:
			var gap := Control.new()
			gap.custom_minimum_size.y = 4.0
			_card.add_child(gap)


func _finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 0.0, 0.4)
	if _backdrop != null or not _stills.is_empty():
		tw.tween_property(_black, "modulate:a", 1.0, 0.8)   # back down to black for what follows
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, 1.0)
	await tw.finished
	_music.stop()
	finished.emit()


# --- stills -------------------------------------------------------------------------------------

## Picture files in STILLS_DIR, in name order. Works in the editor and in an exported game (where
## the folder lists "name.png.import" instead of the picture itself).
static func list_stills() -> Array:
	var names: Array = []
	var d := DirAccess.open(STILLS_DIR)
	if d == null:
		return names
	for f in d.get_files():
		var n := String(f)
		if n.ends_with(".import"):
			n = n.trim_suffix(".import")
		elif n.ends_with(".remap"):
			n = n.trim_suffix(".remap")
		if STILL_EXTS.has(n.get_extension().to_lower()) and not names.has(n):
			names.append(n)
	names.sort_custom(func(a, b): return String(a).naturalnocasecmp_to(String(b)) < 0)
	return names


## Give every card a still: pinned ones ("@picture") hold until the next pin; without any pins the
## pictures are spread evenly over the cards in name order.
func _assign_stills() -> void:
	if _stills.is_empty() or _cards.is_empty():
		return
	var pinned := false
	for c in _cards:
		if String(c.get("image", "")) != "":
			pinned = true
	if pinned:
		var cur := String(_stills[0])
		for c in _cards:
			if String(c.get("image", "")) != "":
				cur = String(c["image"])
			c["image"] = cur
		return
	var n := _cards.size()
	for i in n:
		_cards[i]["image"] = String(_stills[mini(int(float(i) * _stills.size() / n), _stills.size() - 1)])


static func _load_still(name: String) -> Texture2D:
	var path := STILLS_DIR + "/" + name
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t
	if FileAccess.file_exists(path):      # dropped in but not yet imported by the editor
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	push_warning("EndCredits: can't load still " + path)
	return null


## Crossfade to a still (if it isn't already up) and start it drifting for about `hold` seconds -
## longer than it will be up, so the movement never stops on screen.
func _show_still(name: String, instant: bool, hold: float = 0.0) -> void:
	if name == "" or name == _still_now:
		return
	var tex := _load_still(name)
	if tex == null:
		return
	_still_now = name
	var out: TextureRect = _still_rects[_still_front]
	_still_front = 1 - _still_front
	var into: TextureRect = _still_rects[_still_front]
	move_child(into, maxi(into.get_index(), out.get_index()))   # the new one fades in on top of the old
	into.texture = tex
	into.pivot_offset = size * 0.5
	var reduce: bool = GameSettings.get("reduced_motion") == true
	# alternate the drift direction so consecutive stills don't all slide the same way
	var dir := Vector2(1, -0.5) if _still_front == 0 else Vector2(-1, 0.4)
	var span := hold * float(_count_cards_with(name)) + STILL_FADE * 2.0 + 4.0
	into.scale = Vector2.ONE
	into.position = Vector2.ZERO
	if _still_tw != null and _still_tw.is_valid():
		_still_tw.kill()
	into.modulate.a = 1.0 if instant else 0.0
	_still_tw = create_tween().set_parallel(true)
	if not instant:
		_still_tw.tween_property(into, "modulate:a", 1.0, STILL_FADE).set_trans(Tween.TRANS_SINE)
		_still_tw.tween_property(out, "modulate:a", 0.0, STILL_FADE).set_delay(STILL_FADE * 0.5)
	if not reduce:
		_still_tw.tween_property(into, "scale", Vector2.ONE * (1.0 + DRIFT_ZOOM), span) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_still_tw.tween_property(into, "position", dir * size.x * DRIFT_PAN, span) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _count_cards_with(name: String) -> int:
	var n := 0
	for c in _cards:
		if String(c.get("image", "")) == name:
			n += 1
	return maxi(n, 1)
