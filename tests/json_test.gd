@tool
extends Label


# TEST: Root level primitive types.
func test0():
	var test
	test = SimpleJSON.load_from_string("12")
	assert(test is float) # JSON do not distinguish floats and integers, so all parsed as floats.
	assert(test == 12)
	test = SimpleJSON.load_from_string("-5")
	assert(test is float) # JSON do not distinguish floats and integers, so all parsed as floats.
	assert(test == -5)
	test = SimpleJSON.load_from_string("12.5")
	assert(test is float)
	assert(test == 12.5)
	test = SimpleJSON.load_from_string("-5.3")
	assert(test is float)
	assert(test == -5.3)
	test = SimpleJSON.load_from_string("true")
	assert(test is bool)
	assert(test == true)
	test = SimpleJSON.load_from_string("false")
	assert(test is bool)
	assert(test == false)
	test = SimpleJSON.load_from_string("null")
	assert(test == null)
	test = SimpleJSON.load_from_string("\"true\"")
	assert(test is String)
	assert(test == "true")
	test = SimpleJSON.load_from_string("\"5\"")
	assert(test is String)
	assert(test == "5")


# TEST: Simple root level object.
const TEST_1 = """{
	"i": 123,
	"b": true,
	"s": "Hello",
	"f": 3.14
}"""
class Test1:
	var i: int
	var b: bool
	var s: String
	var f: float
func test1_factory(path: String) -> Variant:
	assert(path == "")
	return Test1.new()
func test1a():
	var test := Test1.new()
	assert(SimpleJSON.load_from_string_to(test, TEST_1))
	_test1_asserts(test)
func test1b():
	var test = SimpleJSON.load_from_string(TEST_1, test1_factory)
	assert(test is Test1)
	_test1_asserts(test)
func _test1_asserts(test:Test1):
	assert(test.i == 123)
	assert(test.b == true)
	assert(test.s == "Hello")
	assert(test.f == 3.14)


# TEST: Inner objects.
const TEST_2 = """{
	"i": 123,
	"inner": {
		"s": "Hello",
		"inner2": {
			"x": "GoodBye"
		}
	}
}"""
class Test2 extends Object:
	var i: int
	class Inner2 extends Object:
		var x: String
	class Inner extends Object:
		var s: String
		var inner2: Inner2 # This is null, will be instantiated by factory.
	var inner := Inner.new() # Pre-created (non null) - don't need factory.
var _test3_factory_calls := 0
func test2_factory(path: String) -> Variant:
	_test3_factory_calls += 1
	match path:
		"": return Test2.new()
		"inner.inner2": return Test2.Inner2.new()
		_: assert(false); return null
func test2a():
	_test3_factory_calls = 0
	var test := Test2.new()
	assert(SimpleJSON.load_from_string_to(test, TEST_2, test2_factory))
	_test2_asserts(test)
	assert(_test3_factory_calls == 1)
func test2b():
	_test3_factory_calls = 0
	var test = SimpleJSON.load_from_string(TEST_2, test2_factory)
	assert(test is Test2)
	_test2_asserts(test)
	assert(_test3_factory_calls == 2)
func _test2_asserts(test:Test2):
	assert(test.i == 123)
	assert(test.inner.s == "Hello")
	assert(test.inner.inner2.x == "GoodBye")


# TEST: Root array
const TEST_3 = """[
	{ "i": 1, "s": "Hello" },
	{ "i": 2, "s": "Hi" },
	{ "i": 5, "s": "Bye!" },
]"""
class Test3 extends Object:
	var i: int
	var s: String
func test3_factory(path: String) -> Variant:
	assert(path == "")
	return Test3.new()
func test3a():
	var test := []
	assert(SimpleJSON.load_from_string_to(test, TEST_3, test3_factory))
	_test3_asserts(test)
func test3b():
	var test = SimpleJSON.load_from_string(TEST_3, test3_factory)
	assert(test is Array)
	_test3_asserts(test)
func _test3_asserts(test:Array):
	assert(test[0] is Test3)
	assert(test[0].i == 1)
	assert(test[0].s == "Hello")
	assert(test[1] is Test3)
	assert(test[1].i == 2)
	assert(test[1].s == "Hi")
	assert(test[2] is Test3)
	assert(test[2].i == 5)
	assert(test[2].s == "Bye!")


func _ready() -> void:
	test0()
	test1a()
	test1b()
	test2a()
	test2b()
	test3a()
	test3b()
	#get_tree().quit()
