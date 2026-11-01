class_name WolfVM
extends RefCounted
## Portable interpreter for this JAR's integer CLDC bytecode. Game algorithms are
## executed from the original methods, never substituted by guessed game rules.
## Source mapping: data/classes.json methods retain all byte offsets and handlers.
var classes: Dictionary
var statics: Dictionary = {}
var initialized: Dictionary = {}
var initializing: Dictionary = {}
var fibers: Array[Dictionary] = []
var native: RefCounted
var now_ms: int = 0
var epoch_ms: int = 1170000000000
var instructions: int = 0
var errors: Array[String] = []
var trace: Array[String] = []
var halted: bool = false
var max_slice: int = 45000
# Optional presentation budget; bytecode resumes at the next instruction.
var slice_time_usec: int=0
var profile_enabled: bool = false
var profile_instructions: Dictionary = {}
var field_owner_cache: Dictionary = {}
var next_id: int = 1
var active: Dictionary = {}
var exception: Variant = null
var opcode_hits: Dictionary = {}
var intrinsics: WolfOriginalIntrinsics
var class_locks: Dictionary = {}

func _init() -> void:
	epoch_ms = int(Time.get_unix_time_from_system()*1000.0)
	classes = normalize(JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json")))
	intrinsics = WolfOriginalIntrinsics.new(self)
	for cl: String in classes:
		statics[cl] = {}
		for field: Dictionary in classes[cl].fields:
			if int(field.flags) & 8:
				statics[cl][field.name + ":" + field.desc] = constant(field.constant) if field.has("constant") else default_value(field.desc)

func normalize(value: Variant) -> Variant:
	if value is float: return int(value)
	if value is Array:
		for k: int in value.size(): value[k] = normalize(value[k])
	elif value is Dictionary:
		for k: Variant in value: value[k] = normalize(value[k])
	return value

func constant(value: Variant) -> Variant:
	return WMLong.new(int(value.v)) if value is Dictionary and value.get("kind") == "long" else value

func default_value(desc: String) -> Variant:
	if desc.begins_with("L") or desc.begins_with("["): return null
	return WMLong.new() if desc == "J" else 0

static func i32(n: int) -> int:
	return ((n + 2147483648) & 4294967295) - 2147483648

static func signed(n: int, bits: int) -> int:
	var half: int = 1 << (bits - 1)
	return ((n + half) & ((1 << bits) - 1)) - half

static func number(value: Variant) -> int:
	return value.value if value is WMLong else int(value)

func new_object(type: String) -> WMObject:
	var o: WMObject = WMObject.new(type)
	var cl: String = type
	while classes.has(cl):
		for field: Dictionary in classes[cl].fields:
			if not int(field.flags) & 8:
				o.fields[cl + "." + field.name + ":" + field.desc] = default_value(field.desc)
		cl = classes[cl].parent if classes[cl].parent != null else ""
	return o

func new_array(type: String, length: int) -> WMObject:
	var o: WMObject = WMObject.new(type)
	o.data = []
	o.data.resize(maxi(0, length))
	for k: int in length: o.data[k] = default_value(type.substr(1))
	return o

func field_owner(cl: String, name: String, desc: String) -> String:
	var key: String=cl+"."+name+":"+desc
	if field_owner_cache.has(key):return field_owner_cache[key]
	while classes.has(cl):
		for field: Dictionary in classes[cl].fields:
			if field.name == name and field.desc == desc:
				field_owner_cache[key]=cl;return cl
		cl = classes[cl].parent if classes[cl].parent != null else ""
	field_owner_cache[key]=cl
	return cl

func get_static(cl: String, name: String, desc: String) -> Variant:
	var owner: String = field_owner(cl, name, desc)
	return statics.get(owner, {}).get(name + ":" + desc, default_value(desc))

func set_static(cl: String, name: String, desc: String, value: Variant) -> void:
	statics[field_owner(cl, name, desc)][name + ":" + desc] = value

func get_field(o: WMObject, cl: String, name: String, desc: String) -> Variant:
	return o.fields.get(field_owner(cl, name, desc) + "." + name + ":" + desc, default_value(desc))

func set_field(o: WMObject, cl: String, name: String, desc: String, value: Variant) -> void:
	o.fields[field_owner(cl, name, desc) + "." + name + ":" + desc] = value

func is_instance(o: Variant, type: String) -> bool:
	if o == null: return false
	if o is String: return type in ["java/lang/String", "java/lang/Object"]
	if not o is WMObject: return false
	var cl: String = o.type
	if type == "java/lang/Object": return true
	if type == "java/lang/Throwable" and (cl.ends_with("Exception") or cl.ends_with("Error")): return true
	if type == "java/lang/Exception" and cl.ends_with("Exception"): return true
	while classes.has(cl):
		if cl == type or type in classes[cl].interfaces: return true
		cl = classes[cl].parent if classes[cl].parent != null else ""
	var parents: Dictionary = {"javax/microedition/lcdui/game/GameCanvas":"javax/microedition/lcdui/Canvas","javax/microedition/lcdui/Canvas":"javax/microedition/lcdui/Displayable","java/io/DataInputStream":"java/io/FilterInputStream","java/io/FilterInputStream":"java/io/InputStream","java/io/ByteArrayInputStream":"java/io/InputStream"}
	while parents.has(cl):
		if cl==type: return true
		cl=parents[cl]
	if o.type.begins_with("[") and type=="[Ljava/lang/Object;" and (o.type.begins_with("[L") or o.type.begins_with("[[")): return true
	return cl == type

func find_method(cl: String, key: String) -> Dictionary:
	while classes.has(cl):
		if classes[cl].methods.has(key): return {"owner":cl,"method":classes[cl].methods[key]}
		cl = classes[cl].parent if classes[cl].parent != null else ""
	return {"owner":cl,"method":{}}

func push_frame(fiber: Dictionary, owner: String, method: Dictionary, obj: Variant, args: Array) -> void:
	var locals: Array = []
	locals.resize(int(method.max_locals))
	var n: int = 0
	if not int(method.flags) & 8:
		locals[0] = obj
		n = 1
	for k: int in args.size():
		locals[n] = args[k]
		n += 2 if method.params[k] in ["J","D"] else 1
	var capture: Variant=null
	var phase_graphics: Variant=null
	var previous_phase: String=""
	if owner=="i" and method.desc=="(Ljavax/microedition/lcdui/Graphics;)V" and not args.is_empty() and args[0]!=null:
		var phase: String=""
		if method.name=="a":phase="effects"
		elif method.name=="b":phase="base"
		elif method.name=="d":phase="sky"
		elif method.name=="l":phase="weather"
		elif method.name in ["i","j","k"]:phase="interaction_"+str(method.name)
		elif method.name=="f":phase="hud"
		elif method.name=="h":phase="map"
		elif method.name=="n":phase="transition"
		if not phase.is_empty():
			phase_graphics=args[0].data;previous_phase=phase_graphics.phase;phase_graphics.phase=phase
		if method.name in ["a","b"]:
			capture=args[0].data;capture.begin_capture()
	fiber.frames.append({"owner":owner,"method":method,"pc":0,"last":0,"locals":locals,"stack":[],"lock":null,"entered":false,"this":obj,"capture":capture,"phase_graphics":phase_graphics,"previous_phase":previous_phase,"profile_key":owner+"."+str(method.name)+str(method.desc)})

func finish_frame(frame: Dictionary) -> void:
	if frame.get("lock")!=null:release(frame.lock)
	if frame.get("capture")!=null:frame.capture.end_capture()
	if frame.get("phase_graphics")!=null:frame.phase_graphics.phase=frame.get("previous_phase","")

func acquire(lock: WMObject, fiber: Dictionary, depth: int = 1) -> bool:
	var owner: int = int(lock.extra.get("monitor_owner",0))
	if owner!=0 and owner!=int(fiber.id): return false
	lock.extra.monitor_owner = int(fiber.id)
	lock.extra.monitor_depth = int(lock.extra.get("monitor_depth",0))+depth
	return true

func release(lock: WMObject) -> void:
	lock.extra.monitor_depth = int(lock.extra.get("monitor_depth",1))-1
	if int(lock.extra.monitor_depth)<=0: lock.extra.monitor_owner=0; lock.extra.monitor_depth=0

func launch(cl: String, key: String, obj: Variant = null, args: Array = []) -> Dictionary:
	var found: Dictionary = find_method(cl, key)
	var fiber: Dictionary = {"id":next_id,"frames":[],"wake":now_ms,"waiting":null,"yielded":false,"result":null}
	next_id += 1
	if found.method.is_empty(): fail("Missing entry " + cl + "." + key); return fiber
	push_frame(fiber, found.owner, found.method, obj, args)
	fibers.append(fiber)
	return fiber

func ensure_class(cl: String, fiber: Dictionary) -> bool:
	if not classes.has(cl) or initialized.has(cl): return true
	if initializing.has(cl): return int(initializing[cl]) == int(fiber.id)
	var parent: Variant = classes[cl].parent
	if parent != null and not ensure_class(parent, fiber): return false
	initializing[cl] = fiber.id
	if classes[cl].methods.has("<clinit>()V"):
		push_frame(fiber, cl, classes[cl].methods["<clinit>()V"], null, [])
		return false
	initialized[cl] = true
	return true

func tick(delta_ms: int) -> void:
	if halted: return
	now_ms += delta_ms
	var snapshot: Array[Dictionary] = fibers.duplicate()
	for fiber: Dictionary in snapshot:
		if fiber.frames.is_empty() or fiber.waiting != null or int(fiber.wake) > now_ms: continue
		if fiber.get("reacquire")!=null:
			if not acquire(fiber.reacquire,fiber,int(fiber.get("monitor_depth",1))): continue
			fiber.reacquire = null
		active = fiber
		fiber.yielded = false
		var count: int = 0
		var deadline: int=Time.get_ticks_usec()+slice_time_usec if slice_time_usec>0 else 0
		while not fiber.frames.is_empty() and not fiber.yielded and not halted and count < max_slice:
			step(fiber)
			count += 1
			if deadline>0 and (count&127)==0 and Time.get_ticks_usec()>=deadline:break
	for k: int in range(fibers.size()-1,-1,-1):
		if fibers[k].frames.is_empty(): fibers.remove_at(k)

func fail(message: String) -> void:
	errors.append(message)
	push_error(message)
	halted = true

func throw_exception(type: String, message: String = "") -> void:
	exception = WMObject.new(type)
	exception.data = message

func unwind(fiber: Dictionary) -> void:
	var thrown: Variant = exception
	exception = null
	while not fiber.frames.is_empty():
		var frame: Dictionary = fiber.frames.back()
		for handler: Dictionary in frame.method.exceptions:
			if int(frame.last) >= int(handler.start) and int(frame.last) < int(handler.end) and (handler.type == null or is_instance(thrown, handler.type)):
				frame.stack.clear()
				frame.stack.append(thrown)
				frame.pc = int(handler.handler)
				return
		finish_frame(frame)
		fiber.frames.pop_back()
	fail("Uncaught " + thrown.type + ": " + str(thrown.data))

func step(fiber: Dictionary) -> void:
	var frame: Dictionary = fiber.frames.back()
	if not frame.entered:
		if int(frame.method.flags) & 32:
			var lock: WMObject
			if int(frame.method.flags) & 8:
				if not class_locks.has(frame.owner): class_locks[frame.owner] = WMObject.new("java/lang/Class")
				lock = class_locks[frame.owner]
			else: lock = frame.this
			if not acquire(lock,fiber): fiber.yielded=true; return
			frame.lock = lock
		frame.entered = true
	var pc: int = int(frame.pc)
	var code: Array = frame.method.code
	if pc < 0 or pc >= code.size(): fail("PC out of range " + frame.owner); return
	var ins: Array = code[pc]
	var op: int = int(ins[0])
	# Initialization retries this same instruction after <clinit> returns.
	if op in [178,179,184,187]:
		var target: String = ins[1] if op == 187 else ins[1].owner
		if op in [178,179]: target = field_owner(target, ins[1].name, ins[1].desc)
		if not ensure_class(target, fiber):
			if fiber.frames.back() == frame: fiber.yielded = true
			return
	frame.pc = pc + 1
	frame.last = pc
	instructions += 1
	opcode_hits[op] = int(opcode_hits.get(op,0)) + 1
	if profile_enabled:
		var profile_key: String=frame.get("profile_key",str(frame.owner)+"."+str(frame.method.name)+str(frame.method.desc))
		profile_instructions[profile_key]=int(profile_instructions.get(profile_key,0))+1
	var stack: Array = frame.stack
	var locals: Array = frame.locals
	match op:
		0: pass
		1: stack.append(null)
		2,3,4,5,6,7,8: stack.append(op-3)
		9,10: stack.append(WMLong.new(op-9))
		16,17: stack.append(int(ins[1]))
		18,19,20: stack.append(constant(ins[1]))
		21,22,25: stack.append(locals[int(ins[1])])
		26,27,28,29: stack.append(locals[op-26])
		30,31,32,33: stack.append(locals[op-30])
		42,43,44,45: stack.append(locals[op-42])
		46,47,50,51,52,53:
			var index: int = int(stack.pop_back())
			var arr: Variant = stack.pop_back()
			if arr == null: throw_exception("java/lang/NullPointerException")
			elif index < 0 or index >= arr.data.size(): throw_exception("java/lang/ArrayIndexOutOfBoundsException",str(index))
			else: stack.append(arr.data[index])
		54,55,58: locals[int(ins[1])] = stack.pop_back()
		59,60,61,62: locals[op-59] = stack.pop_back()
		63,64,65,66: locals[op-63] = stack.pop_back()
		75,76,77,78: locals[op-75] = stack.pop_back()
		79,80,83,84,85,86:
			var value: Variant = stack.pop_back()
			var index: int = int(stack.pop_back())
			var arr: Variant = stack.pop_back()
			if arr == null: throw_exception("java/lang/NullPointerException")
			elif index < 0 or index >= arr.data.size(): throw_exception("java/lang/ArrayIndexOutOfBoundsException",str(index))
			else:
				if op == 84: value = signed(int(value),8) if arr.type != "[Z" else int(value) & 1
				elif op == 85: value = int(value) & 65535
				elif op == 86: value = signed(int(value),16)
				arr.data[index] = value
		87: stack.pop_back()
		88:
			if not stack.pop_back() is WMLong: stack.pop_back()
		89: stack.append(stack.back())
		90:
			var a: Variant = stack.pop_back(); var b: Variant = stack.pop_back()
			stack.append_array([a,b,a])
		91:
			var a: Variant = stack.pop_back(); var b: Variant = stack.pop_back()
			if b is WMLong: stack.append_array([a,b,a])
			else:
				var c: Variant = stack.pop_back(); stack.append_array([a,c,b,a])
		92:
			var a: Variant = stack.pop_back()
			if a is WMLong: stack.append_array([a,a])
			else:
				var b: Variant = stack.pop_back(); stack.append_array([b,a,b,a])
		96,97,100,101,104,105,108,109,112,113,120,121,122,123,124,125,126,127,128,129,130,131:
			var b: int = number(stack.pop_back()); var a: int = number(stack.pop_back()); var result: int = 0
			var long_op: bool = op % 2 == 1
			match op:
				96,97: result = a+b
				100,101: result = a-b
				104,105: result = a*b
				108,109,112,113:
					if b == 0: throw_exception("java/lang/ArithmeticException")
					elif op in [108,109]: result = a / b
					else: result = a % b
				120,121: result = a << (b & (63 if long_op else 31))
				122,123: result = a >> (b & (63 if long_op else 31))
				124: result = (a & 4294967295) >> (b & 31)
				125: result = (a >> (b & 63)) & ((1 << (64-(b&63)))-1) if (b&63) != 0 else a
				126,127: result = a & b
				128,129: result = a | b
				130,131: result = a ^ b
			stack.append(WMLong.new(result) if long_op else i32(result))
		116: stack.append(i32(-int(stack.pop_back())))
		117: stack.append(WMLong.new(-number(stack.pop_back())))
		132: locals[int(ins[1])] = i32(int(locals[int(ins[1])]) + int(ins[2]))
		133: stack.append(WMLong.new(int(stack.pop_back())))
		136: stack.append(i32(number(stack.pop_back())))
		145: stack.append(signed(int(stack.pop_back()),8))
		146: stack.append(int(stack.pop_back()) & 65535)
		147: stack.append(signed(int(stack.pop_back()),16))
		148:
			var b: int = number(stack.pop_back()); var a: int = number(stack.pop_back())
			stack.append(1 if a>b else (-1 if a<b else 0))
		153,154,155,156,157,158:
			var a: int = int(stack.pop_back()); var cond: bool = false
			match op:
				153: cond = a==0
				154: cond = a!=0
				155: cond = a<0
				156: cond = a>=0
				157: cond = a>0
				158: cond = a<=0
			if cond: frame.pc = int(ins[1])
		159,160,161,162,163,164,165,166:
			var b: Variant = stack.pop_back(); var a: Variant = stack.pop_back(); var cond: bool = false
			match op:
				159,165: cond = a==b
				160,166: cond = a!=b
				161: cond = a<b
				162: cond = a>=b
				163: cond = a>b
				164: cond = a<=b
			if cond: frame.pc = int(ins[1])
		167,200: frame.pc = int(ins[1])
		170,171:
			var key: int = int(stack.pop_back()); frame.pc = int(ins[1])
			for pair: Array in ins[2]:
				if int(pair[0]) == key: frame.pc = int(pair[1]); break
		172,173,176,177:
			var result: Variant = null if op==177 else stack.pop_back()
			if frame.method.name == "<clinit>": initialized[frame.owner] = true; initializing.erase(frame.owner)
			finish_frame(frame)
			fiber.frames.pop_back()
			if not fiber.frames.is_empty() and op != 177: fiber.frames.back().stack.append(result)
			else: fiber.result = result
		178: stack.append(get_static(ins[1].owner,ins[1].name,ins[1].desc))
		179: set_static(ins[1].owner,ins[1].name,ins[1].desc,stack.pop_back())
		180,181:
			var ref: Dictionary = ins[1]; var value: Variant = null
			if op==181: value = stack.pop_back()
			var obj: Variant = stack.pop_back()
			if obj == null: throw_exception("java/lang/NullPointerException")
			elif op==180: stack.append(get_field(obj,ref.owner,ref.name,ref.desc))
			else: set_field(obj,ref.owner,ref.name,ref.desc,value)
		182,183,184,185:
			var ref: Dictionary = ins[1]; var args: Array = []
			for k: int in ref.params.size(): args.push_front(stack.pop_back())
			var obj: Variant = null if op==184 else stack.pop_back()
			if op!=184 and obj==null: throw_exception("java/lang/NullPointerException")
			else:
				var owner: String = obj.type if op in [182,185] and obj is WMObject else ref.owner
				var found: Dictionary = find_method(owner, ref.name + ref.desc)
				if not found.method.is_empty() and intrinsics.accepts(found.owner,ref.name+ref.desc):
					var result: Variant = intrinsics.invoke(found.owner,ref.name+ref.desc,args,obj)
					if ref["return"] != "V": stack.append(result)
				elif not found.method.is_empty(): push_frame(fiber,found.owner,found.method,obj,args)
				else:
					var result: Variant = native.invoke(ref,obj,args,fiber)
					if ref["return"] != "V" and exception == null: stack.append(result)
		187: stack.append(new_object(ins[1]))
		188,189:
			var length: int = int(stack.pop_back())
			if length < 0: throw_exception("java/lang/NegativeArraySizeException")
			else:
				var type: String = "[L" + str(ins[1]) + ";" if op==189 else str({4:"[Z",5:"[C",6:"[F",7:"[D",8:"[B",9:"[S",10:"[I",11:"[J"}[int(ins[1])])
				if op==189 and str(ins[1]).begins_with("["): type = "[" + str(ins[1])
				stack.append(new_array(type,length))
		190:
			var obj: Variant = stack.pop_back()
			if obj==null: throw_exception("java/lang/NullPointerException")
			else: stack.append(obj.data.size())
		191:
			exception = stack.pop_back()
			if exception==null: throw_exception("java/lang/NullPointerException")
		192:
			var value: Variant = stack.back()
			if value!=null and not is_instance(value,ins[1]): throw_exception("java/lang/ClassCastException",str(ins[1]))
		193: stack.append(1 if is_instance(stack.pop_back(),ins[1]) else 0)
		194:
			var lock: Variant = stack.pop_back()
			if lock==null: throw_exception("java/lang/NullPointerException")
			elif not acquire(lock,fiber): stack.append(lock); frame.pc=pc; fiber.yielded=true
		195:
			var lock: Variant = stack.pop_back()
			if lock==null: throw_exception("java/lang/NullPointerException")
			else: release(lock)
		198,199:
			var obj: Variant = stack.pop_back()
			if (obj==null) == (op==198): frame.pc = int(ins[1])
		_: fail("Unsupported opcode %d at %s.%s byte %s" % [op,frame.owner,frame.method.name,frame.method.offsets[pc]])
	if exception != null: unwind(fiber)
