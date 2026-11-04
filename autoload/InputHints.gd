extends Node
## InputHints (REV 103): on-screen key hints that match how you're playing.
##
## A hint is written once as a template with action names in braces, e.g.
##     InputHints.bind(close_button, "CLOSE  {menu_cancel}")
## and shows "[ESC]" while you use keyboard/mouse, or the right button for your pad - "[B]" on an
## Xbox pad, "[CIRCLE]" on a PlayStation pad, "[A]" on a Nintendo pad (whose right button is A).
## It follows rebinding (it reads the live input map) and switches the moment you touch the other
## device. Parts of a template separated by "|" are dropped when their action has no binding on the
## current device, so a gamepad player never sees a key they can't press.

signal device_changed(gamepad: bool)

var using_gamepad := false
var family := "xbox"          # xbox | playstation | nintendo
var _bound: Array = []        # [WeakRef(Control), template]

## Godot's button order is by POSITION: 0 bottom, 1 right, 2 left, 3 top (then back, guide, start, ...).
const BUTTONS := {
	"xbox": ["A", "B", "X", "Y", "VIEW", "GUIDE", "MENU", "L-STICK", "R-STICK", "LB", "RB", "D-PAD UP", "D-PAD DOWN", "D-PAD LEFT", "D-PAD RIGHT"],
	"playstation": ["CROSS", "CIRCLE", "SQUARE", "TRIANGLE", "SHARE", "PS", "OPTIONS", "L3", "R3", "L1", "R1", "D-PAD UP", "D-PAD DOWN", "D-PAD LEFT", "D-PAD RIGHT"],
	"nintendo": ["B", "A", "Y", "X", "-", "HOME", "+", "L-STICK", "R-STICK", "L", "R", "D-PAD UP", "D-PAD DOWN", "D-PAD LEFT", "D-PAD RIGHT"],
}
const TRIGGERS := {"xbox": ["LT", "RT"], "playstation": ["L2", "R2"], "nintendo": ["ZL", "ZR"]}
const KEY_NAMES := {"Escape": "ESC", "Enter": "ENTER", "Tab": "TAB", "Space": "SPACE", "Backspace": "BKSP",
	"Up": "UP", "Down": "DOWN", "Left": "LEFT", "Right": "RIGHT"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Input.get_connected_joypads().size() > 0:
		family = _family_of(Input.get_joy_name(Input.get_connected_joypads()[0]))
	GameSettings.controls_changed.connect(refresh)


func _input(event: InputEvent) -> void:
	var pad := (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed) \
		or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5)
	var kbm := (event is InputEventKey and (event as InputEventKey).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 6.0)
	if pad and not using_gamepad:
		_set_gamepad(true, event.device)
	elif kbm and using_gamepad:
		_set_gamepad(false, 0)


func _set_gamepad(on: bool, device: int) -> void:
	using_gamepad = on
	if on:
		family = _family_of(Input.get_joy_name(device))
	refresh()
	device_changed.emit(on)


static func _family_of(joy_name: String) -> String:
	var n := joy_name.to_lower()
	for k in ["playstation", "dualsense", "dualshock", "sony", "ps3", "ps4", "ps5"]:
		if n.contains(k):
			return "playstation"
	for k in ["nintendo", "switch", "pro controller", "joy-con"]:
		if n.contains(k):
			return "nintendo"
	return "xbox"


## The bound key or button for an action on the current device, without brackets ("" if none).
func key(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	var events := InputMap.action_get_events(action)
	if using_gamepad:
		for e in events:
			if e is InputEventJoypadButton:
				var names: Array = BUTTONS[family]
				var i := (e as InputEventJoypadButton).button_index
				return String(names[i]) if i >= 0 and i < names.size() else "BUTTON %d" % i
			if e is InputEventJoypadMotion:
				var m := e as InputEventJoypadMotion
				if m.axis == JOY_AXIS_TRIGGER_LEFT or m.axis == JOY_AXIS_TRIGGER_RIGHT:
					return String(TRIGGERS[family][0 if m.axis == JOY_AXIS_TRIGGER_LEFT else 1])
				return "L-STICK" if m.axis <= JOY_AXIS_LEFT_Y else "R-STICK"
		return ""
	for e in events:
		if e is InputEventKey:
			var k := e as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			var label := OS.get_keycode_string(code)
			return String(KEY_NAMES.get(label, label.to_upper()))
		if e is InputEventMouseButton:
			return "MOUSE %d" % (e as InputEventMouseButton).button_index
	return ""


## "[F]" / "[A]" / "" for an action.
func hint(action: String) -> String:
	var k := key(action)
	return "[%s]" % k if k != "" else ""


## Fill a template: "{action}" becomes its hint; "|" separates parts that are dropped when one of
## their actions has nothing on this device. Kept parts are joined with wide spacing.
func fill(template: String) -> String:
	if template.begins_with("="):
		return key(template.substr(1))     # "=interact" -> just "F" (for keycaps)
	var parts: PackedStringArray = []
	var re := RegEx.create_from_string("\\{([a-z_]+)\\}")
	for part in template.split("|"):
		var text := part
		var keep := true
		for m in re.search_all(part):
			var h := hint(m.get_string(1))
			if h == "":
				keep = false
			text = text.replace(m.get_string(0), h)
		if keep:
			parts.append(text.strip_edges())
	return "      ".join(parts)


## Keep a Label's or Button's text filled from a template, updated whenever the device or the
## bindings change. Safe to call again with a new template.
func bind(control: Control, template: String) -> void:
	if control == null:
		return
	for b in _bound:
		if (b[0] as WeakRef).get_ref() == control:
			b[1] = template
			_apply(control, template)
			return
	_bound.append([weakref(control), template])
	_apply(control, template)


func refresh() -> void:
	var alive: Array = []
	for b in _bound:
		var c = (b[0] as WeakRef).get_ref()
		if c != null and is_instance_valid(c):
			_apply(c, String(b[1]))
			alive.append(b)
	_bound = alive


func _apply(control: Object, template: String) -> void:
	var text := fill(template)
	if control is Label:
		(control as Label).text = text
	elif control is Button:
		(control as Button).text = text
	elif control is RichTextLabel:
		(control as RichTextLabel).text = text
