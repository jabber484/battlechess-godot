class_name ResourceStackBar
extends Control

## Segmented resource bar. For mana: Available / Charging / Used (+ empty remainder).
## Optional hover preview: Available→Charging lock, or Charging→Used commit.

const COLOR_AVAILABLE := Color(0.45, 0.55, 0.95)
const COLOR_CHARGING := Color(0.95, 0.75, 0.25)
const COLOR_USED := Color(0.55, 0.35, 0.65)
const COLOR_PREVIEW_LOCK := Color(1.0, 0.85, 0.35) # Available about to lock
const COLOR_PREVIEW_COMMIT := Color(0.85, 0.45, 0.95) # Charging about to Used

var _max_amount: int = 1
var _segments: Array[Dictionary] = [] # { "amount": int, "color": Color }


func set_single(current: int, max_amount: int, fill: Color, preview_spend: int = 0) -> void:
	_max_amount = maxi(1, max_amount)
	var cur := maxi(0, current)
	var spend := clampi(preview_spend, 0, cur)
	if spend > 0:
		_segments = [
			{"amount": cur - spend, "color": fill},
			{"amount": spend, "color": COLOR_PREVIEW_COMMIT},
		]
	else:
		_segments = [{"amount": cur, "color": fill}]
	queue_redraw()


func set_mana(
	available: int,
	charging: int,
	used: int,
	max_amount: int,
	preview_lock: int = 0,
	preview_commit: int = 0,
) -> void:
	_max_amount = maxi(1, max_amount)
	var avail := maxi(0, available)
	var charge := maxi(0, charging)
	var used_amt := maxi(0, used)
	var lock := clampi(preview_lock, 0, avail)
	var commit := clampi(preview_commit, 0, charge)
	_segments = [
		{"amount": avail - lock, "color": COLOR_AVAILABLE},
		{"amount": lock, "color": COLOR_PREVIEW_LOCK},
		{"amount": charge - commit, "color": COLOR_CHARGING},
		{"amount": commit, "color": COLOR_PREVIEW_COMMIT},
		{"amount": used_amt, "color": COLOR_USED},
	]
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var bg := Color(0.1, 0.1, 0.12, 0.9)
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	if _max_amount <= 0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var x := 0.0
	for segment in _segments:
		var amount: int = int(segment.get("amount", 0))
		if amount <= 0:
			continue
		var w := size.x * (float(amount) / float(_max_amount))
		w = minf(w, size.x - x)
		if w <= 0.0:
			break
		draw_rect(Rect2(x, 0.0, w, size.y), segment["color"] as Color)
		x += w
