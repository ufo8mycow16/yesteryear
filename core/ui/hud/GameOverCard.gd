extends CanvasLayer
class_name GameOverCard
## REV 562 (Glen): "a game over. Condition, big letters in the middle of the screen, just like pause, and a
## button to return to the main menu." Same look as PausedCard - Microgramma bold, gold hairlines - with a
## reason line and a RETURN TO MAIN MENU button (mouse, Enter, or the pad's confirm button).

const MAIN_MENU := "res://core/menu/MainMenu.tscn"
const FADE := 0.6

var reason := ""
var _root: Control
var _button: Button


static func show_over(tree: SceneTree, why: String = "") -> GameOverCard:
	var card := GameOverCard.new()
	card.reason = why
	tree.root.add_child(card)
	return card


func _ready() -> void:
	layer = 121
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_custom_mouse_cursor(null)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, UITheme.dur(FADE))
	SfxManager.ui("open", -2.0)
	_button.grab_focus.call_deferred()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	centre.add_child(col)
	col.add_child(_hairline())
	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme.font_bold != null:
		title.add_theme_font_override("font", UITheme.font_bold)
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)
	col.add_child(_hairline())
	if reason != "":
		var why := Label.new()
		why.text = reason
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme.font_bold != null:
			why.add_theme_font_override("font", UITheme.font_bold)
		why.add_theme_font_size_override("font_size", 16)
		why.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
		why.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		why.add_theme_constant_override("outline_size", 4)
		col.add_child(why)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	col.add_child(gap)
	_button = Button.new()
	_button.text = "RETURN TO MAIN MENU"
	_button.custom_minimum_size = Vector2(320, 46)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if UITheme.font_bold != null:
		_button.add_theme_font_override("font", UITheme.font_bold)
	_button.add_theme_font_size_override("font_size", 16)
	var box := UITheme.panel_stylebox(UITheme.GOLD)
	_button.add_theme_stylebox_override("normal", box)
	var hot := UITheme.panel_stylebox(UITheme.GOLD_BRIGHT)
	_button.add_theme_stylebox_override("hover", hot)
	_button.add_theme_stylebox_override("focus", hot)
	_button.add_theme_stylebox_override("pressed", hot)
	_button.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	_button.add_theme_color_override("font_hover_color", UITheme.GOLD_BRIGHT)
	_button.add_theme_color_override("font_focus_color", UITheme.GOLD_BRIGHT)
	_button.pressed.connect(_to_menu)
	col.add_child(_button)


func _hairline() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(520, 1)
	line.color = UITheme.GOLD
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("ui_navigate_confirm"):
		get_viewport().set_input_as_handled()
		_to_menu()


func _to_menu() -> void:
	_button.disabled = true
	SfxManager.ui("confirm", -2.0)
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
	queue_free()
