extends Control

# NOTE: In the scene, these nodes must be changed (Change Type in the editor)
# from MarginContainer/VBoxContainer/HBoxContainer/PanelContainer to
# Control (or Panel for PanelCenter, to keep the background stylebox).
# Positioning for PageUpload's children is now handled in _layout_upload_page()
# below instead of manually in the editor.

@onready var dim_bg: ColorRect          = $DimBackground
@onready var panel: Panel               = $PanelCenter
@onready var margin: Control            = $PanelCenter/MarginContainer
@onready var vbox: Control              = $PanelCenter/MarginContainer/VBoxContainer
@onready var page_rules: Control        = $PanelCenter/MarginContainer/VBoxContainer/PageRules
@onready var page_upload: Control       = $PanelCenter/MarginContainer/VBoxContainer/PageUpload
@onready var rules_buttons: Control     = $PanelCenter/MarginContainer/VBoxContainer/PageRules/HBoxContainer
@onready var upload_buttons: Control    = $PanelCenter/MarginContainer/VBoxContainer/PageUpload/HBoxContainer
@onready var drop_area: Panel           = $PanelCenter/MarginContainer/VBoxContainer/PageUpload/DropArea
@onready var title_label: Label         = $PanelCenter/MarginContainer/VBoxContainer/PageUpload/titleLabel
@onready var back_button: Button        = $PanelCenter/MarginContainer/VBoxContainer/PageUpload/HBoxContainer/BackButton

@onready var file_dialog: FileDialog       = $FileDialog
@onready var choose_file_button: Button    = $PanelCenter/MarginContainer/VBoxContainer/PageUpload/ChooseFileButton
@onready var hint_label: Label             = $PanelCenter/MarginContainer/VBoxContainer/PageUpload/DropArea/HintLabel
@onready var preview_image: TextureRect    = $PanelCenter/MarginContainer/VBoxContainer/PageUpload/DropArea/PreviewImage
@onready var confirm_button: Button        = $PanelCenter/MarginContainer/VBoxContainer/PageUpload/HBoxContainer/ConfirmButton

# Unified storage for both platforms: { "bytes": PackedByteArray, "ext": String }
var selected_files: Array = []

const MAX_FILE_SIZE_MB := 10
const ALLOWED_EXTENSIONS := ["png", "jpg", "jpeg"]
var IS_WEB := OS.get_name() == "Web"

# ---------- setup ----------

func _ready():
	_layout_upload_page()

	if IS_WEB:
		WebFileUpload.files_selected.connect(_on_web_files_selected)
		WebFileUpload.file_selection_error.connect(_show_error)
		WebFileUpload.enable_drag_and_drop_on_canvas()
	else:
		_setup_file_dialog()

	_show_rules_page()
	confirm_button.disabled = true  # no images picked yet


func _setup_file_dialog():
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg ; Image Files"])
	file_dialog.files_selected.connect(_on_files_selected)

	if OS.has_feature("pc"):
		get_tree().get_root().files_dropped.connect(_on_files_dropped)


# ---------- basic manual layout for PageUpload ----------
# These nodes are plain Controls (no auto-layout), so we position
# them here instead of dragging them in the editor.

func _layout_upload_page() -> void:
	var w: float = vbox.size.x
	if w <= 0:
		w = 440.0
		vbox.size.x = w

	page_upload.position = Vector2.ZERO
	page_upload.size = Vector2(w, vbox.size.y)

	title_label.position = Vector2(0, 0)
	title_label.size = Vector2(w, 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	drop_area.position = Vector2(0, 36)
	drop_area.size = Vector2(w, 200)

	preview_image.position = Vector2(10, 10)
	preview_image.size = drop_area.size - Vector2(20, 20)
	preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_image.visible = false

	hint_label.position = Vector2(10, drop_area.size.y / 2.0 - 12)
	hint_label.size = Vector2(w - 20, 24)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	choose_file_button.position = Vector2((w - 160) / 2.0, 246)
	choose_file_button.size = Vector2(160, 36)

	upload_buttons.position = Vector2(0, 300)
	upload_buttons.size = Vector2(w, 36)

	back_button.position = Vector2(0, 0)
	back_button.size = Vector2(100, 36)

	confirm_button.position = Vector2(w - 120, 0)
	confirm_button.size = Vector2(120, 36)


# ---------- page switching ----------

func _show_rules_page():
	page_rules.show()
	page_upload.hide()

func _on_next_button_pressed():
	page_rules.hide()
	page_upload.show()

func _on_back_button_pressed():
	_show_rules_page()

func _on_cancel_button_pressed():
	preview_image.texture = null
	preview_image.visible = false
	hint_label.text = "Drag & drop images here, or click Choose File"
	selected_files.clear()
	hide()


# ---------- desktop (native FileDialog / OS drag&drop) ----------

func _on_files_dropped(files: PackedStringArray):
	if files.size() > 0:
		_try_use_images(files)

func _on_files_selected(paths: PackedStringArray):
	_try_use_images(paths)

func _on_choose_file_button_pressed() -> void:
	if IS_WEB:
		WebFileUpload.open_file_picker()
	else:
		file_dialog.popup_centered_ratio(0.7)

func _try_use_images(paths: PackedStringArray):
	var valid: Array = []
	var skipped := 0

	for path in paths:
		var ext := path.get_extension().to_lower()
		if not ALLOWED_EXTENSIONS.has(ext):
			skipped += 1
			continue

		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			skipped += 1
			continue

		var size_mb := file.get_length() / (1024.0 * 1024.0)
		if size_mb > MAX_FILE_SIZE_MB:
			file.close()
			skipped += 1
			continue

		var bytes := file.get_buffer(file.get_length())
		file.close()

		if _decode_image(bytes, ext) == null:
			skipped += 1
			continue

		valid.append({"bytes": bytes, "ext": ext})

	_finish_selection(valid, skipped)


# ---------- web (JS file picker / HTML5 drag&drop via WebFileUpload) ----------

func _on_web_files_selected(files: Array) -> void:
	var valid: Array = []
	var skipped := 0

	for f in files:
		var filename: String = f.get("filename", "")
		var ext := filename.get_extension().to_lower()
		var bytes: PackedByteArray = f.get("bytes", PackedByteArray())

		if not ALLOWED_EXTENSIONS.has(ext):
			skipped += 1
			continue

		if bytes.size() > MAX_FILE_SIZE_MB * 1024 * 1024:
			skipped += 1
			continue

		if _decode_image(bytes, ext) == null:
			skipped += 1
			continue

		valid.append({"bytes": bytes, "ext": ext})

	_finish_selection(valid, skipped)


# ---------- shared helpers ----------

func _decode_image(bytes: PackedByteArray, ext: String) -> Image:
	var img := Image.new()
	var err: int
	if ext == "png":
		err = img.load_png_from_buffer(bytes)
	else:
		err = img.load_jpg_from_buffer(bytes)

	if err != OK:
		return null
	return img


func _finish_selection(valid: Array, skipped: int) -> void:
	if valid.is_empty():
		_show_error("No valid images selected (PNG/JPG, max %d MB each)." % MAX_FILE_SIZE_MB)
		return

	selected_files = valid
	_update_preview(skipped)
	confirm_button.disabled = false


func _update_preview(skipped_count: int):
	var img := _decode_image(selected_files[0]["bytes"], selected_files[0]["ext"])
	if img:
		preview_image.texture = ImageTexture.create_from_image(img)
		preview_image.visible = true

	hint_label.remove_theme_color_override("font_color")
	hint_label.visible = true

	if selected_files.size() == 1:
		hint_label.text = "1 image selected"
	else:
		hint_label.text = "%d images selected" % selected_files.size()

	if skipped_count > 0:
		hint_label.text += "  (%d skipped: invalid/too large)" % skipped_count


func _show_error(msg: String):
	hint_label.text = msg
	hint_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	preview_image.visible = false
	hint_label.visible = true
	confirm_button.disabled = true


func _on_confirm_button_pressed() -> void:
	if selected_files.is_empty():
		return

	GameState.pending_uploads = selected_files
	GameState.current_upload_index = 0
	GameState.mode = "placement"

	get_tree().change_scene_to_file("res://scenes/Main.tscn")
