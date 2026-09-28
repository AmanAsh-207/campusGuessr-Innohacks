extends Control 
class_name MapContainerWidget


signal marker_placed(normalized: Vector2)
signal marker_removed()

const BASE_SCALE := 0.245  

var zoom := 1.0             
var is_zooming := false
const MIN_ZOOM := 0.25
const MAX_ZOOM := 2.0
const ZOOM_STEP := 1.2 	
var dragging := false
var last_mouse_pos := Vector2.ZERO

@export var pan_overshoot_x: float = 100.0
@export var pan_overshoot_y: float = 50.0

# Other controls (e.g. the Guess button) that should NOT trigger a collapse
# when the mouse moves over them. Set this from the parent scene's script,
# e.g. map_container.linked_controls = [guess_button]
var linked_controls: Array[Control] = []

func _mouse_is_over_linked_control() -> bool:
	var mouse_pos := get_global_mouse_position()
	for c in linked_controls:
		if is_instance_valid(c) and c.visible and c.get_global_rect().has_point(mouse_pos):
			return true
	return false

@onready var map: Sprite2D = $mapRoot/Map
@onready var marker: Sprite2D = $mapRoot/Marker
@onready var answer_marker: Sprite2D = $mapRoot/AnswerMarker
@onready var distance_line: Line2D = $mapRoot/DistanceLine
@onready var map_root: Node2D = $mapRoot
@onready var texture_rect: TextureRect = $TextureRect

signal expanded()
signal collapsed()




const EXPANDED_SIZE := Vector2(560, 560)
const EXPAND_DURATION := 0.3

var collapsed_position: Vector2
var collapsed_size: Vector2
var is_expanded := false

const MARKER_CLICK_TOLERANCE := 10.0

var locked := false

var last_guess_normalized := Vector2.ZERO

var map_root_start_pos: Vector2
func _ready() -> void:
	
	collapsed_position = position
	collapsed_size = size
	map_root_start_pos = map_root.position
	map_root.scale = Vector2.ONE * BASE_SCALE
	answer_marker.visible = false
	distance_line.visible = false
	marker.visible = false

func _process(_delta):
	var inside = get_global_rect().has_point(get_global_mouse_position())
	inside = inside or _mouse_is_over_linked_control()

	if inside and !is_expanded:
		_expand()
	elif !inside and is_expanded and !dragging:
		_collapse()

	if dragging and !Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		dragging = false
		if !inside:
			_collapse()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at_mouse(event.position,ZOOM_STEP)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at_mouse(event.position,1.0 / ZOOM_STEP)

		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not locked:
				_handle_marker_click(event.position)
			
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
			
	if event is InputEventMouseMotion and dragging:
		map_root.position += event.relative
		clamp_map()

func _on_mouse_exited() -> void:
	await get_tree().process_frame

	if get_global_rect().has_point(get_global_mouse_position()):
		return

	if _mouse_is_over_linked_control():
		return

	if dragging:
		return

	_collapse()

func _handle_marker_click(click_pos: Vector2) -> void:

	var local_pos = (click_pos - map_root.position) / map_root.scale

	var tex_size = map.texture.get_size()
	var texture_pos = local_pos + tex_size * 0.5

	if marker.visible:
		var tolerance = 20.0 / zoom
		if local_pos.distance_to(marker.position) < tolerance:
			marker.visible = false
			marker_removed.emit()
			return

	marker.position = local_pos
	marker.visible = true

	var normalized = Vector2(
		texture_pos.x / tex_size.x,
		texture_pos.y / tex_size.y
	)
	last_guess_normalized = normalized
	marker_placed.emit(normalized)


func _normalized_to_local(normalized: Vector2) -> Vector2:
	var tex_size = map.texture.get_size()
	var texture_pos = Vector2(normalized.x * tex_size.x, normalized.y * tex_size.y)
	return texture_pos - tex_size * 0.5

func _marker_tip(spr: Sprite2D) -> Vector2:
	var rect := spr.get_rect()
	var tip_local := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y)
	return spr.position + tip_local * spr.scale

func _centered_between_markers(guess: Vector2, answer: Vector2) -> Vector2:
	var midpoint := (guess + answer) * 0.5
	var ideal := collapsed_size * 0.5 - midpoint * BASE_SCALE
	var scaled_size := map.texture.get_size() * BASE_SCALE
	return _clamp_map_position(ideal, collapsed_size, scaled_size, 0.0, 0.0)
	
func show_answer(answer_normalized: Vector2) -> float:
	locked = true

	var answer_local := _normalized_to_local(answer_normalized)
	answer_marker.position = answer_local
	answer_marker.visible = true

	if marker.visible:
		distance_line.points =PackedVector2Array([_marker_tip(marker), _marker_tip(answer_marker)])
		distance_line.visible = true

	zoom = 1.0

	var target := map_root_start_pos

	if marker.visible:
		target = _centered_between_markers(marker.position, answer_local)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(map_root, "scale", Vector2.ONE * BASE_SCALE, EXPAND_DURATION)
	tween.tween_property(map_root, "position", target, EXPAND_DURATION)

	if marker.visible:
		return last_guess_normalized.distance_to(answer_normalized)
	return -1.0

func reset_round() -> void:
	locked = false
	marker.visible = false
	answer_marker.visible = false
	distance_line.visible = false
	last_guess_normalized = Vector2.ZERO
	zoom = 1.0
	map_root.scale = Vector2.ONE * BASE_SCALE
	map_root.position = map_root_start_pos

func _on_mouse_entered() -> void:
	if is_expanded:
		return
	_expand()


func _expand() -> void:
	is_expanded = true
	var size_delta := EXPANDED_SIZE - collapsed_size

	# Center the map for the expanded view: on the marker if one is placed,
	# otherwise on the map's own center, instead of leaving whatever
	# leftover pan/zoom position it had while collapsed.
	var target_map_root_pos: Vector2
	if marker.visible:
		target_map_root_pos = _centered_map_root_position(marker.position, EXPANDED_SIZE, BASE_SCALE)
	else:
		target_map_root_pos = _centered_map_root_position(Vector2.ZERO, EXPANDED_SIZE, BASE_SCALE)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "size", EXPANDED_SIZE, EXPAND_DURATION)
	tween.tween_property(self, "position", collapsed_position - size_delta, EXPAND_DURATION)
	tween.tween_property(map_root, "scale", Vector2.ONE * BASE_SCALE, EXPAND_DURATION)
	tween.tween_property(map_root, "position", target_map_root_pos, EXPAND_DURATION)
	expanded.emit()



func _clamp_map_position(pos: Vector2, viewport_size: Vector2, scaled_size: Vector2, overshoot_x: float = 0.0, overshoot_y: float = 0.0) -> Vector2:
	var min_x = viewport_size.x - scaled_size.x * 0.5 - overshoot_x
	var max_x = scaled_size.x * 0.5 + overshoot_x
	var min_y = viewport_size.y - scaled_size.y * 0.5 - overshoot_y
	var max_y = scaled_size.y * 0.5 + overshoot_y

	var result := pos
	if min_x > max_x:
		result.x = viewport_size.x * 0.5
	else:
		result.x = clamp(pos.x, min_x, max_x)

	if min_y > max_y:
		result.y = viewport_size.y * 0.5
	else:
		result.y = clamp(pos.y, min_y, max_y)

	return result


func clamp_map():
	if not is_expanded:
		return

	var scaled_size = map.texture.get_size() * map_root.scale
	map_root.position = _clamp_map_position(map_root.position, size, scaled_size, pan_overshoot_x, pan_overshoot_y)


func _centered_map_root_position(local_point: Vector2, viewport_size: Vector2 = collapsed_size, scale_val: float = BASE_SCALE) -> Vector2:
	var ideal := viewport_size * 0.5 - local_point * scale_val
	var scaled_size := map.texture.get_size() * scale_val
	return _clamp_map_position(ideal, viewport_size, scaled_size, 0.0, 0.0)



func _collapse() -> void:
	is_expanded = false
	dragging = false
	zoom = 1.0

	var target_map_root_pos := map_root_start_pos
	if marker.visible:
		target_map_root_pos = _centered_map_root_position(marker.position, collapsed_size, BASE_SCALE)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "size", collapsed_size, EXPAND_DURATION)
	tween.tween_property(self, "position", collapsed_position, EXPAND_DURATION)
	tween.tween_property(map_root, "scale", Vector2.ONE * BASE_SCALE, EXPAND_DURATION)
	tween.tween_property(map_root, "position", target_map_root_pos, EXPAND_DURATION)
	collapsed.emit()




func zoom_at_mouse(mouse_pos: Vector2, factor: float):

	var old_zoom = zoom
	zoom = clamp(zoom * factor, MIN_ZOOM, MAX_ZOOM)

	if zoom == old_zoom:
		return

	var zoom_ratio = zoom / old_zoom

	var local_mouse = mouse_pos - map_root.position

	map_root.scale = Vector2.ONE * zoom * BASE_SCALE

	map_root.position -= local_mouse * (zoom_ratio - 1.0)

	clamp_map()
