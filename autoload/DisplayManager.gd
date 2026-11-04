extends Node
## DisplayManager — window mode / fullscreen handling.
##
## Windowed / Borderless Fullscreen / Exclusive Fullscreen. The player's choice
## is stored by GameSettings (user://settings.cfg) and applied here at start-up;
## the System menu's GRAPHICS page and the fullscreen key both go through
## GameSettings.set_window_mode(). Resolution, vsync, frame limit, texture
## quality and anti-aliasing live in GameSettings.apply_graphics().
##
## REV 293: the list of window modes lives in ONE place, GameSettings.DisplayMode. This file
## used to keep its own copy (Mode) that had to be kept in the same order by hand; now it
## reads GameSettings' list, so the two can't drift apart.

## The window mode in use now (a GameSettings.DisplayMode value).
var current_mode: int = 0


func _ready() -> void:
	current_mode = GameSettings.window_mode
	_apply_mode(current_mode)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		if current_mode == GameSettings.DisplayMode.WINDOWED:
			GameSettings.set_window_mode(GameSettings.DisplayMode.BORDERLESS_FULLSCREEN)
		else:
			GameSettings.set_window_mode(GameSettings.DisplayMode.WINDOWED)


## `mode` is a GameSettings.DisplayMode value.
func set_mode(mode: int) -> void:
	current_mode = mode
	_apply_mode(mode)
	# Resolution and render scale depend on the mode; apply them once the window
	# has finished switching.
	GameSettings.apply_graphics.call_deferred()


func _apply_mode(mode: int) -> void:
	if mode == GameSettings.DisplayMode.BORDERLESS_FULLSCREEN:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif mode == GameSettings.DisplayMode.EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:   # WINDOWED (and anything unexpected)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
