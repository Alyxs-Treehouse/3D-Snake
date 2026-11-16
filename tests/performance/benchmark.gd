extends SceneTree
## CPU submission benchmark only. Headless results are NOT GPU/headset FPS claims.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var results: Array[Dictionary] = []
	var level := SnakeLevel.new()
	var skin := SnakeSkin.new()
	for count in [3, 64, 256, 512]:
		var cells: Array[Vector3i] = []
		for i in count:
			cells.append(Vector3i(i % 8, (i / 8) % 8, i / 64))
		var renderer := SnakeRenderer.new()
		root.add_child(renderer)
		renderer.configure(level, skin)
		renderer.sync(cells, Vector3i.RIGHT, true)
		renderer.sync(cells, Vector3i.RIGHT)
		results.append(measure(renderer, count, "multimesh"))
		renderer.free()
		if "--compare-baseline" in OS.get_cmdline_user_args():
			var script = load("res://.cache/baseline-0.3.3/scripts/board_view.gd")
			var legacy = script.new()
			root.add_child(legacy)
			legacy.sync(cells, Vector3i(4, 4, 4), Vector3i.RIGHT, true)
			legacy.sync(cells, Vector3i(4, 4, 4), Vector3i.RIGHT)
			results.append(measure(legacy, count, "baseline_0.3.3"))
			legacy.free()
	var report := {
		"scope": "Headless CPU transform submission; not GPU or headset frame time",
		"engine": Engine.get_version_info().string,
		"platform": OS.get_name(),
		"results": results
	}
	DirAccess.make_dir_recursive_absolute("res://builds")
	var file := FileAccess.open("res://builds/performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	quit()


func measure(renderer: Node3D, count: int, implementation: String) -> Dictionary:
	var samples: Array[int] = []
	for i in 300:
		var started := Time.get_ticks_usec()
		renderer.animate(float(i % 71) / 71.0)
		var elapsed := Time.get_ticks_usec() - started
		if i >= 60:
			samples.append(elapsed)
	samples.sort()
	return {
		"implementation": implementation,
		"segments": count,
		"render_nodes":
		(
			renderer.get_child_count()
			if implementation == "multimesh"
			else renderer.bodies.size() + renderer.links.size() + 1
		),
		"median_us": samples[samples.size() / 2],
		"p95_us": samples[int(samples.size() * 0.95)]
	}
