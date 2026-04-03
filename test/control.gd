extends Control

func _ready() -> void:
	var control = Control.new()
	BGML.load_bgml(self , FileAccess.get_file_as_string("res://test.xml"))
	add_child(control)