extends Node


# =========================================================
# SUPABASE CONFIG
# =========================================================

const SUPABASE_URL := "https://pgtarimgpkgnrfzqubuy.supabase.co"
const SUPABASE_KEY := "sb_publishable_rRMz2laMc4-JeBveQamsdg_QhvrTBFE"


# =========================================================
# AUTH SIGNALS
# =========================================================

signal register_success(user_data)
signal register_failed(error_message)

signal login_success(user_data)
signal login_failed(error_message)

signal profile_loaded(username)
signal profile_failed(error_message)


# =========================================================
# MATCH SIGNALS
# =========================================================

signal match_saved_success()
signal match_saved_failed(error_message)


# =========================================================
# LEADERBOARD SIGNALS
# =========================================================

signal leaderboard_loaded(rows)
signal leaderboard_failed(error_message)


# =========================================================
# PLAYER STATS SIGNALS
# =========================================================

signal player_stats_loaded(stats)
signal player_stats_failed(error_message)


# =========================================================
# LOCATION SIGNALS
# =========================================================

signal location_upload_success(row)
signal location_upload_failed(error_message)

signal locations_fetched(rows: Array)
signal locations_fetch_failed(error_message)


# =========================================================
# DATA
# =========================================================

var leaderboard_data: Array = []


# =========================================================
# AUTH STATE
# =========================================================

var access_token := ""
var refresh_token := ""

var current_user_id := ""
var current_username := ""

var is_logged_in := false


# =========================================================
# LOGOUT
# =========================================================

func logout_user() -> void:

	print("Logging out...")

	access_token = ""
	refresh_token = ""

	current_user_id = ""
	current_username = ""

	is_logged_in = false

	print("LOGGED OUT")


# =========================================================
# REGISTER
# =========================================================

func register_user(username: String, email: String, password: String):

	print("Starting registration...")

	var http := HTTPRequest.new()
	add_child(http)
	http.accept_gzip = false

	http.request_completed.connect(
		_on_register_completed.bind(http)
	)

	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	]

	var data := {
		"email": email,
		"password": password,
		"data": {
			"username": username
		}
	}

	var body := JSON.stringify(data)

	var error := http.request(
		SUPABASE_URL + "/auth/v1/signup",
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:

		print("Registration request failed: ", error)

		register_failed.emit(
			"Could not connect to Supabase."
		)


# =========================================================
# REGISTER RESPONSE
# =========================================================

func _on_register_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
):

	http.queue_free()

	var response_text := body.get_string_from_utf8()

	print("Registration response code: ", response_code)
	print("Registration response: ", response_text)

	var response = JSON.parse_string(response_text)

	if response_code >= 200 and response_code < 300:

		print("Registration successful!")

		register_success.emit(response)

	else:

		var error_message := "Registration failed."

		if response is Dictionary:

			if response.has("msg"):
				error_message = response["msg"]

			elif response.has("message"):
				error_message = response["message"]

			elif response.has("error_description"):
				error_message = response["error_description"]

		register_failed.emit(error_message)


# =========================================================
# LOGIN
# =========================================================

func login_user(email: String, password: String):

	print("Starting login...")

	var http := HTTPRequest.new()
	add_child(http)
	http.accept_gzip = false

	http.request_completed.connect(
		_on_login_completed.bind(http)
	)

	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	]

	var data := {
		"email": email,
		"password": password
	}

	var body := JSON.stringify(data)

	var error := http.request(
		SUPABASE_URL + "/auth/v1/token?grant_type=password",
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:

		print("Login request failed: ", error)

		login_failed.emit(
			"Could not connect to Supabase."
		)


# =========================================================
# LOGIN RESPONSE
# =========================================================

func _on_login_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
):

	http.queue_free()

	var response_text := body.get_string_from_utf8()

	print("Login response code: ", response_code)
	print("Login response: ", response_text)

	var response = JSON.parse_string(response_text)

	if response_code >= 200 and response_code < 300:

		print("LOGIN SUCCESS!")

		access_token = response["access_token"]
		refresh_token = response["refresh_token"]

		var user = response["user"]

		current_user_id = user["id"]

		is_logged_in = true

		fetch_current_profile()

		print("User ID: ", current_user_id)
		print("Access token received!")

		login_success.emit(response)

	else:

		var error_message := "Login failed."

		if response is Dictionary:

			if response.has("msg"):
				error_message = response["msg"]

			elif response.has("message"):
				error_message = response["message"]

			elif response.has("error_description"):
				error_message = response["error_description"]

		login_failed.emit(error_message)


# =========================================================
# FETCH CURRENT PROFILE
# =========================================================

func fetch_current_profile():

	print("Fetching current profile...")

	var http := HTTPRequest.new()
	add_child(http)
	http.accept_gzip = false

	http.request_completed.connect(
		_on_profile_completed.bind(http)
	)

	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token
	]

	var error := http.request(
		SUPABASE_URL
		+ "/rest/v1/profiles?id=eq."
		+ current_user_id
		+ "&select=username",
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:

		print("Profile request failed: ", error)


# =========================================================
# PROFILE RESPONSE
# =========================================================

func _on_profile_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
):

	http.queue_free()

	var response_text := body.get_string_from_utf8()

	print("Profile response code: ", response_code)
	print("Profile response: ", response_text)

	if response_code != 200:

		print("Failed to fetch profile.")

		return

	var response = JSON.parse_string(response_text)

	if response is Array and response.size() > 0:

		current_username = response[0]["username"]

		print("Current username: ", current_username)
		print("Logged in as: ", current_username)

		profile_loaded.emit(current_username)

	else:

		print("No profile found.")

		profile_failed.emit(
			"Profile not found."
		)


# =========================================================
# UPLOAD LOCATION
# =========================================================

func upload_location(
	image_bytes: PackedByteArray,
	ext: String,
	x: float,
	y: float
) -> void:

	if not is_logged_in:

		location_upload_failed.emit(
			"Not logged in."
		)

		return

	var file_name := "%s_%d.%s" % [
		current_user_id,
		Time.get_unix_time_from_system(),
		ext
	]

	var content_type := "image/png" if ext == "png" else "image/jpeg"

	var http := HTTPRequest.new()
	add_child(http)
	http.accept_gzip = false

	http.request_completed.connect(
		_on_storage_upload_completed.bind(
			http,
			file_name,
			x,
			y
		)
	)

	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: " + content_type,
		"x-upsert: false"
	]

	var error := http.request_raw(
		SUPABASE_URL
		+ "/storage/v1/object/location-images/"
		+ file_name,
		headers,
		HTTPClient.METHOD_POST,
		image_bytes
	)

	if error != OK:

		print("Storage upload request failed: ", error)

		location_upload_failed.emit(
			"Could not reach Supabase storage."
		)


# =========================================================
# STORAGE RESPONSE
# =========================================================

func _on_storage_upload_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest,
	file_name: String,
	x: float,
	y: float
):

	http.queue_free()

	var response_text := body.get_string_from_utf8()

	print(
		"Storage upload response: ",
		response_code,
		" ",
		response_text
	)

	if response_code < 200 or response_code >= 300:

		location_upload_failed.emit(
			"Image upload failed."
		)

		return

	_insert_location_row(
		file_name,
		x,
		y
	)


# =========================================================
# INSERT LOCATION ROW
# =========================================================

func _insert_location_row(
	image_path: String,
	x: float,
	y: float
) -> void:

	var http := HTTPRequest.new()
	add_child(http)
	http.accept_gzip = false

	http.request_completed.connect(
		_on_insert_location_completed.bind(http)
	)

	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: return=representation"
	]

	var data := {
		"user_id": current_user_id,
		"image_path": image_path,
		"x": x,
		"y": y
	}

	http.request(
		SUPABASE_URL + "/rest/v1/locations",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)


# =========================================================
# LOCATION INSERT RESPONSE
# =========================================================

func _on_insert_location_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
):

	http.queue_free()

	var response_text := body.get_string_from_utf8()

	print(
		"Insert location response: ",
		response_code,
		" ",
		response_text
	)

	var response = JSON.parse_string(response_text)

	if response_code >= 200 and response_code < 300:

		location_upload_success.emit(response)

	else:

		location_upload_failed.emit(
			"Could not save location."
		)


# =========================================================
# FETCH ALL LOCATIONS
# =========================================================

func fetch_all_locations() -> void:

	var http := HTTPRequest.new()
	add_child(http)
	http.accept_gzip = false

	http.request_completed.connect(
		_on_fetch_locations_completed.bind(http)
	)

	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Accept: application/json"
	]
	if is_logged_in and access_token != "":
		headers.append(
			"Authorization: Bearer " + access_token
		)

	var error := http.request(
		SUPABASE_URL
		+ "/rest/v1/locations?select=id,image_path,x,y",
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:

		locations_fetch_failed.emit(
			"Could not reach Supabase."
		)


# =========================================================
# LOCATIONS RESPONSE
# =========================================================

func _on_fetch_locations_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
):

	http.queue_free()

	print("================================")
	print("LOCATIONS RESPONSE")
	print("================================")

	print("HTTP result: ", result)
	print("HTTP response code: ", response_code)
	print("Body size: ", body.size())

	var response_text := body.get_string_from_utf8()

	print("Response body:")
	print(response_text)

	print("================================")


	if response_code < 200 or response_code >= 300:

		print(
			"Supabase returned HTTP error: ",
			response_code
		)

		locations_fetch_failed.emit(
			"Supabase returned error %d." % response_code
		)

		return


	if response_text.is_empty():

		print("ERROR: Empty response from Supabase.")

		locations_fetch_failed.emit(
			"Supabase returned an empty response."
		)

		return


	var response = JSON.parse_string(response_text)


	if response == null:

		print("ERROR: Could not parse locations JSON.")

		print("Raw response: ", response_text)

		locations_fetch_failed.emit(
			"Invalid JSON returned by Supabase."
		)

		return


	if not response is Array:

		print("ERROR: Locations response isn't an Array.")

		locations_fetch_failed.emit(
			"Invalid locations response."
		)

		return


	print(
		"Successfully loaded ",
		response.size(),
		" locations."
	)

	locations_fetched.emit(response)


# =========================================================
# PUBLIC IMAGE URL
# =========================================================

func get_public_image_url(image_path: String) -> String:

	return (
		SUPABASE_URL
		+ "/storage/v1/object/public/location-images/"
		+ image_path
	)


# =========================================================
# SAVE MATCH
# =========================================================

func save_match() -> void:

	if not is_logged_in:

		match_saved_failed.emit(
			"Not logged in."
		)

		return

	var http := HTTPRequest.new()
	add_child(http)
	http.accept_gzip = false

	http.request_completed.connect(
		_on_match_saved_completed.bind(http)
	)

	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: return=minimal"
	]

	var data := {
		"player_id": current_user_id,
		"score": GameState.total_score,
		"total_distance": GameState.total_distance
	}

	var error := http.request(
		SUPABASE_URL + "/rest/v1/matches",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)

	if error != OK:

		http.queue_free()

		match_saved_failed.emit(
			"Could not connect to Supabase."
		)


# =========================================================
# MATCH SAVED RESPONSE
# =========================================================

func _on_match_saved_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:

	http.queue_free()

	print(
		"Save match response: ",
		response_code
	)

	if response_code >= 200 and response_code < 300:

		print("MATCH SAVED SUCCESSFULLY")

		match_saved_success.emit()

	else:

		print(
			"Failed to save match: ",
			body.get_string_from_utf8()
		)

		match_saved_failed.emit(
			"Could not save match."
		)


# =========================================================
# FETCH PLAYER STATS
# =========================================================

func fetch_player_stats() -> void:

	if not is_logged_in:

		player_stats_failed.emit(
			"Not logged in."
		)

		return

	if current_user_id.is_empty():

		player_stats_failed.emit(
			"User ID is missing."
		)

		return


	print("================================")
	print("FETCHING PLAYER STATS")
	print("User ID: ", current_user_id)
	print("================================")


	var http := HTTPRequest.new()
	add_child(http)
	http.accept_gzip = false

	http.request_completed.connect(
		_on_player_stats_completed.bind(http)
	)


	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json"
	]


	# -----------------------------------------------------
	# Get all matches belonging to this player
	# -----------------------------------------------------

	var url := (
		SUPABASE_URL
		+ "/rest/v1/matches"
		+ "?select=score,total_distance"
		+ "&player_id=eq."
		+ current_user_id
	)


	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)


	if error != OK:

		http.queue_free()

		print(
			"Player stats request failed: ",
			error
		)

		player_stats_failed.emit(
			"Could not connect to Supabase."
		)


# =========================================================
# PLAYER STATS RESPONSE
# =========================================================

func _on_player_stats_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:

	http.queue_free()


	var response_text := body.get_string_from_utf8()

	print(
		"Player stats response code: ",
		response_code
	)

	print(
		"Player stats response: ",
		response_text
	)


	# -----------------------------------------------------
	# Check response
	# -----------------------------------------------------

	if response_code != 200:

		print("Failed to fetch player stats.")

		player_stats_failed.emit(
			"Failed to fetch player statistics."
		)

		return


	var response = JSON.parse_string(
		response_text
	)


	if not response is Array:

		print("Invalid player stats response.")

		player_stats_failed.emit(
			"Invalid player statistics."
		)

		return


	# =====================================================
	# CALCULATE STATISTICS
	# =====================================================

	var matches_played: int = response.size()

	var total_score := 0
	var best_score := 0

	var total_distance := 0.0


	for match in response:

		if not match is Dictionary:
			continue


		var score := int(
			match.get("score", 0)
		)

		var distance := float(
			match.get("total_distance", 0.0)
		)


		# Total score
		total_score += score


		# Total distance
		total_distance += distance


		# Best score
		if score > best_score:
			best_score = score


	# -----------------------------------------------------
	# Average score
	# -----------------------------------------------------

	var average_score := 0.0

	if matches_played > 0:

		average_score = (
			float(total_score)
			/ float(matches_played)
		)


	# =====================================================
	# CREATE STATS DICTIONARY
	# =====================================================

	var stats := {
		"matches_played": matches_played,
		"total_score": total_score,
		"best_score": best_score,
		"average_score": average_score,
		"total_distance": total_distance
	}


	# =====================================================
	# PRINT RESULTS
	# =====================================================

	print("================================")
	print("PLAYER STATS")
	print("================================")

	print(
		"Matches played: ",
		stats["matches_played"]
	)

	print(
		"Total score: ",
		stats["total_score"]
	)

	print(
		"Best score: ",
		stats["best_score"]
	)

	print(
		"Average score: ",
		stats["average_score"]
	)

	print(
		"Total distance: ",
		stats["total_distance"]
	)

	print("================================")


	# Send stats to whatever UI requested them
	player_stats_loaded.emit(stats)


# =========================================================
# FETCH LEADERBOARD
# =========================================================

func fetch_leaderboard() -> void:

	var http := HTTPRequest.new()
	add_child(http)
	http.accept_gzip = false

	http.request_completed.connect(
		_on_leaderboard_completed.bind(http)
	)

	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	]

	if is_logged_in and access_token != "":
		headers.append(
			"Authorization: Bearer " + access_token
		)

	var error := http.request(
		SUPABASE_URL + "/rest/v1/rpc/get_leaderboard",
		headers,
		HTTPClient.METHOD_POST,
		"{}"
	)

	if error != OK:

		http.queue_free()

		leaderboard_failed.emit(
			"Could not connect to Supabase."
		)


# =========================================================
# LEADERBOARD RESPONSE
# =========================================================

func _on_leaderboard_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:

	http.queue_free()

	var response_text := body.get_string_from_utf8()

	print(
		"Leaderboard response code: ",
		response_code
	)

	print(
		"Leaderboard response: ",
		response_text
	)


	if response_code != 200:

		leaderboard_failed.emit(
			"Failed to load leaderboard."
		)

		return


	var response = JSON.parse_string(
		response_text
	)


	if response is Array:

		leaderboard_data = response

		leaderboard_loaded.emit(
			response
		)

	else:

		leaderboard_failed.emit(
			"Invalid leaderboard data."
		)
