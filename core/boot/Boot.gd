extends Node
## Boot — the project's run/main_scene. Goes straight to the main menu.
## (REV 293: debug builds jump straight into a scene from the menu's DEBUG: SCENE SELECT or
## DEBUG: LOCATIONS lists - the old "DEBUG: GO TO PROLOGUE" entry is gone.)

const MAIN_MENU_SCENE := "res://core/menu/MainMenu.tscn"


func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
