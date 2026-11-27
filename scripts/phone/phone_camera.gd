extends RefCounted
## Local photo capture and gallery storage for ZERO LINK.
const GALLERY_DIR := "user://phone_gallery"

func capture_viewport(viewport: Viewport) -> Dictionary:
    if viewport == null:
        return {"ok": false, "error": "viewport_unavailable"}
    var image := viewport.get_texture().get_image()
    if image == null or image.is_empty():
        return {"ok": false, "error": "empty_frame"}
    var directory := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GALLERY_DIR))
    if directory != OK and directory != ERR_ALREADY_EXISTS:
        return {"ok": false, "error": "gallery_directory_unavailable"}
    var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
    var path := GALLERY_DIR.path_join("zero_photo_" + stamp + "_" + str(Time.get_ticks_msec()) + ".png")
    var result := image.save_png(path)
    if result != OK:
        return {"ok": false, "error": "save_failed"}
    return {"ok": true, "path": path, "width": image.get_width(), "height": image.get_height()}

func get_gallery_images() -> Array[String]:
    var files: Array[String] = []
    var directory := DirAccess.open(GALLERY_DIR)
    if directory == null:
        return files
    directory.list_dir_begin()
    var filename := directory.get_next()
    while not filename.is_empty():
        if not directory.current_is_dir() and filename.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
            files.append(GALLERY_DIR.path_join(filename))
        filename = directory.get_next()
    directory.list_dir_end()
    files.sort()
    files.reverse()
    return files

func load_photo(path: String) -> Image:
    if not path.begins_with(GALLERY_DIR + "/") or not FileAccess.file_exists(path):
        return null
    var image := Image.new()
    var result := image.load(path)
    return image if result == OK else null

func delete_photo(path: String) -> bool:
    if not path.begins_with(GALLERY_DIR + "/") or not FileAccess.file_exists(path):
        return false
    return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
