extends Control
class_name TopicListUI
## KOTOR/adventure-style topic list — plain data-driven topic states, not a
## full-sentence RPG menu. Shown while a conversation is active; keyboard/
## controller/mouse navigable; menu_cancel ends the conversation.
##
## Presentation pass (Glen, Oct 2026): conversations happen over the live
## 3D scene, so this is built to feel like a light cinematic overlay rather
## than a stack of boxed menu buttons — one subtle translucent backing
## region behind the whole list, choices separated mostly by spacing, and
## the selected choice carrying all the visual weight (warm-gold text + a
## narrow marker bar + a soft background wash) rather than every choice
## getting its own border. [End Conversation] is deliberately styled and
## spaced apart as a subordinate exit action, not a fifth topic.
##
## Topic/conversation LOGIC is unchanged from before this pass: still reads
## DialogueManager.topics_available/conversation_ended, still calls
## DialogueManager.select_topic()/end_conversation(), still the same
## keyboard nav actions. Only how each choice is drawn and how selection is
## communicated changed.
##
## Self is anchored full-rect (tracks the viewport) and the backing panel
## is sized from its own content and centered within that rect each time
## topics change — see the class comment history: a VBoxContainer anchored
## to a single point with no explicit size lays out into a zero-size box,
## so this computes real pixel size from content instead.

const SELECTION_TRANSITION_SECONDS := 0.13
const SELECTED_BG_ALPHA := 0.14
const ROW_MIN_WIDTH := 320.0
const TOPIC_FONT_SIZE := 15
const EXIT_FONT_SIZE := 11
const EXIT_COLOR := Color(0.58, 0.58, 0.56)        # == UITheme.TEXT_DIM
const EXIT_SELECTED_COLOR := Color(0.78, 0.72, 0.5) # muted warm, NOT full gold — stays subordinate even when focused

## One entry's live styling handles, kept so selection changes can restyle
## in place rather than rebuilding the list.
class _Row:
	var button: Button
	var label: Label
	var marker: ColorRect
	var highlight_style: StyleBoxFlat
	var is_exit: bool = false
	var tween: Tween


var _backing: PanelContainer
var _list: VBoxContainer
var _rows: Array[_Row] = []
var _selected_index: int = 0


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # pass-through; rows set their own filter
	add_to_group(PadNav.MENU_GROUP)

	_backing = PanelContainer.new()
	_backing.name = "ConversationBacking"
	UITheme.style_dialogue_backing(_backing)
	add_child(_backing)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_backing.add_child(_list)

	DialogueManager.topics_available.connect(_on_topics_available)
	DialogueManager.conversation_ended.connect(_on_conversation_ended)


func _on_topics_available(topics: Array) -> void:
	if ConversationPresenter.handles_topics():
		visible = false
		return   # REV 97: the letterbox shows the choices
	# Remove the old rows right away (queue_free alone leaves them in the list
	# until the frame ends, so the panel was being sized for the OLD rows too —
	# that was the empty space at the bottom).
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()

	for topic in topics:
		var topic_id: String = topic.id
		var row := _make_row(topic.label, TOPIC_FONT_SIZE, false)
		row.button.pressed.connect(func(): DialogueManager.select_topic(topic_id))
		_list.add_child(row.button)
		_rows.append(row)

	# A thin, dim divider plus extra breathing room ahead of it — "[End
	# Conversation] should be ... separated slightly from the topic list" —
	# rather than a bigger box, matching the rest of this list's "spacing/
	# fine separators, not heavy borders" treatment.
	if not topics.is_empty():
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 4)
		_list.add_child(gap)
		_list.add_child(UITheme.make_separator())

	var exit_row := _make_row("End Conversation", EXIT_FONT_SIZE, true)
	exit_row.button.pressed.connect(func():
		print("TopicListUI: [End Conversation] pressed (visible=%s)" % visible)
		DialogueManager.end_conversation()
	)
	_list.add_child(exit_row.button)
	_rows.append(exit_row)

	_center_backing()
	_selected_index = 0
	_refresh_all_rows(false)
	visible = true
	UITheme.fade_in(_backing, 0.15, 8.0)


## Builds one clickable row: a Button carrying the shared highlight
## stylebox (same StyleBoxFlat Resource on every one of its state slots —
## see the comment below on why) plus a marker bar and label layered on
## top as non-interactive children, same "children ignore mouse, the
## Button underneath handles it" technique UITheme.style_function_button
## uses for the HUD's function bank.
func _make_row(text: String, font_size: int, is_exit: bool) -> _Row:
	var row := _Row.new()
	row.is_exit = is_exit

	var btn := Button.new()
	btn.text = ""
	# Tall enough for the text, so the gold highlight covers the whole row.
	btn.custom_minimum_size = Vector2(ROW_MIN_WIDTH, font_size * 1.7 + 10.0)
	btn.focus_mode = Control.FOCUS_NONE     # REV 214: a focused row swallowed d-pad presses
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.0)
	highlight_style.set_corner_radius_all(2)
	highlight_style.content_margin_left = 16.0
	highlight_style.content_margin_right = 10.0
	highlight_style.content_margin_top = 5.0
	highlight_style.content_margin_bottom = 5.0
	# Deliberately the SAME stylebox Resource on all four state slots, not
	# four separate ones: Godot's own normal/hover/pressed/focus switching
	# becomes a no-op this way, and "selected" (driven by _selected_index,
	# kept in sync across keyboard, controller and mouse hover below) is
	# the only visual state that exists — exactly what "keyboard/
	# controller/mouse focus must all use the same visual selected state"
	# asks for, without fighting Godot's built-in per-state styling.
	btn.add_theme_stylebox_override("normal", highlight_style)
	btn.add_theme_stylebox_override("hover", highlight_style)
	btn.add_theme_stylebox_override("pressed", highlight_style)
	btn.add_theme_stylebox_override("focus", highlight_style)
	row.highlight_style = highlight_style

	var marker := ColorRect.new()
	marker.name = "Marker"
	marker.color = UITheme.GOLD
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Explicit anchors/offsets rather than a preset + position/size combo —
	# a narrow (2px) vertical bar pinned to the left edge, inset slightly
	# top/bottom so it doesn't touch the row's own edges.
	marker.anchor_left = 0.0
	marker.anchor_top = 0.0
	marker.anchor_right = 0.0
	marker.anchor_bottom = 1.0
	marker.offset_left = 2.0
	marker.offset_right = 4.0
	marker.offset_top = 4.0
	marker.offset_bottom = -4.0
	marker.modulate.a = 0.0
	btn.add_child(marker)

	var label := Label.new()
	label.name = "Text"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	if UITheme.font_regular != null:
		label.add_theme_font_override("font", UITheme.font_regular)
	label.add_theme_font_size_override("font_size", font_size)
	# font_color stays plain white; the actual on-screen color is
	# label.modulate (tweened below), since a Label's font_color theme
	# override isn't something create_tween() can animate smoothly the
	# way a plain Color property can — white * modulate == modulate.
	label.add_theme_color_override("font_color", Color.WHITE)
	label.modulate = EXIT_COLOR if is_exit else UITheme.TEXT_PRIMARY
	btn.add_child(label)

	row.button = btn
	row.label = label
	row.marker = marker

	var index := _rows.size()
	btn.mouse_entered.connect(func(): _select_index(index))

	return row


func _select_index(index: int) -> void:
	if index == _selected_index:
		return
	_selected_index = index
	_refresh_all_rows(true)


## Sizes the backing panel from its actual content (row count/size just
## changed) and centers it horizontally, pinned a fixed distance above the
## bottom of the screen — same positioning the plain-button version used.
func _center_backing() -> void:
	var content_size: Vector2 = _backing.get_combined_minimum_size()
	_backing.size = content_size
	# See VerbMenu._center_list() — get_viewport_rect().size, not self.size.
	var viewport_size: Vector2 = get_viewport_rect().size
	_backing.position = Vector2(
		(viewport_size.x - content_size.x) / 2.0,
		viewport_size.y - content_size.y - 180.0
	)


func _on_conversation_ended(_dialogue_id: String) -> void:
	print("TopicListUI: conversation_ended received for %s — hiding (was visible=%s)" % [_dialogue_id, visible])
	visible = false


## REV 214: while open, McCoy and the camera ignore the sticks.
func pad_menu_active() -> bool:
	return visible and not _rows.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _rows.is_empty():
		return

	var nav := PadNav.step(event)     # REV 214: d-pad, either stick, arrows
	if nav != 0:
		_selected_index = (_selected_index + nav + _rows.size()) % _rows.size()
		_refresh_all_rows(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		return
	elif PadNav.confirm(event):
		_rows[_selected_index].button.emit_signal("pressed")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_cancel"):
		DialogueManager.end_conversation()
		get_viewport().set_input_as_handled()


func _refresh_all_rows(animate: bool) -> void:
	for i in range(_rows.size()):
		_apply_row_visual(_rows[i], i == _selected_index, animate)


## The actual selected/unselected visual states. Unselected text stays
## clearly readable off-white (TEXT_PRIMARY) rather than a dimmed grey —
## "remain clearly readable," per the brief — with every bit of the
## selection weight going to the gold text + marker + soft wash instead.
## [End Conversation] uses its own, visibly-subordinate pair of colors
## (muted grey -> muted warm) rather than ever going full GOLD_BRIGHT, so
## it reads as an exit action even when it happens to be the focused row.
func _apply_row_visual(row: _Row, is_selected: bool, animate: bool) -> void:
	var target_bg_alpha := SELECTED_BG_ALPHA if is_selected else 0.0
	var target_marker_alpha := 1.0 if is_selected else 0.0
	var target_color: Color
	if row.is_exit:
		target_color = EXIT_SELECTED_COLOR if is_selected else EXIT_COLOR
	else:
		target_color = UITheme.GOLD_BRIGHT if is_selected else UITheme.TEXT_PRIMARY

	if row.tween != null and row.tween.is_valid():
		row.tween.kill()

	if not animate or GameSettings.reduced_motion:     # REV 297: Reduced Motion = instant highlight
		row.highlight_style.bg_color.a = target_bg_alpha
		row.marker.modulate.a = target_marker_alpha
		row.label.modulate = target_color
		return

	row.tween = create_tween()
	row.tween.set_parallel(true)
	row.tween.set_trans(Tween.TRANS_SINE)
	row.tween.tween_property(row.highlight_style, "bg_color:a", target_bg_alpha, SELECTION_TRANSITION_SECONDS)
	row.tween.tween_property(row.marker, "modulate:a", target_marker_alpha, SELECTION_TRANSITION_SECONDS)
	row.tween.tween_property(row.label, "modulate", target_color, SELECTION_TRANSITION_SECONDS)
