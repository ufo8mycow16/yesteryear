extends CanvasLayer
## Test harness: open TitlesPreview.tscn in Godot and press F6 (Run Current
## Scene) to watch the opening titles on their own, without playing the whole
## Prologue first. Debug builds: Right/Left arrows jump between shots.
## Closes the game when the sequence ends or is skipped (Enter/Esc).


func _ready() -> void:
	var titles := TitleSequence.new()
	add_child(titles)
	titles.sequence_finished.connect(func(): get_tree().quit())
	titles.play()
