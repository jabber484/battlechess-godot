class_name AbilityTooltip
extends PanelContainer

## Floating ability-bar tooltip: title, meta lines, body. mouse_filter IGNORE so hover stays on the button.

const GAP_ABOVE := 8.0
const MIN_WIDTH := 220.0

@onready var _title: Label = %TitleLabel
@onready var _meta: Label = %MetaLabel
@onready var _body: Label = %BodyLabel

var _pending_anchor: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	custom_minimum_size = Vector2(MIN_WIDTH, 0)


func show_for(ability: AbilityData, anchor_global: Rect2) -> void:
	if ability == null:
		hide_tooltip()
		return
	_title.text = ability.get_tooltip_title()
	var meta_lines := ability.get_tooltip_meta_lines()
	_meta.text = " · ".join(meta_lines)
	_meta.visible = not meta_lines.is_empty()
	var body := ability.get_tooltip_body()
	_body.text = body
	_body.visible = not body.is_empty()
	_pending_anchor = anchor_global
	visible = true
	call_deferred("_place_above_pending")


func hide_tooltip() -> void:
	visible = false


func _place_above_pending() -> void:
	if not visible:
		return
	_place_above(_pending_anchor)


func _place_above(anchor_global: Rect2) -> void:
	var panel_size := size
	if panel_size.x < MIN_WIDTH:
		panel_size.x = MIN_WIDTH
	if panel_size.y <= 0.0:
		panel_size = get_combined_minimum_size()
		if panel_size.x < MIN_WIDTH:
			panel_size.x = MIN_WIDTH

	var viewport := get_viewport().get_visible_rect()
	var x := anchor_global.position.x + (anchor_global.size.x - panel_size.x) * 0.5
	var y := anchor_global.position.y - panel_size.y - GAP_ABOVE
	x = clampf(x, viewport.position.x + 8.0, viewport.end.x - panel_size.x - 8.0)
	if y < viewport.position.y + 8.0:
		y = anchor_global.end.y + GAP_ABOVE
	y = clampf(y, viewport.position.y + 8.0, viewport.end.y - panel_size.y - 8.0)
	global_position = Vector2(x, y)
