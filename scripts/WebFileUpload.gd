extends Node

# =========================================================
# WEB FILE UPLOAD (multi-file version)
#
# Works around two Godot Web-export limitations:
#   1. FileDialog can only browse Godot's sandboxed virtual
#      filesystem in Web exports (not the real OS files).
#   2. files_dropped signal is unreliable / broken on Web.
#
# Uses JavaScriptBridge to talk to the browser directly:
#   - open_file_picker() -> opens the REAL native OS file picker
#     (supports selecting multiple files)
#   - enable_drag_and_drop_on_canvas() -> real HTML5 drag & drop
#     (supports dropping multiple files)
#
# SETUP:
#   1. Add this as an Autoload (Project Settings > Autoload)
#      named "WebFileUpload".
#   2. Call WebFileUpload.open_file_picker() from your
#      "Choose File" button instead of opening a FileDialog,
#      on Web only.
#   3. Call WebFileUpload.enable_drag_and_drop_on_canvas() once
#      (e.g. in your dialog's _ready()) on Web only.
#   4. Connect to `files_selected` to get an Array of
#      { "bytes": PackedByteArray, "filename": String }.
# =========================================================

signal files_selected(files: Array)          # Array of {bytes, filename}
signal file_selection_cancelled()
signal file_selection_error(message: String)

var _js_callback_ref
var _is_web: bool = false

var _pending_files: Array = []
var _pending_total: int = 0


func _ready() -> void:
	_is_web = OS.get_name() == "Web"

	if not _is_web:
		return

	_js_callback_ref = JavaScriptBridge.create_callback(_on_js_file_chunk)
	JavaScriptBridge.get_interface("window").godotFileCallback = _js_callback_ref

	JavaScriptBridge.eval("""
		if (!document.getElementById('godot-file-input')) {
			var input = document.createElement('input');
			input.type = 'file';
			input.id = 'godot-file-input';
			input.accept = 'image/png,image/jpeg';
			input.multiple = true;
			input.style.display = 'none';
			document.body.appendChild(input);
		}

		window.godotReadFiles = function(fileList) {
			var files = Array.prototype.slice.call(fileList);
			if (files.length === 0) {
				window.godotFileCallback(null, '', 0, 0, 'No file selected.');
				return;
			}
			files.forEach(function(file, index) {
				var reader = new FileReader();
				reader.onload = function(e) {
					window.godotFileCallback(e.target.result, file.name, index, files.length, '');
				};
				reader.onerror = function() {
					window.godotFileCallback(null, file.name, index, files.length, 'Failed to read file.');
				};
				reader.readAsArrayBuffer(file);
			});
		};

		document.getElementById('godot-file-input').onchange = function(e) {
			window.godotReadFiles(e.target.files);
		};
	""", true)


# ---------------------------------------------------------
# Opens the browser's REAL native file picker (multi-select).
# ---------------------------------------------------------
func open_file_picker() -> void:
	if not _is_web:
		push_warning("WebFileUpload.open_file_picker() only works on Web export.")
		return

	_pending_files.clear()
	_pending_total = 0

	JavaScriptBridge.eval("""
		var input = document.getElementById('godot-file-input');
		input.value = '';
		input.click();
	""", true)


# ---------------------------------------------------------
# Enables real HTML5 drag-and-drop (multi-file) onto the
# game canvas. Call this once, e.g. in a dialog's _ready().
# Assumes the exported canvas element has id="canvas"
# (Godot's default).
# ---------------------------------------------------------
func enable_drag_and_drop_on_canvas() -> void:
	if not _is_web:
		return

	JavaScriptBridge.eval("""
		var canvas = document.getElementById('canvas');
		if (canvas && !canvas.dataset.godotDropBound) {
			canvas.dataset.godotDropBound = '1';

			canvas.addEventListener('dragover', function(e) {
				e.preventDefault();
			});

			canvas.addEventListener('drop', function(e) {
				e.preventDefault();
				window.godotReadFiles(e.dataTransfer.files);
			});
		}
	""", true)


# ---------------------------------------------------------
# Called from JS once per file as it finishes reading.
# args = [arrayBufferOrNull, filename, index, total, errorMessage]
# Accumulates until all files in the batch have arrived, then
# emits files_selected with the whole batch at once.
# ---------------------------------------------------------
func _on_js_file_chunk(args: Array) -> void:
	var buffer = args[0]
	var filename: String = args[1]
	var total: int = int(args[3])
	var error_message: String = args[4]

	if total == 0:
		file_selection_cancelled.emit()
		return

	if buffer == null:
		file_selection_error.emit(
			error_message if error_message != "" else "Failed to read a file."
		)
		return

	_pending_total = total
	_pending_files.append({
		"bytes": JavaScriptBridge.js_buffer_to_packed_byte_array(buffer),
		"filename": filename
	})

	if _pending_files.size() >= _pending_total:
		var result: Array = _pending_files.duplicate()
		_pending_files.clear()
		_pending_total = 0
		files_selected.emit(result)
