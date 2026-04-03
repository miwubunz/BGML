# todo:
# styleboxes

class_name BGML
extends Control


static func load_bgml(root: Node, content: String) -> void:
	var parser = XMLParser.new()
	var err = parser.open_buffer(content.to_utf8_buffer())
	if err != OK:
		printerr("ERROR: %s" % error_string(err))
		return

	var stack: Array[Node] = [root]

	var current_node: Node = null

	var on_scene = false;

	var signals: Array[Dictionary] = []

	var ids: Dictionary[String, Node] = {}

	var node_name = ""
	while parser.read() != ERR_FILE_EOF:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				node_name = parser.get_node_name()
				var args = get_args_as_dict(parser)
				match node_name:
					"Scene":
						on_scene = true
						continue
					"GDScript":
						if "src" in args:
							root.set_script(to_script(args.get("src", "")))
						continue
				
				if on_scene:
					var node: Node = ClassDB.instantiate(node_name)
					current_node = node
				
					if "script" in args:
						var script_path = args.get("script")

						if !FileAccess.file_exists(script_path):
							printerr("Script file \"%s\" does not exist" % script_path)
						else:
							var res = load(script_path)


							if res is Script:
								current_node.set_script(res)
							else:
								printerr("script file \"%s\" does not return a script reference" % script_path)
						args.erase("script")

					
					if "id" in args:
						var id = args.get("id");
						ids[id] = current_node
						args.erase("id")
					
					for arg in args:
						if arg.begins_with("on"):
							var sn = arg.substr(2)
							var s = ClassDB.class_get_signal(node.get_class(), sn)
							if s:
								signals.append({
									"node": current_node,
									"signal_name": sn,
									"arguments": args.get(arg)
								})
								continue

						if arg in node:
							var type = ClassDB.class_get_property(node, arg)
							var att_value = args.get(arg)
							if type is not String:
								var val = str_to_var(att_value)

								if val != null:
									att_value = val
							current_node.set(arg, att_value)
						else:
							printerr("\"%s\" does not have a property named \"%s\"" % [node, arg])
					if !stack.is_empty():
						var parent = stack[-1]

						if is_instance_valid(parent):
							parent.add_child(current_node)
					
					stack.append(current_node)
			XMLParser.NODE_TEXT:
				if node_name == "GDScript":
					root.set_script(to_script(parser.get_node_data()))
					continue
				if is_instance_valid(current_node):
					var r = stack[-1]
					if "text" in r:
						r.set("text", parser.get_node_data())
			XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "Scene":
					on_scene = false
				
				if !stack.is_empty():
					stack.pop_back()
	
	if !signals.is_empty():
		for data in signals:
			connect_signals(root, data.node, data.signal_name, data.arguments, ids)

static func get_args_as_dict(parser: XMLParser) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for att_idx in parser.get_attribute_count():
		var key = parser.get_attribute_name(att_idx)
		
		result[key] = parser.get_attribute_value(att_idx)

	return result

static func connect_signals(root: Node, node: Node, sign: String, str: String, ids: Dictionary[String, Node]):
	if str.begins_with("@"): # @id : method[args]
		var callable_bones = str.trim_prefix("@").split(":")
		if callable_bones.size() >= 2:
			var id = callable_bones[0].strip_edges()
			if id in ids or id in ["self", "root"]:
				var id_node: Node
				match id:
					"root": id_node = root
					"self": id_node = node
					_: ids.get(id)
				var callable = split_method(node, id_node, ":".join(callable_bones.slice(1)).strip_edges())
				node.connect(sign, callable)
				return
	else: # expressions
		node.connect(sign, func():
			var exp = Expression.new()
			exp.parse(str.dedent())
			exp.execute([], node))

static func split_method(this: Node, id_node: Node, str: String) -> Callable:
	var parsing = func(s: String):
		var exp = Expression.new()
		exp.parse(s)
		return exp.execute([], this)

	var split = str.find("[")
	var left = str.substr(0, split)

	var callable = Callable(id_node, left)
	callable = callable.bindv(parsing.call(str.substr(split)))
	return callable

		
static func to_script(content: String) -> GDScript:
	var script = GDScript.new()
	script.source_code = content.dedent().strip_edges()
	script.reload()
	return script