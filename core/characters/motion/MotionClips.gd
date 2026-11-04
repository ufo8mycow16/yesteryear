class_name MotionClips
extends RefCounted
## REV 129: the Mixamo animation clips Glen downloaded (assets/animations/mixamo/), and everything
## needed to read them: the skeleton they were made on, sampling a clip at any moment, mirroring,
## masks for playing part of a body, and the small fixes some clips need.
##
## The clips are never played by an AnimationPlayer. CharacterMotion samples them itself, mixes them
## (walk with run, an idle under a gesture, ...) on this Mixamo skeleton, and MotionRig then copies the
## result onto each character's own skeleton (Daz Genesis 8 for McCoy, the captain's-kit stand-ins
## for everyone else). So one set of clips works for every character.
##
## Times below are in seconds of the original clip. "speed" is how fast the clip walks, in body heights
## per second (measured from the planted foot), so the game can play it at the speed the character
## actually moves and the feet don't slide.

const DIR := "res://assets/animations/mixamo/"
## REV 241: clips converted from Glen's Daz animation packs (tools/anim/daz_anim_convert.gd) - already on
## the Mixamo skeleton, loaded the same way. A DEFS entry with "daz": true is looked for here.
const DAZ_DIR := "res://assets/animations/daz/"

## id -> settings.
##   loop        the clip repeats (start..end), crossfading the seam over loop_blend seconds
##   start, end  the part of the clip used (default: all of it)
##   hold        [a, b]: a part that can be repeated for as long as a line needs (pointing, thinking)
##   rate        playback speed (1 = as recorded)
##   mask        which part of the body it moves when played over something else
##   in_place    removes the clip's steady drift (Walking Backwards moved 1.3 m per step)
##   bake_out_yaw  removes the clip's steady turn (the walking turn: the game turns the character)
##   root_motion the character really moves with the clip (standing up out of a seat, the bowl)
##   own_head    the clip turns the head itself, so the eyes-and-head look-at backs off meanwhile
##   still       a single-frame pose (the Kirk and Spock stances), given life by the idle on top
##   fix         with "still": a named correction to that pose ("spock_upright" only - REV 293)
##   file        the .fbx it comes from, when that isn't the id (part of a longer recording)
##   turn_upper  [degrees, from, to]: the upper body turned about the vertical by that much, eased off
##               between those clip times (a recording made side-on, aiming across the body)
##   daz         converted from a Daz animation (assets/animations/daz/<file>.scn, REV 241)
##   level_hips  the clip's hips are held at standing height on average (REV 331: Climbing Ladder is
##               recorded part way up a ladder, hips 0.8 m higher than standing; the feet-on-floor
##               correction then puts the lower foot on the character's own level)
##   line_up_with  another clip: this one is turned and moved so its first pose faces and stands where
##               that one's does (a recording made facing elsewhere, or a few steps away)
const DEFS := {
	# --- moving about
	"idle": {"loop": true, "loop_blend": 0.6},
	"walk": {"loop": true, "speed": 0.985},          # (these three loop seamlessly as recorded)
	"walk_female": {"loop": true, "speed": 0.951},   # REV 160 (item 8): women's walk; speed from its stride, same method as walk's (REV 293: women get it through CharacterMotion.FEMALE_CLIPS; the "female" mark here was never read)
	"run": {"loop": true, "speed": 2.59},
	"walk_back": {"loop": true, "speed": 0.77, "in_place": true},
	"walk_turn_left": {"loop": true, "speed": 0.74, "bake_out_yaw": true, "loop_blend": 0.25},
	# --- stances (one frame each)
	"stance_kirk": {"still": true},
	"stance_spock": {"still": true, "fix": "spock_upright"},
	# --- conversation
	# REV 293: nod and head_shake go ON TOP of everything else - CharacterMotion.gesture() makes their
	# layer additive itself (an "additive" mark here was never read, so it was taken out)
	"nod": {"mask": "head"},
	"head_shake": {"mask": "head"},
	"talk_calm": {"loop": true, "mask": "upper", "loop_blend": 0.5},
	"talk_lively": {"loop": true, "mask": "upper", "loop_blend": 0.5},
	"talk_seated": {"loop": true, "mask": "upper", "loop_blend": 0.5},
	"argue": {"loop": true, "mask": "upper", "loop_blend": 0.8},
	"argue_big": {"loop": true, "mask": "upper", "loop_blend": 0.8},
	"shrug": {"mask": "upper"},
	"point": {"mask": "upper", "hold": [0.75, 1.65]},
	"think": {"mask": "upper", "hold": [1.15, 2.65], "own_head": true},
	# --- looking
	"look_behind": {"mask": "full", "hold": [1.1, 2.3], "own_head": true},
	"look_around": {"mask": "full", "own_head": true, "root_motion": true},
	# --- doing things
	"communicator": {"mask": "upper", "hold": [12.4, 18.6], "own_head": true},
	"tablet": {"loop": true, "mask": "upper", "start": 0.0, "end": 27.0, "loop_blend": 1.0},
	"button": {"mask": "upper"},
	# REV 168 (CLAUDE.md item 11): Glen's Pistol Holster recording. 0-1.2 s aiming at eye level, then
	# lowering, the hand at the holster about 3.55 s, the arm at rest by 5.6 s. Played forward it
	# holsters; backwards it draws; its opening is the aim.
	# The actor stands side-on (hips 34 degrees round) and aims 26.5 degrees across his body: the upper
	# body is turned back so the aim is straight ahead, easing off as the phaser goes in.
	"phaser_holster": {"file": "pistol_holster", "start": 1.2, "end": 5.6, "mask": "upper", "turn_upper": [-26.5, 1.2, 3.55]},
	"phaser_aim": {"file": "pistol_holster", "loop": true, "start": 0.0, "end": 1.2, "loop_blend": 0.4, "mask": "upper", "turn_upper": [-26.5, 1.2, 3.55]},
	"pick_up": {"mask": "full", "start": 0.2, "end": 5.6, "own_head": true},
	# REV 331: Glen's Mixamo "Climbing Ladder" - a 0.77 s climbing loop that stays in place; ModelRoom's
	# ladders play it while they carry the character up (rate -1 climbs down)
	"climb_ladder": {"file": "climbing_ladder", "loop": true, "loop_blend": 0.1, "mask": "full", "own_head": true, "in_place": true, "level_hips": true},
	# REV 171: Glen's "Fist Pump" (Mixamo, seated); the right arm only (CharacterMotion.fist_pump)
	"fist_pump": {"file": "fist_pump_seated", "mask": "arm_r", "start": 0.0, "end": 2.03},
	# REV 293: the throw's bowling crouch is added by CharacterMotion._procedural (_bowl_crouch, for the
	# id "throw"); a "fix": "bowl" mark here was never read, so it was taken out
	"throw": {"mask": "full", "start": 0.85, "end": 3.4, "root_motion": true, "own_head": true},
	# --- sitting and kneeling
	"sit_idle": {"loop": true, "loop_blend": 0.5},
	# REV 192 (Glen: the women sat turned away from the front): the recording sits with the hips turned
	# 38 degrees and the shoulders 44 toward her left; turned back 30, she faces the front, a little angled
	"sit_female_crossed": {"loop": true, "loop_blend": 0.5, "yaw": -30.0},   # REV 160 (item 7): women sit legs crossed (REV 293: chosen through CharacterMotion.FEMALE_CLIPS)
	"typing": {"loop": true, "loop_blend": 0.8, "own_head": true},
	"sit_to_stand": {"mask": "full", "root_motion": true},
	# REV 168 (CLAUDE.md item 10): seated, sipping from a cup in the right hand. Only the seated part of
	# Glen's Sitting Drinking recording (it stands for 3.5 s and sits down first): resting with the cup,
	# the cup up to the mouth (about 7.5-11.3 s), back down, settled - looped.
	# The actor sat down turned about 165 degrees and 30 cm from where Sitting Idle sits: lined up with it.
	"sit_drink": {"file": "sit_drink_raw", "loop": true, "start": 4.75, "end": 14.5, "loop_blend": 1.0, "line_up_with": "sit_idle"},
	"kneel_down": {"mask": "full", "root_motion": true},
	# REV 172: Glen's "One Knee To Standing" (Mixamo) - getting up, instead of kneel_down backwards
	"kneel_to_stand": {"mask": "full", "root_motion": true},
	"kneel_idle": {"loop": true, "loop_blend": 0.6},
	# --- REV 489: fighting (Episode 5's Arena memory - Kirk vs the Gorn). Glen's Mixamo fight reactions
	# (REV 471, "Without Skin", recorded on another body - lined up with the idle so they face front and
	# stand where he stands). REV 673: kirk_punch = Glen's Mixamo Cross Punch (cross_punch.fbx, 2 s: the right
	# fist is furthest out at 1.12 s) - from the wind-up (0.55) to back on guard (1.6) at 1.8x, so it lands 0.32 s
	# in, as ArenaMemory.PUNCH_LANDS expects (was the Gorn's Mutant Punch)
	"kirk_punch": {"file": "cross_punch", "start": 0.55, "end": 1.6, "rate": 1.8, "mask": "full", "own_head": true, "in_place": true, "line_up_with": "idle"},
	"hit_body": {"mask": "full", "own_head": true, "in_place": true, "line_up_with": "idle"},
	"hit_body_2": {"mask": "full", "own_head": true, "in_place": true, "line_up_with": "idle"},
	"hit_stomach": {"mask": "full", "own_head": true, "in_place": true, "line_up_with": "idle"},
	"hit_face_punch": {"mask": "full", "own_head": true, "in_place": true, "line_up_with": "idle"},
	"hit_uppercut_big": {"mask": "full", "own_head": true, "line_up_with": "idle"},    # knocked flat
	"get_up": {"mask": "full", "own_head": true},
	# REV 660 (Glen's Mixamo "Flying Back Death"): Scotty touching the Matrix in Episode 3 - flung backwards and
	# flat on his back (then get_up). In place: the room glides him, so he lands where it chose (clear floor).
	"thrown_back": {"file": "flying_back_death", "mask": "full", "own_head": true, "in_place": true, "line_up_with": "idle"},
	# REV 504: Kirk heaving the Arena's prop boulder over his head (the Gorn's overhead throw on Kirk)
	"kirk_heave": {"file": "gorn_throw_overhead", "mask": "full", "own_head": true, "in_place": true, "line_up_with": "idle"},      # from lying on the ground back to standing
	# --- REV 185: spectators applauding (Glen's Mixamo clips). All start and end in the seated rest pose
	# (hands on the thighs), so they fade in from and back out to sitting. The seated ones play on the upper
	# body only, so the legs keep the person's own sitting pose (a woman's stay crossed).
	"clap_seated_big": {"file": "sitting_clap", "mask": "upper"},          # 6.5 s, hands up high - delighted
	"clap_seated": {"file": "sitting_clap_2", "mask": "upper"},            # 5.7 s, chest height - warm
	"clap_seated_polite": {"file": "sitting_clap_1", "mask": "upper"},     # 3.3 s, chest height - polite
	"clap_seated_loop": {"file": "clapping", "mask": "upper", "hold": [0.0, 1.17]},   # a clapping loop, as long as asked
	"cheer_seated": {"file": "cheering_while_sitting", "mask": "upper"},   # 2.2 s, both arms up
	# stand up out of the seat clapping, then sit back down (all inside the clip: ends where it began)
	"clap_stand_up": {"file": "standing_clap", "mask": "full", "line_up_with": "sit_idle"},      # 4.4 s
	"clap_stand_up_2": {"file": "standing_clap_1", "mask": "full", "line_up_with": "sit_idle"},  # 4.8 s
	# --- REV 241: from Glen's Daz animation packs (Genesis 8 keyframes, converted by tools/anim/convert_packs.py;
	# full fingers). "<id>_f" = the woman's version, picked automatically for women (CharacterMotion.clip_for).
	"daz_angry": {"daz": true, "mask": "full", "own_head": true},   # angry
	"daz_angry_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_check_hand": {"daz": true, "mask": "full", "own_head": true},   # looking at the right hand
	"daz_check_hand_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_check_shoe_l": {"daz": true, "loop": true, "loop_blend": 0.4},   # standing, glancing down at the left shoe now and then (loops)
	"daz_check_shoe_l_f": {"daz": true, "loop": true, "loop_blend": 0.4},
	"daz_check_shoe_r": {"daz": true, "loop": true, "loop_blend": 0.4},   # ... the right shoe
	"daz_excited": {"daz": true, "mask": "full", "own_head": true, "end": 3.6},   # both fists up and shaking (0.3-2.9 s), arms down by 3.6 s - used to 3.6 (McCoy's strike)
	"daz_excited_f": {"daz": true, "mask": "full", "own_head": true, "end": 3.6},
	"daz_eyebrow_l": {"daz": true, "mask": "full", "own_head": true},   # an eyebrow raise (head and body; brow itself via CharacterFace)
	"daz_eyebrow_l_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_eyebrow_r": {"daz": true, "mask": "full", "own_head": true},   # an eyebrow raise
	"daz_eyebrow_r_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_eyebrow_serious_l": {"daz": true, "mask": "full", "own_head": true},   # a serious eyebrow raise
	"daz_eyebrow_serious_l_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_eyebrow_serious_r": {"daz": true, "mask": "full", "own_head": true},   # a serious eyebrow raise
	"daz_eyebrow_serious_r_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_facepalm": {"daz": true, "mask": "full", "own_head": true},   # hand to face
	"daz_facepalm_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_finger_shake": {"daz": true, "mask": "full", "own_head": true},   # wagging a finger - "now, now"
	"daz_finger_shake_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_guffaw": {"daz": true, "mask": "full", "own_head": true},   # a big laugh (face shapes in the Daz file not carried yet)
	"daz_guffaw_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_idle_left": {"daz": true, "loop": true, "loop_blend": 0.4},   # standing, weight on the left leg (loops)
	"daz_idle_left_f": {"daz": true, "loop": true, "loop_blend": 0.4},
	"daz_idle_right": {"daz": true, "loop": true, "loop_blend": 0.4},   # standing, weight on the right leg (loops)
	"daz_idle_right_f": {"daz": true, "loop": true, "loop_blend": 0.4},
	"daz_laugh": {"daz": true, "mask": "full", "own_head": true},   # laughing
	"daz_laugh_2": {"daz": true, "mask": "full", "own_head": true},   # laughing
	"daz_laugh_2_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_laugh_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_laugh_short": {"daz": true, "mask": "full", "own_head": true},   # a short laugh
	"daz_laugh_short_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_shift_center_left": {"daz": true, "mask": "full", "own_head": true},   # shifting weight to the left
	"daz_shift_center_left_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_shift_center_right": {"daz": true, "mask": "full", "own_head": true},   # shifting weight to the right
	"daz_shift_center_right_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_shift_left_center": {"daz": true, "mask": "full", "own_head": true},   # back from the left
	"daz_shift_left_center_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_shift_right_center": {"daz": true, "mask": "full", "own_head": true},   # back from the right
	"daz_shift_right_center_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_shock": {"daz": true, "mask": "full", "own_head": true},   # shocked
	"daz_shock_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_smile": {"daz": true, "mask": "full", "own_head": true},   # a pleased, smiling stance
	"daz_smile_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_surprised": {"daz": true, "mask": "full", "own_head": true},   # surprised
	"daz_surprised_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_walk_cautious": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.732},   # cautious walk, in place
	"daz_walk_cheerful": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.638},   # cheerful walk, in place
	"daz_walk_creeping": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.399},   # creeping, in place
	"daz_walk_mad": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.739},   # angry walk, in place
	"daz_walk_power": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 1.186},   # power walk, in place
	"daz_walk_relaxed": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.653},   # relaxed walk, in place (speeds: tools/anim/measure_walk.gd x 1.061, calibrated on Mixamo walk)
	"daz_walk_stroll": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.607},   # strolling, in place
	# REV 449: the women's versions of the walks (Walks Collection, Victoria 8 - same Mocap Online set as the men's)
	"daz_walk_relaxed_f": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.638},   # relaxed walk - the women's walk (CharacterMotion.clip_for), in place
	"daz_walk_cheerful_f": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.607},   # cheerful, in place
	"daz_walk_mad_f": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.713},   # angry, in place
	"daz_walk_stroll_f": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.586},   # strolling, in place
	"daz_walk_cautious_f": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.719},   # cautious, in place
	"daz_walk_creeping_f": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.390},   # creeping, in place
	"daz_walk_power_f": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 1.121},   # power walk, in place
	# REV 318: the Walk Normal kit for Genesis 8 women (flat shoes; women only - no men's version)
	"daz_walk_normal_f": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.911},       # a woman's natural walk, in place
	"daz_walk_normal_slow_f": {"daz": true, "loop": true, "loop_blend": 0.0, "in_place": true, "speed": 0.729},  # ... slower
	# REV 318: Everyday Movement (one-shots, men's and women's)
	"daz_sit_down_tired": {"daz": true, "mask": "full"},       # 5.8 s, standing -> sinks into a seat, tired
	"daz_sit_down_tired_f": {"daz": true, "mask": "full"},
	"daz_get_up_tired": {"daz": true, "mask": "full"},         # 6.0 s, seated -> gets up, tired
	"daz_get_up_tired_f": {"daz": true, "mask": "full"},
	"daz_through_door": {"daz": true, "mask": "full"},         # 6.3 s, walks forward through a doorway
	"daz_through_door_f": {"daz": true, "mask": "full"},
	"daz_wave_hello": {"daz": true, "mask": "full", "own_head": true},   # 5.0 s, a friendly wave
	"daz_wave_hello_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_rushing": {"daz": true, "mask": "full"},              # 5.0 s, hurrying along (late for work)
	"daz_rushing_f": {"daz": true, "mask": "full"},
	"daz_yawn": {"daz": true, "mask": "full", "own_head": true},   # a yawn
	"daz_yawn_f": {"daz": true, "mask": "full", "own_head": true},
	"daz_yesss": {"daz": true, "mask": "full", "own_head": true},   # "Yesss!" - a big win
	"daz_yesss_f": {"daz": true, "mask": "full", "own_head": true},
	# Conversations Animation Collection (Michael 8; men's only - women use them too). Loops; CharacterMotion.talk picks them (DAZ_TALK).
	"daz_talk_lowkey": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # talking, low key (calm)
	"daz_talk_upbeat": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # talking, up beat
	"daz_talk_animated": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # talking, animated
	"daz_talk_very_animated": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # talking, very animated
	"daz_talk_argue": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # arguing
	"daz_talk_argue_2": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # arguing, bigger
	"daz_talk_sad": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # talking, sad
	"daz_talk_directions_l": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # giving directions, to the left
	"daz_talk_directions_r": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # giving directions, to the right
	"daz_talk_side_r": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # gesturing to the right side
	"daz_talk_side_l": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # gesturing to the left side
	"daz_talk_big_idea": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # "big idea"
	"daz_listen": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # listening (the one being spoken to)
	"daz_talk_up_r": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # gesturing up and right
	"daz_talk_up_l": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # gesturing up and left
	"daz_talk_up_c": {"daz": true, "loop": true, "loop_blend": 0.6, "mask": "upper"},   # gesturing up
	"daz_stand_relaxed": {"daz": true, "loop": true, "loop_blend": 0.4},   # standing relaxed
	"daz_stand_relaxed_2": {"daz": true, "loop": true, "loop_blend": 0.4},   # standing relaxed (2)
	# Working from Home pack (REV 245) - seated at a desk/console; not used in a scene yet
	"daz_sit_typing": {"daz": true, "loop": true, "loop_blend": 0.4},      # typing at a console, a bit frustrated
	# REV 576: kneeling, sat back on the heels (Glen's Zeddicuss "Kneel Sit Crouch" poses 13 G8M / 10 G8F)
	"daz_kneel_sit": {"daz": true, "loop": true, "loop_blend": 0.2},
	"daz_kneel_sit_f": {"daz": true, "loop": true, "loop_blend": 0.2},
	"daz_sit_lean_back": {"daz": true, "loop": true, "loop_blend": 0.4},   # leaning back in a chair, relaxed
	"daz_sit_phone": {"daz": true, "loop": true, "loop_blend": 0.4},       # seated, hand held to the ear (comm call)
}

## Moments inside clips that the game reacts to (seconds of the original clip).
const BOWL_RELEASE := 1.8       # latest moment the ball leaves Spock's hand (normally: the bottom of the swing)
const PICK_UP_GRAB := 2.4       # the hand is at its lowest
const HOLSTER_AT := 3.55        # Pistol Holster: the hand is at the holster (the phaser changes hands here)

# ---- the Mixamo skeleton ----------------------------------------------------------------

class SrcSkel:
	var names: PackedStringArray = []
	var index := {}                         # name (without "mixamorig_") -> bone
	var parent: PackedInt32Array = []
	var rest_q: Array[Quaternion] = []      # local rest rotations
	var rest_p: PackedVector3Array = []     # local rest positions
	var rest_gq: Array[Quaternion] = []     # rest rotations in skeleton space
	var rest_gp: PackedVector3Array = []    # rest positions in skeleton space
	var order: PackedInt32Array = []        # parents before children
	var mirror_of: PackedInt32Array = []    # the bone on the other side (or itself)
	var hips := 0
	var hip_height := 1.0
	var height := 1.0

	func setup(sk: Skeleton3D) -> void:
		var n := sk.get_bone_count()
		for i in n:
			var nm := sk.get_bone_name(i).replace("mixamorig:", "").replace("mixamorig_", "")
			names.append(nm)
			index[nm] = i
			parent.append(sk.get_bone_parent(i))
			var r := sk.get_bone_rest(i)
			rest_q.append(r.basis.get_rotation_quaternion())
			rest_p.append(r.origin)
		rest_gq.resize(n)
		rest_gp.resize(n)
		var done := {}
		while order.size() < n:
			for i in n:
				if done.has(i):
					continue
				var p := parent[i]
				if p < 0 or done.has(p):
					order.append(i)
					done[i] = true
		for i in order:
			var p := parent[i]
			if p < 0:
				rest_gq[i] = rest_q[i]
				rest_gp[i] = rest_p[i]
			else:
				rest_gq[i] = (rest_gq[p] * rest_q[i]).normalized()
				rest_gp[i] = rest_gp[p] + rest_gq[p] * rest_p[i]
		for i in n:
			var nm := names[i]
			var other := nm
			if nm.begins_with("Left"):
				other = "Right" + nm.substr(4)
			elif nm.begins_with("Right"):
				other = "Left" + nm.substr(5)
			mirror_of.append(int(index.get(other, i)))
		hips = int(index.get("Hips", 0))
		hip_height = maxf(rest_gp[hips].y, 0.0001)
		var top := int(index.get("HeadTop_End", -1))
		height = rest_gp[top].y if top >= 0 else hip_height * 1.76

	func bone(nm: String) -> int:
		return int(index.get(nm, -1))

	## Skeleton-space rotations from local ones.
	func globals(local_q: Array[Quaternion], out: Array[Quaternion]) -> void:
		for i in order:
			var p := parent[i]
			out[i] = local_q[i] if p < 0 else (out[p] * local_q[i])

	## Local rotations from skeleton-space ones.
	func locals(global_q: Array[Quaternion], out: Array[Quaternion]) -> void:
		for i in order:
			var p := parent[i]
			out[i] = global_q[i] if p < 0 else (global_q[p].inverse() * global_q[i]).normalized()

	## Joint positions (skeleton space) for a pose.
	func positions(global_q: Array[Quaternion], hips_pos: Vector3, out: PackedVector3Array) -> void:
		for i in order:
			var p := parent[i]
			if p < 0:
				out[i] = hips_pos if i == hips else rest_p[i]
			else:
				out[i] = out[p] + global_q[p] * (hips_pos if i == hips else rest_p[i])


class Clip:
	var id := ""
	var anim: Animation
	var own: SrcSkel                        # the skeleton this clip was recorded on
	var same_rest := true                   # recorded on the reference skeleton (all but "think")
	var rot_track: PackedInt32Array = []    # reference bone -> track (or -1)
	var hips_track := -1
	var start := 0.0
	var end := 0.0
	var loop := false
	var loop_blend := 0.0
	var settings := {}
	var drift := Vector3.ZERO               # in_place: hips movement per second, removed
	var level_y := 0.0                      # level_hips: hips height above standing, removed
	var yaw_rate := 0.0                     # bake_out_yaw: radians per second, removed
	var match_inv: Array[Quaternion] = []   # different body: its rest, lined up with the reference T-pose (inverted)
	var align_yaw := 0.0                    # line_up_with: turn about the vertical (radians)
	var align_from := Vector3.ZERO          # ... about this hips point (the clip's first pose)
	var align_to := Vector3.ZERO            # ... then moved here (the other clip's hips, height kept)
	var aligned := false
	var phase0 := 0.0                       # walking clips: where in the cycle the left foot is furthest forward (0..1)
	var still_q: Array[Quaternion] = []     # a "still" clip's (fixed) pose
	var still_p := Vector3.ZERO

	func length() -> float:
		return end - start

	## How long one time round a loop takes.
	func period() -> float:
		return maxf(end - start - (loop_blend if loop else 0.0), 0.01)


static var _ref: SrcSkel = null
static var _clips := {}
static var _tried := {}
static var _masks := {}


## The skeleton every clip is mixed on (the one Walking was recorded with).
static func ref() -> SrcSkel:
	if _ref == null:
		var sk := _load_skeleton("walk")
		if sk.is_empty():
			return null
		_ref = sk[0]
	return _ref


static func available() -> bool:
	return ref() != null


static func has_clip(id: String) -> bool:
	return get_clip(id) != null


## A clip by id, loaded the first time it's asked for. null if the file isn't in the project.
static func get_clip(id: String) -> Clip:
	if _clips.has(id):
		return _clips[id]
	if _tried.has(id) or ref() == null:
		return null
	_tried[id] = true
	var path := DIR + String(DEFS.get(id, {}).get("file", id)) + ".fbx"
	if bool(DEFS.get(id, {}).get("daz", false)):
		path = DAZ_DIR + String(DEFS.get(id, {}).get("file", id)) + ".scn"
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skels.is_empty():
		inst.free()
		return null
	var ap := players[0] as AnimationPlayer
	var list := ap.get_animation_list()
	if list.is_empty():
		inst.free()
		return null
	var c := Clip.new()
	c.id = id
	c.anim = ap.get_animation(list[0])
	c.own = SrcSkel.new()
	c.own.setup(skels[0] as Skeleton3D)
	inst.free()
	c.settings = DEFS.get(id, {})
	c.start = float(c.settings.get("start", 0.0))
	c.end = minf(float(c.settings.get("end", c.anim.length)), c.anim.length)
	c.loop = bool(c.settings.get("loop", false))
	c.loop_blend = minf(float(c.settings.get("loop_blend", 0.0)), c.length() * 0.4)
	# tracks, by bone name
	var r := _ref
	c.rot_track.resize(c.own.names.size())
	c.rot_track.fill(-1)
	for t in c.anim.get_track_count():
		var path_s := String(c.anim.track_get_path(t))
		var bn := path_s.get_slice(":", path_s.get_slice_count(":") - 1).replace("mixamorig_", "")
		var b := c.own.bone(bn)
		if b < 0:
			continue
		match c.anim.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				c.rot_track[b] = t
			Animation.TYPE_POSITION_3D:
				if b == c.own.hips:
					c.hips_track = t
	# recorded on a different body (Thinking was): convert while sampling
	c.same_rest = c.own.names.size() == r.names.size()
	if c.same_rest:
		for i in r.names.size():
			if c.own.names[i] != r.names[i] or c.own.rest_q[i].angle_to(r.rest_q[i]) > 0.02:
				c.same_rest = false
				break
	if not c.same_rest:
		_line_up(c)
	_clips[id] = c
	# the steady drift / turn to take out
	if bool(c.settings.get("in_place", false)) and c.hips_track >= 0:
		var a := c.anim.position_track_interpolate(c.hips_track, c.start)
		var b2 := c.anim.position_track_interpolate(c.hips_track, c.end)
		c.drift = Vector3(b2.x - a.x, 0.0, b2.z - a.z) / maxf(c.length(), 0.01)
	if bool(c.settings.get("level_hips", false)):
		var tq: Array[Quaternion] = []
		tq.resize(r.names.size())
		var sum := 0.0
		for i in 16:
			sum += _raw(c, c.start + c.length() * i / 16.0, tq).y
		c.level_y = sum / 16.0 - r.rest_p[r.hips].y
	if bool(c.settings.get("bake_out_yaw", false)):
		var q0: Array[Quaternion] = []
		var q1: Array[Quaternion] = []
		q0.resize(r.names.size())
		q1.resize(r.names.size())
		_raw(c, c.start, q0)
		_raw(c, c.end - 0.001, q1)
		var f0: Vector3 = q0[r.hips] * Vector3.BACK
		var f1: Vector3 = q1[r.hips] * Vector3.BACK
		var turn := atan2(f1.x, f1.z) - atan2(f0.x, f0.z)
		c.yaw_rate = wrapf(turn, -PI, PI) / maxf(c.length(), 0.01)
	if c.settings.has("speed"):
		c.phase0 = _left_foot_forward(c)
	if bool(c.settings.get("still", false)):
		c.still_q.resize(r.names.size())
		c.still_p = _raw(c, 0.0, c.still_q)
		var fix := String(c.settings.get("fix", ""))
		if fix == "spock_upright":
			_fix_spock_upright(c.still_q)
	if c.settings.has("line_up_with"):
		var other := get_clip(String(c.settings["line_up_with"]))
		if other != null:
			var qa: Array[Quaternion] = []
			var qb: Array[Quaternion] = []
			qa.resize(r.names.size())
			qb.resize(r.names.size())
			var pa := _fixed(c, c.start, qa)
			var pb := _fixed(other, other.start, qb)
			var fa: Vector3 = qa[r.hips] * Vector3.BACK
			var fb: Vector3 = qb[r.hips] * Vector3.BACK
			c.align_yaw = wrapf(atan2(fb.x, fb.z) - atan2(fa.x, fa.z), -PI, PI)
			c.align_from = pa
			c.align_to = pb
			c.aligned = true
	# REV 192: "yaw" (degrees) turns the whole pose about the vertical through the hips
	if c.settings.has("yaw"):
		if not c.aligned:
			var qz: Array[Quaternion] = []
			qz.resize(r.names.size())
			var p0 := _fixed(c, c.start, qz)
			c.align_from = p0
			c.align_to = p0
			c.aligned = true
		c.align_yaw = wrapf(c.align_yaw + deg_to_rad(float(c.settings["yaw"])), -PI, PI)
	return c


## Where in a walking cycle the left foot is furthest ahead of the right (0..1), so walk, run and
## the rest can be blended in step.
static func _left_foot_forward(c: Clip) -> float:
	var r := _ref
	var lf := r.bone("LeftFoot")
	var rf := r.bone("RightFoot")
	var q: Array[Quaternion] = []
	q.resize(r.names.size())
	var g: Array[Quaternion] = []
	g.resize(r.names.size())
	var pos := PackedVector3Array()
	pos.resize(r.names.size())
	var best := -1.0e9
	var at := 0.0
	var steps := 48
	for k in steps:
		var u := float(k) / steps
		var hp := _fixed(c, c.start + u * c.period(), q)
		r.globals(q, g)
		r.positions(g, hp, pos)
		var ahead := pos[lf].z - pos[rf].z
		if ahead > best:
			best = ahead
			at = u
	return at


## A clip recorded on a different body may rest in a different pose (Thinking's body rests with its arms
## lower than the T-pose). Line its limbs up with the reference skeleton's rest first, so a turn of
## "arm 45 degrees down from rest" means the same on both.
static func _line_up(c: Clip) -> void:
	var r := _ref
	var own := c.own
	var n := own.names.size()
	var a: Array[Quaternion] = []
	a.resize(n)
	c.match_inv.resize(n)
	for i in own.order:
		var p := own.parent[i]
		var inherit := a[p] if p >= 0 else Quaternion.IDENTITY
		var nm := own.names[i]
		var q := inherit if (nm.contains("Arm") or nm.contains("Hand") or nm.contains("Shoulder") or nm.contains("Leg") or nm.contains("Foot") or nm.contains("Toe")) else Quaternion.IDENTITY
		if p >= 0 and q == inherit:
			var tip := _tip_of(nm)
			var oi := own.bone(tip)
			var ri := r.bone(nm)
			var rt := r.bone(tip)
			if oi >= 0 and ri >= 0 and rt >= 0:
				var d_own: Vector3 = (q * (own.rest_gp[oi] - own.rest_gp[i])).normalized()
				var d_ref: Vector3 = (r.rest_gp[rt] - r.rest_gp[ri]).normalized()
				if d_own.length() > 0.5 and d_ref.length() > 0.5:
					q = Quaternion(d_own, d_ref) * q
		a[i] = q
		c.match_inv[i] = (q * own.rest_gq[i]).inverse()


static func _tip_of(nm: String) -> String:
	var tips := {"Shoulder": "Arm", "Arm": "ForeArm", "ForeArm": "Hand", "UpLeg": "Leg", "Leg": "Foot", "Foot": "ToeBase", "ToeBase": "Toe_End"}
	for side in ["Left", "Right"]:
		if nm.begins_with(side):
			var rest := nm.substr(side.length())
			if tips.has(rest):
				return side + String(tips[rest])
			if rest == "Hand":
				return side + "HandMiddle1"
			if rest.begins_with("Hand") and rest.right(1).is_valid_int():
				return nm.left(nm.length() - 1) + str(int(rest.right(1)) + 1)
	return ""


static func _load_skeleton(id: String) -> Array:
	var path := DIR + id + ".fbx"
	if not ResourceLoader.exists(path):
		return []
	var packed := load(path) as PackedScene
	if packed == null:
		return []
	var inst := packed.instantiate()
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		inst.free()
		return []
	var s := SrcSkel.new()
	s.setup(skels[0] as Skeleton3D)
	inst.free()
	return [s]


# ---- sampling ----------------------------------------------------------------------------

## The pose at clip time t (seconds of the original clip), as local rotations on the reference
## skeleton, written into out_q. Returns the hips position (local). Loops wrap and crossfade their
## seam; one-shots hold their first/last frame outside start..end.
static func sample(c: Clip, t: float, out_q: Array[Quaternion]) -> Vector3:
	if not c.still_q.is_empty():
		for i in out_q.size():
			out_q[i] = c.still_q[i]
		return c.still_p
	if not c.loop:
		return _fixed(c, clampf(t, c.start, c.end - 0.0001), out_q)
	# REV 133: a loop whose ends don't quite meet repeats over (length - loop_blend) seconds, and its
	# first loop_blend seconds are faded in from the part just past the repeat point - continuous on
	# both sides of the seam. (Before, the fade ended loop_blend seconds ahead of where the clip then
	# carried on, so every loop jumped back about two frames - the run's little stutter.)
	var lb := c.loop_blend
	var per := c.period()
	var u := fposmod(t - c.start, per)
	var p := _fixed(c, c.start + u, out_q)
	if lb > 0.0 and u < lb:
		var w := u / lb
		w = w * w * (3.0 - 2.0 * w)
		var tmp: Array[Quaternion] = []
		tmp.resize(out_q.size())
		var p2 := _fixed(c, c.start + per + u, tmp)      # the clip's own tail
		for i in out_q.size():
			out_q[i] = tmp[i].slerp(out_q[i], w)
		p = p2.lerp(p, w)
	return p


## Sample with the clip's own fixes applied (drift and turn taken out).
static func _fixed(c: Clip, t: float, out_q: Array[Quaternion]) -> Vector3:
	var p := _raw(c, t, out_q)
	if c.settings.has("turn_upper"):
		var tu: Array = c.settings["turn_upper"]
		var w := 1.0 - clampf((t - float(tu[1])) / maxf(float(tu[2]) - float(tu[1]), 0.001), 0.0, 1.0)
		w = w * w * (3.0 - 2.0 * w)
		var sp := _ref.bone("Spine")
		if w > 0.0 and sp >= 0:
			var qh := out_q[_ref.hips]
			var qy2 := Quaternion(Vector3.UP, deg_to_rad(float(tu[0]) * w))
			out_q[sp] = (qh.inverse() * qy2 * qh * out_q[sp]).normalized()
	if c.aligned:
		var qy := Quaternion(Vector3.UP, c.align_yaw)
		out_q[_ref.hips] = (qy * out_q[_ref.hips]).normalized()
		var d := qy * Vector3(p.x - c.align_from.x, 0.0, p.z - c.align_from.z)
		p = Vector3(c.align_to.x + d.x, p.y, c.align_to.z + d.z)
	var dt := t - c.start
	p.y -= c.level_y
	if c.drift != Vector3.ZERO:
		p -= c.drift * dt
	if c.yaw_rate != 0.0:
		var h := _ref.hips
		out_q[h] = (Quaternion(Vector3.UP, -c.yaw_rate * dt) * out_q[h]).normalized()
		p = Quaternion(Vector3.UP, -c.yaw_rate * dt) * p
	return p


## The recorded pose, on the reference skeleton.
static func _raw(c: Clip, t: float, out_q: Array[Quaternion]) -> Vector3:
	var r := _ref
	var own := c.own
	var hips_p := own.rest_p[own.hips]
	if c.hips_track >= 0:
		hips_p = c.anim.position_track_interpolate(c.hips_track, t)
	if c.same_rest:
		for i in r.names.size():
			var tr := c.rot_track[i]
			out_q[i] = c.anim.rotation_track_interpolate(tr, t) if tr >= 0 else r.rest_q[i]
		return hips_p
	# a different body: carry each bone's turn (relative to its own rest) over to the reference body
	var n := own.names.size()
	var lq: Array[Quaternion] = []
	lq.resize(n)
	for i in n:
		var tr := c.rot_track[i]
		lq[i] = c.anim.rotation_track_interpolate(tr, t) if tr >= 0 else own.rest_q[i]
	var gq: Array[Quaternion] = []
	gq.resize(n)
	own.globals(lq, gq)
	var rg: Array[Quaternion] = []
	rg.resize(r.names.size())
	for i in r.order:
		var j := own.bone(r.names[i])
		if j >= 0:
			rg[i] = (gq[j] * c.match_inv[j]) * r.rest_gq[i]
		else:
			var p := r.parent[i]
			rg[i] = r.rest_gq[i] if p < 0 else rg[p] * r.rest_q[i]
	r.locals(rg, out_q)
	return r.rest_p[r.hips] + (hips_p - own.rest_p[own.hips]) * (r.hip_height / own.hip_height)


# ---- mirroring ---------------------------------------------------------------------------

## The same pose done by the other side of the body (a left turn becomes a right turn).
static func mirror(local_q: Array[Quaternion], hips_p: Vector3) -> Vector3:
	var r := _ref
	var n := r.names.size()
	var g: Array[Quaternion] = []
	g.resize(n)
	r.globals(local_q, g)
	var d: Array[Quaternion] = []
	d.resize(n)
	for i in n:
		var q: Quaternion = g[i] * r.rest_gq[i].inverse()
		d[i] = Quaternion(q.x, -q.y, -q.z, q.w)      # reflected in the body's middle (x = 0)
	for i in n:
		g[i] = d[r.mirror_of[i]] * r.rest_gq[i]
	r.locals(g, local_q)
	return Vector3(-hips_p.x, hips_p.y, hips_p.z)


# ---- masks -------------------------------------------------------------------------------

## Per-bone weights (reference skeleton) for playing a clip on part of the body.
##   full   everything
##   upper  from the waist up (the lower back blends in gradually)
##   head   neck and head
##   arm_r  the right arm (with the shoulder); arm_r_head the same and the head
##   arms_head  both arms and the head; tablet  the upper body with the right arm turned well down
static func mask(name_s: String) -> PackedFloat32Array:
	if _masks.has(name_s):
		return _masks[name_s]
	var r := ref()
	var w := PackedFloat32Array()
	w.resize(r.names.size())
	for i in r.names.size():
		var nm := r.names[i]
		var v := 1.0
		match name_s:
			"upper":
				if nm == "Hips" or nm.contains("UpLeg") or nm.contains("Leg") or nm.contains("Foot") or nm.contains("Toe"):
					v = 0.0
				elif nm == "Spine":
					v = 0.55
				elif nm == "Spine1":
					v = 0.8
			"head":
				v = 1.0 if (nm == "Neck" or nm == "Head") else 0.0
			"arm_r":
				v = 1.0 if nm.begins_with("Right") and not (nm.contains("Leg") or nm.contains("Foot") or nm.contains("Toe")) else 0.0
			"arms_head":
				v = 1.0 if (nm == "Neck" or nm == "Head" or nm.contains("Shoulder") or nm.contains("Arm") or nm.contains("Hand")) else 0.0
			"arm_r_head":
				v = 1.0 if (nm == "Neck" or nm == "Head" or (nm.begins_with("Right") and not (nm.contains("Leg") or nm.contains("Foot") or nm.contains("Toe")))) else 0.0
			"tablet":
				# the tricorder: everything from the waist up, the busy right arm only a little
				if nm == "Hips" or nm.contains("UpLeg") or nm.contains("Leg") or nm.contains("Foot") or nm.contains("Toe"):
					v = 0.0
				elif nm == "Spine":
					v = 0.55
				elif nm == "Spine1":
					v = 0.8
				elif nm.begins_with("Right") and (nm.contains("Arm") or nm.contains("Hand")):
					v = 0.38
		w[i] = v
	_masks[name_s] = w
	return w


# ---- fixes -------------------------------------------------------------------------------

## Glen: "he appears a little hunched over". The back straightened (about 5 degrees at each part of
## the spine), the chin up 7 degrees and the shoulders drawn back a little.
## Spock's stance straightening (degrees; negative = back): spine, spine1, spine2, neck, head; and a
## small sideways roll (+ = toward his right).
const SPOCK_BACK := [1.0, 0.0, 0.0, -1.0, -1.0]
const SPOCK_ROLL := 1.5

static func _fix_spock_upright(q: Array[Quaternion]) -> void:
	var r := _ref
	var g: Array[Quaternion] = []
	g.resize(q.size())
	r.globals(q, g)
	# REV 146: retuned on the real (Daz) Spock - the old amounts were set for the blocky stand-in and
	# left him leaning about 11 degrees back (chest puffed out) and 1.5 degrees to his left.
	var turns := {
		"Spine": Quaternion(Vector3.RIGHT, deg_to_rad(SPOCK_BACK[0])) * Quaternion(Vector3.BACK, deg_to_rad(SPOCK_ROLL)),
		"Spine1": Quaternion(Vector3.RIGHT, deg_to_rad(SPOCK_BACK[1])),
		"Spine2": Quaternion(Vector3.RIGHT, deg_to_rad(SPOCK_BACK[2])),
		"Neck": Quaternion(Vector3.RIGHT, deg_to_rad(SPOCK_BACK[3])),
		"Head": Quaternion(Vector3.RIGHT, deg_to_rad(SPOCK_BACK[4])),
		"LeftShoulder": Quaternion(Vector3.UP, deg_to_rad(5.0)),
		"RightShoulder": Quaternion(Vector3.UP, deg_to_rad(-5.0)),
	}
	_turn_subtrees(g, turns)
	r.locals(g, q)


## Turn bones (and everything below them) by extra rotations given in skeleton space.
static func _turn_subtrees(g: Array[Quaternion], turns: Dictionary) -> void:
	var r := _ref
	var extra: Array[Quaternion] = []
	extra.resize(g.size())
	for i in r.order:
		var p := r.parent[i]
		var e := extra[p] if p >= 0 else Quaternion.IDENTITY
		var nm := r.names[i]
		if turns.has(nm):
			e = (turns[nm] as Quaternion) * e
		extra[i] = e
		g[i] = (e * g[i]).normalized()


## Two-bone leg reach: turn the thigh and knee so the ankle lands on `target` (skeleton space),
## keeping the knee bending the way it already does, and keep the foot's own turn. Works on
## skeleton-space rotations `g` and joint positions `pos` (updated).
## REV 171: two-bone arm reach - turn the upper arm and forearm so the wrist lands on `target`
## (skeleton space), keeping the elbow bending the way it already does. Updates `pos` for the arm.
static func reach_arm(g: Array[Quaternion], pos: PackedVector3Array, side: String, target: Vector3) -> void:
	var r := _ref
	var up := r.bone(side + "Arm")
	var el := r.bone(side + "ForeArm")
	var wr := r.bone(side + "Hand")
	if up < 0 or el < 0 or wr < 0:
		return
	var a := r.rest_p[el].length()
	var b := r.rest_p[wr].length()
	var sh := pos[up]
	var d := clampf(sh.distance_to(target), absf(a - b) + 0.0001, a + b - 0.0001)
	var elbow := pos[el]
	var wrist := pos[wr]
	var cur := (sh - elbow).angle_to(wrist - elbow)
	var want := acos(clampf((a * a + b * b - d * d) / (2.0 * a * b), -1.0, 1.0))
	var axis := (sh - elbow).cross(wrist - elbow)
	if axis.length() < 0.000001:
		axis = Vector3.UP
	axis = axis.normalized()
	var bend := Quaternion(axis, want - cur)
	g[el] = (bend * g[el]).normalized()
	wrist = elbow + bend * (wrist - elbow)
	if (wrist - sh).length() < 0.0001 or (target - sh).length() < 0.0001:
		return
	var swing := Quaternion((wrist - sh).normalized(), (target - sh).normalized())
	g[up] = (swing * g[up]).normalized()
	g[el] = (swing * g[el]).normalized()
	pos[el] = sh + swing * (elbow - sh)
	pos[wr] = sh + swing * (wrist - sh)


static func reach_leg(g: Array[Quaternion], pos: PackedVector3Array, side: String, target: Vector3, foot_g: Quaternion) -> void:
	var r := _ref
	var up := r.bone(side + "UpLeg")
	var kn := r.bone(side + "Leg")
	var ft := r.bone(side + "Foot")
	if up < 0 or kn < 0 or ft < 0:
		return
	var a := r.rest_p[kn].length()
	var b := r.rest_p[ft].length()
	var hip := pos[up]
	var d := clampf(hip.distance_to(target), absf(a - b) + 0.0001, a + b - 0.0001)
	var knee := pos[kn]
	var ankle := pos[ft]
	# 1. bend the knee to the right angle
	var cur := (hip - knee).angle_to(ankle - knee)
	var want := acos(clampf((a * a + b * b - d * d) / (2.0 * a * b), -1.0, 1.0))
	var axis := (hip - knee).cross(ankle - knee)
	if axis.length() < 0.000001:
		axis = (g[up] * Vector3.RIGHT)
	axis = axis.normalized()
	# REV 146: was (cur - want), which turned the shin the wrong way - straightening the leg when it
	# had to bend, so a lowered body pushed the feet through the floor
	var bend := Quaternion(axis, want - cur)
	g[kn] = (bend * g[kn]).normalized()
	ankle = knee + bend * (ankle - knee)
	# 2. swing the whole leg so the ankle points at the target
	if (ankle - hip).length() < 0.0001 or (target - hip).length() < 0.0001:
		return
	var swing := Quaternion((ankle - hip).normalized(), (target - hip).normalized())
	g[up] = (swing * g[up]).normalized()
	g[kn] = (swing * g[kn]).normalized()
	pos[kn] = hip + swing * (knee - hip)
	pos[ft] = hip + swing * (ankle - hip)
	g[ft] = foot_g
	var toe := r.bone(side + "ToeBase")
	if toe >= 0:
		pos[toe] = pos[ft] + g[ft] * r.rest_p[toe]
