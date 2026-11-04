extends Node3D
class_name CutsceneCameraController
## Plays a CAM_PRO_xxx shot by temporarily taking over Camera3D.current, then
## hands control back to the gameplay OrbitCameraRig. Minimal by design — the
## Prologue only needs a single slow push-in (CAM_PRO_004); extend here
## rather than hand-rolling a one-off Tween per scene when more shots exist.

signal shot_finished(shot_id: String)

var _camera: Camera3D
var _gameplay_camera: Camera3D


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# Godot's default clip range (0.05 to 4000) leaves too little depth precision, so surfaces that
	# sit close together flicker as you move. A tighter range keeps them steady.
	_camera.near = 0.1
	_camera.far = 1200.0
	add_child(_camera)


func play_shot(shot: CameraShotData, gameplay_camera: Camera3D) -> void:
	_gameplay_camera = gameplay_camera
	_camera.global_position = gameplay_camera.global_position
	_camera.look_at(shot.look_at_position, Vector3.UP)
	_camera.current = true

	var tween := create_tween()
	tween.tween_property(_camera, "global_position", shot.target_position, shot.blend_time)
	tween.finished.connect(_on_shot_finished.bind(shot.id))


func _on_shot_finished(shot_id: String) -> void:
	if _gameplay_camera != null:
		_gameplay_camera.current = true
	shot_finished.emit(shot_id)


## Holds a static shot with no tween and no auto-handback — for a beat whose
## length is driven by a variable-length dialogue sequence (e.g. Opening
## Banter's 12 lines) rather than by a fixed blend_time. play_shot() isn't
## right for that: its handback fires as soon as its tween finishes, which
## would cut back to the gameplay camera mid-dialogue, well before the
## sequence calling it is actually done. Call release() when it's over.
func hold_shot(shot: CameraShotData, gameplay_camera: Camera3D) -> void:
	_gameplay_camera = gameplay_camera
	_camera.global_position = shot.target_position
	_camera.look_at(shot.look_at_position, Vector3.UP)
	_camera.current = true


func release() -> void:
	if _gameplay_camera != null:
		_gameplay_camera.current = true


## REV 160: from the shot being held, glide (eased, not cut) to `shot` over `seconds`, turning to its
## look point on the way. A crane up from the pins to the scoreboard, say. Returns when it arrives.
func move_to(shot: CameraShotData, seconds: float) -> void:
	if not _camera.current:
		hold_shot(shot, _gameplay_camera)
		return
	var from := _camera.global_transform
	var to := Transform3D(Basis.IDENTITY, shot.target_position).looking_at(shot.look_at_position, Vector3.UP)
	var tw := create_tween()
	tw.tween_method(_glide.bind(from, to), 0.0, 1.0, seconds)
	await tw.finished


func _glide(w: float, from: Transform3D, to: Transform3D) -> void:
	var e := w * w * (3.0 - 2.0 * w)
	_camera.global_transform = Transform3D(from.basis.slerp(to.basis, e).orthonormalized(), from.origin.lerp(to.origin, e))


## REV 160: glide from the held shot back to wherever the gameplay camera is (it may be moving), then
## hand it back - an ease back to normal play instead of a cut.
func ease_back(seconds: float) -> void:
	if _gameplay_camera == null or not _camera.current:
		release()
		return
	var from := _camera.global_transform
	var from_fov := _camera.fov
	var tw := create_tween()
	tw.tween_method(_glide_home.bind(from, from_fov), 0.0, 1.0, seconds)
	await tw.finished
	_camera.fov = from_fov
	release()


func _glide_home(w: float, from: Transform3D, from_fov: float) -> void:
	if not is_instance_valid(_gameplay_camera):
		return
	var e := w * w * (3.0 - 2.0 * w)
	var to := _gameplay_camera.global_transform.orthonormalized()
	_camera.global_transform = Transform3D(from.basis.orthonormalized().slerp(to.basis, e).orthonormalized(), from.origin.lerp(to.origin, e))
	_camera.fov = lerpf(from_fov, _gameplay_camera.fov, e)
