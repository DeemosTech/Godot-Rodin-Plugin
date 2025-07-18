@tool 
class_name ImageGallery extends PanelContainer

@onready var image_node: TextureRect = %Image

func _ready() -> void:
	%"删除".pressed.connect(queue_free)
	%"替换".load_image.connect(load_image)

func load_image(path: String) -> void:
	if path.begins_with("res://"):
		image_node.texture = load(path)
	else:
		var image = Image.load_from_file(path)
		image_node.texture = ImageTexture.create_from_image(image)
	var image_size = image_node.texture.get_size()
	%Info.text = "图片尺寸: %d x %d" % [image_size.x, image_size.y]

func prepare_image() -> Dictionary:
	var texture: Texture2D = image_node.texture
	var img = texture.get_image()
	#var png_buffer = FileAccess.get_file_as_bytes(path)
	#var img = Image.new()
	#img.load(path)
	#var save_path = convert_image(img)
	#var img_data = FileAccess.get_file_as_bytes(save_path)
	var img_data = img.save_png_to_buffer()
	var buffer = "data:image/png;base64," + Marshalls.raw_to_base64(img_data)
	var data = {
		"format": "png",  # 文件格式
		"length": buffer.length(),  # 文件长度
		"md5": buffer.md5_text(),  # 文件md5
		"content": buffer,  # base64编码
	}
	return data

func convert_image(img: Image) -> String:
	#if img.is_compressed():
		#img.decompress()
	#if img.get_format() != Image.FORMAT_RGBA8:
		#img.convert(Image.FORMAT_RGBA8)
	#img.linear_to_srgb()
	#print(RBUtils.get_temp_dir())
	var save_path = RBUtils.get_temp_dir().path_join("RodinTempSave.png")
	#var save_path = "/Users/karrycharon/Desktop/OutputImage/WX20250208-113603.png"
	img.save_png(save_path)
	return save_path
