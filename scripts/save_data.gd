class_name SaveData
extends RefCounted
## What is kept between sessions (user://save.json): the mode and options last used, and the totals for each way of
## playing. A "variant" is a mode plus its lives setting (Modes.variant), because three lives is a different game
## from one.
##
## Totals per variant: runs played, machines cleared, best score, furthest machine, best streak, and how many streaks
## of each size have ended ("streaks": {"3": 12} = twelve streaks that got to x3 and stopped there).

const PATH := "user://save.json"
const VERSION := 1

var mode := "traditional"
var lives_on := {"traditional": false, "zen": false}
var sound := true
var haptics := true
var stats := {}


static func empty_stats() -> Dictionary:
	return {"runs": 0, "machines": 0, "best_score": 0, "best_machine": 0, "best_streak": 1, "streaks": {}}


func stats_for(variant: String) -> Dictionary:
	if not stats.has(variant):
		stats[variant] = empty_stats()
	return stats[variant]


func lives_for(for_mode: String) -> bool:
	return bool(lives_on.get(for_mode, false))


## A streak came to an end at `mult` (x2 or more).
func record_streak(variant: String, mult: int) -> void:
	if mult < 2:
		return
	var s := stats_for(variant)
	var key := str(mult)
	s.streaks[key] = int(s.streaks.get(key, 0)) + 1
	s.best_streak = maxi(int(s.best_streak), mult)


## A run ended. Returns true if its score is this variant's best.
func record_run(variant: String, score: int, machines: int, machine_reached: int) -> bool:
	var s := stats_for(variant)
	s.runs = int(s.runs) + 1
	s.machines = int(s.machines) + machines
	s.best_machine = maxi(int(s.best_machine), machine_reached)
	var best := score > int(s.best_score) and score > 0
	if best:
		s.best_score = score
	return best


func load_file() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	if Modes.LIST.has(data.get("mode")):
		mode = data.mode
	var saved_lives: Variant = data.get("lives_on")
	if typeof(saved_lives) == TYPE_DICTIONARY:
		for key: String in lives_on:
			lives_on[key] = bool(saved_lives.get(key, false))
	sound = bool(data.get("sound", true))
	haptics = bool(data.get("haptics", true))
	var saved_stats: Variant = data.get("stats")
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for variant: String in saved_stats:
			var raw: Variant = saved_stats[variant]
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var clean := empty_stats()
			for key: String in ["runs", "machines", "best_score", "best_machine", "best_streak"]:
				clean[key] = maxi(int(raw.get(key, clean[key])), int(clean[key]))
			var raw_streaks: Variant = raw.get("streaks")
			if typeof(raw_streaks) == TYPE_DICTIONARY:
				for size: String in raw_streaks:
					if size.is_valid_int() and int(raw_streaks[size]) > 0:
						clean.streaks[size] = int(raw_streaks[size])
			stats[variant] = clean


func save_file() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"version": VERSION, "mode": mode, "lives_on": lives_on, "sound": sound, "haptics": haptics, "stats": stats}))
