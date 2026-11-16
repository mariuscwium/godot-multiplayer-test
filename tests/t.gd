class_name T extends RefCounted
# Minimal assertion helpers; failures are collected and reported by run_tests.gd.
static var fails: Array = []

static func eq(actual, expected, msg: String = "") -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		return
	fails.append("%s: expected %s, got %s" % [msg, str(expected), str(actual)])

static func ok(cond: bool, msg: String = "") -> void:
	if not cond:
		fails.append(msg)

static func near(actual: float, expected: float, eps: float, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		fails.append("%s: expected %f +/- %f, got %f" % [msg, expected, eps, actual])
