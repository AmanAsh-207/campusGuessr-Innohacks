extends Node2D


# =========================================================
# MAIN UI
# =========================================================

@onready var login_ui: Node2D = $login_ui
@onready var login_bg: Control = $login_bg
@onready var guest_label: Label = $login_ui/Guest_label


# =========================================================
# LOGIN PANEL
# =========================================================

@onready var username_input: LineEdit = $login_bg/loginPanel/UsernameInput
@onready var email_input: LineEdit = $login_bg/loginPanel/EmailInput
@onready var password_input: LineEdit = $login_bg/loginPanel/passwordInput

@onready var submit_login: Button = $login_bg/loginPanel/SubmitLogin
@onready var login_button: Button = $login_bg/loginPanel/login
@onready var register_button: Button = $login_bg/loginPanel/Register
@onready var close_button: Button = $login_bg/loginPanel/CloseButton


# =========================================================
# ACCOUNT PANEL
# =========================================================

@onready var control: Control = $login_bg/loginPanel/Control

@onready var logout_button: Button = $login_bg/loginPanel/Control/Logout

@onready var user_name: Label = $login_bg/loginPanel/Control/UserName
@onready var user_avg_score: Label = $login_bg/loginPanel/Control/UserAvgScore
@onready var user_matches_played: Label = $login_bg/loginPanel/Control/UserMatchesPlayed


# =========================================================
# READY
# =========================================================

func _ready():

	# =====================================================
	# SUPABASE SIGNALS
	# =====================================================

	Supabase.profile_loaded.connect(_on_profile_loaded)

	Supabase.login_success.connect(_on_login_success)
	Supabase.login_failed.connect(_on_login_failed)

	Supabase.register_success.connect(_on_register_success)
	Supabase.register_failed.connect(_on_register_failed)

	# NEW: Player statistics
	Supabase.player_stats_loaded.connect(_on_player_stats_loaded)
	Supabase.player_stats_failed.connect(_on_player_stats_failed)


	# =====================================================
	# LOGOUT BUTTON
	# =====================================================

	logout_button.pressed.connect(_on_logout_pressed)


	# =====================================================
	# INITIAL ACCOUNT STATE
	# =====================================================

	if Supabase.is_logged_in:

		guest_label.text = Supabase.current_username

		# User is already logged in.
		# Fetch their statistics.
		Supabase.fetch_player_stats()

	else:

		guest_label.text = "Guest"


	# =====================================================
	# UPDATE PANEL
	# =====================================================

	update_login_panel()


# =========================================================
# MAIN MENU BUTTONS
# =========================================================

func _on_button_pressed() -> void:

	get_tree().change_scene_to_file(
		"res://scenes/Main.tscn"
	)


func _on_play_pressed() -> void:

	GameState.reset_game()

	get_tree().change_scene_to_file(
		"res://scenes/Main.tscn"
	)


func _on_how_to_play_pressed() -> void:

	$UploadImagePopup.show()


func _on_leaderboard_pressed() -> void:

	$LeaderBoardOpen.open()


# =========================================================
# OPEN LOGIN / ACCOUNT PANEL
# =========================================================

func _on_nameplate_pressed() -> void:

	open_login_panel()


func _on_dp_pressed() -> void:

	open_login_panel()


func open_login_panel() -> void:

	login_ui.visible = false
	login_bg.visible = true

	# Update account state
	update_login_panel()

	# If logged in, refresh stats
	if Supabase.is_logged_in:

		Supabase.fetch_player_stats()


# =========================================================
# CLOSE LOGIN / ACCOUNT PANEL
# =========================================================

func _on_close_button_pressed() -> void:

	login_bg.visible = false
	login_ui.visible = true


# =========================================================
# LOGIN SUCCESS
# =========================================================

func _on_login_success(user_data) -> void:

	print("================================")
	print("MAIN MENU: LOGIN SUCCESS")
	print("================================")

	# -----------------------------------------------------
	# Login has completed.
	# current_user_id is already available in Supabase.gd.
	# -----------------------------------------------------

	update_login_panel()

	# -----------------------------------------------------
	# FETCH PLAYER STATISTICS
	# -----------------------------------------------------

	print("Fetching player statistics after login...")

	Supabase.fetch_player_stats()


# =========================================================
# LOGIN FAILED
# =========================================================

func _on_login_failed(error_message) -> void:

	print("LOGIN FAILED: ", error_message)

	# Keep login panel open
	update_login_panel()


# =========================================================
# REGISTER SUCCESS
# =========================================================

func _on_register_success(user_data) -> void:

	print("================================")
	print("MAIN MENU: REGISTER SUCCESS")
	print("================================")

	# Registration does not necessarily log the user in.
	update_login_panel()


# =========================================================
# REGISTER FAILED
# =========================================================

func _on_register_failed(error_message) -> void:

	print("REGISTER FAILED: ", error_message)

	update_login_panel()


# =========================================================
# PROFILE LOADED
# =========================================================

func _on_profile_loaded(username: String):

	print("Main menu received username: ", username)

	# Update username on main menu
	guest_label.text = username

	# Update account panel name
	user_name.text = "Name: " + username

	# Close login/account panel
	login_bg.visible = false
	login_ui.visible = true

	# Update account panel
	update_login_panel()


# =========================================================
# PLAYER STATS LOADED
# =========================================================

func _on_player_stats_loaded(stats: Dictionary):

	print("================================")
	print("MAIN MENU: PLAYER STATS LOADED")
	print("================================")

	var matches_played: int = int(
		stats.get("matches_played", 0)
	)

	var average_score: float = float(
		stats.get("average_score", 0.0)
	)

	print("Matches played: ", matches_played)
	print("Average score: ", average_score)


	# =====================================================
	# UPDATE UI
	# =====================================================

	user_matches_played.text = "Matches: " + str(matches_played)

	# Round average score so we don't show
	# something like 734.6666666667
	user_avg_score.text ="AvgScore: " + str(
		round(average_score)
	)

	print("Stats UI updated.")

	print("================================")


# =========================================================
# PLAYER STATS FAILED
# =========================================================

func _on_player_stats_failed(error_message):

	print("================================")
	print("PLAYER STATS FAILED")
	print(error_message)
	print("================================")

	# Show default values instead of leaving
	# the labels blank.

	user_matches_played.text = "0"
	user_avg_score.text = "0"


# =========================================================
# UPDATE LOGIN PANEL
# =========================================================

func update_login_panel():

	if Supabase.is_logged_in:

		# -------------------------------------------------
		# Hide login form
		# -------------------------------------------------

		username_input.hide()
		email_input.hide()
		password_input.hide()

		submit_login.hide()
		login_button.hide()
		register_button.hide()

		# -------------------------------------------------
		# Show account panel
		# -------------------------------------------------

		close_button.show()
		control.show()

		# -------------------------------------------------
		# Username
		# -------------------------------------------------

		user_name.text = (
			"Name: "
			+ Supabase.current_username
		)

	else:

		# -------------------------------------------------
		# Show login/register form
		# -------------------------------------------------

		email_input.show()
		password_input.show()

		submit_login.show()

		# IMPORTANT:
		# DO NOT control login/register mode here.
		#
		# login.gd handles:
		# REGISTER MODE
		# LOGIN MODE
		#
		# Otherwise the two scripts will fight again.

		# -------------------------------------------------
		# Hide account panel
		# -------------------------------------------------

		control.hide()


# =========================================================
# LOGOUT
# =========================================================

func _on_logout_pressed():

	print("Logging out...")

	Supabase.logout_user()

	# Reset main menu username
	guest_label.text = "Guest"

	# Reset account labels
	user_name.text = "Name: Guest"
	user_avg_score.text = "0"
	user_matches_played.text = "0"

	# Close account panel
	login_bg.visible = false

	# Show normal account UI
	login_ui.visible = true

	# Update panel
	update_login_panel()

	print("User logged out.")
