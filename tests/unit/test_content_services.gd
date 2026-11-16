extends "res://tests/test_suite.gd"


func _run() -> void:
	var catalog := load("res://content/catalog.tres") as GameCatalog
	expect(catalog != null and catalog.validate().is_empty(), "All shipped content validates")
	expect(
		catalog.level_by_id("training").rules.size() == 1, "Second level supplies its own objective"
	)
	expect(
		catalog.skin_by_id("sunset") != null and catalog.level_by_id("missing") == null,
		"Catalog lookup is explicit"
	)
	var bad := SnakeLevel.new()
	bad.initial_body.append(bad.initial_body[0])
	expect(not bad.validate().is_empty(), "Duplicate body rejected")
	bad = SnakeLevel.new()
	bad.obstacles = [bad.first_food]
	expect(not bad.validate().is_empty(), "Food/obstacle overlap rejected")
	bad = SnakeLevel.new()
	bad.step_seconds = NAN
	expect(not bad.validate().is_empty(), "Nonfinite timing rejected")
	var definition := load("res://content/tutorials/basic_controls.tres") as TutorialDefinition
	var tutorial := TutorialRunner.new()
	tutorial.start(definition)
	tutorial.notify("food")
	expect(tutorial.index == 0, "Out-of-order tutorial events ignored")
	tutorial.notify("move")
	expect(
		tutorial.index == 1 and "Release" in tutorial.instruction(),
		"Tutorial advances by semantic event"
	)
	tutorial.notify("move")
	expect(tutorial.index == 1, "Repeated hold does not complete release step")
	tutorial.notify("stop")
	tutorial.notify("food")
	expect(
		tutorial.index == 3 and tutorial.instruction().is_empty(),
		"Tutorial completes without adding gameplay conditionals"
	)
	tutorial.start(definition)
	expect(
		tutorial.index == 0 and definition.steps.size() == 3,
		"Tutorial can replay without mutating definition"
	)
	var store := ProfileStore.new()
	store.path = "user://test-profile-%d.json" % Time.get_ticks_usec()
	store.record_score("classic", 30)
	store.record_score("classic", 10)
	store.complete_tutorial("basic_controls")
	var loaded := ProfileStore.new()
	loaded.path = store.path
	loaded.load_profile()
	expect(
		(
			loaded.best_scores.get("classic") == 30
			and loaded.completed_tutorials.has("basic_controls")
		),
		"Profile preserves best and tutorial progress"
	)
	# Corrupt the primary; a previous completed write is retained as backup.
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	loaded = ProfileStore.new()
	loaded.path = store.path
	loaded.load_profile()
	expect(
		loaded.best_scores.get("classic") == 30, "Corrupted primary recovers previous valid backup"
	)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(store.path + suffix):
			DirAccess.remove_absolute(store.path + suffix)
	finish()
