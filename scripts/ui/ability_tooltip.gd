class_name AbilityTooltip
extends PanelContainer

## Floating ability-bar tooltip: title, meta lines, body. mouse_filter IGNORE so hover stays on the button.

const GAP_ABOVE := 6.0
## Comfortable wrap width — wide enough that body text stays short in height.
const WIDTH := 260.0

@onready var _title: Label = %TitleLabel
@onready var _meta: Label = %MetaLabel
@onready var _body: Label = %BodyLabel

var _pending_anchor: Rect2 = Rect2()
## Bumped on hide / newer show so an in-flight layout await can abort.
var _show_token: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_meta.custom_minimum_size = Vector2(WIDTH, 0)
	_body.custom_minimum_size = Vector2(WIDTH, 0)
	custom_minimum_size = Vector2(WIDTH + 12.0, 0)


func show_for(ability: AbilityData, anchor_global: Rect2) -> void:
	if ability == null:
		hide_tooltip()
		return
	_show_token += 1
	var token := _show_token
	_title.text = ability.get_tooltip_title()
	var meta_lines := ability.get_tooltip_meta_lines()
	_meta.text = " · ".join(meta_lines)
	_meta.visible = not meta_lines.is_empty()
	var body := ability.get_tooltip_body()
	_body.text = body
	_body.visible = not body.is_empty()
	_meta.custom_minimum_size = Vector2(WIDTH, 0)
	_body.custom_minimum_size = Vector2(WIDTH, 0)
	custom_minimum_size = Vector2(WIDTH + 12.0, 0)
	_pending_anchor = anchor_global
	# Invisible controls skip layout — show (transparent) first, wait a frame for size, then place.
	modulate.a = 0.0
	visible = true
	size = Vector2(WIDTH + 12.0, 0)
	reset_size()
	await get_tree().process_frame
	if token != _show_token:
		return
	reset_size()
	_place_above(_pending_anchor)
	modulate.a = 1.0


func hide_tooltip() -> void:
	_show_token += 1
	visible = false
	modulate.a = 1.0


func _place_above(anchor_global: Rect2) -> void:
	var panel_size := size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = get_combined_minimum_size()
	if panel_size.x <= 0.0:
		panel_size.x = WIDTH + 12.0
	if panel_size.y <= 0.0:
		panel_size.y = 48.0

	var viewport := get_viewport().get_visible_rect()
	var x := anchor_global.position.x + (anchor_global.size.x - panel_size.x) * 0.5
	var y := anchor_global.position.y - panel_size.y - GAP_ABOVE
	x = clampf(x, viewport.position.x + 8.0, viewport.end.x - panel_size.x - 8.0)
	if y < viewport.position.y + 8.0:
		y = anchor_global.end.y + GAP_ABOVE
	y = clampf(y, viewport.position.y + 8.0, viewport.end.y - panel_size.y - 8.0)
	global_position = Vector2(x, y)
