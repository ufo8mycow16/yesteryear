extends Control
const Glyph := preload("res://core/ui/ButtonGlyph.gd")   # REV 160: controller button pictures
## HUD — built procedurally so the node tree always matches this script
## exactly (no editor required to verify it). Layout follows the locked
## Game Systems Design HUD rules, reconfirmed in the Prologue document's own
## Systems Reconciliation:
##   bottom-left  = WHO (current speaker)
##   bottom-right = WHAT YOU HAVE / GAME FUNCTIONS (inventory, mission log,
##                  collection, system)
##   top-right    = circular minimap
##   contextual world prompt = WHAT YOU CAN DO (replaces any permanent
##                  objective tracker; objective changes are fading-only)
##
## All placeholder visuals here (ColorRects standing in for icons/minimap)
## are tagged PLACEHOLDER and are swap-in targets only — nothing downstream
## references their visuals, only their node names/signals.
##
## WHO is the character the PLAYER is currently controlling (McCoy, for the
## whole Prologue; in story rooms whoever fills the controlled slot - REV 293,
## see _refresh_who) — it is never touched by dialogue playback.
## It is a different thing from "who is talking right now," which gets its
## own small speaker tag above the subtitle instead. An earlier version of
## this file wrongly conflated the two (WHO got overwritten with "Kirk" or
## "Spock" the moment either NPC had a line), which misleadingly implied the
## player was now controlling that character.

const NOTIFICATION_DISPLAY_SECONDS := 2.5
const CLUE_NOTICE_SECONDS := 2.2      # REV 160: a clue card stays at least this long, even with others queued
const NOTIFICATION_FADE_SECONDS := 0.6

var who_label: Label
var speaker_label: Label
var subtitle_label: Label
var target_prompt: PanelContainer
var target_name_label: Label
var notification_label: Label
var function_bank: HBoxContainer
var verb_menu: VerbMenu
var topic_list_ui: TopicListUI
var inventory_ui: InventoryEquipmentUI
var settings_ui: SettingsUI
var mission_log_ui: MissionLogUI
var history_ui: DialogueHistoryUI
var collection_ui: CollectionUI
var examine_view: ExamineView
var map_ui: FullMapScreen

var _modal_dim: ColorRect
var _who_card: PanelContainer
var _function_rail: PanelContainer
var _minimap_frame: Control
## REV 144: the room label under the minimap (was always "Recreation Deck"); see GameNames.
var _room_tag: Label
var _room_scene: Node = null
var _target_text_tween: Tween
var _hud_cutscene_locked: bool = false
var _modal_was_open: bool = false
## True for the duration of a conversation — used only to keep the world
## target prompt ("F Captain Kirk") off-screen while the dialogue topic
## list already shows who's being talked to; doesn't touch interaction
## locking, which DialogueManager/InteractionManager already handle on
## their own.
var _conversation_active: bool = false
# label_text -> Button, built in _build_function_bank, so modal open/close
# can brighten/dim the matching button without rebuilding the whole bank.
var _function_buttons: Dictionary = {}


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The three modal panels are INSTANCED here (so inventory_ui/settings_ui/
	# mission_log_ui exist and _build_function_bank below can connect their
	# .toggle methods) but deliberately NOT add_child()'ed yet — that's what
	# caused the "Invalid access to property or key 'toggle' on a base
	# object of type 'Nil'" crash: a previous pass reordered _ready() to
	# build the function bank before these existed at all. Actually adding
	# them to the tree happens further down, after the function bank/
	# minimap, so draw order still puts the modal panels on top of the
	# persistent HUD without the bank needing them to exist that early.
	inventory_ui = InventoryEquipmentUI.new()
	settings_ui = SettingsUI.new()
	mission_log_ui = MissionLogUI.new()
	history_ui = DialogueHistoryUI.new()
	collection_ui = CollectionUI.new()
	examine_view = ExamineView.new()

	_build_subtitle_area()
	map_ui = FullMapScreen.new()   # made before the function bank, whose MAP button connects to it
	map_ui.name = "FullMapScreen"
	# REV 301 (Glen's pick, "Option D"): one console bar along the bottom replaces the WHO card and the
	# button rail (_build_who_card / _build_function_bank are kept below but no longer called)
	_build_console_bar()
	_apply_room_case_file.call_deferred()     # REV 475
	_build_focus_prompt()
	_build_minimap()
	_build_objective_tracker()     # REV 475
	_build_notification_banner()
	_build_held_badge()            # REV 521

	_build_modal_dim()
	add_child(inventory_ui)
	add_child(settings_ui)
	add_child(mission_log_ui)
	add_child(history_ui)
	add_child(collection_ui)
	add_child(map_ui)
	add_child(examine_view)
	_build_verb_menu()
	_build_topic_list()

	AudioSubtitleManager.subtitle_requested.connect(_on_subtitle_requested)
	AudioSubtitleManager.line_skipped.connect(_on_subtitle_skipped)
	InteractionManager.focus_changed.connect(_on_focus_changed)
	InteractionManager.held_source_changed.connect(_on_held_source_changed)
	InteractionManager.held_source_changed.connect(_set_item_cursor)   # REV 160 (item 32)
	InteractionManager.held_source_changed.connect(_refresh_held_badge)  # REV 521
	InputHints.device_changed.connect(func(_pad: bool) -> void: _refresh_held_badge(InteractionManager.get_held_source()))
	# REV 149: the radial menu shows the name itself, so the bottom prompt steps aside while it's open
	InteractionManager.verb_menu_opened.connect(_on_verb_menu_opened)
	InteractionManager.verb_menu_closed.connect(_on_held_source_changed.bind(""))
	MissionLog.notification_requested.connect(_on_notification_requested)
	ObjectiveManager.notification_requested.connect(_on_notification_requested)
	ObjectiveManager.objective_changed.connect(func(o): _last_objective_text = String(o.text) if o != null else "")
	ObjectiveManager.objective_changed.connect(_on_tracker_objective)            # REV 475
	ObjectiveManager.objective_completed.connect(_on_tracker_completed)
	ObjectiveManager.objective_cleared.connect(_on_tracker_cleared)
	DialogueManager.conversation_started.connect(_on_conversation_started)
	DialogueManager.conversation_ended.connect(_on_conversation_ended_hide_target_prompt)
	InteractionManager.lock_changed.connect(_on_lock_changed)
	CollectorCards.notification_requested.connect(_on_notification_requested)
	GameSettings.accessibility_changed.connect(_apply_accessibility)
	_apply_accessibility()
	# REV 105: the SYSTEM menu pauses the game, so this HUD's _process stops - dim the scene the
	# moment it opens; when it closes (and the game runs again) _process notices as usual
	add_to_group("hud")
	settings_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_ui.opened.connect(_sync_modal_state)
	settings_ui.closed.connect(_sync_modal_state)


## The mockup's function-bank buttons carry keybind labels ("LOG [L]",
## "SYSTEM [F10]") — those input actions (inventory_open, mission_log_open,
## system_menu_open) already existed in project.godot's input map but
## nothing actually read them; only clicking the buttons worked. Same class
## of gap as the buttons themselves originally being unwired.
func _unhandled_input(event: InputEvent) -> void:
	# REV 296: while a pad menu (ChoiceMenu, Case File...) is up and none of these panels is, its
	# shortcuts would open a panel the menu then steals the d-pad and A from. The system menu still opens.
	if PadNav.any_open(get_tree()) and not is_any_panel_open() and not event.is_action_pressed("system_menu_open"):
		return
	if event.is_action_pressed("inventory_open"):
		inventory_ui.toggle()
	elif event.is_action_pressed("mission_log_open"):
		mission_log_ui.toggle()
	elif event.is_action_pressed("system_menu_open"):
		if settings_ui.visible:
			settings_ui.toggle()
		else:
			open_pause_menu()
	elif event.is_action_pressed("dialogue_history_open"):
		history_ui.toggle()
	elif event.is_action_pressed("collection_open"):
		collection_ui.toggle()
	elif event.is_action_pressed("map_open"):
		if not (inventory_ui.visible or settings_ui.visible or mission_log_ui.visible or history_ui.visible or collection_ui.visible or examine_view.visible):
			map_ui.toggle()


## Polls rather than wiring an opened()/closed() signal into every panel:
## Inventory/Settings/MissionLog can each close themselves internally (ESC
## via their own _unhandled_input), so HUD can't always know the moment of
## closing any other way without adding a signal to all three. Visibility
## is cheap to check once a frame and is always correct.
func _process(_delta: float) -> void:
	_sync_modal_state()
	_refresh_function_bank_active_states()
	_refresh_room_tag()
	_refresh_who()      # REV 293
	_place_subtitle_box()
	_place_held_badge()       # REV 521
	_refresh_tracker_peek()   # REV 528


## REV 318: the subtitle box sits just above the console bar only while the bar is on screen; in
## conversations and cutscenes (bar hidden) it goes back down to the bottom of the screen.
func _place_subtitle_box() -> void:
	if _subtitle_box == null:
		return
	var bar_up := console_bar != null and console_bar.is_visible_in_tree() and console_bar.modulate.a > 0.5
	var lift: float = console_bar.shown_height() if bar_up else 0.0   # REV 319: follows the bar tucking away
	_subtitle_box.offset_top = -104 - lift
	_subtitle_box.offset_bottom = -20 - lift


## REV 144: whenever the current scene changes, ask it (via GameNames) what the room is called.
func _refresh_room_tag() -> void:
	if _room_tag == null:
		return
	var scene := get_tree().current_scene
	if scene == _room_scene:
		# REV 647: a map with several decks in it (the hangar map, Decks 15-19) names the one you're standing on -
		# asked again a few times a second as you walk between them
		# REV 707 (Glen: the label said Engineering in sickbay): a scene holding several rooms you walk between (Episode
		# 3's one-scene Deck 7) says so with room_label_live() - its name follows where you stand the same way
		var live := scene != null and ((scene.has_method("room_label_follows_level") and bool(scene.call("room_label_follows_level")))
				or (scene.has_method("room_label_live") and bool(scene.call("room_label_live"))))
		if live and Engine.get_process_frames() % 15 == 0:
			_room_tag.text = GameNames.room_of(scene)
		return
	_room_scene = scene
	_room_tag.text = GameNames.room_of(scene) if scene != null else ""


func _sync_modal_state() -> void:
	var modal_open := inventory_ui.visible or settings_ui.visible or mission_log_ui.visible or history_ui.visible or collection_ui.visible or examine_view.visible or map_ui.visible
	if modal_open != _modal_was_open:
		_modal_was_open = modal_open
		UITheme.fade_backdrop(_modal_dim, modal_open)
		InteractionManager.set_modal_suspended(modal_open)
		_suspend_hud_extras(modal_open)
	# a line paused mid-sentence waits under the pause menu, not on top of it
	_subtitle_layer.visible = not settings_ui.visible


## REV 144: a modal screen (Scoreboard Replay, inventory, map...) owns the screen. Everything else
## the HUD carries - the who card, minimap, prompts, notices and anything a scene adds to the HUD
## (like the bowling alley's "[C] CASE FILE" in the top-left corner, which used to print straight
## through the SCOREBOARD REPLAY title) is hidden while it is open, then put back exactly as it was.
## The function bank stays, because its buttons show which screen is open and switch between them.
func _suspend_hud_extras(suspend: bool) -> void:
	var keep: Array[Node] = [inventory_ui, settings_ui, mission_log_ui, history_ui, collection_ui,
		examine_view, map_ui, _modal_dim, _subtitle_layer, _function_rail, _held_badge]
	for child in get_children():
		if child in keep or not (child is CanvasItem):
			continue
		var item := child as CanvasItem
		if suspend:
			item.set_meta("_vf_modal_was_visible", item.visible)
			item.visible = false
		elif item.has_meta("_vf_modal_was_visible"):
			item.visible = bool(item.get_meta("_vf_modal_was_visible"))
			item.remove_meta("_vf_modal_was_visible")


## REV 105: the pause menu (Esc on the keyboard, the SYSTEM key, or Start on a pad).
func open_pause_menu() -> void:
	# REV 144: during a cinematic the HUD is hidden, so the menu inside it would open invisibly
	# (the game froze with nothing on screen). Show the PAUSED card instead.
	if not is_visible_in_tree():
		if get_tree().paused:
			return
		PausedCard.show_over(get_tree())
		get_viewport().set_input_as_handled()
		return
	if not settings_ui.visible:
		settings_ui.open()


func is_any_panel_open() -> bool:
	return inventory_ui.visible or settings_ui.visible or mission_log_ui.visible or history_ui.visible \
		or collection_ui.visible or examine_view.visible or map_ui.visible


func _refresh_function_bank_active_states() -> void:
	_set_function_button_active_if_changed("INVENTORY", inventory_ui.visible)
	_set_function_button_active_if_changed("LOG", mission_log_ui.visible)
	_set_function_button_active_if_changed("SYSTEM", settings_ui.visible)
	_set_function_button_active_if_changed("COLLECTION", collection_ui.visible)
	_set_function_button_active_if_changed("MAP", map_ui.visible)


func _set_function_button_active_if_changed(label_text: String, active: bool) -> void:
	var btn: Button = _function_buttons.get(label_text)
	if btn == null:
		return
	if console_bar != null:
		console_bar.set_key_active(label_text, active)     # REV 301
		return
	if btn.get_meta("active", false) == active:
		return
	btn.set_meta("active", active)
	UITheme.set_function_button_active(btn, active)


## Full-screen translucent black, built once and toggled visible/invisible —
## "retain enough transparency that the player still feels located in the
## scene" rather than a hard cut to black. Sits just above the persistent
## HUD and just below the modal panels in tree order.
func _build_modal_dim() -> void:
	_modal_dim = UITheme.make_blur_backdrop(UITheme.MODAL_DIM_ALPHA)   # REV 103: blurred, fades
	_modal_dim.name = "ModalDim"
	_modal_dim.process_mode = Node.PROCESS_MODE_ALWAYS   # REV 105: still fades in/out while paused
	add_child(_modal_dim)


## The dialogue subtitle box: speaker portrait on the left, the speaker's name
## in gold above the line of text, all in a bordered box along the bottom of
## the screen (it stops short of the function bank on the right). Shown only
## while a line is being spoken, and only when the Audio setting allows
## subtitles (SYSTEM > AUDIO).
const SUBTITLE_PORTRAIT_SIZE := Vector2(66, 66)
const PORTRAITS_DIR := "res://assets/portraits/"

var _subtitle_layer: CanvasLayer
var _subtitle_box: PanelContainer
var _subtitle_portrait_holder: Control
var _subtitle_serial: int = 0


func _build_subtitle_area() -> void:
	_subtitle_box = PanelContainer.new()
	_subtitle_box.name = "SubtitleBox"
	_subtitle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_box.anchor_left = 0.0
	_subtitle_box.anchor_right = 1.0
	_subtitle_box.anchor_top = 1.0
	_subtitle_box.anchor_bottom = 1.0
	_subtitle_box.offset_left = 20
	_subtitle_box.offset_right = -230
	_subtitle_box.offset_top = -104 - ConsoleBar.BAR_HEIGHT     # REV 301: above the console bar
	_subtitle_box.offset_bottom = -20 - ConsoleBar.BAR_HEIGHT
	var style := UITheme.dialogue_backing_stylebox()
	style.bg_color = Color(UITheme.PANEL_BG.r, UITheme.PANEL_BG.g, UITheme.PANEL_BG.b, 0.88)
	style.border_color = UITheme.GOLD
	style.set_border_width_all(2)
	style.set_content_margin_all(9)
	_subtitle_box.add_theme_stylebox_override("panel", style)
	_subtitle_box.visible = false
	# Its own canvas layer, so it still shows when cutscenes hide the rest of
	# the HUD (the opening banter and the Uhura call both do).
	_subtitle_layer = CanvasLayer.new()
	_subtitle_layer.name = "SubtitleLayer"
	_subtitle_layer.layer = 34    # REV 318: above a room's black fade (30), so lines over black can be read
	add_child(_subtitle_layer)
	_subtitle_layer.add_child(_subtitle_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_box.add_child(row)

	_subtitle_portrait_holder = Control.new()
	_subtitle_portrait_holder.custom_minimum_size = SUBTITLE_PORTRAIT_SIZE
	_subtitle_portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_portrait_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_subtitle_portrait_holder)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)

	speaker_label = Label.new()
	speaker_label.name = "SpeakerLabel"
	UITheme.style_title(speaker_label)
	speaker_label.add_theme_color_override("font_color", UITheme.GOLD)
	speaker_label.add_theme_font_size_override("font_size", 17)
	column.add_child(speaker_label)

	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	UITheme.style_body(subtitle_label)
	subtitle_label.add_theme_font_size_override("font_size", 15)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	column.add_child(subtitle_label)


## Accessibility settings that change how the HUD looks: subtitle text size and
## the high-contrast subtitle box. Runs at start-up and whenever one changes.
func _apply_accessibility() -> void:
	var big: int = GameSettings.subtitle_size
	subtitle_label.add_theme_font_size_override("font_size", GameSettings.subtitle_font_size())
	speaker_label.add_theme_font_size_override("font_size", 17 + 3 * big)
	var contrast: bool = GameSettings.high_contrast
	subtitle_label.add_theme_color_override("font_color", Color.WHITE if contrast else UITheme.TEXT_PRIMARY)
	_subtitle_box.grow_vertical = Control.GROW_DIRECTION_BEGIN   # a taller box grows upward
	var style := _subtitle_box.get_theme_stylebox("panel") as StyleBoxFlat
	var alpha: float = GameSettings.subtitle_background_alpha()
	if style != null:
		style.bg_color = Color(0, 0, 0, 1.0) if contrast else Color(UITheme.PANEL_BG.r, UITheme.PANEL_BG.g, UITheme.PANEL_BG.b, alpha)
		# REV 105: the border fades with the box, so NONE really is just text over the scene
		var edge: Color = Color.WHITE if contrast else UITheme.GOLD
		style.border_color = Color(edge.r, edge.g, edge.b, 1.0 if contrast else clampf(alpha / 0.88, 0.0, 1.0))
	# a dark outline keeps the words readable when the box is light or gone
	var outline: int = 0 if alpha >= 0.85 else (4 if alpha > 0.0 else 6)
	for l in [subtitle_label, speaker_label]:
		(l as Label).add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		(l as Label).add_theme_constant_override("outline_size", outline)
	speaker_label.visible = GameSettings.speaker_names
	_subtitle_portrait_holder.visible = GameSettings.speaker_names and speaker_label.text != ""
	if _subtitle_box.visible:
		_colour_speaker(speaker_label.text)


## REV 105: the speaker's name in their own colour (Settings > Accessibility > SPEAKER COLOURS).
func _colour_speaker(speaker: String) -> void:
	speaker_label.add_theme_color_override("font_color", GameSettings.speaker_colour(speaker, UITheme.GOLD))


## res://assets/portraits/<name>.png, trying the full display name first
## ("captain_kirk"), then its last word ("kirk"). No file is fine: the frame
## just shows empty.
func _portrait_for(speaker: String) -> Texture2D:
	var base := speaker.strip_edges().to_lower().replace(".", "")
	# REV 498: "Kirk (remembering)" (Episode 5's inner voice) uses Kirk's picture - drop a "(...)" note
	if base.contains("("):
		base = base.get_slice("(", 0).strip_edges()
	var candidates: Array[String] = [base.replace(" ", "_"), base.get_slice(" ", base.get_slice_count(" ") - 1)]
	for c in candidates:
		var path := PORTRAITS_DIR + c + ".png"
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _set_subtitle_portrait(speaker: String) -> void:
	for child in _subtitle_portrait_holder.get_children():
		child.queue_free()
	var portrait := PortraitFrame.new()
	_subtitle_portrait_holder.add_child(portrait)
	portrait.setup(_portrait_for(speaker), SUBTITLE_PORTRAIT_SIZE, UITheme.GOLD, 11.0, 2.0, 1.5, PORTRAIT_CROP, PORTRAIT_CROP_FOCUS_Y)


const MCCOY_PORTRAIT_PATH := "res://assets/portraits/mccoy.png"
const PORTRAIT_SIZE := Vector2(52, 52)
## Face matters more than torso at gameplay scale: keep ~80% of the source,
## window biased toward the top where the face sits.
const PORTRAIT_CROP := 0.8
const PORTRAIT_CROP_FOCUS_Y := 0.2
## 75% of PORTRAIT_SIZE's height, per Glen's spec — not used yet (see
## _build_who_card's comment) but sized here so a future party member
## portrait is a one-line addition, not a new size to invent. Color
## matches UITheme.ACCENT_SCIENCE_BLUE (duplicated as a literal rather
## than referenced, since a top-level const can't reliably fold a
## property read off another autoload at parse time).
const PARTY_PORTRAIT_SIZE := Vector2(39, 39)
const PARTY_BORDER_COLOR := Color(0.45, 0.62, 0.78)

## Bottom-left "WHO" area, upgraded from a bare text label to a small
## framed character card (KOTOR-II-inspired layout, not its look). McCoy is
## the only playable character in the Prologue, so the card is just his —
## no party strip, no implied character-switching (Kirk/Spock are NPCs,
## not party members, so they don't get a portrait here even though
## PortraitFrame already supports the smaller/blue-border treatment Glen
## specified for "other party members, if there are any" — wire that in
## only once there's an actual party roster to show). Deliberately no
## health/mana bar — Vulcan Fury has no stat system for one to represent,
## and a decorative bar would wrongly imply it does.
func _build_who_card() -> void:
	var card := PanelContainer.new()
	card.name = "WhoCard"
	UITheme.style_bezel(card)
	# Same reasoning as the function bank rail: style_bezel's default
	# stylebox has no content margin (the minimap bezel wants its map
	# flush to the ring), so widen this node's own override instance.
	var card_style: StyleBoxFlat = card.get_theme_stylebox("panel")
	card_style.set_content_margin_all(UITheme.SPACING_STD)
	card_style.content_margin_right = 6  # trim dead space right of the name
	card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	card.position = Vector2(20, -76)
	_who_card = card
	add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	card.add_child(row)

	var portrait := PortraitFrame.new()
	portrait.name = "McCoyPortrait"
	row.add_child(portrait)
	var portrait_texture: Texture2D = null
	if ResourceLoader.exists(MCCOY_PORTRAIT_PATH):
		portrait_texture = load(MCCOY_PORTRAIT_PATH)
	else:
		push_warning("HUD: McCoy portrait not found/imported at %s" % MCCOY_PORTRAIT_PATH)
	# McCoy is the active/main character, so gold — the same border
	# treatment the function bank and other panels use for "this is the
	# live/selected one," not a separate color scheme of its own.
	portrait.setup(portrait_texture, PORTRAIT_SIZE, UITheme.GOLD, 10.0, 2.0, 1.5, PORTRAIT_CROP, PORTRAIT_CROP_FOCUS_Y)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)

	var role_label := Label.new()
	role_label.text = "NOW PLAYING"
	UITheme.style_keybind(role_label)
	column.add_child(role_label)

	who_label = Label.new()
	who_label.name = "WhoLabel"
	# The player-controlled character. Never written to by dialogue/subtitle
	# code — see the class comment. REV 293: no longer a typed-in "McCoy" -
	# _refresh_who() fills it from GameNames for whoever is being played.
	who_label.text = GameNames.character(DEFAULT_LEAD)
	UITheme.style_title(who_label)
	column.add_child(who_label)


## REV 301: the bottom console bar (core/ui/hud/ConsoleBar.gd) - party portraits, PARTY / SOLO, quick
## items, the big CASE FILE key, the screen keys. who_label and the "McCoyPortrait" node live in it,
## so code that looked for them still finds them.
var console_bar: ConsoleBar


func _build_console_bar() -> void:
	console_bar = ConsoleBar.new()
	add_child(console_bar)
	who_label = console_bar.who_label
	_function_rail = console_bar        # fades with conversations/cutscenes, stays over modal screens
	_who_card = null                    # (the bar shows who you are; it isn't faded separately)
	for k in console_bar.buttons.keys():
		_function_buttons[k] = console_bar.buttons[k]
	console_bar.key_pressed.connect(_on_bar_key)


## REV 475: a room that has no Case File (the redesigned Prologue) says so with hud_case_file() -> false.
func _apply_room_case_file() -> void:
	var scene := get_tree().current_scene
	if console_bar != null and scene != null and scene.has_method("hud_case_file"):
		console_bar.set_case_file_visible(bool(scene.call("hud_case_file")))


func _on_bar_key(key_name: String) -> void:
	match key_name:
		"INVENTORY":
			inventory_ui.toggle()
		"LOG":
			mission_log_ui.toggle()
		"COLLECTION":
			collection_ui.toggle()
		"MAP":
			map_ui.toggle()
		"SYSTEM":
			if settings_ui.visible:
				settings_ui.toggle()
			else:
				open_pause_menu()
		"CASE FILE":
			# the scene opens its own Case File on this action (EpisodeRoom / the Prologue), exactly as if
			# the key or pad button had been pressed
			for pressed in [true, false]:
				var ev := InputEventAction.new()
				ev.action = "case_file_open"
				ev.pressed = pressed
				Input.parse_input_event(ev)


## REV 301: a hint is pointing at the Case File - make its key pulse so the eye finds it.
func pulse_case_file() -> void:
	if console_bar != null:
		console_bar.pulse(true)


## REV 301: rooms call this (call_group "hud") when the Case File opens - the new-clue count resets.
func case_file_opened() -> void:
	if console_bar != null:
		console_bar.case_file_opened()


## REV 293: who the player is controlling, for the NOW PLAYING card. Story rooms (EpisodeRoom) know
## it: their lead(current) is the person in the controlled slot (Episode 2 puts Spock or Chapel
## there). Any other scene may answer hud_lead_id(); everything else (the Prologue, viewers) is McCoy.
const DEFAULT_LEAD := "mccoy"
var _who_id := ""


func _current_lead_id() -> String:
	var scene := get_tree().current_scene
	if scene != null:
		if scene.has_method("hud_lead_id"):
			var own := String(scene.call("hud_lead_id"))
			if own != "":
				return own
		if scene.has_method("lead") and "current" in scene:
			var slot := String(scene.get("current"))
			if slot != "":
				return String(scene.call("lead", slot))
	return DEFAULT_LEAD


## Keeps the card's name (rank + surname, from GameNames - Glen's rule) and portrait on the person
## being played. Cheap enough to run every frame: it only rebuilds the portrait when that person changes.
func _refresh_who() -> void:
	if who_label == null or console_bar != null:     # REV 301: the console bar keeps itself up to date
		return
	var id := _current_lead_id()
	var shown := GameNames.character(id)
	if who_label.text != shown:
		who_label.text = shown
	if id == _who_id:
		return
	_who_id = id
	var frame := find_child("McCoyPortrait", true, false)   # (the node keeps its old name: EpisodeRoom looks for it)
	if frame == null:
		return
	var path := PORTRAITS_DIR + id + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	for child in frame.get_children():
		child.queue_free()
	# no picture for this person: an empty frame rather than somebody else's face
	frame.call("setup", tex, PORTRAIT_SIZE, UITheme.GOLD, 10.0, 2.0, 1.5, PORTRAIT_CROP, PORTRAIT_CROP_FOCUS_Y)


## World target identification ("Bowling Lane", "Captain Kirk") — replaces
## the old plain "[F] <name>" debug-style label with a small key-chip plus
## a properly-weighted name, on a subtle backing rather than bare text
## floating over the world. Content/positioning only; which hotspot is
## focused and when still comes entirely from InteractionManager — this
## pass doesn't touch what's interactable or when.
func _build_focus_prompt() -> void:
	target_prompt = PanelContainer.new()
	target_prompt.name = "TargetPrompt"
	UITheme.style_target_prompt(target_prompt)
	# Explicit anchors + offsets (NOT `position`): position is parent-relative,
	# so assigning it on an anchored control at runtime put the card at the
	# screen's left edge. Offsets are relative to the anchor, which is what's
	# wanted here (bottom-centre).
	target_prompt.anchor_left = 0.5
	target_prompt.anchor_right = 0.5
	target_prompt.anchor_top = 1.0
	target_prompt.anchor_bottom = 1.0
	target_prompt.offset_left = -90.0
	target_prompt.offset_right = 90.0
	target_prompt.offset_top = -68.0 - ConsoleBar.BAR_HEIGHT     # REV 301: above the console bar
	target_prompt.offset_bottom = -40.0 - ConsoleBar.BAR_HEIGHT
	target_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_prompt.visible = false
	target_prompt.modulate.a = 0.0
	add_child(target_prompt)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	target_prompt.add_child(row)

	# Small bordered "keycap" instead of a bracketed "[F]" inline with the
	# name — same information, presented like an actual key hint rather
	# than debug-print punctuation.
	var key_chip := PanelContainer.new()
	key_chip.name = "KeyChip"
	key_chip.custom_minimum_size = Vector2(18, 18)
	UITheme.style_bezel(key_chip)
	row.add_child(key_chip)

	var key_label := Label.new()
	key_label.text = "F"
	InputHints.bind(key_label, "=interact")   # REV 103: the real key, or the pad's button
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.style_heading(key_label)
	key_chip.add_child(key_label)

	# REV 160 (item 17): on a gamepad, the button's own picture instead of the key cap
	var glyph := Glyph.make("interact", 22.0, true)
	glyph.name = "PadGlyph"
	row.add_child(glyph)
	row.move_child(glyph, key_chip.get_index())
	var sync_chip := func(_g: bool = false) -> void:
		key_chip.visible = not InputHints.using_gamepad
	InputHints.device_changed.connect(sync_chip)
	sync_chip.call()

	target_name_label = Label.new()
	target_name_label.name = "TargetNameLabel"
	UITheme.style_heading(target_name_label)
	row.add_child(target_name_label)


## INVENTORY / LOG / COLLECTION / SYSTEM as "one unified instrument bank,
## not four unrelated buttons" (art direction point 4): a single bordered
## rail (UITheme.style_bezel) behind all four, each button built via
## UITheme.style_function_button so its keybind is a smaller, subordinate
## second line rather than appended to the same string/size as the label.
func _build_function_bank() -> void:
	var rail := PanelContainer.new()
	rail.name = "FunctionBankRail"
	UITheme.style_bezel(rail)
	# style_bezel's stylebox has no content margin by default (the minimap
	# bezel wants its map flush to the ring) — this rail wants breathing
	# room around its buttons, so widen the margin on this node's own
	# override instance rather than changing bezel_stylebox()'s default.
	var rail_style: StyleBoxFlat = rail.get_theme_stylebox("panel")
	rail_style.set_content_margin_all(16)
	_function_rail = rail
	add_child(rail)

	function_bank = HBoxContainer.new()
	function_bank.name = "GameFunctionsBank"
	function_bank.add_theme_constant_override("separation", 6)
	rail.add_child(function_bank)

	# Keybind suffix only shown for buttons that actually have a working
	# shortcut behind them (see _unhandled_input above). REV 293: every one
	# does now - COLLECTION opens CollectionUI and its key is collection_open
	# (K). Labeling a button with a keybind that doesn't do anything would be
	# a subtler version of the original "decorative button" bug.
	var labels_and_keys := {
		"INVENTORY": "[I]",
		"LOG": "[L]",
		"COLLECTION": "[K]",
		"MAP": "[M]",
		"SYSTEM": "[F10]",
	}
	# REV 103: the shown key follows rebinding and the device in use
	var label_actions := {"INVENTORY": "{inventory_open}", "LOG": "{mission_log_open}",
		"COLLECTION": "{collection_open}", "MAP": "{map_open}", "SYSTEM": "{system_menu_open}"}
	for label_text in labels_and_keys.keys():
		var btn := Button.new()
		var key_suffix: String = labels_and_keys[label_text]
		btn.name = label_text.capitalize().replace(" ", "") + "Button"
		btn.custom_minimum_size = Vector2(78, 36)
		# REV 43: a clicked button must not keep keyboard focus, or Enter / Space later presses it again
		# (Enter in the prop editor was opening the mission log).
		btn.focus_mode = Control.FOCUS_NONE
		UITheme.style_function_button(btn, label_text, key_suffix, false)
		var kb := btn.find_child("KeybindLabel", true, false) as Label
		if kb != null and label_actions.has(label_text):
			InputHints.bind(kb, String(label_actions[label_text]))
		function_bank.add_child(btn)
		_function_buttons[label_text] = btn
		if label_text == "INVENTORY":
			# This was the actual bug: four buttons were built here and NONE
			# of them had a .pressed connection — clicking any of them did
			# literally nothing. Every button is wired now (below), COLLECTION
			# and MAP included.
			btn.pressed.connect(inventory_ui.toggle)
		elif label_text == "SYSTEM":
			btn.pressed.connect(settings_ui.toggle)
		elif label_text == "LOG":
			btn.pressed.connect(mission_log_ui.toggle)
		elif label_text == "COLLECTION":
			btn.pressed.connect(collection_ui.toggle)
		elif label_text == "MAP":
			btn.pressed.connect(map_ui.toggle)

	# Sized from its own content rather than a guessed fixed width — the
	# previous fixed 260px box was narrower than 4 buttons' actual minimum
	# width, so SYSTEM overflowed past the container and got clipped by the
	# viewport edge. Anchored fully to the bottom-right corner (1,1,1,1) so
	# the margin below holds at any window size, including on resize.
	var content_size: Vector2 = function_bank.get_combined_minimum_size() + Vector2(32, 32)
	var margin := 24.0
	rail.anchor_left = 1.0
	rail.anchor_right = 1.0
	rail.anchor_top = 1.0
	rail.anchor_bottom = 1.0
	rail.offset_right = -margin
	rail.offset_left = -margin - content_size.x
	rail.offset_bottom = -margin
	rail.offset_top = -margin - content_size.y


## Circular ring+bezel per the art direction ("final minimap should be
## circular... no giant rectangular modern minimap card") — see
## CircularMinimapFrame.gd for the actual drawing. Content inside remains
## explicitly placeholder until real level geometry exists to map.
func _build_minimap() -> void:
	var frame := CircularMinimapFrame.new()
	frame.name = "MinimapFrame"
	frame.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	frame.position = Vector2(-112, 16)
	frame.size = Vector2(96, 96)
	_minimap_frame = frame
	add_child(frame)

	# Wider than the frame and right-aligned to its right edge, so the text
	# can't run off the screen edge (the frame sits right against it) —
	# the previous 64px-wide label was narrower than "(placeholder)".
	# REV 749 (Glen's list, "maybe later": the room name under the minimap was cut off) - the round frame clips
	# what's inside it, so the name hangs off the HUD itself now, right-aligned under the frame, wide enough for
	# "Deck 7 - Transporter Room 1"
	var tag := Label.new()
	tag.text = ""   # REV 144: filled in from the current room (_refresh_room_tag)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tag.offset_left = -376.0
	tag.offset_right = -16.0
	tag.offset_top = 116.0
	tag.offset_bottom = 136.0
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_hint(tag)
	add_child(tag)
	_room_tag = tag


# =========================================================================
# REV 475: the mission tracker (Glen: "World of Warcraft style, except for the fetch quests") - one
# line under the minimap saying what to do now, in plain words. A new objective slides in; a finished
# one gets a green tick and fades. Hidden in conversations and cutscenes like the minimap. The full
# list stays in the Mission Log (L).
# REV 528 (Tiffany's review, Glen agreed): orientation, not a checklist sitting over the game. The line
# slides in when the goal CHANGES, stays TRACKER_PEEK_SECONDS, then fades. It comes back while the
# "highlight_hotspots" key is held (H / the pad's Back - the same "what can I do here?" button that lights
# the hotspots), and by itself when the player is stuck (EpisodeRoom._stuck_nudge -> peek_tracker). A
# checklist with unticked items (the Arena's multi-part puzzle) keeps it up while it lasts.
# =========================================================================
const TRACKER_PEEK_SECONDS := 6.0
var _tracker_peek_until := 0
var _tracker_showing := false
var _tracker: PanelContainer
var _tracker_text: Label
var _tracker_tick: Label
var _tracker_has_text := false
var _tracker_done_tween: Tween
var _tracker_next: Label


func _build_objective_tracker() -> void:
	_tracker = PanelContainer.new()
	_tracker.name = "ObjectiveTracker"
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.border_color = Color(UITheme.GOLD_DIM, 0.7)
	sb.border_width_right = 3
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 6.0
	_tracker.add_theme_stylebox_override("panel", sb)
	_tracker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tracker.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tracker.offset_top = 140.0
	_tracker.offset_right = -16.0
	_tracker.offset_left = -16.0
	_tracker.modulate.a = 0.0
	_tracker.visible = false
	add_child(_tracker)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 1)
	_tracker.add_child(col)
	var head := Label.new()
	head.text = "MISSION"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_heading(head)
	head.add_theme_font_size_override("font_size", 10)
	head.add_theme_color_override("font_color", Color(UITheme.GOLD, 0.75))
	col.add_child(head)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	_tracker_tick = Label.new()
	_tracker_tick.text = "\u2714"
	_tracker_tick.add_theme_color_override("font_color", Color(0.45, 0.95, 0.5))
	_tracker_tick.add_theme_font_size_override("font_size", 15)
	_tracker_tick.visible = false
	row.add_child(_tracker_tick)
	_tracker_text = Label.new()
	_tracker_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tracker_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tracker_text.custom_minimum_size = Vector2(0, 0)
	UITheme.style_body(_tracker_text)
	_tracker_text.add_theme_font_size_override("font_size", 15)
	row.add_child(_tracker_text)
	# REV 741 (Glen: the H box said only "CAPTURE ROMULAN INTRUDERS", not the next step): the room's current goal
	_tracker_next = Label.new()
	_tracker_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tracker_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_body(_tracker_next)
	_tracker_next.add_theme_font_size_override("font_size", 13)
	_tracker_next.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45, 0.95))
	_tracker_next.visible = false
	col.add_child(_tracker_next)
	_tracker_list = VBoxContainer.new()       # REV 523: an optional checklist under the line
	_tracker_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker_list.add_theme_constant_override("separation", 0)
	col.add_child(_tracker_list)
	var o := ObjectiveManager.get_current_objective()
	if o != null:
		_on_tracker_objective(o)


func _on_tracker_objective(o: ObjectiveData) -> void:
	if _tracker == null:
		return
	if o == null or String(o.text) == "":
		_on_tracker_cleared()
		return
	if _tracker_done_tween != null and _tracker_done_tween.is_valid():
		_tracker_done_tween.kill()
	var t := String(o.text).to_upper()
	_tracker_text.text = t
	for c in _tracker_list.get_children():      # REV 523: a new objective brings its own checklist
		_tracker_list.remove_child(c)
		c.queue_free()
	# one line where it fits, wrapping at about a third of the screen
	var w := minf(_tracker_text.get_theme_font("font").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 4.0, 380.0)
	_tracker_text.custom_minimum_size.x = w
	_tracker_tick.visible = false
	_tracker_text.modulate = Color.WHITE
	_tracker_has_text = true
	# anchored top-right: the right edge sits 16 px in, the panel grows leftward to fit the line
	var mw := _tracker.get_combined_minimum_size().x
	_tracker.offset_top = 140.0
	_tracker.offset_right = -16.0
	_tracker.offset_left = -16.0 - mw
	peek_tracker()     # REV 528: a new goal is shown for a few seconds, then fades
	if not GameSettings.reduced_motion:
		_tracker_text.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_tracker_text, "modulate:a", 1.0, 0.45)


## REV 528: show the mission line for a few seconds (a new goal, a finished one, or a stuck player).
func peek_tracker(seconds: float = TRACKER_PEEK_SECONDS) -> void:
	_tracker_peek_until = maxi(_tracker_peek_until, Time.get_ticks_msec() + int(seconds * 1000.0))
	_refresh_tracker_peek()


func _tracker_wanted() -> bool:
	if not _tracker_has_text:
		return false
	if Time.get_ticks_msec() < _tracker_peek_until:
		return true
	if InputMap.has_action("highlight_hotspots") and Input.is_action_pressed("highlight_hotspots"):
		return true
	return _tracker_checklist_open()


func _tracker_checklist_open() -> bool:
	if _tracker_list == null:
		return false
	for c in _tracker_list.get_children():
		if c is Label and not c.is_queued_for_deletion() and not (c as Label).text.begins_with("\u2714"):
			return true
	return false


func _refresh_tracker_peek() -> void:
	if _tracker == null:
		return
	var want := _tracker_wanted()
	if want and not _tracker_showing and _tracker_next != null:
		var room := get_tree().current_scene
		var goal := String(room.call("current_goal")) if room != null and room.has_method("current_goal") else ""
		_tracker_next.visible = goal != "" and goal.to_upper() != _tracker_text.text
		if _tracker_next.visible:
			_tracker_next.text = "NEXT: " + goal
			var w := minf(_tracker_next.get_theme_font("font").get_string_size(_tracker_next.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 4.0, 380.0)
			_tracker_next.custom_minimum_size.x = w
			_tracker.offset_left = -16.0 - _tracker.get_combined_minimum_size().x
	if want != _tracker_showing:
		_tracker_showing = want
		_update_hud_groups()


## REV 523: a checklist under the current objective - [[text, done], ...]. A room sets it right after the
## objective (a new objective clears it). Ticked lines go green; the rest dim gold. [] clears it.
var _tracker_list: VBoxContainer

func tracker_checklist(items: Array) -> void:
	if _tracker_list == null:
		return
	for c in _tracker_list.get_children():
		c.queue_free()
	for it in items:
		var done := bool(it[1]) if it.size() > 1 else false
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.text = ("\u2714  " if done else "\u25cb  ") + String(it[0]).to_upper()
		UITheme.style_body(l)
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6) if done else Color(UITheme.GOLD, 0.9))
		_tracker_list.add_child(l)
	_refit_tracker.call_deferred()
	peek_tracker()     # REV 528: a changed checklist is worth a look


func _refit_tracker() -> void:
	if _tracker == null:
		return
	var mw := _tracker.get_combined_minimum_size().x
	_tracker.offset_left = -16.0 - mw


func _on_tracker_completed(_o: ObjectiveData) -> void:
	if _tracker == null or not _tracker_has_text:
		return
	_tracker_tick.visible = true
	_tracker_text.modulate = Color(0.7, 1.0, 0.72)
	peek_tracker(3.5)     # REV 528: let the tick be seen
	# a new objective normally follows within a moment; if not, the ticked one fades out
	_tracker_done_tween = create_tween()
	_tracker_done_tween.tween_interval(3.0)
	_tracker_done_tween.tween_callback(_on_tracker_cleared)


func _on_tracker_cleared() -> void:
	_tracker_has_text = false
	_update_hud_groups()


func _build_notification_banner() -> void:
	# REV 103: a small gold-edged card at the top centre (header + text), see _on_notification_requested.
	_notice_panel = PanelContainer.new()
	_notice_panel.name = "NotificationBanner"
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UITheme.panel_stylebox(UITheme.GOLD_DIM)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 9.0
	_notice_panel.add_theme_stylebox_override("panel", sb)
	_notice_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice_panel.modulate.a = 0.0
	add_child(_notice_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_panel.add_child(box)
	_notice_head = Label.new()
	_notice_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_heading(_notice_head)
	_notice_head.add_theme_font_size_override("font_size", 13)
	box.add_child(_notice_head)
	_notice_body = Label.new()
	_notice_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_body(_notice_body)
	_notice_body.add_theme_font_size_override("font_size", 13)
	box.add_child(_notice_body)
	_notice_foot = Label.new()
	_notice_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_heading(_notice_foot)
	_notice_foot.add_theme_font_size_override("font_size", 10)
	_notice_foot.add_theme_color_override("font_color", Color(UITheme.GOLD, 0.8))
	_notice_foot.visible = false
	box.add_child(_notice_foot)
	# kept for anything that still looks for the old label; never shown
	notification_label = Label.new()
	notification_label.visible = false
	add_child(notification_label)


func _build_verb_menu() -> void:
	verb_menu = VerbMenu.new()
	add_child(verb_menu)


func _build_topic_list() -> void:
	topic_list_ui = TopicListUI.new()
	add_child(topic_list_ui)


func _on_subtitle_requested(speaker: String, text: String, duration: float) -> void:
	# REV 296: with subtitles off only SPOKEN lines are hidden. Speakerless notes ("COMPARE
	# AVAILABLE", scan read-outs, "Switch to McCoy...") have no voice and are game information.
	if not GameSettings.wants_subtitles() and speaker != "":
		return
	if ConversationPresenter.letterboxed:
		_subtitle_box.visible = false   # REV 97: the letterbox's top bar shows conversation lines
		return
	_subtitle_serial += 1
	var my_serial := _subtitle_serial
	speaker_label.text = speaker
	_colour_speaker(speaker)
	subtitle_label.text = text
	if GameSettings.speaker_names:
		_set_subtitle_portrait(speaker)
	# REV 318: narration (no speaker) has no face - no empty portrait frame
	_subtitle_portrait_holder.visible = GameSettings.speaker_names and speaker != ""
	_subtitle_box.visible = true
	# The box takes the place of the bottom-left "NOW PLAYING" card while it is up.
	_fade_group_to(_who_card, 0.0)
	get_tree().create_timer(duration + 0.3, false).timeout.connect(func():   # (false: waits while paused)
		if my_serial == _subtitle_serial:
			_subtitle_box.visible = false
			_update_hud_groups()
	)


func _on_subtitle_skipped() -> void:
	_subtitle_serial += 1
	_subtitle_box.visible = false
	_update_hud_groups()


func _on_verb_menu_opened(_verbs: Array) -> void:
	if target_prompt.visible:
		UITheme.fade_out(target_prompt, UITheme.ANIM_SMALL, 0.0)


func _on_held_source_changed(_id: String) -> void:
	if not InteractionManager.is_modal_suspended() and not InteractionManager.is_locked():
		_on_focus_changed(InteractionManager.get_focus())


## REV 521 (docs/design/HELD_ITEM_INTERACTION.md): a HOLDING badge above the console bar, bottom right -
## the item's picture, its name and how to use it on this device. On a pad there is no pointer, so this
## is how you see what you're holding; with a mouse it backs up the item pointer.
var _held_badge: PanelContainer
var _held_icon: TextureRect
var _held_name: Label
var _held_hint: Label

func _build_held_badge() -> void:
	_held_badge = PanelContainer.new()
	_held_badge.name = "HeldBadge"
	_held_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_panel(_held_badge, UITheme.GOLD_BRIGHT)
	_held_badge.visible = false
	add_child(_held_badge)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_badge.add_child(row)
	_held_icon = TextureRect.new()
	_held_icon.custom_minimum_size = Vector2(52, 52)
	_held_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_held_icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var tag := Label.new()
	tag.text = "HOLDING"
	UITheme.style_keybind(tag)
	col.add_child(tag)
	_held_name = Label.new()
	UITheme.style_heading(_held_name)
	col.add_child(_held_name)
	_held_hint = Label.new()
	UITheme.style_hint(_held_hint)
	col.add_child(_held_hint)


func _refresh_held_badge(source_id: String) -> void:
	if _held_badge == null:
		return
	if source_id == "":
		return
	_held_icon.texture = InventoryEquipmentUI.icon_texture(source_id)
	_held_icon.visible = _held_icon.texture != null
	_held_name.text = InteractionManager.source_name(source_id).to_upper()
	if InputHints.using_gamepad:
		_held_hint.text = InputHints.fill("{interact} USE IT ON SOMETHING    {menu_cancel} PUT IT BACK")
	else:
		_held_hint.text = "CLICK: USE  -  RIGHT-CLICK: MORE  -  ESC: PUT BACK"
	_held_badge.reset_size()


func _place_held_badge() -> void:
	if _held_badge == null:
		return
	# shown whenever something is in hand and the world is in play (not under a screen or a cutscene)
	var want := InteractionManager.get_held_source() != "" and not InteractionManager.is_modal_suspended() \
			and not InteractionManager.is_locked()
	if _held_badge.visible != want:
		_held_badge.visible = want
	if not want:
		return
	var vp := get_viewport_rect().size
	var bar_up := console_bar != null and console_bar.is_visible_in_tree() and console_bar.modulate.a > 0.5
	var lift: float = console_bar.shown_height() if bar_up else 0.0
	var sz := _held_badge.get_combined_minimum_size()
	_held_badge.size = sz
	_held_badge.position = Vector2(vp.x - sz.x - 24.0, vp.y - lift - sz.y - 18.0)


## REV 160 (CLAUDE.md item 32): with an item in hand the mouse pointer IS that item (its backpack
## icon, small, with a thin gold ring so it reads as "holding"), as in the classic adventure games.
## Hands empty, or no icon for it: the normal pointer.
const ITEM_CURSOR_PX := 40
## REV 293 (docs/design/INTERACTION_MODEL.md: "offset so it doesn't hide the hotspot"): the item
## sits this many pixels down and to the right of the pointer's tip, and a small gold arrow tip marks
## the exact click point in the top-left corner, so you can always see what you are pointing at.
const ITEM_CURSOR_OFFSET := 14
## The little arrow at the click point: outer shape (dark edge) and inner shape (gold), in pixels.
const ITEM_CURSOR_TIP_OUTER := [Vector2(0, 0), Vector2(0, 14), Vector2(4, 10.5), Vector2(10, 10)]
const ITEM_CURSOR_TIP_INNER := [Vector2(1, 2.5), Vector2(1, 11.5), Vector2(4, 9), Vector2(7.5, 9)]

func _set_item_cursor(source_id: String) -> void:
	var tex: Texture2D = InventoryEquipmentUI.icon_texture(source_id) if source_id != "" else null
	if tex == null:
		Input.set_custom_mouse_cursor(null)
		return
	var img := tex.get_image()
	if img == null:
		Input.set_custom_mouse_cursor(null)
		return
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(ITEM_CURSOR_PX - 4, ITEM_CURSOR_PX - 4, Image.INTERPOLATE_LANCZOS)
	var full := ITEM_CURSOR_OFFSET + ITEM_CURSOR_PX     # the whole cursor picture (54 px: well under Godot's 256 limit)
	var canvas := Image.create(full, full, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var at := Vector2i(ITEM_CURSOR_OFFSET, ITEM_CURSOR_OFFSET)
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at + Vector2i(2, 2))
	# thin gold ring round the item
	var c := Vector2(at) + Vector2(ITEM_CURSOR_PX, ITEM_CURSOR_PX) * 0.5
	var r := ITEM_CURSOR_PX * 0.5 - 1.0
	for y in range(at.y, full):
		for x in range(at.x, full):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if absf(d - r) < 0.9:
				canvas.set_pixel(x, y, UITheme.GOLD)
	# the arrow tip: a dark edge so it reads on light walls, gold inside
	var outer := PackedVector2Array(ITEM_CURSOR_TIP_OUTER)
	var inner := PackedVector2Array(ITEM_CURSOR_TIP_INNER)
	for y in 16:
		for x in 12:
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, inner):
				canvas.set_pixel(x, y, UITheme.GOLD_BRIGHT)
			elif Geometry2D.is_point_in_polygon(p, outer):
				canvas.set_pixel(x, y, Color(0.05, 0.05, 0.06, 0.95))
	# the click point is the arrow's tip (top-left), so the item never covers what you point at
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(canvas), Input.CURSOR_ARROW, Vector2(0, 0))


## REV 160 (item 19): a tiny, quiet tick when something new becomes the target - the same for mouse,
## keyboard and pad. Never twice within FOCUS_TICK_GAP (sweeping across a row of things stays calm).
## REV 293: its loudness is set in ONE place, SfxManager.UI_SOUNDS["focus"] (the old FOCUS_TICK_DB
## here was never used, so it is gone).
const FOCUS_TICK_GAP := 0.15
var _last_focus: Hotspot = null
var _last_focus_tick := -1.0

func _on_focus_changed(hotspot: Hotspot) -> void:
	if hotspot != null and hotspot != _last_focus and not _conversation_active and not InteractionManager.is_locked():
		var t := Time.get_ticks_msec() / 1000.0
		if t - _last_focus_tick >= FOCUS_TICK_GAP:
			_last_focus_tick = t
			SfxManager.ui("focus")
	_last_focus = hotspot
	if hotspot == null or _conversation_active:
		if target_prompt.visible:
			UITheme.fade_out(target_prompt, UITheme.ANIM_MODAL, 6.0)
		return
	# REV 148: with an item in hand the prompt reads USE [ITEM] WITH [TARGET] (or SCAN [TARGET])
	var text := InteractionManager.held_action_text(hotspot.display_name)
	if target_prompt.visible and target_name_label.text != text:
		# Already showing another target: quick crossfade of the name only,
		# so the card stays put and nothing waits on the animation.
		_crossfade_target_text(text)
		return
	_set_target_text(text)
	UITheme.fade_in(target_prompt, UITheme.ANIM_MODAL, 6.0)


const TARGET_NAME_MAX_WIDTH := 460.0   # REV 148: room for USE [ITEM] WITH [TARGET]
const TARGET_CARD_BOTTOM_GAP := 40.0 + ConsoleBar.BAR_HEIGHT     # REV 301: above the console bar


## Sizes the card from its content (capped, ellipsis beyond the cap) and
## re-centres it, so long NPC/hotspot names neither clip nor overflow.
func _set_target_text(text: String) -> void:
	target_name_label.text = text
	var font: Font = target_name_label.get_theme_font("font")
	var font_size: int = target_name_label.get_theme_font_size("font_size")
	var natural: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	target_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	target_name_label.custom_minimum_size.x = minf(natural + 2.0, TARGET_NAME_MAX_WIDTH)
	var card_size: Vector2 = target_prompt.get_combined_minimum_size()
	target_prompt.offset_left = -card_size.x / 2.0
	target_prompt.offset_right = card_size.x / 2.0
	target_prompt.offset_top = -TARGET_CARD_BOTTOM_GAP - card_size.y
	target_prompt.offset_bottom = -TARGET_CARD_BOTTOM_GAP


func _crossfade_target_text(text: String) -> void:
	if _target_text_tween != null and _target_text_tween.is_valid():
		_target_text_tween.kill()
	_target_text_tween = create_tween()
	_target_text_tween.tween_property(target_name_label, "modulate:a", 0.0, UITheme.dur(UITheme.ANIM_SMALL * 0.5))
	_target_text_tween.tween_callback(_set_target_text.bind(text))
	_target_text_tween.tween_property(target_name_label, "modulate:a", 1.0, UITheme.dur(UITheme.ANIM_SMALL))


## "During conversation, suppress the normal bottom-centre world-target
## prompt" — plus (HUD state hierarchy) the function bank and minimap fade
## right back so the conversation UI is the dominant thing on screen. WHO
## stays: it reinforces which character the player is. Presentation only —
## locking is still DialogueManager's/InteractionManager's business.
func _on_conversation_started(_dialogue: DialogueData) -> void:
	_conversation_active = true
	if target_prompt.visible:
		UITheme.fade_out(target_prompt, UITheme.ANIM_MODAL, 6.0)
	_update_hud_groups()


func _on_conversation_ended_hide_target_prompt(_dialogue_id: String) -> void:
	_conversation_active = false
	_update_hud_groups()


func _on_lock_changed(locked: bool) -> void:
	_hud_cutscene_locked = locked
	_update_hud_groups()


## Cutscene: nonessential exploration HUD fades out entirely. Conversation:
## bank dims hard, minimap hides. Otherwise everything is fully present. Only
## modulate/visibility change — never any interaction/lock state.
func _update_hud_groups() -> void:
	var secondary_alpha := 1.0
	var who_alpha := 1.0
	var map_alpha := 1.0
	if _hud_cutscene_locked:
		secondary_alpha = 0.0
		who_alpha = 0.0
		map_alpha = 0.0
	elif _conversation_active:
		secondary_alpha = UITheme.HUD_DIMMED_ALPHA
		map_alpha = 0.0     # REV 153 (Glen): the minimap and room label hide in conversations (dimmed, they peeked out above the letterbox)
	if _subtitle_box != null and _subtitle_box.visible:
		who_alpha = 0.0     # REV 105: the subtitle box has that corner while a line is up
	_fade_group_to(_function_rail, secondary_alpha)
	_fade_group_to(_minimap_frame, map_alpha)
	_fade_group_to(_room_tag, map_alpha)     # REV 749: the room name is its own node now
	_fade_group_to(_tracker, map_alpha if (_tracker_has_text and _tracker_showing) else 0.0)     # REV 475 / 528: peeks
	_fade_group_to(_who_card, who_alpha)


func _fade_group_to(control: Control, alpha: float) -> void:
	if control == null:
		return
	var existing: Tween = control.get_meta("_hud_group_tween") if control.has_meta("_hud_group_tween") else null
	if existing != null and existing.is_valid():
		existing.kill()
	if alpha > 0.0:
		control.visible = true
	var tween := create_tween()
	control.set_meta("_hud_group_tween", tween)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", alpha, UITheme.dur(UITheme.ANIM_HUD))     # REV 301: Reduced Motion
	if alpha <= 0.0:
		tween.tween_callback(func(): control.visible = false)


## REV 103: notices queue (one at a time, never cut each other off) and say what happened:
##   "Case File Updated: X"  -> CASE FILE UPDATED / X           (clue sound)
##   "Objective Updated"     -> NEW OBJECTIVE / <the objective> (objective sound)
##   "Objective Complete"    -> OBJECTIVE COMPLETE              (objective sound)
##   "Mission Log Updated"   -> folded into a NEW OBJECTIVE that arrives with it
##   anything else           -> shown as it is                  (notify sound)
const NOTICE_MAX_QUEUE := 4
const NOTICE_WIDTH := 520.0
var _notice_panel: PanelContainer
var _notice_head: Label
var _notice_body: Label
var _notice_foot: Label    # REV 160: "EVIDENCE ADDED" under a clue
var _notice_queue: Array = []
var _notice_busy := false
var _last_objective_text := ""
static var _case_file_taught := false     # REV 215: once per session


func _on_notification_requested(message: String) -> void:
	var n := {"head": "", "body": message, "sound": "notify", "colour": UITheme.GOLD, "kind": "other"}
	if message.begins_with("Case File Updated"):
		n["head"] = "CASE FILE UPDATED"
		n["body"] = message.substr(message.find(":") + 1).strip_edges() if message.contains(":") else ""
		n["sound"] = "clue"
		n["kind"] = "clue"
		# REV 160 (item 24): a third line saying what kind of thing went into the Case File
		if Case.last_added_id != "" and Case.get_title(Case.last_added_id) == String(n["body"]):
			n["foot"] = Case.added_line(Case.last_added_id)
		# REV 215 (Nikki's playtest): the first clue of the session explains the Case File and shows
		# the button that opens it (pad or keyboard), and stays up longer. Later ones stay quiet.
		if not _case_file_taught:
			_case_file_taught = true
			var how := InputHints.fill("{case_file_open} OPEN CASE FILE")
			var teach := "Every clue you find is kept in your Case File."
			if how != "":
				teach += "   " + how
			n["foot"] = (String(n.get("foot", "")) + "\n" if n.get("foot", "") != "" else "") + teach
			n["hold"] = 6.5
			n["foot_size"] = 13
	elif message == "Objective Updated":
		n["head"] = "NEW OBJECTIVE"
		n["body"] = _last_objective_text
		n["sound"] = "objective"
		n["colour"] = UITheme.ACCENT_SCIENCE_BLUE
		n["kind"] = "objective"
	elif message == "Objective Complete":
		n["head"] = "OBJECTIVE COMPLETE"
		n["body"] = ""
		n["sound"] = "objective"
		n["colour"] = UITheme.ACCENT_SCIENCE_BLUE
		n["kind"] = "objective"
	elif message == "Mission Log Updated":
		n["head"] = "MISSION LOG UPDATED"
		n["body"] = ""
		n["kind"] = "log"
	# the same notice twice in a row (e.g. two clues with one name) shows once
	for q in _notice_queue:
		if q["head"] == n["head"] and q["body"] == n["body"]:
			return
	_notice_queue.append(n)
	while _notice_queue.size() > NOTICE_MAX_QUEUE:
		_notice_queue.remove_at(0)
	if not _notice_busy:
		_notice_busy = true   # set now: several notices in one moment must start only one display
		_show_next_notice.call_deferred()   # deferred: notices sent together are sorted out together


## After the layout pass (wrapped text now knows its real width): fit the card again.
func _refit_notice() -> void:
	_notice_body.size.x = _notice_body.custom_minimum_size.x
	_notice_panel.size = Vector2.ZERO
	_notice_panel.reset_size()
	var w := _notice_panel.get_combined_minimum_size().x
	_notice_panel.offset_left = -w * 0.5
	_notice_panel.offset_right = w * 0.5


func _show_next_notice() -> void:
	if _notice_queue.is_empty():
		_notice_busy = false
		return
	_notice_busy = true
	var n: Dictionary = _notice_queue.pop_front()
	# a Mission Log notice that comes with a new objective is the same news: show the objective
	if n["kind"] == "log":
		for q in _notice_queue:
			if q["kind"] == "objective":
				_show_next_notice()
				return
	_notice_head.text = String(n["head"])
	_notice_head.visible = n["head"] != ""
	_notice_head.add_theme_color_override("font_color", n["colour"])
	# REV 111: size the text box BEFORE giving it the text. A word-wrapping label briefly at width 0
	# measured one letter per line, and the card grew to the full height of the screen.
	var body_text := String(n["body"])
	var font: Font = _notice_body.get_theme_font("font")
	var fsize: int = _notice_body.get_theme_font_size("font_size")
	var natural := font.get_string_size(body_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x if font != null else 300.0
	_notice_body.custom_minimum_size.x = clampf(natural + 6.0, 220.0, NOTICE_WIDTH)
	# only wrap when it really doesn't fit on one line (a wrapping label measures its height from
	# its current width, which isn't laid out yet - one letter per line, a screen-tall card)
	_notice_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if natural + 6.0 > NOTICE_WIDTH else TextServer.AUTOWRAP_OFF
	_notice_body.text = body_text
	_notice_body.visible = body_text != ""
	_notice_foot.text = String(n.get("foot", ""))
	_notice_foot.add_theme_font_size_override("font_size", int(n.get("foot_size", 10)))
	_notice_foot.visible = _notice_foot.text != ""
	_notice_panel.size = Vector2.ZERO      # shrink to fit this notice, not the last one
	_notice_panel.reset_size()
	_refit_notice.call_deferred()
	var w := _notice_panel.get_combined_minimum_size().x
	_notice_panel.offset_left = -w * 0.5
	_notice_panel.offset_right = w * 0.5
	var snd := String(n["sound"])
	if SfxManager.UI_SOUNDS.has(snd):
		SfxManager.ui(snd)      # REV 168: clue / objective through the interface sound family
	else:
		SfxManager.play(snd if SfxManager.has_sound(snd) else "notify", -8.0)
	var hold := NOTIFICATION_DISPLAY_SECONDS if _notice_queue.is_empty() else 1.6
	if n["kind"] == "clue":
		hold = maxf(hold, CLUE_NOTICE_SECONDS)
	if n.has("hold"):
		hold = maxf(hold, float(n["hold"]))     # REV 215: the teaching card stays up longer
	# REV 301: Reduced Motion - the card simply appears in place (no slide, no fade in)
	var rm := GameSettings.reduced_motion
	_notice_panel.position.y = 28.0 if rm else 18.0
	_notice_panel.modulate.a = 1.0 if rm else 0.0
	var tw := create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_notice_panel, "modulate:a", 1.0, UITheme.dur(0.22))
	tw.tween_property(_notice_panel, "position:y", 28.0, UITheme.dur(0.28))
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(_notice_panel, "modulate:a", 0.0, UITheme.dur(NOTIFICATION_FADE_SECONDS))
	tw.chain().tween_callback(_show_next_notice)
