extends CanvasLayer
class_name PausedCard
## REV 144 (CLAUDE.md item 6): the pause screen for cinematics. During a scripted scene the HUD is
## hidden, so the normal pause menu (which lives inside the HUD) used to open invisibly: the game
## froze and nothing showed. Now a paused cinematic shows a simple centred card instead:
##
##        ─────────────────────
##               PAUSED
##        ─────────────────────
##        PRESS ESC TO CONTINUE
##
## Microgramma bold, thin gold hairlines like the dialogue bars. On a controller the bottom line
## names the pad's own button. Esc, the SYSTEM key or Start (and the pad's cancel button) resume.

const FADE := 0.14

var _root: Control
var _hint: Label
var _pad_row: HBoxContainer
var _paused_it := false


static func show_over(tree: SceneTree) -> PausedCard:
	var card := PausedCard.new()
	tree.root.add_child(card)
	return card


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if not get_tree().paused:
		get_tree().paused = true
		_paused_it = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, UITheme.dur(FADE))   # REV 297: instant with Reduced Motion
	SfxManager.ui("open", -2.0)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP     # nothing behind it gets clicked while paused
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(col)

	col.add_child(_hairline())

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme.font_bold != null:
		title.add_theme_font_override("font", UITheme.font_bold)
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 6)
	col.add_child(title)

	col.add_child(_hairline())

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme.font_bold != null:
		_hint.add_theme_font_override("font", UITheme.font_bold)
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 4)
	# REV 160 (item 17): on a gamepad the line reads PRESS (button picture) TO CONTINUE
	_pad_row = HBoxContainer.new()
	_pad_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pad_row.add_theme_constant_override("separation", 8)
	var press := _hint.duplicate() as Label
	press.text = "PRESS"
	var cont := _hint.duplicate() as Label
	cont.text = "TO CONTINUE"
	_pad_row.add_child(press)
	_pad_row.add_child(preload("res://core/ui/ButtonGlyph.gd").make("system_menu_open", 24.0))
	_pad_row.add_child(cont)
	col.add_child(_hint)
	col.add_child(_pad_row)
	_refresh_hint()


func _hairline() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(420, 1)
	line.color = UITheme.GOLD
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## "PRESS ESC TO CONTINUE", or the pad's own button name (e.g. "PRESS MENU TO CONTINUE").
func _refresh_hint() -> void:
	var button := "ESC"
	if InputHints.using_gamepad:
		var pad := InputHints.key("system_menu_open")
		if pad != "":
			button = pad
	_hint.text = "PRESS %s TO CONTINUE" % button
	# the picture version when the pad's button is known
	var pad_pic := InputHints.using_gamepad and InputHints.key("system_menu_open") != ""
	if _pad_row != null:
		_pad_row.visible = pad_pic
		_hint.visible = not pad_pic


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventKey:
		_refresh_hint.call_deferred()
	if event.is_echo():
		return
	if event.is_action_pressed("menu_cancel") or event.is_action_pressed("system_menu_open") \
			or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume()


func resume() -> void:
	if _paused_it and is_inside_tree():
		get_tree().paused = false
	_paused_it = false
	set_process_input(false)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, UITheme.dur(FADE))   # REV 297
	tw.tween_callback(queue_free)


func _exit_tree() -> void:
	# never leave the game frozen if the scene changes underneath the card
	if _paused_it and get_tree() != null:
		get_tree().paused = false
	_paused_it = false
