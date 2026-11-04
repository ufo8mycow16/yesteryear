extends Control
class_name EndOfPrologueScreen
## The last card of the Prologue: the teaser for Episode One.
##
## This is what a player sees at the end of the free Prologue, so it is a
## "coming soon" card, not a stop sign. Two things to know:
##
##   TEASER_MODE  true  = release build: the card offers MAIN MENU only (Episode One
##                        itself is not in the teaser).
##                false = also offers CONTINUE TO EPISODE ONE for everyone.
##                In a debug build (running from the editor) the Continue button
##                is ALWAYS there, labelled [DEV], so you can keep testing Episode One.
##
##   RELEASE_DATES  the date shown under "COMING". With one entry it just shows
##                that date. With more, the card plays the running gag: each date
##                gets struck through and the next one takes its place, a sly nod
##                to the original game that was promised again and again.
##                Add or remove dates here, in order. Nothing else needs changing.

const TEASER_MODE := true
const RELEASE_DATES: Array = ["DECEMBER 2026"]
const STUDIO := "THIRD MOON INTERACTIVE"
const MAIN_MENU_SCENE := "res://core/menu/MainMenu.tscn"
const EPISODE_ONE_SCENE := "res://episodes/episode1/scenes/Ep1Opening.tscn"   # REV 227: the opening, then the beam-down

const GOLD := Color(0.95, 0.80, 0.35)
const DIM := Color(0.62, 0.64, 0.70)

var _vbox: VBoxContainer
var _date_label: RichTextLabel
var _leaving := false
var _born_ms: int = 0


func _ready() -> void:
	_born_ms = Time.get_ticks_msec()
	TitleSequence.preload_world()     # REV 229: Episode One opens in space - read the Enterprise now
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 10)
	_vbox.custom_minimum_size = Vector2(900, 0)
	add_child(_vbox)

	_add_label("THE SECRET OF VULCAN FURY", 44, GOLD)
	_add_label("EPISODE ONE", 16, DIM)
	_add_label("IN SHEEP'S CLOTHING", 30, Color.WHITE)
	_add_spacer(26)
	_add_label("COMING", 16, DIM)

	_date_label = RichTextLabel.new()
	_date_label.bbcode_enabled = true
	_date_label.fit_content = true
	_date_label.scroll_active = false
	_date_label.custom_minimum_size = Vector2(900, 46)
	_date_label.add_theme_font_size_override("normal_font_size", 32)
	_date_label.add_theme_font_size_override("bold_font_size", 32)
	_date_label.add_theme_color_override("default_color", GOLD)
	_vbox.add_child(_date_label)
	_show_date(0, -1)

	_add_spacer(26)
	_add_label(STUDIO, 14, DIM)
	_add_spacer(18)

	if TEASER_MODE:
		var menu_button := Button.new()
		menu_button.text = "MAIN MENU"
		menu_button.focus_mode = Control.FOCUS_ALL
		UITheme.style_button(menu_button, true)
		menu_button.pressed.connect(_go_to_main_menu)
		_vbox.add_child(menu_button)
		menu_button.grab_focus.call_deferred()
		if OS.is_debug_build():
			_vbox.add_child(_make_continue_button("[DEV] CONTINUE TO EPISODE ONE"))
	else:
		var go := _make_continue_button("CONTINUE TO EPISODE ONE")
		_vbox.add_child(go)
		go.grab_focus.call_deferred()

	# Same centering pattern as every other menu in this project.
	var content_size: Vector2 = _vbox.get_combined_minimum_size()
	_vbox.size = content_size
	var viewport_size: Vector2 = get_viewport_rect().size
	_vbox.position = (viewport_size - content_size) / 2.0

	# Fade the whole card in, then (if there is more than one date) run the gag.
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, UITheme.dur(2.0))   # REV 297: instant with Reduced Motion
	if RELEASE_DATES.size() > 1:
		_run_date_gag()


func _add_label(text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	_vbox.add_child(label)


func _add_spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	_vbox.add_child(spacer)


func _make_continue_button(text: String) -> Button:
	var go := Button.new()
	go.text = text
	go.focus_mode = Control.FOCUS_ALL
	UITheme.style_button(go, false)
	go.pressed.connect(_go_to_episode_one)
	return go


## Shows RELEASE_DATES[index]; every date before it (up to `struck`) is struck through.
func _show_date(index: int, struck: int) -> void:
	var text := ""
	for i in range(0, index + 1):
		var date_text: String = String(RELEASE_DATES[i])
		if i <= struck:
			text += "[s][color=#7a7a80]%s[/color][/s]\n" % date_text
		else:
			text += "[b]%s[/b]" % date_text
	_date_label.text = "[center]" + text + "[/center]"


func _run_date_gag() -> void:
	await get_tree().create_timer(3.5).timeout
	for i in range(1, RELEASE_DATES.size()):
		if _leaving:
			return
		_show_date(i, i - 1)
		await get_tree().create_timer(3.0).timeout


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if Time.get_ticks_msec() < _born_ms + 3000:
			return  # ignore an Enter pressed through the end of the titles
		if TEASER_MODE:
			_go_to_main_menu()
		else:
			_go_to_episode_one()


func _go_to_main_menu() -> void:
	if _leaving:
		return
	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		push_error("EndOfPrologueScreen: main menu scene missing: " + MAIN_MENU_SCENE)
		return
	_leaving = true
	get_tree().paused = false
	AudioSubtitleManager.stop_all()
	InteractionManager.reset_for_load()
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)


func _go_to_episode_one() -> void:
	if _leaving:
		return
	if not ResourceLoader.exists(EPISODE_ONE_SCENE):
		push_error("EndOfPrologueScreen: Episode One scene missing: " + EPISODE_ONE_SCENE)
		return
	_leaving = true
	get_tree().paused = false
	Ep1.new_game(true)     # REV 297: keep the Prologue's flags and crew (same people aboard, bowling remembered)
	AudioSubtitleManager.stop_all()
	InteractionManager.reset_for_load()
	get_tree().change_scene_to_file.call_deferred(EPISODE_ONE_SCENE)
