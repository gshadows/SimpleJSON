class_name SimpleJSON
extends RefCounted

# ============================= #
# ---===<<< FILE ACCESS >>===--- #
# ============================= #

static func string_to_file(text:String, file_name:String) -> bool:
	print("Saving file: " + file_name)
	var file := FileAccess.open(file_name, FileAccess.WRITE)
	if not file:
		printerr("Could not create file:", file_name, "->", FileAccess.get_open_error())
		return false
	file.store_string(text)
	file.close()
	return true

static func string_from_file(file_name:String) -> Variant: # Returns string or null.
	print("Loading file: " + file_name)
	if not FileAccess.file_exists(file_name):
		return null
	var file := FileAccess.open(file_name, FileAccess.READ)
	if not file:
		printerr("Could not open settings file:", file_name, "->", FileAccess.get_open_error())
		return null
	var text := file.get_as_text()
	file.close()
	return text


# =============================== #
# ---===<<<  SAVE JSON  >>>===--- #
# =============================== #

static func save_to_file(obj, file_name:String) -> bool:
	return string_to_file(save_to_string(obj), file_name)

static func save_to_string(obj) -> String:
	var data
	if obj is Array:
		data = add_fields_to_array(obj)
	elif (obj is int) or (obj is float) or (obj is String) or (obj is bool) or (obj == null):
		data = obj
	else:
		data = add_fields_to_dict(obj)
	return JSON.stringify(data, "\t")

static func add_fields_to_dict(obj) -> Dictionary:
	var dict := Dictionary()
	var props = obj.get_property_list()
	for p in props:
		if (p.has('usage') and (p.usage == PROPERTY_USAGE_SCRIPT_VARIABLE)):
			var value = obj.get(p.name)
			if (p.type == TYPE_OBJECT):
				value = add_fields_to_dict(value)
			elif (p.type == TYPE_ARRAY):
				value = add_fields_to_array(value)
			dict[p.name] = value
	return dict

static func add_fields_to_array(array:Array) -> Array:
	var result := []
	for obj in array:
		if obj is Array:
			result.push_back(add_fields_to_array(obj))
		elif (obj is int) or (obj is float) or (obj is String) or (obj is bool) or (obj == null):
			result.push_back(obj)
		elif (obj == null):
			pass
		else:
			result.push_back(add_fields_to_dict(obj))
	return result


# =============================== #
# ---===<<<  LOAD JSON  >>>===--- #
# =============================== #

# Restrictions:
# 1. All JSON arrays must be homogenous. Because no ideas how to request different items from type factory (by index?).
# 2. Can't use load_from_file_to() with primitive root type, because GDScript pass it by value.

# TYPE FACTORY:
# In most non-trivial cases, caller should provide actual type factory implementation.
# Type factory should instantiate objects according provided "path" argument.
# Path is non-null the dot-separated member names path inside JSON tree. Empty string means root.
# 0. Array items has no names. so it is skipped from path. Arrays are homogenous.
# 1. Empty path ("") means root object (or root array's item).
# 2. For root array of arrays, empty path assumes first non-array level item name.
# 3. Similarly, for non-root array of arrays, path is the outer array's field path.
static func _empty_type_factory(path:String) -> Variant:
	printerr("Factory required to instantiate ", path)
	return null


static func load_from_file(file_name:String, type_factory:Callable=_empty_type_factory) -> Variant:
	var file_str = string_from_file(file_name)
	if file_str == null:
		return null
	return load_from_string(file_str, type_factory)

static func load_from_file_to(obj, file_name:String, type_factory:Callable=_empty_type_factory) -> bool:
	var file_str = string_from_file(file_name)
	if file_str == null:
		return false
	return load_from_string_to(obj, file_str, type_factory)


static func parse_json(json:String) -> Variant:
	var json_converter := JSON.new()
	var error := json_converter.parse(json)
	if error:
		printerr("Invalid JSON format: ", error)
		return null
	return json_converter.get_data()


static func load_from_string(json:String, type_factory:Callable=_empty_type_factory) -> Variant:
	var parsed = parse_json(json)
	if parsed == null:
		return null
	if (parsed is Dictionary) or (parsed is Array):
		# Root is JSON Object or JSON Array.
		var result = type_factory.call("") if (parsed is Dictionary) else [] # Instantiate
		if result == null:
			printerr("Failed to instantiate: root")
			return null
		if not _assign_parsed_to(result, parsed, type_factory):
			return null
		return result
	elif (parsed is int) or (parsed is float) or (parsed is String) or (parsed is bool):
		# Root is a primitive type.
		return parsed
	else:
		printerr("Unsupported root type: ", typeof(parsed))
		return null


static func load_from_string_to(obj:Variant, json:String, type_factory:Callable=_empty_type_factory) -> bool:
	var parsed = parse_json(json)
	return _assign_parsed_to(obj, parsed, type_factory) if parsed else false


# obj - where assign to (Object, Dictionary or Array), parsed - JSON parsed item
static func _assign_parsed_to(obj, parsed, type_factory:Callable=_empty_type_factory) -> bool:
	if parsed is Dictionary:
		# === JSON OBJECT ===
		if obj is Object:
			# Dictionary to Object: apply fields one by one recursively.
			return apply_fields_from_dict(parsed as Dictionary, obj as Object, "", type_factory)
		if obj is Dictionary:
			# Dictionary to Dictionary: just merge.
			(obj as Dictionary).merge(parsed)
			return true
		printerr("Can't assign Dictionary to ", typeof(obj))
		return false
	elif parsed is Array:
		# === JSON ARRAY ===
		if not obj is Array:
			# Arrays are only assignable to arrays.
			printerr("Can't assign Array to ", typeof(obj))
			return false
		# Convert JSON Array elements one by one to application objects.
		return apply_json_array_items(parsed as Array, obj as Array, "", type_factory)
	else:
		# Primitive types assignment is impossible because it is not reference type.
		printerr("Impossible to assign primitive types, consider using load_from_string()")
		return false


static func apply_fields_from_dict(dict:Dictionary, obj:Object, path:String, type_factory:Callable=_empty_type_factory) -> bool:
	var props := obj.get_property_list()
	for p in props:
		if (p.has('usage') and (p.usage == PROPERTY_USAGE_SCRIPT_VARIABLE) and dict.has(p.name)):
			var new_value = dict[p.name]
			var sub_path: String = p.name if (path == "") else (path + '.' + p.name)
			var field = obj.get(p.name)
			
			if (p.type == TYPE_OBJECT):
				# Field is object - recursively set from dictionary.
				if (new_value is Dictionary):
					print("Setting sub-dict %s..." % sub_path)
					if field == null:
						field = type_factory.call(sub_path) # Instantiate
						if field == null:
							printerr("Failed to instantiate: ", sub_path)
							return false
						obj.set(p.name, field)
					if not apply_fields_from_dict(new_value, field, sub_path, type_factory):
						return false
				else:
					# Field is object, but new item from dictionary isn't.
					printerr("Not a dictionary %s to set object field!" % sub_path)
					return false
					
			elif (p.type == TYPE_ARRAY):
				# Field is object - recursively set from array.
				if (new_value is Array):
					print("Setting sub-array %s..." % sub_path)
					if field == null:
						field = []
						obj.set(p.name, field)
					if not apply_json_array_items(new_value, field, sub_path, type_factory):
						return false
				else:
					# Field is array, but new item from dictionary isn't.
					printerr("Not an array %s to set array field!" % sub_path)
					return false
					
			elif (p.type == TYPE_DICTIONARY):
				# Field is dictionary type - merge or assign.
				if (new_value is Dictionary):
					print("Setting value %s = %s" % [sub_path, new_value])
					if field:
						field.merge(new_value)
					else:
						obj.set(p.name, new_value)
				else:
					# Field is disctionary, but new item from dictionary isn't.
					printerr("Not a dictionary %s to set dictionary field!" % sub_path)
					return false
					
			else:
				# Field is normal type - set directly.
				print("Setting value %s = %s" % [sub_path, new_value])
				obj.set(p.name, new_value)
	return true


# Convert JSON parsed array, replacing dictionaries with objects. Type should be null for root array.
static func apply_json_array_items(input:Array, output:Array, path:String, type_factory:Callable=_empty_type_factory) -> bool:
	for src_item in input:
		if (src_item is int) or (src_item is float) or (src_item is String) or (src_item is bool) or (src_item == null):
			# Primitive types: no conversion
			output.append(src_item)
		elif src_item is Dictionary:
			# Convert dictionaries to objects recursively.
			var obj = type_factory.call(path) # Instantiate
			if obj == null:
				printerr("Failed to instantiate: ", path)
				return false
			if not apply_fields_from_dict(src_item as Dictionary, obj, path, type_factory):
				return false
			output.append(obj)
		elif src_item is Array:
			# Convert array of arrays. Type name not modified. See _empty_type_factory comment.
			var sub_array := []
			if not apply_json_array_items(input, sub_array, path, type_factory):
				return false
			output.append(sub_array)
		else:
			printerr("Can't convert array of ", typeof(src_item))
			return false
	return true
