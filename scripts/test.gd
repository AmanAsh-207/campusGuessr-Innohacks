extends Control
@onready var question_image: TextureRect = $QuestionImage
@onready var map: Sprite2D = $map
@onready var marker: Sprite2D = $map/marker
const QUESTIONS = [
	preload("uid://2hvacl14xhcj"),
	preload("uid://dc2rp6gve4iho"),
	preload("uid://dd23j8mhmn0sd"),
	preload("uid://dnrsfjp6oe0m5"),
	preload("uid://bgo4wn1qqgwbd"),
	preload("uid://tj0ptykrkyi3"),
	preload("uid://cc6fb33fvj5l3"),
	preload("uid://bvevfsp21315j")
]
const UIDS = [
	"uid://2hvacl14xhcj",
	"uid://dc2rp6gve4iho",
	"uid://dd23j8mhmn0sd",
	"uid://dnrsfjp6oe0m5",
	"uid://bgo4wn1qqgwbd",
	"uid://tj0ptykrkyi3",
	"uid://cc6fb33fvj5l3",
	"uid://bvevfsp21315j"
]
const IMAGE_NAMES = [
	"image1.png",
	"image2.png",
	"image4.png",
	"image5.png",
	"image6.png",
	"image8.png",
	"image9.png",
	"image10.png",
]

# Keep these in the same order/index as IMAGE_NAMES so we can look the uid
# back up when printing the ANSWERS 


var current_index := 0
var current_location := Vector2.ZERO
var data := []

func _ready():
	print("READY")
	load_current_image()
	marker.visible = false
	question_image.custom_minimum_size = Vector2(40, 40)
	question_image.size = Vector2(40, 40)
	
func load_current_image():
	question_image.texture = QUESTIONS[current_index]
	question_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	question_image.stretch_mode = TextureRect.STRETCH_SCALE
	marker.visible = false
	
	
func _on_save_pressed() -> void:
	data.append({
		"image": IMAGE_NAMES[current_index],
		"x": current_location.x,
		"y": current_location.y
	})
	print("Saved:", data.back())
func _on_next_pressed() -> void:
	current_index += 1
	if current_index >= QUESTIONS.size():
		save_json()
		print_answers_array()
		print("Finished!")
		return
	load_current_image()
	
func save_json():
	var file = FileAccess.open("user://locations.json", FileAccess.WRITE)
	file.store_string(
		JSON.stringify(data, "\t")
	)
	file.close()
	print("Saved to user://locations.json")
	print(ProjectSettings.globalize_path("user://locations.json"))

## Prints `data` formatted as a ready-to-paste GDScript `ANSWERS` array,
## matching the const format used in the game script (preload + name/x/y).
func print_answers_array() -> void:
	var lines := []
	for entry in data:
		var idx: int = IMAGE_NAMES.find(entry["image"])
		var uid: String = UIDS[idx] if idx != -1 else "MISSING_UID"
		lines.append('\t{ "image": preload("%s"), "name": "%s", "x": %s, "y": %s },' % [
			uid, entry["image"], entry["x"], entry["y"]
		])
	var output := "const ANSWERS = [\n" + "\n".join(lines) + "\n]"
	print(output)
	
func _input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:

		var mouse_pos = get_global_mouse_position()

		# Convert mouse position to the map's local coordinates
		var click_pos = map.to_local(mouse_pos)

		var tex_size = map.texture.get_size()

		# Ignore clicks outside the sprite
		if click_pos.x < -tex_size.x / 2 \
		or click_pos.x > tex_size.x / 2 \
		or click_pos.y < -tex_size.y / 2 \
		or click_pos.y > tex_size.y / 2:
			return

		print("Click:", click_pos)

		if marker.visible and click_pos.distance_to(marker.position) < 40:
			marker.visible = false
			return

		marker.position = click_pos
		marker.visible = true

		current_location = Vector2(
			(click_pos.x + tex_size.x / 2) / tex_size.x,
			(click_pos.y + tex_size.y / 2) / tex_size.y
		)
