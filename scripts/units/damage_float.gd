class_name DamageFloat
extends Node3D


@onready var _label: Label3D = $Label3D


func play(amount: int) -> void:
	play_text("- %d" % amount, Color(1, 0.4, 0.35, 1))


func play_miss() -> void:
	play_text("MISS", Color(0.82, 0.82, 0.88, 1))


func play_text(text: String, color: Color) -> void:
	_label.text = text
	_label.modulate = color
	var start_y := position.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", start_y + 0.9, 0.85)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_label, "modulate:a", 0.0, 0.85).set_delay(0.15)
	await tween.finished
	queue_free()
