class_name DevProfiler
extends RefCounted

static var enabled: bool = false
static var stats: Dictionary = {}
static var samples: Dictionary = {}


static func reset() -> void:
	stats.clear()
	samples.clear()


static func start(_label: String) -> int:
	if not enabled:
		return 0
	return Time.get_ticks_usec()


static func stop(label: String, started_at_usec: int) -> void:
	if not enabled or started_at_usec <= 0:
		return
	var elapsed_usec: int = Time.get_ticks_usec() - started_at_usec
	var entry: Dictionary = stats.get(label, {
		"count": 0,
		"total_usec": 0,
		"max_usec": 0,
	})
	entry.count = int(entry.count) + 1
	entry.total_usec = int(entry.total_usec) + elapsed_usec
	entry.max_usec = maxi(int(entry.max_usec), elapsed_usec)
	stats[label] = entry


static func sample(label: String, value_usec: int) -> void:
	if not enabled or value_usec < 0:
		return
	var entry: Dictionary = samples.get(label, {
		"values": [],
		"total_usec": 0,
		"max_usec": 0,
	})
	(entry.values as Array).append(value_usec)
	entry.total_usec = int(entry.total_usec) + value_usec
	entry.max_usec = maxi(int(entry.max_usec), value_usec)
	samples[label] = entry


static func report() -> String:
	if stats.is_empty() and samples.is_empty():
		return "No profiling samples collected."

	var rows: Array = []
	for label in stats.keys():
		var entry: Dictionary = stats[label]
		var count: int = int(entry.get("count", 0))
		var total_usec: int = int(entry.get("total_usec", 0))
		var max_usec: int = int(entry.get("max_usec", 0))
		var avg_usec: float = float(total_usec) / float(maxi(1, count))
		rows.append({
			"label": label,
			"count": count,
			"total_usec": total_usec,
			"avg_usec": avg_usec,
			"max_usec": max_usec,
		})

	rows.sort_custom(func(a, b): return int(a.total_usec) > int(b.total_usec))

	var lines: Array[String] = ["=== Chunk Movement Profile ==="]
	for row in rows:
		lines.append(
			"%s | calls=%d avg=%.3fms max=%.3fms total=%.3fms" % [
				str(row.label),
				int(row.count),
				float(row.avg_usec) / 1000.0,
				float(row.max_usec) / 1000.0,
				float(row.total_usec) / 1000.0,
			]
		)
	if not samples.is_empty():
		lines.append("=== Sampled Timing ===")
		var sample_rows: Array = []
		for label in samples.keys():
			var entry: Dictionary = samples[label]
			var values: Array = (entry.get("values", []) as Array).duplicate()
			values.sort()
			var count: int = values.size()
			var total_usec: int = int(entry.get("total_usec", 0))
			var max_usec: int = int(entry.get("max_usec", 0))
			var avg_usec: float = float(total_usec) / float(maxi(1, count))
			var p95_idx: int = clampi(int(ceil(float(count) * 0.95)) - 1, 0, maxi(0, count - 1))
			var p95_usec: int = int(values[p95_idx]) if count > 0 else 0
			var spikes_over_16ms: int = 0
			var spikes_over_33ms: int = 0
			for value in values:
				if int(value) > 16667:
					spikes_over_16ms += 1
				if int(value) > 33333:
					spikes_over_33ms += 1
			sample_rows.append({
				"label": label,
				"count": count,
				"avg_usec": avg_usec,
				"p95_usec": p95_usec,
				"max_usec": max_usec,
				"spikes_16": spikes_over_16ms,
				"spikes_33": spikes_over_33ms,
			})
		sample_rows.sort_custom(func(a, b): return float(a.max_usec) > float(b.max_usec))
		for row in sample_rows:
			lines.append(
				"%s | samples=%d avg=%.3fms p95=%.3fms max=%.3fms >16.7ms=%d >33.3ms=%d" % [
					str(row.label),
					int(row.count),
					float(row.avg_usec) / 1000.0,
					float(row.p95_usec) / 1000.0,
					float(row.max_usec) / 1000.0,
					int(row.spikes_16),
					int(row.spikes_33),
				]
			)
	return "\n".join(lines)
