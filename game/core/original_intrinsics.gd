class_name WolfOriginalIntrinsics
extends RefCounted
## Direct, bytecode-checked translations of hot accessors and sprite compositing.
## Every shortcut is optional; tests compare interpreter and intrinsic paths.
var vm: WolfVM
var enabled: bool = true
var fast_render: bool = true
var hits: Dictionary = {}
var renderer: WolfRenderIntrinsics
const WEATHER_METHODS: Array[String]=["f.a(I)V","f.a(I)I","f.a(IIIIIIIIIIIIIZ)V","i.l(Ljavax/microedition/lcdui/Graphics;)V"]
const METHODS: Array[String] = ["c.a(IIILjavax/microedition/lcdui/Graphics;)V","c.a(II)I","c.b(I)Ljava/lang/Object;","c.a(I)Ljava/lang/String;","i.a(B)I","i.a(BBII)I","i.a(IILjava/util/Random;)I","i.f(I)I","i.a(IIIIIIILjavax/microedition/lcdui/Graphics;)V","i.a(IIIIIIIIIIIIILjavax/microedition/lcdui/Graphics;IZ)V","i.b(BBII)Z","i.a(BBI)Z"]
const FAST_METHODS: Array[String]=["i.a(IILjava/util/Random;)I","i.f(I)I","i.a(IIIIIIILjavax/microedition/lcdui/Graphics;)V","i.a(IIIIIIIIIIIIILjavax/microedition/lcdui/Graphics;IZ)V","i.b(BBII)Z","i.a(BBI)Z"]

func _init(machine: WolfVM) -> void:
	vm = machine
	renderer=WolfRenderIntrinsics.new(machine,self)

func accepts(owner: String,key: String) -> bool:
	if owner in ["f","i"] and (owner+"."+key) in WEATHER_METHODS:return enabled and fast_render
	return enabled and (owner+"."+key) in METHODS and (fast_render or not (owner+"."+key) in FAST_METHODS)

func invoke(owner: String,key: String,args: Array,object: Variant=null) -> Variant:
	var method: String = owner+"."+key
	hits[method] = int(hits.get(method,0))+1
	match method:
		"f.a(I)V":renderer.particles(object,int(args[0]));return null
		"f.a(I)I":return renderer.integer_root(int(args[0]))
		"f.a(IIIIIIIIIIIIIZ)V":renderer.emit_rain(object,args);return null
		"i.l(Ljavax/microedition/lcdui/Graphics;)V":renderer.rain(args[0]);return null
		"i.a(IILjava/util/Random;)I":return renderer.random_range(int(args[0]),int(args[1]),args[2])
		"i.f(I)I":return clampi(int(args[0]),0,255)
		"i.a(IIIIIIILjavax/microedition/lcdui/Graphics;)V":renderer.ground(args);return null
		"i.a(IIIIIIIIIIIIILjavax/microedition/lcdui/Graphics;IZ)V":renderer.gradient(args);return null
		"i.b(BBII)Z","i.a(BBI)Z":
			var types: Array=vm.get_static("i","r","[B").data;var xs: Array=vm.get_static("i","s","[B").data
			var ys: Array=vm.get_static("i","t","[B").data;var states: Array=vm.get_static("i","u","[B").data
			for index: int in types.size():
				if int(xs[index])!=int(args[0]) or int(ys[index])!=int(args[1]) or int(types[index])!=int(args[2]):continue
				if (int(states[index])!=int(args[3])) if args.size()==4 else (int(states[index])==2):continue
				vm.get_static("i","f","[I").data[0]=index;return 1
			return 0
		"c.a(IIILjavax/microedition/lcdui/Graphics;)V":
			# c.a(IIILGraphics;)V byte offsets 0..103: original metadata,
			# m.a(Graphics,rect,[I) intersection, drawImage, restore clip.
			var meta: WMObject = vm.get_static("c","a","[[S")
			var record: Array = meta.data[int(args[2])].data
			var cache: WMObject = vm.get_static("c","b","[Ljava/lang/Object;")
			var image: Image = cache.data[int(record[6])].data
			var graphics: MidpGraphics = args[3].data
			var group: Vector2=Vector2(-9999,-9999)
			var group_type: int=-1
			var coverage: Rect2i=Rect2i()
			for n: int in range(vm.active.frames.size()-1,-1,-1):
				var frame: Dictionary=vm.active.frames[n]
				if frame.owner=="i" and frame.method.name=="a" and frame.method.desc=="(IIILjavax/microedition/lcdui/Graphics;)V":
					if group_type<0:group=Vector2(int(frame.locals[0]),int(frame.locals[1]))+Vector2(graphics.offset);group_type=int(frame.locals[2])
				if frame.owner=="i" and frame.method.name=="b" and frame.method.desc=="(IIIIIILjavax/microedition/lcdui/Graphics;)V":
					coverage=Rect2i(int(frame.locals[0])+graphics.offset.x,int(frame.locals[1])+graphics.offset.y,int(frame.locals[2]),int(frame.locals[3]));break
			graphics.record_sprite(int(args[2]),int(args[0])+graphics.offset.x,int(args[1])+graphics.offset.y,group,group_type,coverage)
			var old: Rect2i = graphics.clip
			var scratch: Array = vm.get_static("c","a","[I").data
			scratch[0]=old.position.x-graphics.offset.x; scratch[1]=old.position.y-graphics.offset.y
			scratch[2]=old.size.x; scratch[3]=old.size.y
			var rect: Rect2i = Rect2i(int(args[0])-int(record[4])+graphics.offset.x,int(args[1])-int(record[5])+graphics.offset.y,int(record[2]),int(record[3])).intersection(old)
			if rect.has_area():
				graphics.clip=rect
				graphics.suppress_capture=true
				graphics.blit(image,int(args[0])-int(record[4])-int(record[0]),int(args[1])-int(record[5])-int(record[1]),20)
				graphics.suppress_capture=false
				graphics.clip=old
			return null
		"c.a(II)I": return vm.get_static("c","a","[[S").data[int(args[0])].data[int(args[1])]
		"c.b(I)Ljava/lang/Object;": return vm.get_static("c","b","[Ljava/lang/Object;").data[int(args[0])]
		"c.a(I)Ljava/lang/String;": return vm.get_static("c","b","[Ljava/lang/Object;").data[0].data[int(args[0])]
		"i.a(B)I": return int(args[0]) & 255
		"i.a(BBII)I":
			var w: int = vm.get_static("i","b","B"); var h: int = vm.get_static("i","c","B")
			var x: int = args[0]; var y: int = args[1]
			if x<0 or y<0 or x>=w or y>=h: return -1 if y>=h else 6
			return (int(vm.get_static("i","s","[S").data[x+y*w]) & int(args[3])) >> int(args[2])
	return null
