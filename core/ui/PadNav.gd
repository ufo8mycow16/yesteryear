extends RefCounted
class_name PadNav
## REV 214 (Nikki, Xbox pad): one place that turns gamepad/keyboard input into menu steps, and says
## whether a menu is open (so McCoy and the camera ignore the sticks while one is).
##
## step(event) -> -1 (up/previous), +1 (down/next) or 0. Counts:
##   d-pad up/down (and left/right), arrow keys, ui_navigate_up/down, ui_up/down/left/right;
##   EITHER stick pushed up/down - once per push (it must come back near the middle before it counts
##   again), so a stick never skips several rows.
## confirm(event) -> true for A / Enter / Space / interact.
##
## Menus that should freeze movement join the group MENU_GROUP and have a method
## pad_menu_active() -> bool. any_open(tree) asks them.

const MENU_GROUP := "pad_menus"
const PUSH := 0.6        # stick past this = one step
const RELEASE := 0.3     # stick back inside this = ready for the next step

static var _held := {}   # axis -> true while that stick is pushed


static func step(event: InputEvent) -> int:
	var jm := event as InputEventJoypadMotion
	if jm != null:
		if jm.axis != JOY_AXIS_LEFT_Y and jm.axis != JOY_AXIS_RIGHT_Y:
			return 0
		var key := "%d:%d" % [jm.device, jm.axis]
		var v := jm.axis_value
		if absf(v) < RELEASE:
			_held.erase(key)
			return 0
		if absf(v) > PUSH and not _held.has(key):
			_held[key] = true
			return 1 if v > 0.0 else -1
		return 0
	var jb := event as InputEventJoypadButton
	if jb != null:
		if not jb.pressed:
			return 0
		match jb.button_index:
			JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT:
				return 1
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT:
				return -1
	if event.is_action_pressed("ui_navigate_down") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		return 1
	if event.is_action_pressed("ui_navigate_up") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		return -1
	return 0


static func confirm(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return false
	return event.is_action_pressed("ui_navigate_confirm") or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")


## True while any menu that wants the sticks is open.
static func any_open(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for n in tree.get_nodes_in_group(MENU_GROUP):
		if is_instance_valid(n) and n.has_method("pad_menu_active") and n.pad_menu_active():
			return true
	return false
