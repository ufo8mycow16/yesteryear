extends Control
class_name InventoryEquipmentUI
## "WHAT YOU HAVE" — the inventory screen, opened by the HUD's INVENTORY button
## or the inventory key. Laid out like a game backpack:
##
##   EQUIPMENT   McCoy's fixed gear (Tricorder, Communicator, ...) in a row of slots.
##   BACKPACK    a grid of slots. Items you pick up (the Bowling Ball, ...) fill it
##               in the order you found them; empty slots stay dark.
##
## Every slot shows a picture of the item. Rest the mouse on a slot (or move the
## cursor onto it with the keyboard / gamepad) and a tooltip shows its name,
## what kind of thing it is and a short description.
##
## REV 521: click a slot (or ENTER / A) to PICK IT UP - it becomes the pointer and the backpack stays
## open; click another item to COMBINE them there and then; click the held one to put it back; click
## outside (or B / Esc) to go and use it on the world. docs/design/HELD_ITEM_INTERACTION.md.
##
## Pictures: an item's own `icon` if it has one, otherwise
## res://assets/ui/icons/icon_<name>.png from the ICON_FILES table below, otherwise
## the "?" picture. To give a new item a picture, drop a PNG into assets/ui/icons
## and add its id to ICON_FILES.
##
## Equipment (EquipmentManager) and collected items (InventoryManager) stay two
## separate systems; this screen only displays and selects.
## REV 293: the EQUIPMENT row is the kit of whoever is being played - the same
## InteractionManager.kit_owner() that decides whether SCAN shows in the verb arc,
## so the two never disagree (McCoy's kit when the played person has none).
##
## REV 293: joins PadNav's "pad_menus" group, so while it's open the sticks steer the
## cursor instead of walking the player or turning the camera; the sticks move one
## slot per push.

const ICON_DIR := "res://assets/ui/icons/"
const ICON_FILES := {
	"EQUIP_MCCOY_TRICORDER": "icon_tricorder.png",
	"EQUIP_MCCOY_COMMUNICATOR": "icon_communicator.png",
	# REV 300: every lead's own kit (EquipmentManager.KITS) uses the same pictures
	"EQUIP_KIRK_TRICORDER": "icon_tricorder.png",
	"EQUIP_SPOCK_TRICORDER": "icon_tricorder.png",
	"EQUIP_CHAPEL_TRICORDER": "icon_tricorder.png",
	"EQUIP_KIRK_COMMUNICATOR": "icon_communicator.png",
	"EQUIP_SPOCK_COMMUNICATOR": "icon_communicator.png",
	"EQUIP_CHAPEL_COMMUNICATOR": "icon_communicator.png",
	"INV_PRO_001": "icon_bowling_ball.png",
	"INV_PRO_002": "icon_medkit.png",          # REV 475: McCoy's medical kit (tools/make_prologue_icons.py)
	"INV_PRO_003": "icon_rosin_empty.png",     # the alley's rosin bag, empty
	"INV_PRO_004": "icon_rosin_full.png",      # ... filled with antiseptic powder
	"EQUIP_PHASER": "icon_phaser.png",
	# REV 741 (Glen: "kyle's toolkit is the missing icon"): Episode 3's items (tools/make_ep3_icons.py - stand-ins,
	# Glen can drop his own pictures in under the same names)
	"EP3_ITEM_TOOLKIT": "icon_ep3_toolkit.png",
	"EP3_ITEM_INTERVAL": "icon_ep3_interval.png",
	"EP3_ITEM_LISTENER": "icon_ep3_listener.png",
	"EP3_ITEM_LISTENER_B": "icon_ep3_listener_dead.png",
	"EP3_ITEM_SANDWICH": "icon_ep3_sandwich.png",
	"EP3_ITEM_FORM": "icon_ep3_card.png",
	"EP3_ITEM_FORM_S": "icon_ep3_card.png",
	"EP3_ITEM_ISOLATOR": "icon_ep3_isolator.png",
	"EP3_ITEM_ISOLATOR_K": "icon_ep3_isolator.png",
	"EP3_ITEM_TRIBBLE": "icon_ep3_tribble.png",
	"EP3_ITEM_SPANNER": "icon_ep3_spanner.png",
	"EP3_ITEM_TIMESTAMP": "icon_ep3_timestamp.png",
	"EP3_ITEM_SHIELDED": "icon_tricorder.png",
	"EP3_ITEM_PATTERNS": "icon_ep3_patterns.png",
}
const UNKNOWN_ICON := "icon_unknown.png"

const SLOT_SIZE := 76.0
const SLOT_GAP := 6.0
const BAG_COLUMNS := 6
const BAG_ROWS := 4
const EQUIPMENT_SLOTS := 6

const HELD_COLOR := Color(1.0, 0.9, 0.4)
const TOOLTIP_WIDTH := 260.0

var _panel: PanelContainer
var _equipment_grid: GridContainer
var _bag_grid: GridContainer
var _close_button: Button
var _tooltip: PanelContainer
var _tooltip_name: Label
var _tooltip_kind: Label
var _tooltip_text: Label
var _tooltip_held: Label

## Filled slots you can move the cursor onto, in reading order. Each entry:
## {"button": Button, "id": String, "name": String, "kind": String, "description": String}
var _entries: Array[Dictionary] = []
var _selected_index: int = 0
var _icon_cache: Dictionary = {}


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	UITheme.style_panel(_panel)
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)

	var title := Label.new()
	title.text = "WHAT YOU HAVE"
	UITheme.style_title(title)
	outer.add_child(title)
	outer.add_child(UITheme.make_separator())

	var equip_heading := Label.new()
	equip_heading.text = "EQUIPMENT"
	UITheme.style_heading(equip_heading)
	outer.add_child(equip_heading)

	_equipment_grid = _make_grid(EQUIPMENT_SLOTS)
	outer.add_child(_equipment_grid)

	var bag_heading := Label.new()
	bag_heading.text = "BACKPACK"
	UITheme.style_heading(bag_heading)
	outer.add_child(bag_heading)

	_bag_grid = _make_grid(BAG_COLUMNS)
	outer.add_child(_bag_grid)

	outer.add_child(UITheme.make_separator())
	var bottom := HBoxContainer.new()
	outer.add_child(bottom)
	var hint := Label.new()
	_hint_label = hint
	_refresh_hint()      # REV 293: names the pad's buttons on a pad
	UITheme.style_dim(hint)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hint)
	_close_button = Button.new()
	_close_button.text = "CLOSE  [ESC]"
	InputHints.bind(_close_button, "CLOSE  {menu_cancel}")
	_close_button.custom_minimum_size = Vector2(150, 0)
	_close_button.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(_close_button)
	_close_button.pressed.connect(close)
	bottom.add_child(_close_button)

	_build_tooltip()
	InventoryManager.item_added.connect(_on_item_added)
	InventoryManager.item_removed.connect(func(_id: String) -> void:   # REV 293
		if visible:
			_rebuild()
			_update_selection_highlight())
	# REV 293: the sticks steer this screen, not the player or the camera, while it's open
	add_to_group(PadNav.MENU_GROUP)
	InputHints.device_changed.connect(func(_pad: bool) -> void:
		_refresh_hint()
		if visible:
			_show_tooltip_for(_selected_index))


## REV 293: while open, McCoy and the camera ignore the sticks (PadNav.any_open).
func pad_menu_active() -> bool:
	return _is_open


var _hint_label: Label

## REV 306: the name shown for an item or a piece of equipment.
func _name_of(id: String) -> String:
	for e in _entries:
		if String(e["id"]) == id:
			return String(e["name"])
	return id


## REV 293: the help line under the grids - mouse words with keyboard and mouse, the real buttons on a pad.
func _refresh_hint() -> void:
	if _hint_label == null:
		return
	if InputHints.using_gamepad:
		_hint_label.text = InputHints.fill("{ui_navigate_confirm} PICK UP  -  ON ANOTHER ITEM: COMBINE    {menu_cancel} BACK TO THE WORLD")
	else:
		_hint_label.text = "CLICK AN ITEM TO PICK IT UP  -  CLICK ANOTHER TO COMBINE  -  CLICK OUTSIDE TO USE IT"


## REV 293: "CLICK" with the mouse, the confirm button ("[A]") on a pad - for the tooltip's last line.
func _choose_word() -> String:
	if InputHints.using_gamepad:
		var h := InputHints.hint("ui_navigate_confirm")
		if h == "":
			h = InputHints.hint("interact")
		return h if h != "" else "SELECT"
	return "CLICK"


func _make_grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", int(SLOT_GAP))
	grid.add_theme_constant_override("v_separation", int(SLOT_GAP))
	return grid


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	_tooltip.z_index = 10
	UITheme.style_panel(_tooltip, UITheme.GOLD_BRIGHT)   # REV 297: registered, so High Contrast restyles it live
	add_child(_tooltip)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(box)

	_tooltip_name = Label.new()
	UITheme.style_heading(_tooltip_name)
	_tooltip_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_name.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 24.0, 0)
	box.add_child(_tooltip_name)

	_tooltip_kind = Label.new()
	UITheme.style_dim(_tooltip_kind)
	box.add_child(_tooltip_kind)

	_tooltip_text = Label.new()
	UITheme.style_body(_tooltip_text)
	_tooltip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_text.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 24.0, 0)
	box.add_child(_tooltip_text)

	_tooltip_held = Label.new()
	UITheme.style_hint(_tooltip_held)
	box.add_child(_tooltip_held)


func _on_item_added(_item: InventoryItemData) -> void:
	# Keep the grid current if the panel is open when something is picked up.
	if visible:
		_rebuild()
		_flash_new_items.call_deferred()      # REV 521: a combine's result lights up


## REV 160: whether the backpack is open (it can still be on screen for a moment while it closes).
var _is_open := false

func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_rebuild()
	visible = true
	_is_open = true
	_restore_place()
	_update_selection_highlight()
	UITheme.panel_open(_panel)      # REV 160 (item 21)


## REV 160 (CLAUDE.md item 23): the backpack opens where you left it - on the same item (found by id,
## so it still works if items were added or used up since), or the first one if that item is gone.
var _last_item_id := ""

func _restore_place() -> void:
	_selected_index = 0
	if _last_item_id != "":
		for i in _entries.size():
			if String(_entries[i].get("id", "")) == _last_item_id:
				_selected_index = i
				break


func close() -> void:
	if _selected_index >= 0 and _selected_index < _entries.size():
		_last_item_id = String(_entries[_selected_index].get("id", ""))
	_is_open = false
	_tooltip.visible = false
	UITheme.panel_close(_panel, func() -> void:
		if not _is_open:
			visible = false)


# =========================================================================
# Building the grids
# =========================================================================

func _rebuild() -> void:
	for grid in [_equipment_grid, _bag_grid]:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	_entries.clear()

	var equipment := EquipmentManager.get_equipment_for(InteractionManager.kit_owner())   # REV 293
	for i in maxi(EQUIPMENT_SLOTS, equipment.size()):
		if i < equipment.size():
			var e: EquipmentItemData = equipment[i]
			_add_item_slot(_equipment_grid, e.id, e.display_name, "STANDARD EQUIPMENT", e.description, e.icon)
		else:
			_equipment_grid.add_child(_make_empty_slot())

	var items := InventoryManager.get_all_items()
	var total := maxi(BAG_COLUMNS * BAG_ROWS, int(ceil(items.size() / float(BAG_COLUMNS))) * BAG_COLUMNS)
	for i in total:
		if i < items.size():
			var it: InventoryItemData = items[i]
			_add_item_slot(_bag_grid, it.id, it.display_name, "ITEM", it.description, it.icon)
		else:
			_bag_grid.add_child(_make_empty_slot())

	_selected_index = clampi(_selected_index, 0, maxi(_entries.size() - 1, 0))
	_refresh_held_highlight()

	# Centre the panel (get_viewport_rect().size rather than self.size — self.size
	# isn't reliably current the instant a menu opens).
	var content_size: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = content_size
	var viewport_size: Vector2 = get_viewport_rect().size
	_panel.position = (viewport_size - content_size) / 2.0


func _make_empty_slot() -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.026, 0.75)
	sb.border_color = Color(UITheme.GOLD_DIM.r, UITheme.GOLD_DIM.g, UITheme.GOLD_DIM.b, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", sb)
	return slot


func _add_item_slot(grid: GridContainer, id: String, item_name: String, kind: String, description: String, icon: Texture2D) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.focus_mode = Control.FOCUS_NONE
	btn.icon = icon if icon != null else _icon_for(id)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.add_theme_constant_override("icon_max_width", int(SLOT_SIZE) - 14)
	UITheme.style_button(btn)
	if btn.icon == null:
		btn.text = item_name   # picture not imported yet: fall back to the name
		btn.clip_text = true
	grid.add_child(btn)

	var entry := {"button": btn, "id": id, "name": item_name, "kind": kind, "description": description}
	_entries.append(entry)
	var index := _entries.size() - 1
	btn.pressed.connect(func() -> void: _on_entry_selected(id))
	# REV 306: right-click = USE the held item WITH this one
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			_use_with(id))
	btn.mouse_entered.connect(func() -> void:
		_selected_index = index
		_update_selection_highlight())
	btn.mouse_exited.connect(func() -> void:
		if _selected_index == index and not _mouse_is_over_a_slot():
			_tooltip.visible = false)


func _mouse_is_over_a_slot() -> bool:
	var mouse := get_viewport().get_mouse_position()
	for entry in _entries:
		var b: Button = entry["button"]
		if b.get_global_rect().has_point(mouse):
			return true
	return false


## REV 160: the same icon, for anyone (the mouse cursor shows the item in hand).
## REV 521: falls back to the item's own picture (InventoryItemData.icon) - items a room makes with an
## icon (every Arena item) never reached the pointer or the console bar before, which showed text.
static func icon_texture(id: String) -> Texture2D:
	var file: String = String(ICON_FILES.get(id, ""))
	if file == "" and id.begins_with("EQUIP_"):     # REV 674: any lead's kit, by what it is
		for kind in ["TRICORDER", "COMMUNICATOR", "PHASER"]:
			if id.ends_with("_" + kind):
				file = "icon_%s.png" % kind.to_lower()
	if file != "" and ResourceLoader.exists(ICON_DIR + file):
		return load(ICON_DIR + file) as Texture2D
	var it: InventoryItemData = InventoryManager.get_item(id) if InventoryManager.has_item(id) else InventoryManager.find_known_item(id)
	if it != null and it.icon != null:
		return it.icon
	for who in ["mccoy", "kirk", "spock", "chapel"]:
		for e in EquipmentManager.get_equipment_for(who):
			if e != null and String(e.id) == id and e.icon != null:
				return e.icon
	return null


func _icon_for(id: String) -> Texture2D:
	var file: String = String(ICON_FILES.get(id, UNKNOWN_ICON))
	# REV 674 (Glen: none of Scotty's kit had a picture): every lead's kit by what it is, whoever carries it
	if not ICON_FILES.has(id):
		for kind in ["TRICORDER", "COMMUNICATOR", "PHASER"]:
			if id.begins_with("EQUIP_") and id.ends_with("_" + kind):
				file = "icon_%s.png" % kind.to_lower()
	if _icon_cache.has(file):
		return _icon_cache[file]
	var path := ICON_DIR + file
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	if tex == null and file != UNKNOWN_ICON and ResourceLoader.exists(ICON_DIR + UNKNOWN_ICON):
		tex = load(ICON_DIR + UNKNOWN_ICON)
	_icon_cache[file] = tex
	return tex


# =========================================================================
# Holding an item
# =========================================================================

## REV 521 (docs/design/HELD_ITEM_INTERACTION.md): the classic backpack. Choosing an item with nothing
## in hand PICKS IT UP (it becomes the pointer) and the backpack stays open; choosing another item while
## holding one COMBINES them on the spot (the result appears with a flash; no match = a line and the
## item stays in hand); choosing the held one puts it back. Tricorder in hand + an item = scan that item.
## Close the backpack (click outside it, B / Esc, I) to use what you're holding on the world.
func _on_entry_selected(source_id: String) -> void:
	var held_now := InteractionManager.get_held_source()
	if held_now == source_id:
		SfxManager.ui("back", -2.0)
		InteractionManager.set_held_source("")
		_update_selection_highlight()
		return
	if held_now != "" and InteractionManager.is_tricorder(held_now) and not InteractionManager.is_tricorder(source_id):
		SfxManager.ui("confirm")
		close()
		InteractionManager.scan_item(source_id)
		return
	if held_now != "" and not InteractionManager.is_tricorder(source_id) and not _is_equipment(held_now) and not _is_equipment(source_id):
		_combine(held_now, source_id)
		return
	SfxManager.ui("confirm")
	InteractionManager.set_held_source(source_id)
	for equip in EquipmentManager.get_equipment_for(InteractionManager.kit_owner()):   # REV 293
		if equip.id == source_id:
			if InteractionManager.is_tricorder(source_id) or source_id.contains("COMMUNICATOR"):
				close()      # the kit is for using on the world - straight back to it
				return
	_update_selection_highlight()


func _is_equipment(id: String) -> bool:
	for e in EquipmentManager.get_equipment_for(InteractionManager.kit_owner()):
		if e != null and String(e.id) == id:
			return true
	return false


## REV 521: the held item dropped on another in the backpack. Stays open so the result can be seen.
func _combine(held: String, target_id: String) -> void:
	var before := {}
	for it in InventoryManager.get_all_items():
		before[String(it.id)] = true
	SfxManager.ui("confirm")
	_flash_next = before
	await InteractionManager.combine_items(held, target_id)


## Items that were in the backpack before a combine; anything new afterwards gets the flash.
var _flash_next := {}

func _flash_new_items() -> void:
	if _flash_next.is_empty():
		return
	for e in _entries:
		if String(e["kind"]) == "ITEM" and not _flash_next.has(String(e["id"])):
			var b: Button = e["button"]
			b.pivot_offset = b.custom_minimum_size * 0.5
			b.modulate = Color(2.2, 2.0, 1.4)
			b.scale = Vector2(1.25, 1.25)
			var tw := b.create_tween().set_parallel(true)
			tw.tween_property(b, "modulate", Color.WHITE, 0.6)
			tw.tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_selected_index = _entries.find(e)
	_flash_next = {}
	_update_selection_highlight()


## REV 306 (design: "the player may USE one inventory object ON another"): the item in hand on this one.
## Nothing in hand, the same item, or a tricorder (that's a scan - A does it) -> the "can't" tick only.
func _use_with(target_id: String) -> void:
	var held := InteractionManager.get_held_source()
	if held == "" or held == target_id or InteractionManager.is_tricorder(held) or InteractionManager.is_tricorder(target_id):
		SfxManager.ui("invalid")
		return
	_combine(held, target_id)


## REV 306: how to say "use with" on the device in use.
func _use_with_word() -> String:
	if InputHints.using_gamepad:
		var t := CaseFileUI._pad_tag(JOY_BUTTON_X).strip_edges()
		return t if t != "" else "[X]"
	return "RIGHT-CLICK / [U]"


func _is_held(id: String) -> bool:
	var held := InteractionManager.get_held_source()
	return held != "" and held == id


## The held item gets a gold frame; the item under the cursor gets the bright
## "active" frame; both together get the bright one with the gold ring kept.
func _refresh_held_highlight() -> void:
	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		var btn: Button = entry["button"]
		var held := _is_held(String(entry["id"]))
		var cursor := i == _selected_index
		UITheme.style_button(btn, cursor or held)
		if held:
			var sb := UITheme.button_stylebox(true)
			sb.border_color = HELD_COLOR
			sb.set_border_width_all(3)
			for state in ["normal", "hover", "pressed", "focus"]:
				btn.add_theme_stylebox_override(state, sb)


# =========================================================================
# Keyboard / gamepad navigation and the tooltip
# =========================================================================

## REV 521: a click outside the backpack closes it (still holding whatever is in hand), so the next
## click can use it on the world. The console bar's own keys still work (they toggle screens).
func _input(event: InputEvent) -> void:
	if not _is_open or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or (mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT):
		return
	if _panel.get_global_rect().has_point(mb.position):
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and "console_bar" in hud and hud.get("console_bar") != null:
		var bar := hud.get("console_bar") as Control
		if bar.is_visible_in_tree() and bar.get_global_rect().has_point(mb.position):
			return
	close()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:      # REV 160: not while it's fading shut
		return

	# REV 293: a stick moves one slot per push (Godot's ui_left/right also fire for every little stick
	# movement past the deadzone, which made the cursor race across the grid)
	if event is InputEventJoypadMotion:
		var dir := _stick_step(event as InputEventJoypadMotion)
		if dir != Vector2.ZERO:
			_move_cursor(dir)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("menu_cancel"):
		close()
	elif event.is_action_pressed("ui_navigate_down") or event.is_action_pressed("ui_down"):
		_move_cursor(Vector2.DOWN)
	elif event.is_action_pressed("ui_navigate_up") or event.is_action_pressed("ui_up"):
		_move_cursor(Vector2.UP)
	elif event.is_action_pressed("ui_left"):
		_move_cursor(Vector2.LEFT)
	elif event.is_action_pressed("ui_right"):
		_move_cursor(Vector2.RIGHT)
	elif (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_X) \
			or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_U):
		# REV 306: X on a pad / U on the keyboard = USE the held item WITH the one under the cursor
		if not _entries.is_empty():
			_use_with(String(_entries[_selected_index]["id"]))
	elif PadNav.confirm(event):      # REV 293: Enter / Space / A (ui_navigate_confirm, ui_accept or interact)
		if not _entries.is_empty():
			_on_entry_selected(String(_entries[_selected_index]["id"]))
	else:
		return
	get_viewport().set_input_as_handled()


## REV 293: either stick, one step per push: past PadNav.PUSH it counts once, and it must come back
## inside PadNav.RELEASE before it counts again (the same feel as every other menu).
var _stick_held := {}    # "device:axis" -> true while pushed

func _stick_step(jm: InputEventJoypadMotion) -> Vector2:
	var horizontal := jm.axis == JOY_AXIS_LEFT_X or jm.axis == JOY_AXIS_RIGHT_X
	var vertical := jm.axis == JOY_AXIS_LEFT_Y or jm.axis == JOY_AXIS_RIGHT_Y
	if not horizontal and not vertical:
		return Vector2.ZERO
	var key := "%d:%d" % [jm.device, jm.axis]
	var v := jm.axis_value
	if absf(v) < PadNav.RELEASE:
		_stick_held.erase(key)
		return Vector2.ZERO
	if absf(v) > PadNav.PUSH and not _stick_held.has(key):
		_stick_held[key] = true
		var s := 1.0 if v > 0.0 else -1.0
		return Vector2(s, 0.0) if horizontal else Vector2(0.0, s)
	return Vector2.ZERO


## Moves to the nearest filled slot in the pressed direction (works for the
## equipment row and the backpack grid together).
func _move_cursor(dir: Vector2) -> void:
	if _entries.is_empty():
		return
	var from_btn: Button = _entries[_selected_index]["button"]
	var from_c := from_btn.get_global_rect().get_center()
	var best := -1
	var best_score := INF
	for i in _entries.size():
		if i == _selected_index:
			continue
		var b: Button = _entries[i]["button"]
		var delta := b.get_global_rect().get_center() - from_c
		var along := delta.dot(dir)
		if along < 4.0:
			continue
		var across := absf(delta.dot(Vector2(dir.y, dir.x)))
		var score := along + across * 2.5
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_selected_index = best
		_update_selection_highlight()


func _update_selection_highlight() -> void:
	_refresh_held_highlight()
	_show_tooltip_for(_selected_index)


func _show_tooltip_for(index: int) -> void:
	if index < 0 or index >= _entries.size() or not visible:
		_tooltip.visible = false
		return
	var entry: Dictionary = _entries[index]
	_tooltip_name.text = String(entry["name"]).to_upper()
	_tooltip_kind.text = String(entry["kind"])
	var desc := String(entry["description"])
	_tooltip_text.text = desc if desc != "" else "No description."
	# REV 293: names the pad button on a pad
	# REV 521: what a click does now
	var held := InteractionManager.get_held_source()
	var eid := String(entry["id"])
	if _is_held(eid):
		_tooltip_held.text = "HOLDING  -  %s TO PUT BACK" % _choose_word()
	elif held != "" and InteractionManager.is_tricorder(held) and not InteractionManager.is_tricorder(eid):
		_tooltip_held.text = "%s  SCAN THIS" % _choose_word()
	elif held != "" and not InteractionManager.is_tricorder(eid) and not _is_equipment(held) and not _is_equipment(eid):
		_tooltip_held.text = "%s  COMBINE WITH %s" % [_choose_word(), _name_of(held).to_upper()]
	else:
		_tooltip_held.text = "%s TO PICK UP" % _choose_word()
	_tooltip.visible = true
	_tooltip.reset_size()
	_place_tooltip.call_deferred(index)


func _place_tooltip(index: int) -> void:
	if index >= _entries.size() or not _tooltip.visible:
		return
	var btn: Button = _entries[index]["button"]
	var rect := btn.get_global_rect()
	var viewport_size: Vector2 = get_viewport_rect().size
	var tip_size := _tooltip.get_combined_minimum_size()
	_tooltip.size = tip_size
	var pos := Vector2(rect.end.x + 10.0, rect.position.y)
	if pos.x + tip_size.x > viewport_size.x - 8.0:
		pos.x = rect.position.x - tip_size.x - 10.0
	pos.y = clampf(pos.y, 8.0, maxf(viewport_size.y - tip_size.y - 8.0, 8.0))
	_tooltip.position = pos
