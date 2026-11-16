class_name ProfileStore
extends RefCounted
## Versioned local progress. Writes happen on milestones, never in the frame loop.
const SCHEMA := 1
var path := "user://profile.json"
var enabled := true
var best_scores: Dictionary = {}
var completed_tutorials: Array[String] = []
var selected_skin := "mint"


func load_profile() -> void:
	if not enabled:
		return
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK:
			continue
		var parsed = parser.data
		if not parsed is Dictionary or parsed.get("schema", 0) != SCHEMA:
			continue
		if (
			not parsed.get("best_scores", {}) is Dictionary
			or not parsed.get("tutorials", []) is Array
		):
			continue
		for id in parsed.get("best_scores", {}):
			var score = parsed.best_scores[id]
			if score is float or score is int:
				best_scores[str(id)] = maxi(0, int(score))
		for id in parsed.get("tutorials", []):
			if id is String and not completed_tutorials.has(id):
				completed_tutorials.append(id)
		if parsed.get("skin", "mint") is String:
			selected_skin = parsed.get("skin", "mint")
		return


func record_score(level_id: String, score: int) -> void:
	if score > int(best_scores.get(level_id, 0)):
		best_scores[level_id] = score
		save_profile()


func complete_tutorial(id: String) -> void:
	if not completed_tutorials.has(id):
		completed_tutorials.append(id)
		save_profile()


func save_profile() -> Error:
	if not enabled:
		return OK
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(
		JSON.stringify(
			{
				"schema": SCHEMA,
				"best_scores": best_scores,
				"tutorials": completed_tutorials,
				"skin": selected_skin
			}
		)
	)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		error = DirAccess.rename_absolute(path, path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(temporary, path)
