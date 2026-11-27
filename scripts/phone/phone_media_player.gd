extends Control

signal close_requested
var _feed_items: Array[Dictionary] = []
var _current_index := -1
var _current_path := ""
var _current_title := ""
var _feed_buttons: Array[Button] = []
## Plays actual imported video and image assets; metadata-only feed entries are rejected.
@onready var video: VideoStreamPlayer = $Layout/MediaFrame/Video
@onready var image: TextureRect = $Layout/MediaFrame/Image
@onready var status: Label = $Layout/Status
@onready var source_path: LineEdit = $Layout/SourcePath
@onready var feed_list: VBoxContainer = $Layout/FeedScroll/FeedList

func _ready() -> void:
	video.finished.connect(_on_video_finished)
	$Layout/Actions/Open.pressed.connect(_on_open_pressed)
	$Layout/Actions/Stop.pressed.connect(_on_stop_pressed)
	var previous := Button.new()
	previous.name = "Previous"
	previous.text = "PREVIOUS"
	previous.pressed.connect(_show_previous)
	$Layout/Actions.add_child(previous)
	var next := Button.new()
	next.name = "Next"
	next.text = "NEXT"
	next.pressed.connect(_show_next)
	$Layout/Actions.add_child(next)
	$Layout/Actions/Close.pressed.connect(func() -> void: close_requested.emit())
	status.text = "Choose an imported video (.ogv) or image asset."
	image.hide()

func load_feed(items: Array) -> void:
	_feed_items.clear()
	_current_index = -1
	_feed_buttons.clear()
	var playable_count := 0
	for child in feed_list.get_children():
		child.queue_free()
	for item in items:
		if not item is Dictionary:
			continue
		var record: Dictionary = item
		_feed_items.append(record.duplicate(true))
		var title := str(record.get("title", record.get("caption", "Untitled media")))
		var path := str(record.get("asset_path", record.get("file_path", "")))
		var entry := Button.new()
		entry.text = title + ("  •  " + path.get_file() if not path.is_empty() else "  •  Media file unavailable")
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var available := not path.is_empty() and ResourceLoader.exists(path)
		entry.disabled = not available
		if available:
			playable_count += 1
		var item_index := _feed_items.size() - 1
		entry.pressed.connect(func() -> void: _play_feed_item(item_index))
		_feed_buttons.append(entry)
		feed_list.add_child(entry)
	if _feed_items.is_empty():
		status.text = "No media items in this feed yet."
	else:
		status.text = str(_feed_items.size()) + " feed entries • " + str(playable_count) + " playable installed assets."

func _play_feed_item(index: int) -> void:
	if index < 0 or index >= _feed_items.size():
		return
	_current_index = index
	for i in range(_feed_buttons.size()):
		_feed_buttons[i].modulate = Color(0.2, 1.0, 1.0) if i == index else Color.WHITE
	open_media(_feed_items[index])

func _show_previous() -> void:
	if not _feed_items.is_empty():
		_play_feed_item(posmod(_current_index - 1, _feed_items.size()))

func _show_next() -> void:
	if not _feed_items.is_empty():
		_play_feed_item(posmod(_current_index + 1, _feed_items.size()))

func open_media(media: Dictionary) -> bool:
	var path := str(media.get("asset_path", media.get("file_path", ""))).strip_edges()
	if path.is_empty() or not ResourceLoader.exists(path):
		status.text = "Real media file is not installed: " + path
		return false
	return open_asset(path)

func open_asset(path: String) -> bool:
	var resource: Resource = load(path)
	if resource is VideoStream:
		video.stop()
		image.hide()
		video.stream = resource as VideoStream
		video.show()
		video.play()
		_current_path = path
		_current_title = str(_feed_items[_current_index].get("title", _feed_items[_current_index].get("caption", path.get_file()))) if _current_index >= 0 and _current_index < _feed_items.size() else path.get_file()
		status.text = "NOW PLAYING  •  " + _current_title + "  •  " + path.get_file()
		return true
	if resource is Texture2D:
		video.stop()
		video.hide()
		image.texture = resource as Texture2D
		image.show()
		_current_path = path
		_current_title = str(_feed_items[_current_index].get("title", _feed_items[_current_index].get("caption", path.get_file()))) if _current_index >= 0 and _current_index < _feed_items.size() else path.get_file()
		status.text = "PHOTO  •  " + _current_title + "  •  " + path.get_file()
		return true
	status.text = "Unsupported asset. Use a Godot video stream or image texture."
	return false

func _on_open_pressed() -> void:
	open_asset(source_path.text)

func _on_stop_pressed() -> void:
	video.stop()
	video.stream = null
	image.texture = null
	image.hide()
	video.hide()
	_current_path = ""
	_current_title = ""
	for entry in _feed_buttons:
		entry.modulate = Color.WHITE
	status.text = "Playback stopped. Choose another feed item or open an asset."

func _on_video_finished() -> void:
	status.text = "Video finished. Loading next installed media…"
	if _feed_items.size() > 1:
		for offset in range(1, _feed_items.size()):
			var candidate := posmod(_current_index + offset, _feed_items.size())
			var path := str(_feed_items[candidate].get("asset_path", _feed_items[candidate].get("file_path", ""))).strip_edges()
			if not path.is_empty() and ResourceLoader.exists(path):
				_play_feed_item(candidate)
				return
	status.text = "Video finished. No other installed media is available."