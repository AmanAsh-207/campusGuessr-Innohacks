extends Control

@onready var question_image: TextureRect = $QuestionImage
@onready var map: TextureRect = $map
@onready var marker: Sprite2D = $map/marker



const QUESTIONS = [
	preload("uid://x5g5tx7km5ke"),
	preload("uid://bwcnl1gcmb28e"),
	preload("uid://bff81h31mna6o"),
	preload("uid://3p82k3ucw6rh"),
	preload("uid://cx7sbua4wwc1p")
	
]

const IMAGE_NAMES = [
	"image1.png",
	"image2.png",
	"image3.png",
	"image4.png",
	"image5.png",
]

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

	

func _on_map_gui_input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:

		var click_pos = event.position

		print("Click:", click_pos)
		print("Marker:", marker.position)

		if marker.visible:
			print("Distance:", click_pos.distance_to(marker.position))

		if marker.visible and click_pos.distance_to(marker.position) < 40:
			print("Hiding marker")
			marker.visible = false
			return

		print("Showing marker")
		marker.position = click_pos
		marker.visible = true

		current_location = Vector2(
			click_pos.x / map.size.x,
			click_pos.y / map.size.y
		)
