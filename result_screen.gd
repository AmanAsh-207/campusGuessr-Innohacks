extends Control

const ZOOM_STEP := 1.2
const MAX_SCALE := 2.5
const MARKER_PADDING := 180.0  
const PAN_OVERSHOOT := 80.0
const FIT_DURATION := 0.6

@export var score_max_distance_px: float = 2500.0

@export var line_width: float = 4.0
@export var line_color: Color = Color.WHITE
@export_range(0.0, 1.0, 0.01) var marker_tip_x: float = 0.5  
@export_range(0.0, 1.0, 0.01) var marker_tip_y: float = 1.0  

@onready var texture_rect: TextureRect = $TextureRect
@onready var next_button_2: TextureButton = $TextureRect/NextButton2
@onready var final_score_label: Label = $TextureRect/finalScoreLabel


@onready var map_root: Node2D = $MapRoot
@onready var map_sprite: Sprite2D = $MapRoot/Map
@onready var guess_marker: Sprite2D = $MapRoot/GuessMarker
@onready var answer_marker: Sprite2D = $MapRoot/AnswerMarker
@onready var distance_line: Line2D = $MapRoot/DistanceLine
@onready var round_label: Label = $RoundLabel
@onready var distance_label: Label = $DistanceLabel
@onready var score_label: Label = $ScoreLabel
@onready var next_button: Button = $NextButton

var min_scale := 1.0  
var zoom := 1.0
var dragging := false
var is_last_round := false  


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	print(">>> result_screen ready. size=", size, " viewport=", get_viewport_rect().size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	is_last_round = GameState.round_num >= GameState.total_rounds
	next_button.pressed.connect(_on_next_pressed)
	next_button_2.pressed.connect(_on_next_button_2_pressed)
	round_label.text = "Round %d/%d" % [GameState.round_num, GameState.total_rounds]
	texture_rect.visible = false
	_place_markers()
	_show_distance()
	await get_tree().process_frame
	_fit_view()


func _place_markers() -> void:
	var tex_size = map_sprite.texture.get_size()

	answer_marker.position = (GameState.answer_normalized * tex_size) - tex_size * 0.5
	answer_marker.visible = true

	guess_marker.visible = GameState.has_guess
	distance_line.visible = false

	distance_line.width = line_width
	distance_line.default_color = line_color

	if GameState.has_guess:
		guess_marker.position = (GameState.guess_normalized * tex_size) - tex_size * 0.5
		distance_line.points = PackedVector2Array([
			_marker_tip(guess_marker),
			_marker_tip(answer_marker)
		])
		distance_line.visible = true


func _marker_tip(spr: Sprite2D) -> Vector2:
	var tex_size = spr.texture.get_size()
	var local_tip := Vector2(
		(marker_tip_x - 0.5) * tex_size.x,
		(marker_tip_y - 0.5) * tex_size.y
	)
	return spr.position + local_tip * spr.scale

var match_saved := false

func _show_distance() -> void:
	var round_score := 0

	if not GameState.has_guess:
		distance_label.text = "No guess placed."
	else:
		var dist_px := guess_marker.position.distance_to(answer_marker.position)

		round_score = int(round(clamp(100.0 * (1.0 - dist_px / score_max_distance_px), 0.0, 100.0)))

		GameState.total_distance += dist_px
		distance_label.text = "Distance: %.0f px" % dist_px

	GameState.total_score += round_score

	if is_last_round:
		var max_total := GameState.total_rounds * 100
		score_label.text = "Score: %d / 100" % round_score

		# Last round: hide the normal Next button, show the TextureRect
		# overlay with the total score and the NextButton2 to continue.
		next_button.visible = false
		texture_rect.visible = true
		final_score_label.text = str(GameState.total_score)
		final_score_label.add_theme_color_override("font_color","black")
		if not match_saved:
			match_saved = true
			Supabase.save_match()
	else:
		score_label.text = "Score: %d / 100" % round_score


func _fit_view() -> void:
	var tex_size = map_sprite.texture.get_size()
	var view_size = get_viewport_rect().size
	min_scale = min(view_size.x / tex_size.x, view_size.y / tex_size.y)

	var target_scale: float
	var midpoint: Vector2

	if GameState.has_guess:
		var guess_tip := _marker_tip(guess_marker)
		var answer_tip := _marker_tip(answer_marker)
		var bbox := Vector2(
			abs(answer_tip.x - guess_tip.x),
			abs(answer_tip.y - guess_tip.y)
		)
		var avail: Vector2 = view_size - Vector2.ONE * MARKER_PADDING * 2.0
		var scale_x: float = MAX_SCALE if bbox.x < 1.0 else avail.x / bbox.x
		var scale_y: float = MAX_SCALE if bbox.y < 1.0 else avail.y / bbox.y
		target_scale = clamp(min(scale_x, scale_y), min_scale, MAX_SCALE)
		midpoint = (guess_tip + answer_tip) * 0.5
	else:
		target_scale = min_scale
		midpoint = answer_marker.position

	zoom = target_scale
	var target_pos: Vector2 = view_size * 0.5 - midpoint * target_scale

	map_root.scale = Vector2.ONE * min_scale
	map_root.position = view_size * 0.5 - midpoint * min_scale

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(map_root, "scale", Vector2.ONE * target_scale, FIT_DURATION)
	tween.tween_property(map_root, "position", target_pos, FIT_DURATION)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_mouse(event.position, ZOOM_STEP)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_mouse(event.position, 1.0 / ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed

	if event is InputEventMouseMotion and dragging:
		map_root.position += event.relative
		_clamp_map()


func _zoom_at_mouse(mouse_pos: Vector2, factor: float) -> void:
	var running_tweens = get_tree().get_processed_tweens()
	for t in running_tweens:
		if t.is_valid():
			t.kill()

	var old_zoom = zoom
	zoom = clamp(zoom * factor, min_scale, MAX_SCALE)
	if zoom == old_zoom:
		return

	var zoom_ratio = zoom / old_zoom
	var local_mouse = mouse_pos - map_root.position

	map_root.scale = Vector2.ONE * zoom
	map_root.position -= local_mouse * (zoom_ratio - 1.0)
	_clamp_map()


func _clamp_map() -> void:
	var tex_size = map_sprite.texture.get_size()
	var scaled_size = tex_size * map_root.scale
	var view_size = get_viewport_rect().size

	var min_x = view_size.x - scaled_size.x * 0.5 - PAN_OVERSHOOT
	var max_x = scaled_size.x * 0.5 + PAN_OVERSHOOT
	var min_y = view_size.y - scaled_size.y * 0.5 - PAN_OVERSHOOT
	var max_y = scaled_size.y * 0.5 + PAN_OVERSHOOT

	var pos := map_root.position
	pos.x = clamp(pos.x, min(min_x, max_x), max(min_x, max_x))
	pos.y = clamp(pos.y, min(min_y, max_y), max(min_y, max_y))
	map_root.position = pos

@onready var main_menu: Button = $MainMenu


func _on_next_pressed() -> void:
	GameState.round_num += 1
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_next_button_2_pressed() -> void:
	GameState.round_num = 1
	GameState.total_score = 0
	GameState.total_distance = 0.0
	GameState.new_game_requested = true
	GameState.round_order.clear()
	GameState.cached_answers.clear()
	GameState.answers_ready = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
