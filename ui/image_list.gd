@tool
class_name ImageList extends VBoxContainer

var file_dialog: FileDialog = FileDialog.new()
var gallery_sce: PackedScene = preload("./image_gallery.tscn")

func _ready() -> void:
	init_filedialog()
	add_child(file_dialog)
	%AddImage.pressed.connect(popup_file_dialog)
	%Delete.pressed.connect(clear_images)
	var path: String = "../asset/default.jpeg"
	path = self.get_script().resource_path.get_base_dir().path_join(path)

	self.add_image(path)
	# self.add_image("/Users/karrycharon/Desktop/OutputImage/ComfyUI_00391_.png")

func add_image(path: String) -> ImageGallery:
	var gallery: ImageGallery = gallery_sce.instantiate()
	add_child(gallery)
	gallery.load_image.call_deferred(path)
	return gallery

func prepare_images() -> Array:
	var images: Array = []
	for image in get_children():
		if not (image is ImageGallery):
			continue
		images.append(image.prepare_image())
	return images

func init_filedialog() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.visible = false
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	#file_dialog.root_subfolder = "/Users/karrycharon/Desktop/OutputImage"
	file_dialog.filters = ["*.png; PNG Images", "*.jpg; JPEG Images", "*.jpeg; JPEG Images",]
	file_dialog.files_selected.connect(proc)
	file_dialog.ok_button_text = "确认"
	file_dialog.cancel_button_text = "取消"
	file_dialog.title = "请选择图片"
	file_dialog.dialog_hide_on_ok = true
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)

func proc(paths: PackedStringArray) -> void:
	for path in paths:
		add_image(path)

func popup_file_dialog() -> void:
	file_dialog.popup_centered(Vector2i(400, 600))

func clear_images() -> void:
	for child in get_children():
		if not (child is ImageGallery):
			continue
		child.queue_free()
