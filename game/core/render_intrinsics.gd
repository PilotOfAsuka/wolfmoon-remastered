class_name WolfRenderIntrinsics
extends RefCounted
## Direct translations of original rendering loops, preserving Random calls and
## the legacy raster. Extra grass-band records affect only the wide presentation.
var vm: WolfVM
var sprites: RefCounted
func _init(machine: WolfVM,original: RefCounted) -> void:vm=machine;sprites=original
func random_range(lo: int,hi: int,random: WMObject) -> int:
	var span: int=WolfVM.i32(hi-lo+1)
	if span==0:hi=WolfVM.i32(hi+1);span=WolfVM.i32(hi-lo+1)
	return WolfVM.i32((vm.native.random_next(random,32)>>1)%span+lo)

func integer_root(value: int) -> int:
	# f.a(I)I: preserve its 16-step signed integer algorithm exactly.
	var result: int=0;var bit: int=32768;var shift: int=15
	while bit!=0:
		var trial: int=WolfVM.i32(WolfVM.i32((result<<1)+bit)<<shift)
		shift-=1
		if value>=trial:result=WolfVM.i32(result+bit);value=WolfVM.i32(value-trial)
		bit>>=1
	return result

func particles(object: WMObject,delta: int) -> void:
	# f.a(I)V. Keep fixed-point overflow, swap removal and splash callbacks.
	var age: Array=vm.get_field(object,"f","a","[I").data
	var xs: Array=vm.get_field(object,"f","b","[I").data
	var ys: Array=vm.get_field(object,"f","c","[I").data
	var dx: Array=vm.get_field(object,"f","d","[I").data
	var dy: Array=vm.get_field(object,"f","e","[I").data
	var count: int=int(vm.get_field(object,"f","f","I"))
	var splash: bool=int(vm.get_field(object,"f","a","Z"))!=0
	var drag: int=int(vm.get_field(object,"f","e","I"))
	var ax: int=int(vm.get_field(object,"f","a","I"));var ay: int=int(vm.get_field(object,"f","b","I"))
	var wind_x: int=int(vm.get_field(object,"f","c","I"));var wind_y: int=int(vm.get_field(object,"f","d","I"))
	var index: int=0
	while index<=count:
		var remaining: int=WolfVM.i32(int(age[index])-delta)
		if remaining<1:
			if splash:synchronous("a(IIII)V",[xs[index],ys[index],int(dy[index])>>15,index])
			if index!=count:
				age[index]=age[count];xs[index]=xs[count];ys[index]=ys[count];dx[index]=dx[count];dy[index]=dy[count]
			count-=1;vm.set_field(object,"f","f","I",count)
			continue
		age[index]=remaining
		if drag!=0:
			dx[index]=WolfVM.i32(int(dx[index])-(WolfVM.i32(WolfVM.i32(int(dx[index])*drag)*delta)>>14))
			dy[index]=WolfVM.i32(int(dy[index])-(WolfVM.i32(WolfVM.i32(int(dy[index])*drag)*delta)>>14))
		dx[index]=WolfVM.i32(int(dx[index])+WolfVM.i32(ax*delta))
		dy[index]=WolfVM.i32(int(dy[index])+WolfVM.i32(ay*delta))
		xs[index]=WolfVM.i32(int(xs[index])+(WolfVM.i32(WolfVM.i32(int(dx[index])+wind_x)*delta)>>4))
		ys[index]=WolfVM.i32(int(ys[index])+(WolfVM.i32(WolfVM.i32(int(dy[index])+wind_y)*delta)>>4))
		index+=1

func emit_rain(object: WMObject,args: Array) -> void:
	# f.a(13 ints, boolean)V, including the original four RNG draws per drop.
	var count: int=int(vm.get_field(object,"f","f","I"));var capacity: int=int(vm.get_field(object,"f","g","I"))
	var amount: int=int(args[0])
	if 1+amount+count>capacity:amount=capacity-count-1
	var age: Array=vm.get_field(object,"f","a","[I").data
	var xs: Array=vm.get_field(object,"f","b","[I").data;var ys: Array=vm.get_field(object,"f","c","[I").data
	var dx: Array=vm.get_field(object,"f","d","[I").data;var dy: Array=vm.get_field(object,"f","e","[I").data
	var random: WMObject=vm.get_static("i","a","Ljava/util/Random;")
	var sine: Array=vm.get_static("f","a","[S").data
	var span_x: int=int(args[3])-int(args[1])+1;var span_y: int=int(args[4])-int(args[2])+1
	for index: int in amount:
		var x: int=WolfVM.i32(int(args[1])+absi(WolfVM.i32(vm.native.random_next(random,32))%span_x))
		var y: int=WolfVM.i32(int(args[2])+absi(WolfVM.i32(vm.native.random_next(random,32))%span_y))
		var speed: int=WolfVM.i32(random_range(int(args[9]),int(args[10]),random)*int(sine[90]))
		var distance: int=int(args[8]);var magnitude: int=integer_root(WolfVM.i32(distance*distance))
		count+=1
		age[count]=random_range(int(args[11]),int(args[12]),random) if int(args[12])!=0 else int(args[11])
		xs[count]=WolfVM.i32(x*16384);ys[count]=WolfVM.i32(y*16384)
		dx[count]=0;dy[count]=WolfVM.i32(WolfVM.i32(speed*distance)/magnitude)
		vm.set_field(object,"f","f","I",count)

func rain(graphics: WMObject) -> void:
	# i.l(Graphics)V: same raster, without interpreting each drop's bytecode.
	if int(vm.get_static("i","A","B"))==0 or int(vm.get_static("i","c","Z"))!=0 or int(vm.get_static("i","h","Z"))!=0 or int(vm.get_static("i","e","Z"))!=0:return
	var x: int=int(vm.get_static("i","d","B"));var y: int=int(vm.get_static("i","e","B"))
	if tile(x,y,13,57344) in [2,4]:return
	var g: MidpGraphics=graphics.data;var previous: String=g.phase;g.phase="weather";g.set_clip(0,0,240,281)
	var hour: int=int(vm.get_static("i","i","B"));var night: bool=hour>=19 or hour<=4
	var near: WMObject=vm.get_static("i","a","Lf;");var far: WMObject=vm.get_static("i","b","Lf;")
	if tile(x,y,0,7) in [0,3,7]:
		g.set_color(0x111122 if night else 0x777788)
		var fx: Array=vm.get_field(far,"f","b","[I").data;var fy: Array=vm.get_field(far,"f","c","[I").data
		for index: int in int(vm.get_field(far,"f","f","I"))+1:
			var px: int=int(fx[index])>>14;var py: int=int(fy[index])>>14;g.line(px,py-1,px,py)
	var nx: Array=vm.get_field(near,"f","b","[I").data;var ny: Array=vm.get_field(near,"f","c","[I").data;var lengths: Array=vm.get_field(near,"f","e","[I").data
	var wind: int=int(vm.get_field(near,"f","c","I"))>>14
	var count: int=int(vm.get_field(near,"f","f","I"))+1
	for index: int in count:
		var px: int=int(nx[index])>>14;var py: int=int(ny[index])>>14;var length: int=int(lengths[index])>>14
		g.set_color((0x111122 if night else 0x777788) if length<3 else (0x222233 if night else 0x888899))
		g.line(px,py,px+wind,py+length)
	var sx: Array=vm.get_static("i","p","[I").data;var sy: Array=vm.get_static("i","q","[I").data
	var radii: Array=vm.get_static("i","r","[I").data;var stages: Array=vm.get_static("i","G","[B").data
	var color: int=-1
	for index: int in count:
		if int(sx[index])==0 or int(sy[index])==0 or int(stages[index])>=6:continue
		if color<0:color=int(synchronous("a(IZZ)I",[7,1,0]))
		g.set_color(color)
		var radius: int=int(radii[index]);var stage: int=int(stages[index])
		g.arc([int(sx[index])-radius-stage,int(sy[index])-radius-(stage>>1),stage*2+radius,stage+radius,0,360],false)
	g.set_clip(0,0,240,320);g.phase=previous
func sprite(x: int,y: int,id: int,graphics: WMObject) -> void:
	sprites.invoke("c","a(IIILjavax/microedition/lcdui/Graphics;)V",[x,y,id,graphics])
func tile(x: int,y: int,shift: int,mask: int) -> int:
	return sprites.invoke("i","a(BBII)I",[WolfVM.signed(x,8),WolfVM.signed(y,8),shift,mask])
func intersection(n2: int,n3: int,n4: int,n5: int,n6: int,n7: int,n8: int,n9: int) -> int:
	var n10: int=n2*(n9-n7)+n4*(n7-n9)+n8*(n5-n3)+n6*(n3-n5)
	if n10==0:return -1
	var n11: int=((n2*(n9-n7)+n6*(n3-n9)+n8*(n7-n3))<<8)/n10
	return n2+((n11*(n4-n2))>>8)
func ground(args: Array) -> void:
	var n2: int=args[0];var n3: int=args[1];var n4: int=args[2];var n5: int=args[3]
	var n6: int=args[4];var n7: int=args[5];var n8: int=args[6];var graphics: WMObject=args[7]
	var g: MidpGraphics=graphics.data
	var meta: Array=vm.get_static("c","a","[[S").data
	var random: WMObject=vm.get_static("i","b","Ljava/util/Random;")
	var horizon: int=vm.get_static("i","H","I")
	var n9: int=n4;var n10: int=n5;var n11: int=(281-horizon)/5
	var n12: int=0;var n13: int=0;var n14: int=0
	var n15: int=tile(n2,n3,0,7)
	if n15==-1:n15=0
	var n17: int=0;var n18: int=0;var n19: int=0;var n20: int=0
	if n15==7:
		var shape: int=water_shape(n2,n3)
		var facing: int=vm.get_static("i","h","B")
		var table: Array=vm.get_static("h","a","[[S").data[n8].data if facing in [0,2,4,6] else vm.get_static("h","j","[[B").data[n8].data
		n19=n4+((((int(table[shape*4+1])*10)<<8)/1000*n6)>>8)
		n20=n4+((((int(table[shape*4+3])*10)<<8)/1000*n6)>>8)
		n17=n4+((((int(table[shape*4])*10)<<8)/1000*n6)>>8)
		n18=n4+((((int(table[shape*4+2])*10)<<8)/1000*n6)>>8)
	var chances: Array=vm.get_static("h","a","[B").data
	var weights: Array[int]=[int(chances[n15*4])+1,int(chances[n15*4+1]),int(chances[n15*4+2]),100-int(chances[n15*4])-int(chances[n15*4+1])-int(chances[n15*4+2])]
	var material: int=147+15*weights.find(weights.max())
	while true:
		var distance: int=absi(n10-281)
		var level: int=4 if distance<2*n11 else (3 if distance<3*n11 else (2 if distance<4*n11 else (1 if distance<4*n11+n11/2+n11/3 else 0)))
		var left_water: int=-1;var right_water: int=666
		if n15==7:
			if n17!=n18:left_water=intersection(0,n10,n9+240,n10,n17,n5,n18,n5+n7)
			if n19!=n20:
				right_water=intersection(0,n10,n9+240,n10,n19,n5,n20,n5+n7)
				if right_water==-1:right_water=666
		while true:
			if n14==0:
				var chance: int=random_range(0,100,random)
				n12=159 if chance<=int(chances[n15*4]) else (174 if chance<=int(chances[n15*4])+int(chances[n15*4+1]) else (189 if chance<=int(chances[n15*4])+int(chances[n15*4+1])+int(chances[n15*4+2]) else 204))
				n13=n12;n14=random_range(1,3,random)
			n12=n13+random_range(0,2,random)-3*level
			var jitter: int=2 if n7==110 else (1 if n7==34 else 0)
			if n15!=7 or n9<left_water or n9>right_water:
				sprite(n9+random_range(-jitter,jitter,random),n10+random_range(-jitter,jitter,random),n12,graphics)
			if n9==n4+n6:break
			var step_x: int=meta[n12].data[2]
			if n7==110:step_x-=int(meta[n12].data[2])/5
			if step_x==0:step_x=1
			n9=mini(n4+n6,n9+step_x);n14-=1
		if left_water!=-1:sprite(left_water,n10,n12,graphics)
		if right_water!=666:sprite(right_water,n10,n12,graphics)
		# Row advance uses the LAST selected sprite, whose height may differ from
		# the first one. Matching it prevents bare horizontal seams in wide mode.
		var step_y: int=maxi(1,int(meta[n12].data[3])/2)
		g.record({"kind":"grass_band","rect":Rect2i(n4,n10,n6,mini(step_y,n5+n7-n10+1)),"sprite":material,"water":Vector2(left_water,right_water) if n15==7 else Vector2(-1,-1)})
		if n10==n5+n7:return
		n9=n4
		n10=mini(n5+n7,n10+step_y)
func water_shape(x: int,y: int) -> int:
	# Call the small original helper synchronously. It contains cardinal/diagonal
	# connectivity rules; keeping its instructions avoids inventing shore rules.
	return int(synchronous("a(II)I",[x,y]))
func synchronous(key: String,args: Array) -> Variant:
	var found: Dictionary=vm.find_method("i",key)
	var fiber: Dictionary={"id":vm.active.id,"frames":[],"wake":vm.now_ms,"waiting":null,"yielded":false,"result":null}
	var active: Dictionary=vm.active
	vm.push_frame(fiber,found.owner,found.method,null,args)
	vm.active=fiber
	while not fiber.frames.is_empty() and not vm.halted:vm.step(fiber)
	vm.active=active
	return fiber.result

func gradient(args: Array) -> void:
	# i.a(13 ints, Graphics, int, boolean): original two-edge scan conversion.
	var n2: int=args[0];var n3: int=args[1];var n4: int=args[2];var n5: int=args[3];var n6: int=args[4]
	var n7: int=args[5];var n8: int=args[6];var n9: int=args[7];var n10: int=args[8]
	var n11: int=args[9];var n12: int=args[10];var n13: int=args[11];var n14: int=args[12]
	var graphics: MidpGraphics=args[13].data;var n15: int=args[14];var shore: bool=int(args[15])!=0
	var capture_start: int=graphics.pending_commands.size()
	var n22: int=n7;var n23: int=n9;var n24: int=n11;var n25: int=n13
	var n26: int=n10-n8;var n27: int=n9-n7;var n28: int=n14-n12;var n29: int=n13-n11
	var n30: int=n8;var n31: int=absi(n4-n3);var n32: int=n2
	var n33: int=(n5>>16)&255;var n34: int=(n5>>8)&255;var n35: int=n5&255
	var n36: int=(n6>>16)&255;var n37: int=(n6>>8)&255;var n38: int=n6&255
	var n39: int=-(((n33-n36)<<8)/n31);var n40: int=-(((n34-n37)<<8)/n31);var n41: int=-(((n35-n38)<<8)/n31)
	var n21: int=-1 if n26<0 else 1;n26=absi(n26)*2
	var n20: int=-1 if n27<0 else 1;n27=absi(n27)*2
	var n19: int=-1 if n28<0 else 1;n28=absi(n28)*2
	var n18: int=-1 if n29<0 else 1;n29=absi(n29)*2
	var left_steep: bool=n27>n26;var right_steep: bool=n29>n28
	var n17: int=n26-(n27>>1) if left_steep else n27-(n26>>1)
	var n16: int=n28-(n29>>1) if right_steep else n29-(n28>>1)
	var left_ready: bool=true;var right_ready: bool=true
	var horizon: int=vm.get_static("i","H","I")
	var random: WMObject=vm.get_static("i","b","Ljava/util/Random;")
	var effects_random: WMObject=vm.get_static("i","a","Ljava/util/Random;")
	var animated_water: bool=int(vm.get_static("h","a","I"))!=0
	while true:
		if left_ready and right_ready:
			n15-=1
			var n47: int=clampi(n33+((n39*(n32-n2+n30-n3))>>8),0,255)
			var n48: int=clampi(n34+((n40*(n32-n2+n30-n3))>>8),0,255)
			var n49: int=clampi(n35+((n41*(n32-n2+n30-n3))>>8),0,255)
			if n15<=0:graphics.set_color((n47<<16)|(n48<<8)|n49);graphics.line(n7,n8,n11,n12)
			left_ready=false;right_ready=false
			if n3==horizon*70/100:
				var base_color: Vector3i=Vector3i(n47,n48,n49)
				for count: int in 4:
					var percent: int=random_range(95,105,random)
					n47=clampi(n47*percent/100,0,255);n48=clampi(n48*percent/100,0,255);n49=clampi(n49*percent/100,0,255)
					var from_x: int=n7 if count==0 else random_range(n7,n11,random)
					var to_x: int=n11 if count==0 else random_range(n7,n11,random)
					graphics.set_color((n47<<16)|(n48<<8)|n49);graphics.line(from_x,n8,to_x,n12)
					n47=base_color.x;n48=base_color.y;n49=base_color.z
			if animated_water and shore and n15<=0:
				n47=clampi(n47-(n47>>2),0,255);n48=clampi(n48-(n48>>2),0,255);n49=clampi(n49-(n49>>2),0,255)
				var n43: int=n8-horizon+((n8-horizon)>>1)
				n43=(n43+random_range(0,n43>>3,random))/5
				graphics.set_color((n47<<16)|(n48<<8)|n49)
				if n22!=n23:graphics.line(n7,n8,n7+n43,n12)
				if n24!=n25:graphics.line(n11-n43,n8,n11,n12)
				if n32==110:
					var count: int=2 if n22!=n23 else 3
					if n24!=n25:count-=1
					var xs: Array=vm.get_static("i","u","[S").data;var ys: Array=vm.get_static("i","v","[S").data
					var flags: Array=vm.get_static("i","e","[Z").data
					for unused: int in count:
						var index: int=vm.get_static("i","a","S")
						if index>=xs.size() or random_range(0,100,effects_random)>=80:continue
						var left_gap: int=n43+5 if n22!=n23 else 0;var right_gap: int=n43+5 if n24!=n25 else 0
						if n11-right_gap<=n7+left_gap:break
						xs[index]=WolfVM.signed(random_range(n7+left_gap,n11-right_gap,effects_random),16);ys[index]=WolfVM.signed(n8,16)
						flags[index]=1 if random_range(0,100,effects_random)<50 else 0
						vm.set_static("i","a","S",WolfVM.signed(index+1,16))
			n2-=1
			if n2<=0:
				record_gradient_lighting(graphics,capture_start,n5,n6,n3,n4)
				return
		if not left_ready:
			if left_steep:
				if n17>=0:left_ready=true;n8+=n21;n17-=n27
				n7+=n20;n17+=n26
			else:
				if n17>=0:n7+=n20;n17-=n26
				n8+=n21;left_ready=true;n17+=n27
		if right_ready:continue
		if right_steep:
			if n16>=0:right_ready=true;n12+=n19;n16-=n29
			n11+=n18;n16+=n28
			continue
		if n16>=0:n11+=n18;n16-=n28
		right_ready=true;n12+=n19;n16+=n29

func record_gradient_lighting(graphics: MidpGraphics,start: int,from_rgb: int,to_rgb: int,top: int,bottom: int) -> void:
	# Metadata only: the classic raster and the original random calls are intact.
	if graphics.capture_depth<=0 or graphics.phase not in ["sky","base"]:return
	var table: WMObject=vm.get_static("h","a","[[I")
	if table==null:return
	var column: int=WolfLightPalette.column(int(vm.get_static("i","i","B")))
	var from_row: int=-1;var to_row: int=-1
	var pairs: Array=[Vector2i(8,9)] if top==0 else [Vector2i(10,11)]
	if graphics.phase!="sky":pairs=[Vector2i(0,1),Vector2i(2,3),Vector2i(4,5),Vector2i(6,7)]
	for pair: Vector2i in pairs:
		if int(table.data[pair.x].data[column])==from_rgb and int(table.data[pair.y].data[column])==to_rgb:
			from_row=pair.x;to_row=pair.y;break
	if from_row<0 or to_row<0:return
	var source_from: Color=Color.hex((from_rgb<<8)|255)
	var source_to: Color=Color.hex((to_rgb<<8)|255)
	var difference: Vector3=Vector3(source_to.r-source_from.r,source_to.g-source_from.g,source_to.b-source_from.b)
	var channel: int=difference.abs().max_axis_index()
	for index: int in range(start,graphics.pending_commands.size()):
		var command: Dictionary=graphics.pending_commands[index]
		if command.kind!="line":continue
		var amount: float=clampf((float(command.a.y)-graphics.offset.y-top)/maxi(1,bottom-top),0,1)
		if absf(difference[channel])>0.001:
			amount=clampf((float(command.color[channel])-float(source_from[channel]))/difference[channel],0,1)
		command.lighting={"from":from_row,"to":to_row,"source_from":source_from,"source_to":source_to,"amount":amount}
