extends Node

## REV 138: physics smoothing is on in project.godot, but only the player body uses it (see
## PlayerController). This is the first autoload, so turning it off at the root happens before any
## room or character exists; everything else in the game is drawn exactly as before.
func _enter_tree() -> void:
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

## PauseKey (REV 105): Esc opens the pause menu - but only when nothing else wanted the key.
##
## Esc already means "back / cancel / skip" in many places (the verb menu, conversation choices,
## the case file, the map, the cold open...). This autoload is listed FIRST in Project Settings >
## Autoload, which makes it the LAST thing to hear an unhandled key, so it only acts when every
## other screen has let Esc go by. Gamepads use Start (the SYSTEM MENU button) instead, because
## their cancel button (B / CIRCLE) is pressed far too often to double as pause.


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not event.is_action_pressed("menu_cancel"):
		return
	if not can_pause():
		return
	var hud := get_tree().get_first_node_in_group("hud")
	hud.call("open_pause_menu")
	get_viewport().set_input_as_handled()


## True when a game scene with a HUD is running and nothing else has the screen.
func can_pause() -> bool:
	if get_tree().paused or PhotoMode.active:
		return false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.is_inside_tree() or not hud.has_method("open_pause_menu"):
		return false
	var scene := get_tree().current_scene
	if scene == null or not scene.is_ancestor_of(hud):
		return false
	if bool(hud.call("is_any_panel_open")) or InteractionManager.is_modal_suspended():
		return false
	return true
