extends Node
var total_rounds := 5
var round_num := 1
var round_order: Array = []
var total_distance := 0.0
var map_width_km := 0.0
var total_score := 0
var has_guess := false
var guess_normalized := Vector2.ZERO
var answer_normalized := Vector2.ZERO

var mode := "game"

var pending_uploads: Array = []
var current_upload_index := 0

var cached_answers: Array = []
var answers_ready := false
var new_game_requested := true

var all_location_rows: Array = []
var location_rows_ready := false


func _ready() -> void:
	if not Supabase.locations_fetched.is_connected(_on_locations_preloaded):
		Supabase.locations_fetched.connect(_on_locations_preloaded)
	if not Supabase.locations_fetch_failed.is_connected(_on_locations_preload_failed):
		Supabase.locations_fetch_failed.connect(_on_locations_preload_failed)
	Supabase.fetch_all_locations()


func _on_locations_preloaded(rows: Array) -> void:
	all_location_rows = rows
	location_rows_ready = true


func _on_locations_preload_failed(msg: String) -> void:
	print("Preloading location list failed: ", msg)
	
	
func reset_game() -> void:
	round_num = 1
	total_score = 0
	total_distance = 0.0
	map_width_km = 0.0

	has_guess = false
	guess_normalized = Vector2.ZERO
	answer_normalized = Vector2.ZERO

	round_order.clear()
	cached_answers.clear()
	answers_ready = false

	new_game_requested = true

	pending_uploads.clear()
	current_upload_index = 0
