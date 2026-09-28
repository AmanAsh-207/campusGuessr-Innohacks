extends Control


# =========================================================
# UI REFERENCES
# =========================================================

@onready var username_input: LineEdit = $loginPanel/UsernameInput
@onready var email_input: LineEdit = $loginPanel/EmailInput
@onready var password_input: LineEdit = $loginPanel/passwordInput

@onready var submit_login: Button = $loginPanel/SubmitLogin
@onready var close_button: Button = $loginPanel/CloseButton

# These are MODE SWITCH buttons
@onready var switch_to_login_button: Button = $loginPanel/login
@onready var switch_to_register_button: Button = $loginPanel/Register


# =========================================================
# STATE
# =========================================================

var register_mode := true
var request_in_progress := false


# =========================================================
# READY
# =========================================================

func _ready():

	# -----------------------------------------------------
	# Button connections
	# -----------------------------------------------------

	submit_login.pressed.connect(_on_submit_pressed)

	switch_to_login_button.pressed.connect(_on_login_mode_pressed)
	switch_to_register_button.pressed.connect(_on_register_mode_pressed)

	close_button.pressed.connect(_on_close_pressed)


	# -----------------------------------------------------
	# ENTER key from LineEdits
	# -----------------------------------------------------

	email_input.text_submitted.connect(_on_text_submitted)
	password_input.text_submitted.connect(_on_text_submitted)
	username_input.text_submitted.connect(_on_text_submitted)


	# -----------------------------------------------------
	# Supabase signals
	# -----------------------------------------------------

	Supabase.login_success.connect(_on_login_success)
	Supabase.login_failed.connect(_on_login_failed)

	Supabase.register_success.connect(_on_register_success)
	Supabase.register_failed.connect(_on_register_failed)


	# -----------------------------------------------------
	# IMPORTANT:
	# Start in REGISTER mode
	# -----------------------------------------------------

	set_register_mode()


# =========================================================
# REGISTER MODE
# =========================================================

func set_register_mode():

	register_mode = true
	request_in_progress = false

	# -----------------------------------------------------
	# Show registration fields
	# -----------------------------------------------------

	username_input.show()
	email_input.show()
	password_input.show()

	# -----------------------------------------------------
	# Main submit button
	# -----------------------------------------------------

	submit_login.show()
	submit_login.text = "CREATE ACCOUNT"

	# -----------------------------------------------------
	# Mode buttons
	#
	# REGISTER MODE:
	# LOGIN button = visible
	# REGISTER button = hidden
	# -----------------------------------------------------

	switch_to_login_button.show()
	switch_to_register_button.hide()

	# Focus username
	username_input.grab_focus()

	print("================================")
	print("REGISTER MODE")
	print("Username visible: ", username_input.visible)
	print("Login button visible: ", switch_to_login_button.visible)
	print("Register button visible: ", switch_to_register_button.visible)
	print("================================")


# =========================================================
# LOGIN MODE
# =========================================================

func set_login_mode():

	register_mode = false
	request_in_progress = false

	# -----------------------------------------------------
	# Hide username because login doesn't need it
	# -----------------------------------------------------

	username_input.hide()

	# Email + password remain visible
	email_input.show()
	password_input.show()

	# -----------------------------------------------------
	# Main submit button
	# -----------------------------------------------------

	submit_login.show()
	submit_login.text = "ENTER"

	# -----------------------------------------------------
	# Mode buttons
	#
	# LOGIN MODE:
	# LOGIN button = hidden
	# REGISTER button = visible
	# -----------------------------------------------------

	switch_to_login_button.hide()
	switch_to_register_button.show()

	# Focus email
	email_input.grab_focus()

	print("================================")
	print("LOGIN MODE")
	print("Username visible: ", username_input.visible)
	print("Login button visible: ", switch_to_login_button.visible)
	print("Register button visible: ", switch_to_register_button.visible)
	print("================================")


# =========================================================
# ENTER KEY
# =========================================================

func _on_text_submitted(_text: String):

	if request_in_progress:
		return

	_on_submit_pressed()


func _unhandled_key_input(event):

	if not event.is_pressed():
		return

	if event.keycode != KEY_ENTER and event.keycode != KEY_KP_ENTER:
		return

	if request_in_progress:
		return

	# -----------------------------------------------------
	# REGISTER MODE
	#
	# ENTER on LOGIN button
	# -----------------------------------------------------

	if register_mode and switch_to_login_button.visible:
		_on_login_mode_pressed()
		return

	# -----------------------------------------------------
	# LOGIN MODE
	#
	# ENTER on REGISTER button
	# -----------------------------------------------------

	if not register_mode and switch_to_register_button.visible:
		_on_register_mode_pressed()
		return


# =========================================================
# SUBMIT
# =========================================================

func _on_submit_pressed():

	if request_in_progress:
		return

	request_in_progress = true

	if register_mode:
		register_account()
	else:
		login_account()


# =========================================================
# REGISTER ACCOUNT
# =========================================================

func register_account():

	var username := username_input.text.strip_edges()
	var email := email_input.text.strip_edges()
	var password := password_input.text

	print("================================")
	print("REGISTER")
	print("Username: ", username)
	print("Email: ", email)
	print("================================")


	# -----------------------------------------------------
	# Validation
	# -----------------------------------------------------

	if username.is_empty():

		print("Username is empty!")

		request_in_progress = false
		username_input.grab_focus()

		return


	if email.is_empty():

		print("Email is empty!")

		request_in_progress = false
		email_input.grab_focus()

		return


	if password.is_empty():

		print("Password is empty!")

		request_in_progress = false
		password_input.grab_focus()

		return


	# -----------------------------------------------------
	# Close UI while request is running
	# -----------------------------------------------------

	close_login_ui()


	# -----------------------------------------------------
	# Supabase registration
	# -----------------------------------------------------

	Supabase.register_user(
		username,
		email,
		password
	)


# =========================================================
# LOGIN ACCOUNT
# =========================================================

func login_account():

	var email := email_input.text.strip_edges()
	var password := password_input.text

	print("================================")
	print("LOGIN")
	print("Email: ", email)
	print("================================")


	# -----------------------------------------------------
	# Validation
	# -----------------------------------------------------

	if email.is_empty():

		print("Email is empty!")

		request_in_progress = false
		email_input.grab_focus()

		return


	if password.is_empty():

		print("Password is empty!")

		request_in_progress = false
		password_input.grab_focus()

		return


	# -----------------------------------------------------
	# Close UI while request is running
	# -----------------------------------------------------

	close_login_ui()


	# -----------------------------------------------------
	# Supabase login
	# -----------------------------------------------------

	Supabase.login_user(
		email,
		password
	)


# =========================================================
# SWITCH TO LOGIN
# =========================================================

func _on_login_mode_pressed():

	print("Switching to LOGIN mode")

	set_login_mode()


# =========================================================
# SWITCH TO REGISTER
# =========================================================

func _on_register_mode_pressed():

	print("Switching to REGISTER mode")

	set_register_mode()


# =========================================================
# CLOSE LOGIN UI
# =========================================================

func close_login_ui():

	clear_login_fields()

	hide()

	var parent := get_parent()

	if parent:

		var login_bg = parent.get_node_or_null("login_bg")

		if login_bg:
			login_bg.hide()


# =========================================================
# CLOSE BUTTON
# =========================================================

func _on_close_pressed():

	close_login_ui()


# =========================================================
# LOGIN SUCCESS
# =========================================================

func _on_login_success(user_data):

	print("================================")
	print("LOGIN SUCCESS!")
	print(user_data)
	print("================================")

	clear_login_fields()

	request_in_progress = false


# =========================================================
# LOGIN FAILED
# =========================================================

func _on_login_failed(error_message):

	request_in_progress = false

	print("================================")
	print("LOGIN FAILED")
	print(error_message)
	print("================================")


	# Re-open UI
	show()

	var parent := get_parent()

	if parent:

		var login_bg = parent.get_node_or_null("login_bg")

		if login_bg:
			login_bg.show()


	# Make sure we're in LOGIN mode
	set_login_mode()

	password_input.grab_focus()


# =========================================================
# REGISTER SUCCESS
# =========================================================

func _on_register_success(user_data):

	request_in_progress = false

	print("================================")
	print("REGISTER SUCCESS!")
	print(user_data)
	print("================================")

	clear_login_fields()


# =========================================================
# REGISTER FAILED
# =========================================================

func _on_register_failed(error_message):

	request_in_progress = false

	print("================================")
	print("REGISTER FAILED")
	print(error_message)
	print("================================")


	# Re-open UI
	show()

	var parent := get_parent()

	if parent:

		var login_bg = parent.get_node_or_null("login_bg")

		if login_bg:
			login_bg.show()


	# Stay in REGISTER mode
	set_register_mode()

	username_input.grab_focus()


# =========================================================
# CLEAR FIELDS
# =========================================================

func clear_login_fields():

	username_input.clear()
	email_input.clear()
	password_input.clear()
