extends Button

var able = true

func _ready():
	self.pressed.connect(Callable(self , "press"))

func press():
	if self.get_child_count() <= 0:
		var original_text = text
		text = "Hello, World! ;D" if able else "Nuh huh. No more 'Hello, World' for you! >:C"
		var timer = Timer.new()
		timer.wait_time = 1.0
		self.add_child(timer)
		timer.start()
		await timer.timeout
		timer.queue_free()
		text = original_text
	else:
		if able:
			for i in get_children():
				if i is Timer:
					able = false
					text = "Hey, do not click me yet! I'm upset now. :^"
					i.queue_free()
