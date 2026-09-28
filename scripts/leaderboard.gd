extends Control

const PLACEHOLDER := "--"

@onready var close_button: Button = $TextureRect/Panel/closeButton
@onready var loading_label: Label = $TextureRect/Panel/loadingLabel if has_node("TextureRect/Panel/loadingLabel") else null

# Podium (ranks 1-3): each node still has name/score/matches children directly.
@onready var podium_nodes: Array = [
	$TextureRect/Panel/First,
	$TextureRect/Panel/second,
	$TextureRect/Panel/third,
]

# Ranks 4-8 are split across two GridContainers, both direct children of the root:
#   GridContainer2 -> AVG. SCORE / GAMES columns  (score, matches, score2, matches2, ...)
#   GridContainer  -> RANK / PLAYER columns        (Label, name, Label2, name2, ...)
@onready var score_matches_grid: GridContainer = $GridContainer2
@onready var rank_name_grid: GridContainer = $GridContainer

# Built once in _ready(): one dict per extra row (ranks 4-8), each holding
# references to that row's name/score/matches Labels.
var extra_rows: Array = []


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	Supabase.leaderboard_loaded.connect(_on_leaderboard_loaded)
	Supabase.leaderboard_failed.connect(_on_leaderboard_failed)
	_build_extra_rows()
	_clear_all()
	# Don't fetch here — this only runs once, when main_menu first loads.
	# Call open() instead, each time the popup is shown, to get fresh data.


func _build_extra_rows() -> void:
	extra_rows.clear()
	for i in range(5):
		var suffix := "" if i == 0 else str(i + 1)
		extra_rows.append({
			"name": rank_name_grid.get_node("name" + suffix),
			"score": score_matches_grid.get_node("score" + suffix),
			"matches": score_matches_grid.get_node("matches" + suffix),
		})


# Baseline styling so rows are readable even with no editor theme set up yet.
# Podium rows (top 3) get bigger, bolder text; the rest read like a plain table.
func _apply_minimal_style() -> void:
	for node in podium_nodes:
		var name_label: Label = node.get_node("name")
		var score_label: Label = node.get_node("score")
		var matches_label: Label = node.get_node("matches")
		for lbl in [name_label, score_label, matches_label]:
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_font_size_override("font_size", 22)
		score_label.add_theme_font_size_override("font_size", 18)

	for row in extra_rows:
		var name_label: Label = row["name"]
		var score_label: Label = row["score"]
		var matches_label: Label = row["matches"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		matches_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for lbl in [name_label, score_label, matches_label]:
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.add_theme_font_size_override("font_size", 16)


# Call this from main_menu instead of .show() directly.
func open() -> void:
	show()
	_clear_all()
	_set_loading(true)
	Supabase.fetch_leaderboard()


func _on_leaderboard_loaded(rows: Array) -> void:
	_set_loading(false)

	for i in range(podium_nodes.size()):
		if i < rows.size():
			_set_podium_row(podium_nodes[i], rows[i])
		else:
			_clear_podium_row(podium_nodes[i])

	for i in range(extra_rows.size()):
		var rank_index := i + 3  # ranks 4-8 map to rows[3..7]
		if rank_index < rows.size():
			_set_extra_row(extra_rows[i], rows[rank_index])
		else:
			_clear_extra_row(extra_rows[i])


func _on_leaderboard_failed(error_message: String) -> void:
	_set_loading(false)
	print("Leaderboard failed: ", error_message)
	_clear_all()


func _set_podium_row(node: Node, row: Dictionary) -> void:
	node.get_node("name").text = str(row.get("username", PLACEHOLDER))
	node.get_node("score").text = str(row.get("total_score", PLACEHOLDER))
	node.get_node("matches").text = str(row.get("matches_played", PLACEHOLDER))


func _clear_podium_row(node: Node) -> void:
	node.get_node("name").text = PLACEHOLDER
	node.get_node("score").text = PLACEHOLDER
	node.get_node("matches").text = PLACEHOLDER


func _set_extra_row(row: Dictionary, data: Dictionary) -> void:
	row["name"].text = str(data.get("username", PLACEHOLDER))
	row["score"].text = str(data.get("total_score", PLACEHOLDER))
	row["matches"].text = str(data.get("matches_played", PLACEHOLDER))


func _clear_extra_row(row: Dictionary) -> void:
	row["name"].text = PLACEHOLDER
	row["score"].text = PLACEHOLDER
	row["matches"].text = PLACEHOLDER


func _clear_all() -> void:
	for node in podium_nodes:
		_clear_podium_row(node)
	for row in extra_rows:
		_clear_extra_row(row)


func _set_loading(is_loading: bool) -> void:
	if loading_label:
		loading_label.visible = is_loading


func _on_close_pressed() -> void:
	hide()
