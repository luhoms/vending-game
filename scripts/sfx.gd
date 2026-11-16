class_name Sfx
extends Node
## All the sound: a small pool of players, and the vending machine's three little tunes, as in the Roblox version's
## SoundManager (a ping one step up a major pentatonic scale per correct hit, an arpeggio when all six are lit, a fail
## blip with a low thud for a mistake). The sounds themselves are in assets/sfx (made by tools/make_sounds.py).

const NAMES: Array[String] = ["ding", "sparkle", "complete", "coin", "error", "tick", "whoosh", "powerup", "clank", "boom"]
const VOICES := 20

var muted := false
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for sound in NAMES:
		var path := "res://assets/sfx/%s.wav" % sound
		if ResourceLoader.exists(path):
			_streams[sound] = load(path)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Play a sound at a pitch (1 = as recorded) and volume (0-1).
func play(sound: String, pitch := 1.0, volume := 1.0) -> void:
	if muted or not _streams.has(sound) or volume <= 0.0:
		return
	var player: AudioStreamPlayer = null
	for i in VOICES:
		var candidate := _players[(_next + i) % VOICES]
		if not candidate.playing:
			player = candidate
			_next = (_next + i + 1) % VOICES
			break
	if player == null: # every voice busy: take the oldest
		player = _players[_next]
		_next = (_next + 1) % VOICES
	player.stream = _streams[sound]
	player.pitch_scale = clampf(pitch, 0.05, 8.0)
	player.volume_db = linear_to_db(volume)
	player.play()


func _later(seconds: float, action: Callable) -> void:
	get_tree().create_timer(seconds).timeout.connect(action)


## A correct hit: a bright ping one step higher than the last, with a soft shimmer under it.
func vend_hit(count: int) -> void:
	var step := Fx.HIT_SCALE[clampi(count, 1, Fx.HIT_SCALE.size()) - 1]
	play("ding", Fx.semitones(step), Fx.DING_VOLUME)
	play("sparkle", Fx.SPARKLE_PITCH * Fx.semitones(step), Fx.SPARKLE_VOLUME)


## All six lit: a quick four-note arpeggio off the top of the scale, then the gold pick-up and a coin.
func vend_complete() -> void:
	for i in Fx.CLEAR_ARPEGGIO.size():
		var step := Fx.CLEAR_ARPEGGIO[i]
		var volume := 0.55 + (i + 1) * 0.05
		_later(i * Fx.ARPEGGIO_STEP, func() -> void: play("ding", Fx.semitones(step), volume * Fx.DING_VOLUME))
	var pick_up := func() -> void:
		play("complete", 1.0, Fx.COMPLETE_VOLUME)
		play("coin", 1.0, 0.5)
	_later(Fx.ARPEGGIO_STEP * 3.0, pick_up)


## A mistake (or a bomb): a short fail blip with a low thud under it.
func vend_error() -> void:
	play("error", 1.0, Fx.ERROR_VOLUME)
	play("ding", 0.32, 0.7 * Fx.DING_VOLUME)


func tick() -> void:
	play("tick", 1.0, Fx.TICK_VOLUME)
