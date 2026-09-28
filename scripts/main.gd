extends Control

@onready var map_container: MapContainerWidget = $MapContainer
@onready var black_screen: TextureRect = $BlackScreen
@onready var countdown_label: Label = $BlackScreen/CountdownLabel
@onready var question_image: TextureRect = $QuestionImage
@onready var guess_button: Button = $GuessButton
@onready var countdown_round_label: Label = $BlackScreen/RoundLabel
@onready var round_2: Label = $BlackScreen/round2

var ANSWERS: Array = []

var _images_pending := 0


var guess_button_collapsed_position: Vector2
var guess_button_collapsed_size: Vector2


const TOTAL_ROUNDS := 5
const COUNTDOWN_SECONDS := 3

@export var map_width_km: float = 0.0

var round_order: Array = []
var round_num := 0
var has_guessed := false
var total_distance := 0.0

var _countdown_done := false
var _images_ready := false


func _ready() -> void:
	map_container.marker_placed.connect(_on_marker_placed)
	map_container.marker_removed.connect(_on_marker_removed)
	map_container.expanded.connect(_on_map_expanded)
	map_container.collapsed.connect(_on_map_collapsed)
	guess_button.pressed.connect(_on_guess_pressed)

	map_container.linked_controls = [guess_button]

	# ------------------------------------------------------------
	# PLACEMENT MODE
	# ------------------------------------------------------------
	if GameState.mode == "placement":
		guess_button.disabled = true
		map_container.visible = false
		_start_placement_mode()
		return

	# ------------------------------------------------------------
	# NORMAL GAME MODE
	# ------------------------------------------------------------

	guess_button.disabled = true
	map_container.visible = false

	black_screen.visible = true

	await get_tree().process_frame

	guess_button_collapsed_position = guess_button.position
	guess_button_collapsed_size = guess_button.size

	# Show round number immediately
	round_num = GameState.round_num if GameState.round_num > 0 else 1
	_update_round_label()

	# Start countdown immediately
	_start_countdown()

	# ------------------------------------------------------------
	# IMPORTANT:
	# Decide whether we need a NEW batch of 5 images.
	# ------------------------------------------------------------

	if GameState.new_game_requested:
		print(">>> NEW GAME - selecting new random images")
		GameState.cached_answers.clear()
		GameState.answers_ready = false
		GameState.round_order.clear()
		GameState.new_game_requested = false
		_prepare_round_images()

	else:
		print(">>> SAME GAME - using cached images")
		if GameState.answers_ready and not GameState.cached_answers.is_empty():
			ANSWERS = GameState.cached_answers
			_on_all_images_ready()
		else:
			_prepare_round_images()


func _start_placement_mode() -> void:
	map_container.visible = true
	black_screen.visible = false

	guess_button.text = "Confirm Location"

	if not Supabase.location_upload_success.is_connected(_on_location_upload_success):
		Supabase.location_upload_success.connect(_on_location_upload_success)
	if not Supabase.location_upload_failed.is_connected(_on_location_upload_failed):
		Supabase.location_upload_failed.connect(_on_location_upload_failed)

	_load_current_placement_image()


func _load_current_placement_image() -> void:
	if GameState.current_upload_index >= GameState.pending_uploads.size():
		_finish_placement_queue()
		return

	has_guessed = false
	guess_button.disabled = true
	map_container.reset_round()

	var entry: Dictionary = GameState.pending_uploads[GameState.current_upload_index]
	var img := Image.new()
	var err: int
	if entry["ext"] == "png":
		err = img.load_png_from_buffer(entry["bytes"])
	else:
		err = img.load_jpg_from_buffer(entry["bytes"])

	if err == OK:
		_set_question_image(ImageTexture.create_from_image(img))
	else:
		print("Failed to load image at queue index ", GameState.current_upload_index)

	var total: int = GameState.pending_uploads.size()
	var current: int = GameState.current_upload_index + 1
	print("Placing image %d of %d" % [current, total])
	# If you add a spare Label to the placement UI, this is a good place
	# to set its text to "%d / %d" % [current, total] to show progress.


func _finish_placement_queue() -> void:
	GameState.mode = "game"
	GameState.pending_uploads = []
	GameState.current_upload_index = 0

	# New locations were added — force a refetch next time the game starts
	# instead of serving the stale cached list.
	GameState.answers_ready = false
	GameState.cached_answers = []
	GameState.location_rows_ready = false
	GameState.all_location_rows = []
	Supabase.fetch_all_locations()  # kick off a fresh preload now, in the background

	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_location_upload_success(_row) -> void:
	GameState.current_upload_index += 1
	_load_current_placement_image()


func _on_location_upload_failed(msg: String) -> void:
	print("Upload failed: ", msg)
	# Leave the current image up so the user can just retry the same one.
	has_guessed = false
	guess_button.disabled = false


# ---------- picking + downloading only the images this round needs ----------

func _on_locations_fetch_failed(msg: String) -> void:
	print("Failed to fetch locations: ", msg)


func _prepare_round_images() -> void:
	if GameState.location_rows_ready and not GameState.all_location_rows.is_empty():
		# Metadata was already preloaded at app startup — no network wait here.
		_pick_and_download_round_images(GameState.all_location_rows)
	else:
		# Preload hasn't finished yet (e.g. very fast game start, or it
		# failed) — fetch it now as a fallback.
		if not Supabase.locations_fetched.is_connected(_on_locations_fetched):
			Supabase.locations_fetched.connect(_on_locations_fetched)
		if not Supabase.locations_fetch_failed.is_connected(_on_locations_fetch_failed):
			Supabase.locations_fetch_failed.connect(_on_locations_fetch_failed)
		Supabase.fetch_all_locations()


func _on_locations_fetched(rows: Array) -> void:
	GameState.all_location_rows = rows
	GameState.location_rows_ready = true
	_pick_and_download_round_images(rows)


func _pick_and_download_round_images(rows: Array) -> void:
	if rows.is_empty():
		print("No locations in database yet.")
		return

	# Only download as many images as this game actually needs — never the
	# whole table. This keeps round-start time constant whether there are
	# 8 locations or 8,000.
	var pool := rows.duplicate()
	pool.shuffle()
	var chosen: Array = pool.slice(0, min(TOTAL_ROUNDS, pool.size()))

	ANSWERS.clear()
	_images_pending = chosen.size()

	for row in chosen:
		var url := Supabase.get_public_image_url(row["image_path"])
		var http := HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(_on_image_downloaded.bind(http, row))
		http.request(url)


func _on_image_downloaded(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest,
	row: Dictionary
) -> void:
	http.queue_free()
	_images_pending -= 1

	if response_code == 200:
		var img := Image.new()
		var ext: String = row["image_path"].get_extension().to_lower()
		var err: int
		if ext == "png":
			err = img.load_png_from_buffer(body)
		else:
			err = img.load_jpg_from_buffer(body)

		if err == OK:
			ANSWERS.append({
				"image": ImageTexture.create_from_image(img),
				"name": row["image_path"],
				"x": row["x"],
				"y": row["y"]
			})
		else:
			print("Failed to decode image for ", row["image_path"])
	else:
		print("Failed to download image, code: ", response_code)

	if _images_pending <= 0:
		_on_all_images_ready()


func _on_all_images_ready() -> void:

	if ANSWERS.is_empty():
		print("No usable images downloaded, cannot start round.")
		return

	# ------------------------------------------------------------
	# Save these 5 images as the CURRENT GAME'S cache.
	# ------------------------------------------------------------

	GameState.cached_answers = ANSWERS.duplicate()
	GameState.answers_ready = true

	# ------------------------------------------------------------
	# Build the round order.
	#
	# This happens only for a new batch.
	# ------------------------------------------------------------

	if GameState.round_order.is_empty():

		_build_round_order()

		GameState.round_order = round_order.duplicate()

	else:

		round_order = GameState.round_order.duplicate()

		# Safety check
		round_order = round_order.filter(
			func(i):
				return i < ANSWERS.size()
		)

		if round_order.is_empty():
			_build_round_order()
			GameState.round_order = round_order.duplicate()

	round_num = GameState.round_num

	_images_ready = true

	_maybe_start_round()

func _maybe_start_round() -> void:
	# Only reveal the round once the 3-2-1 countdown has finished playing
	# AND the images have finished downloading — whichever takes longer.
	if not _countdown_done or not _images_ready:
		return

	black_screen.visible = false
	map_container.visible = true
	_start_round()


func _on_map_expanded() -> void:
	var size_delta := map_container.EXPANDED_SIZE - map_container.collapsed_size

	var target_size := Vector2(map_container.EXPANDED_SIZE.x, guess_button_collapsed_size.y)
	var target_pos := Vector2(guess_button_collapsed_position.x - size_delta.x, guess_button_collapsed_position.y)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(guess_button, "size", target_size, MapContainerWidget.EXPAND_DURATION)
	tween.tween_property(guess_button, "position", target_pos, MapContainerWidget.EXPAND_DURATION)


func _on_map_collapsed() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(guess_button, "size", guess_button_collapsed_size, MapContainerWidget.EXPAND_DURATION)
	tween.tween_property(guess_button, "position", guess_button_collapsed_position, MapContainerWidget.EXPAND_DURATION)


func _build_round_order() -> void:
	var indices := []
	for i in ANSWERS.size():
		indices.append(i)
	indices.shuffle()
	round_order = indices.slice(0, min(TOTAL_ROUNDS, indices.size()))


func _start_countdown() -> void:
	var seconds_left := COUNTDOWN_SECONDS
	countdown_label.text = str(seconds_left)

	while seconds_left > 0:
		await get_tree().create_timer(1.0).timeout
		seconds_left -= 1
		if seconds_left > 0:
			countdown_label.text = str(seconds_left)

	_countdown_done = true
	_maybe_start_round()


func _start_round() -> void:
	has_guessed = false
	map_container.reset_round()

	guess_button.disabled = true

	_update_round_label()


	var answer = ANSWERS[round_order[round_num - 1]]
	_set_question_image(answer["image"])

func _set_question_image(tex: Texture2D) -> void:
	question_image.texture = tex
	question_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	question_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var is_portrait := tex.get_height() > tex.get_width()

	question_image.pivot_offset = question_image.size / 2.0

	if is_portrait:
		question_image.rotation_degrees = -90
	else:
		question_image.rotation_degrees = 0


func _on_marker_placed(_normalized: Vector2) -> void:
	guess_button.visible = true
	if not has_guessed:
		guess_button.disabled = false


func _on_marker_removed() -> void:
	guess_button.visible =false
	if not has_guessed:
		guess_button.disabled = true


func _on_guess_pressed() -> void:
	if has_guessed:
		return
	has_guessed = true
	guess_button.disabled = true

	# ---- Placement mode: confirming where the current queued photo was taken ----
	if GameState.mode == "placement":
		var entry: Dictionary = GameState.pending_uploads[GameState.current_upload_index]
		Supabase.upload_location(
			entry["bytes"],
			entry["ext"],
			map_container.last_guess_normalized.x,
			map_container.last_guess_normalized.y
		)
		return

	# ---- Normal game mode ----
	var answer = ANSWERS[round_order[round_num - 1]]

	GameState.answer_normalized = Vector2(answer["x"], answer["y"])
	GameState.has_guess = map_container.marker.visible
	GameState.guess_normalized = map_container.last_guess_normalized
	GameState.round_num = round_num
	GameState.total_rounds = TOTAL_ROUNDS
	GameState.round_order = round_order
	GameState.map_width_km = map_width_km

	get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")
@onready var _0: Label = $"BlackScreen/0"

func _update_round_label() -> void:
	_0.text = str(GameState.total_score)
	var text := "%d/%d" % [round_num, TOTAL_ROUNDS]
	countdown_round_label.text = text
	round_2.text = str(round_num)
	countdown_round_label.text = text


@onready var upload_popup: Control = $UploadImagePopup

func _on_upload_image_button_pressed():
	upload_popup.show()
	upload_popup.open_popup()  # if you kept that method, or just call _show_rules_page logic
