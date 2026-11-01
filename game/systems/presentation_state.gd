class_name WolfPresentationState
extends RefCounted
## Read-only projection of original fields. No gameplay decisions or extra alerts.
var vm: WolfVM
const ITEM_NAMES_RU: Array[String]=["Патроны к револьверу","Бензопила","Ружьё","Аптечка","Ключи от джипа","Самогон","Пиво","Динамит","Нож","Шоколад","Лопата","Череп оборотня","Дрова","Бензин","Сырое мясо","Бинокль","Фонарик","Наручники","Ружейные патроны","Серебряные пули","Серебро","Череп охотника","Револьвер","Ключ от хижины","Тотем Вендиго","Когти"]
const ITEM_NAMES_EN: Array[String]=["Revolver ammo","Chainsaw","Rifle","First aid kit","Jeep keys","Moonshine","Beer","Dynamite","Knife","Chocolate","Shovel","Werewolf skull","Firewood","Gasoline","Raw meat","Binoculars","Flashlight","Handcuffs","Rifle ammo","Silver bullets","Silver","Hunter skull","Revolver","Cabin key","Wendigo totem","Claws"]

func _init(machine: WolfVM) -> void: vm=machine

func array(cl: String,name: String,desc: String) -> Array:
	var o: Variant=vm.get_static(cl,name,desc)
	return o.data if o is WMObject and o.data is Array else []

func text_block(e: WMObject) -> String:
	var lines: Variant=vm.get_field(e,"e","a","[Ljava/lang/String;")
	return " ".join(lines.data) if lines!=null else ""

func paragraphs(container: WMObject,cl: String) -> String:
	var parts: PackedStringArray=[]
	var blocks: Variant=vm.get_field(container,cl,"a","[Le;") if cl=="b" else vm.get_static(cl,"a","[Le;")
	if blocks!=null:
		for e: Variant in blocks.data:
			if e!=null: parts.append(text_block(e))
	return "\n\n".join(parts)

func collect() -> Dictionary:
	var state: Dictionary={"screen":"","world_ready":false,"menu":[],"dialogue":"","story_sprite":-1,"inventory":[],"creatures":[],"objects":[],"items":[],"inside":false,"softkeys":[]}
	var screen: Variant=vm.get_static("m","a","Lp;")
	var language_cache: Array=array("c","b","[Ljava/lang/Object;")
	state.locale="en" if language_cache.size()>0 and language_cache[0]!=null and language_cache[0].data.size()>4 and str(language_cache[0].data[4])=="Yes" else "ru"
	if screen!=null:
		state.screen=screen.type
		var softkeys: Variant=vm.get_field(screen,"p","a","[Ljava/lang/String;")
		if softkeys!=null:state.softkeys=softkeys.data.duplicate()
	if screen!=null and screen.type=="j":
		state.menu_id=vm.get_field(screen,"j","j","I")
		state.title=vm.get_field(screen,"j","a","Ljava/lang/String;")
		state.selection=vm.get_field(screen,"j","f","I")
		var rows: Variant=vm.get_field(screen,"j","a","Ljava/util/Vector;")
		if rows!=null:
			for n: int in rows.data.size():
				var row: WMObject=rows.data[n]
				var variants: WMObject=vm.get_field(row,"k","a","[Le;")
				var chosen: int=int(vm.get_field(row,"k","a","I"))
				state.menu.append({"index":n,"text":text_block(variants.data[chosen]),"enabled":int(vm.get_field(row,"k","a","B"))!=0,"variant":variants.data.size()>1})
	elif screen!=null and screen.type=="b": state.dialogue=paragraphs(screen,"b")
	elif screen!=null and screen.type=="d":
		state.dialogue=paragraphs(screen,"d")
		state.story_sprite=vm.get_static("d","m","I")
	var adapted: String=WolfControlText.adapt(state.dialogue)
	state.tutorial=adapted!=state.dialogue;state.dialogue=adapted
	if not vm.initialized.has("i") or array("i","s","[S").is_empty() or array("i","A","[B").is_empty(): return state
	state.world_ready=true
	var graphics: Variant=vm.get_static("i","b","Ljavax/microedition/lcdui/Graphics;")
	if graphics!=null:
		state.render_commands=graphics.data.commands
		state.render_revision=graphics.data.revision
	var overlay: MidpGraphics=vm.native.screen.data
	state.overlay_commands=overlay.commands
	state.overlay_revision=overlay.revision
	var map_image: Variant=vm.get_static("i","a","Ljavax/microedition/lcdui/Image;")
	if map_image!=null:state.map_image=map_image.data
	state.x=vm.get_static("i","d","B");state.y=vm.get_static("i","e","B");state.facing=vm.get_static("i","h","B")
	var world_cells: WMObject=vm.get_static("i","s","[S")
	state.world_id=world_cells.get_instance_id();state.world_cells=world_cells.data
	state.world_width=int(vm.get_static("i","b","B"));state.world_height=int(vm.get_static("i","c","B"))
	state.render_busy=graphics!=null and graphics.data.capture_depth>0
	state.scene_groups=array("h","b","[[S")
	state.grass_weights=array("h","a","[B")
	state.sky_clouds=array("i","e","[B");state.sky_cloud_types=array("i","f","[B")
	state.sky_stars=array("i","b","[B");state.sky_star_types=array("i","c","[B")
	state.sky_star_colors=array("i","c","[I");state.sky_sun_points=array("i","a","[I");state.sky_moon_points=array("i","b","[I")
	state.room_openings=array("i","d","[B")
	state.corpse_present=int(vm.get_static("i","m","I"))!=-1
	state.puzzle_stage=int(vm.get_static("i","x","B"))
	state.in_vehicle=int(vm.get_static("i","e","Z"))!=0
	state.moon_phase=int(vm.get_static("i","z","I"))/90
	state.hour=vm.get_static("i","i","B");state.day=vm.get_static("i","A","I");state.stamina=vm.get_static("i","C","I")
	var light_rows: Array=array("h","a","[[I")
	var light_column: int=WolfLightPalette.column(int(state.hour))
	state.light_palette=[]
	for row: WMObject in light_rows:
		state.light_palette.append(Color.hex((int(row.data[light_column])<<8)|255))
	state.inside=int(vm.get_static("i","c","Z"))!=0
	state.full_map=int(vm.get_static("i","h","Z"))!=0
	state.flashlight=int(vm.get_static("i","d","Z"))!=0
	state.battle=int(vm.get_static("i","l","Z"))!=0
	state.transformed=int(vm.get_static("i","C","Z"))!=0
	# These are the original rain painter's exposure and intensity conditions.
	var weather_cells: Array=array("i","s","[S")
	var weather_at: int=int(state.x)+int(state.y)*int(vm.get_static("i","b","B"))
	var shelter: int=(int(weather_cells[weather_at])>>13)&7 if weather_at>=0 and weather_at<weather_cells.size() else 0
	state.weather_exposed=not state.inside and int(vm.get_static("i","e","Z"))==0 and shelter not in [2,4]
	state.rain_strength=clampf(float(vm.get_static("i","V","I"))/150.0,0.0,1.0) if int(vm.get_static("i","A","B"))!=0 else 0.0
	var rain: Variant=vm.get_static("i","a","Lf;")
	state.rain_wind=float(vm.get_field(rain,"f","c","I"))/16384.0 if rain is WMObject else 0.0
	state.view_offsets=array("h","a","[[B")[int(state.facing)].data.duplicate()
	state.object_icons=array("h","d","[S")
	state.creature_icons=array("h","e","[S")
	state.item_icons=array("h","b","[S")
	var items: Array=array("i","A","[B")
	state.selected=int(vm.get_static("i","o","B"))
	for n: int in range(0,items.size(),2):
		var id: int=int(items[n])
		if id<0 or id>=state.item_icons.size(): continue
		# h.c contains descriptions of ground discoveries, including repeated
		# quest text. Inventory entries need their own short localized names.
		var names: Array[String]=ITEM_NAMES_RU if state.locale=="ru" else ITEM_NAMES_EN
		var name: String=names[id] if id<names.size() else ("Предмет" if state.locale=="ru" else "Item")
		state.inventory.append({"slot":n/2,"id":id,"count":items[n+1],"name":name,"sprite":state.item_icons[id]})
	var types: Array=array("i","h","[B");var xs: Array=array("i","i","[B");var ys: Array=array("i","j","[B");var active: Array=array("i","a","[Z")
	for n: int in types.size(): state.creatures.append({"type":types[n],"x":xs[n],"y":ys[n],"active":int(active[n])!=0})
	var ot: Array=array("i","r","[B");var ox: Array=array("i","s","[B");var oy: Array=array("i","t","[B");var os: Array=array("i","u","[B")
	for n: int in ot.size(): state.objects.append({"type":ot[n],"x":ox[n],"y":oy[n],"status":os[n]})
	# The original inventory ends with a virtual Zzz slot (i.p), whose item ID
	# is 69, outside h.b's item icons. Keep it as a fixed action beside the scroll.
	state.rest_slot=int(vm.get_static("i","p","B"))
	state.rest_available=rest_available(state)
	var it: Array=array("i","w","[B");var ix: Array=array("i","x","[B");var iy: Array=array("i","y","[B");var ist: Array=array("i","z","[B")
	for n: int in it.size(): state.items.append({"type":it[n],"x":ix[n],"y":iy[n],"status":ist[n]})
	return state

func rest_available(state: Dictionary) -> bool:
	# Read-only equivalent of the virtual slot's original i.b()Z predicate.
	# Actual rest still goes through keypad input and the original i.j()V handler.
	var width: int=int(vm.get_static("i","b","B"))
	var cells: Array=array("i","s","[S")
	var at: int=int(state.x)+int(state.y)*width
	if at<0 or at>=cells.size():return false
	var tile: int=int(cells[at]);var shelter: int=(tile>>13)&7
	var protected: bool=state.inside or int(vm.get_static("i","e","Z"))!=0 or shelter in [2,4]
	if state.transformed or int(vm.get_static("i","m","I"))!=-1 or (tile&7)==7:return false
	if (state.battle or int(vm.get_static("i","k","Z"))!=0) and not protected:return false
	for object: Dictionary in state.objects:
		if int(object.x)==int(state.x) and int(object.y)==int(state.y) and int(object.type)==5 and int(object.status)!=2:return false
	return true
