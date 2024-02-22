# SimpleJSON
Yet another Godot 4 library to de/serialize JSON files from/into your classes.

## Features
* Supports custom classes, arrays and primitives.
* Deserialize JSON into new instances.
* Deserialize JSON into existing instance (merge).
* Serialize JSON.
* Supports both files and strings.

## Limitations
* Requires providing type factory Callable for instantiation of custom classes.
* JSON Arrays must be homogenous (regarding to custom classes only, unless your type factory can guess types).
* Can't deserialize into existing instance, if JSON root object is primitive. This is limitation of GDscript.
* Deserialize new integer instances as floats. This is limitation of JSON format: there 's only a "number".
If you have ideas how to remove those limitations - wellcome to the Issues or PR!
Currently I decided not to try guessing integers by zero fraction part because it is unreliable.

## Usage examples

Primitives as a root objects.
```gdscript
var test = SimpleJSON.load_from_string("-5.3")
assert(test is float)
assert(test == -5.3)
test = SimpleJSON.load_from_string("12")
assert(test is float) # JSON do not distinguish floats and integers, so all parsed as floats.
assert(test == 12)
```

Deserialize simple JSON class.
```gdscript
const TEST_1 = "{ "i": 123, "b": true, "s": "Hello", "f": 3.14 }"
class Test1:
	var i: int
	var b: bool
	var s: String
	var f: float

# Deserialize into existing variable - requires NO type factory.
func test1a():
	var test := Test1.new()
	var is_success = SimpleJSON.load_from_string_to(test, TEST_1)
	assert(is_success)

# Deserialize into new variable - requires type factory to instantiate your custom class.
func test1_factory(path: String) -> Variant:
	return Test1.new()
func test1b():
	var test = SimpleJSON.load_from_string(TEST_1, test1_factory)
	assert(test is Test1)
```

Quick implementation of game Settings class.
```gdscript
extends Node

const PATH = 'user://settings.json'

class Video:
	var full_screen	:= false
var video := Video.new()

class Audio:
	var master_enabled	:= true
	var master_vol		:= 1.0
var audio := Audio.new()

func _ready():
	reload()

func reload():
	SimpleJSON.load_from_file(self, PATH)

func save():
	SimpleJSON.save_to_file(self, PATH)
```
