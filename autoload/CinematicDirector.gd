extends Node
## Lightweight awaitable choreography runner. Commands are Dictionaries.
## REV 293: NOT USED. It is registered as an autoload (project.godot) but no script calls play(); every
## cutscene is written as plain code in its room (CutsceneCameraController for the camera moves). Kept in
## case a data-driven cutscene list is wanted later; nothing breaks if it is left alone.
signal sequence_started(id: String)
signal sequence_finished(id: String)
var running := false
func play(id: String, host: Node, commands: Array) -> void:
	if running: return
	running = true; sequence_started.emit(id)
	for c in commands: await _command(host, c)
	running = false; sequence_finished.emit(id)
func _command(host: Node, c: Dictionary) -> void:
	match String(c.get("op", "")):
		"wait": await get_tree().create_timer(float(c.get("seconds", 0.1)), false).timeout
		"call":
			var target: Node = host.get_node_or_null(NodePath(c.get("target", ".")))
			if target and target.has_method(StringName(c.get("method", ""))):
				var result = target.callv(StringName(c.method), c.get("args", []))
				if result is Signal: await result
		"set":
			var target: Node = host.get_node_or_null(NodePath(c.get("target", ".")))
			if target: target.set(StringName(c.get("property", "")), c.get("value"))
		"move_to":
			var actor: Node3D = host.get_node_or_null(NodePath(c.get("target", ""))) as Node3D
			var marker: Node3D = host.get_node_or_null(NodePath(c.get("marker", ""))) as Node3D
			if actor and marker: await _move(actor, marker.global_position, float(c.get("speed", 2.0)))
		"face":
			var actor: Node3D = host.get_node_or_null(NodePath(c.get("target", ""))) as Node3D
			var other: Node3D = host.get_node_or_null(NodePath(c.get("at", ""))) as Node3D
			if actor and other:
				var d := other.global_position - actor.global_position
				if Vector2(d.x, d.z).length() > 0.001:
					actor.rotation.y = atan2(d.x, d.z)
		"line":
			var line := c.get("line") as DialogueLineData
			if line != null:
				for var_name in line.variables_set.keys(): GameState.set_var(var_name, line.variables_set[var_name])
				AudioSubtitleManager.play_line(line.character_folder, line.filename, line.speaker_display_name, line.subtitle, line.audio_bus)
				await AudioSubtitleManager.line_finished
		"banter":
			var banter_id := String(c.get("id", ""))
			if BanterManager.try_play(banter_id): await BanterManager.banter_finished
		_: push_warning("CinematicDirector: unknown op %s" % c.get("op", ""))
func _move(actor: Node3D, destination: Vector3, speed: float) -> void:
	while actor.global_position.distance_to(destination) > 0.06:
		actor.global_position = actor.global_position.move_toward(destination, speed * get_process_delta_time())
		await get_tree().process_frame
