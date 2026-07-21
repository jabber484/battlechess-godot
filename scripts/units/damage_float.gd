class_name DamageFloat
extends Node3D


@onready var _label: Label3D = $Label3D


func play(amount: int) -> void:
	_label.text = "-%d" % amount
	var start_y := position.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", start_y + 0.9, 0.85)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_label, "modulate:a", 0.0, 0.85).set_delay(0.15)
	await tween.finished
	queue_free()
