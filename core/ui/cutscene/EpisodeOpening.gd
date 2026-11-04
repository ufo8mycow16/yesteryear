extends CanvasLayer
class_name EpisodeOpening
## REV 320 - EVERY EPISODE OPENS THE SAME WAY (Glen, 24 Oct: "episode 2's opening should be the existing
## one we use for episode 1, it should carry across all of the episodes"):
##
##   1. the TOS main titles - TitleSequence's own one-minute opening ("Space... the final frontier",
##      the Enterprise sweeping past, STAR TREK / SECRET OF VULCAN FURY);
##   2. the episode's own space sequence in the same world (the same Enterprise, Vulcan, sky and
##      lights): its title card in TOS yellow and Kirk's Captain's Log, plus any other voice-over.
##
## An episode only writes its shots and lines (episodes/episode1/scenes/Ep1Opening.gd,
## episodes/episode2/scenes/Ep2Opening.gd); this does the rest. It works as a scene's root part
## (Episode 1: then the transporter room) or over a room that carries on afterwards (Episode 2: the
## sickbay reprise, the opening, back to sickbay):
##
##   var op := EpisodeOpening.new()
##   op.ep = Ep2                      # SPEAKERS, SPEECH_ROOT, line_id() - where the recordings are
##   op.settings = {...}              # see below
##   add_child(op)
##   await op.run()
##
## settings keys (all optional except "shots"):
##   "shots":   the episode sequence's shots (TitleSequence.SHOTS format)
##   "titles":  on-screen titles (TitleSequence.TITLE_LINES format; "area": "lower" = the episode title)
##   "log":     the voice-over, in order: [when, [who, words]] or [when, [who, words], {"name": true}]
##              when = seconds, or {"shot": n, "at": s} = s seconds into shot n. A line never starts
##              before the one before it has finished (recording length, or reading time without one);
##              when a line anchored to shot n would be late, the shot before n runs longer instead.
##              {"name": true} puts the speaker's name in front of the subtitle (Kirk's log has none).
##   "layout":  where the F1 shot editor saves this sequence's own cut (send it over, it goes in the repo)
##   "music", "ready_check", "on_world", "aspect": passed on to TitleSequence (see its `opening`)
##   "line_gap": seconds of quiet between lines (0.5)
##   "each_frame": a Callable(seconds into the episode sequence, this EpisodeOpening) called every frame
##              while the episode sequence plays - for timed extras in the space world (Episode 2's shimmer)
##
## main_titles: false skips part 1. The Prologue plays the main titles at its end, just before Episode
## One, and sets titles_just_played so they are not shown twice in a row.

signal finished

## Set by the Prologue when its titles have just played (the next opening skips its own copy once).
static var titles_just_played := false

var ep = null                      # the episode's data class (Ep1, Ep2, ...)
var settings: Dictionary = {}
var main_titles := true
var sequence: TitleSequence = null  # the episode sequence while it plays (for timed extras)
var shots_built: Array = []         # the episode sequence's shots as played (after any stretching)


func _init() -> void:
	layer = 50      # over the room, its fade (30), its dialogue (34/35) and the loading card (40)


## Plays the main titles (unless just seen), then the episode's own sequence. Await it.
func run() -> void:
	TitleSequence.preload_world()
	if main_titles and not titles_just_played:
		var titles := TitleSequence.new()
		add_child(titles)
		titles.play()
		await titles.sequence_finished
		titles.queue_free()
	titles_just_played = false
	if settings.has("shots"):
		sequence = TitleSequence.new()
		sequence.opening = build()
		add_child(sequence)
		sequence.play()
		await sequence.sequence_finished
		AudioSubtitleManager.stop_all()
	finished.emit()


func _process(_delta: float) -> void:
	if sequence != null and is_instance_valid(sequence) and settings.has("each_frame"):
		(settings["each_frame"] as Callable).call(float(sequence._time), self)


## When shot n of the episode sequence starts (after build()).
func shot_start(n: int) -> float:
	if n < 0 or n >= shots_built.size():
		return 0.0
	return float(shots_built[n]["start"])


## TitleSequence's `opening` settings: the shots, and the lines placed around their recordings.
func build() -> Dictionary:
	var shots: Array = []
	for s in settings.get("shots", []):
		shots.append((s as Dictionary).duplicate(true))
	var gap := float(settings.get("line_gap", 0.5))
	var subtitles: Array = []
	var free_from := 0.0
	var anchored_shots := {}
	for entry in settings.get("log", []):
		var line: Array = entry[1]
		var opts: Dictionary = entry[2] if entry.size() > 2 else {}
		var who := String(line[0])
		var text := String(line[1])
		var voice := _voice_path(who, text)
		var length := _length(voice)
		var reading := 1.2 + text.length() * 0.055      # how long a subtitle stays up without a voice
		var planned := 0.0
		var anchored := -1
		if entry[0] is Dictionary:
			var n := int(entry[0].get("shot", 0))
			var at := float(entry[0].get("at", 0.0))
			n = clampi(n, 0, shots.size() - 1)
			var late := free_from - (float(shots[n]["start"]) + at)
			if late > 0.0 and n > 0 and not anchored_shots.has(n):
				# the first line of shot n would be late: the shot before runs longer instead
				_lengthen(shots, n - 1, late)
			planned = float(shots[n]["start"]) + at
			anchored = n
			anchored_shots[n] = true
		else:
			planned = float(entry[0])
		var start := maxf(planned, free_from)
		var finish := start + maxf(reading, length + 0.3)
		var shown := text
		if bool(opts.get("name", false)):
			shown = _display_name(who) + ":  " + text
		subtitles.append({"start": start, "end": finish, "text": shown, "voice": voice})
		free_from = finish + gap
		# a shot's own lines run past its end: it runs longer (the shots after it move later)
		if anchored >= 0 and anchored < shots.size() - 1:
			var over := free_from - (float(shots[anchored]["start"]) + float(shots[anchored]["dur"]))
			if over > 0.0:
				_lengthen(shots, anchored, over)
	var duration := 0.0
	if not shots.is_empty():
		duration = float(shots[-1]["start"]) + float(shots[-1]["dur"])
		var needed := free_from + 1.5          # the last line, then the fade
		if needed > duration:
			shots[-1]["dur"] = float(shots[-1]["dur"]) + needed - duration
			duration = needed
	shots_built = shots
	var out := {"shots": shots, "duration": duration, "titles": settings.get("titles", []), "subtitles": subtitles,
		"aspect": float(settings.get("aspect", 0.0)), "music": String(settings.get("music", ""))}
	for k in ["layout", "ready_check", "on_world", "edit_note"]:
		if settings.has(k):
			out[k] = settings[k]
	return out


## Shot n runs `extra` seconds longer; the shots after it start that much later.
static func _lengthen(shots: Array, n: int, extra: float) -> void:
	shots[n]["dur"] = float(shots[n]["dur"]) + extra
	for j in range(n + 1, shots.size()):
		shots[j]["start"] = float(shots[j]["start"]) + extra


func _voice_path(who: String, text: String) -> String:
	if ep == null:
		return ""
	var info: Array = ep.SPEAKERS.get(who, [who, who])
	return String(ep.SPEECH_ROOT) + String(info[0]) + "/" + String(ep.line_id(who, text)) + ".mp3"


func _display_name(who: String) -> String:
	var plain := who.capitalize()
	if ep != null:
		var info: Array = ep.SPEAKERS.get(who, [who, plain])
		plain = String(info[1])
	return GameNames.character(who, plain)


static func _length(path: String) -> float:
	if path == "" or not ResourceLoader.exists(path):
		return 0.0
	var stream: AudioStream = load(path)
	return stream.get_length() if stream != null else 0.0
