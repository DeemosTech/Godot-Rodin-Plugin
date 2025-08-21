@tool
class_name ConditionOptions extends HBoxContainer

var btn_group: ButtonGroup = ButtonGroup.new()
var btns: Array[Button] = []

signal option_selected(btn: Button)
signal option_trigger(option: String)


func _ready() -> void:
	if "allow_unpress" in btn_group:
		btn_group.allow_unpress = true
	var any_btn_presset = false
	for child in get_children():
		if not (child is Button):
			continue
		init_btn(child)
		btns.append(child)
		any_btn_presset = child.button_pressed or any_btn_presset

	for btn in btns:
		btn.pressed.connect(option_btn_pressed.bind(btn))

	if btns.is_empty(): return
	
	if not any_btn_presset:
		btns[0].button_pressed = true

func dump_config() -> void:
	pass

func init_btn(btn: Button) -> void:
	btn.toggle_mode = true
	btn.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	btn.set_button_group(btn_group)

func option_btn_pressed(btn: Button) -> void:
	option_selected.emit(btn)
	btn.set_pressed_no_signal(true)
	option_trigger.emit(btn.name)
	#print("当前按下的按钮: ", btn_group.get_pressed_button().name)
	
func option_btn_toggled(state: bool, btn: Button) -> void:
	if not btn: return
	btn.set_pressed_no_signal(true)
