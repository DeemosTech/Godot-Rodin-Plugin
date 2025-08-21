@tool
class_name RBProps extends Node

static func instance() -> RBProps:
	return RBSettings.fetch("props_inst")

var prompt: String = ""
var gen_type: String = "OneClick":
	set(v):
		gen_type = v
		if v == "OneClick":
			self.bypass = true
	get:
		return gen_type

var material_type: String = "Shaded":
	set(v):
		material_type = v
		self.update_material_config()
	get:
		return material_type

var material_resolution: String = "2K":
	set(v):
		material_resolution = v
		self.update_material_config()
	get:
		return material_resolution

var condition_type: String = "image":
	set(v):
		if v not in ["image", "bbox", "voxel", "pointCloud"]:
			printerr("Condition Type Error: ", v)
		condition_type = v
var images: Array[Texture2D] = []
var rendering: bool = false
var mode: String = "Fast":
	set(v):
		mode = v
		if v != "Fast":
			return
		if self.material_resolution != "1K":
			self.material_resolution = "1K"
	get:
		return mode

var height: float = 100
var align: String = "Bottom":
	set(v):
		if v not in ["Bottom", "Center"]:
			printerr("Align Type Error: ", v)
		align = v
var voxel_condition_cfg: String = "Strict":
	set(v):
		if v not in ["Strict", "Rough"]:
			printerr("Voxel Condition Cfg Error: ", v)
		voxel_condition_cfg = v
var voxel_condition_weight: float = 1
var pcd_condition_uncertainty: float = 0.01
var polygons: String = "Raw":
	set(v):
		if v not in ["Quad", "Raw"]:
			printerr("Polygons Type Error: ", v)
		polygons = v
var quality: int = 18000
var textTo: String = "Image"
var bypass: bool = true
var text_input: String = ""

func get_material_config() -> Dictionary:
	return {
		"type": [self.material_type, ],
		"resolution": self.material_resolution,
	}

func dump_config() -> Dictionary:
	var config = {
		"type": "OneClick" if RBWSServer.get_compatible_browser() else self.gen_type,
		"model": "glb",
		"material": self.get_material_config(),
		"height": self.height,
		"align": self.align,
		"voxel_condition_cfg": self.voxel_condition_cfg,
		"voxel_condition_weight": self.voxel_condition_weight,
		"pcd_condition_uncertainty": self.pcd_condition_uncertainty,
		"polygons": self.polygons,
		"mode": self.mode,
		"quality": self.quality,
		"textTo": self.textTo == "Text",
		"bypass": self.bypass,
		"text": self.text_input,
	}
	return config

func update_material_config() -> void:
	RBCtx.instance().material_config = self.get_material_config()
	RBCtx.instance().config = self.dump_config()
	RBCtx.instance().condition_type = self.condition_type

func on_prop_event(value, prop: String) -> void:
	if prop not in self:
		printerr("未知属性: %s %s" % [prop, value])
		return
	# print("变更属性: %s %s -> %s" % [prop, self.get(prop), value])
	self.set(prop, value)
