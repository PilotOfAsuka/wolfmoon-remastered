class_name WolfRemasteredWorld
extends Control
## Continuous world projection with retained original UI, effects and Classic fallback.
var sprites: Dictionary
var last_revision: int=-1
var last_overlay_revision: int=-1
var last_size: Vector2=Vector2.ZERO
var last_commands: Array=[]
var textures: Dictionary={}
var grass_textures: Dictionary={}
var base_layer: WolfSceneLayer
var sky_layer: WolfSceneLayer
var cloud_layer: WolfCloudLayer
var rain_layer: WolfRainLayer
var continuous_view: WolfWorldView
var lighting: WolfLightPalette=WolfLightPalette.new()
var vegetation_wind: WolfVegetationWind=WolfVegetationWind.new()
var cloud_styles: Dictionary={}
var overlay_layer: WolfSceneLayer
var map_layer: WolfSceneLayer
var logical_height: float=281.0
const DRAW_SCHEMA: int=9
var seen_schema: int=-1
var pixel_scale: float=1.0
var projection: Vector2=Vector2.ONE
var render_signature: String=""
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
 sprites=JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json"))
 sky_layer=WolfSceneLayer.new();add_child(sky_layer)
 cloud_layer=WolfCloudLayer.new();add_child(cloud_layer)
 base_layer=WolfSceneLayer.new();add_child(base_layer)
 continuous_view=WolfWorldView.new();add_child(continuous_view)
 rain_layer=WolfRainLayer.new();add_child(rain_layer)
 overlay_layer=WolfSceneLayer.new();add_child(overlay_layer)
 map_layer=WolfSceneLayer.new();add_child(map_layer)
 sky_layer.lighting=lighting;base_layer.lighting=lighting;overlay_layer.lighting=lighting;cloud_layer.lighting=lighting
 base_layer.material=vegetation_wind.material
 sky_layer.material=vegetation_wind.material
func synchronize(state: Dictionary,delta: float) -> void:
 if not state.get("world_ready",false) or not state.has("render_commands") or size.y<=0:return
 if map_layer==null:map_layer=WolfSceneLayer.new();add_child(map_layer)
 if seen_schema!=DRAW_SCHEMA:
  grass_textures.clear();last_revision=-1;last_overlay_revision=-1;last_size=Vector2.ZERO;seen_schema=DRAW_SCHEMA
 var changed_size: bool=last_size!=size
 pixel_scale=size.y/281.0;projection=Vector2(size.x/240.0,pixel_scale)
 vegetation_wind.synchronize(state,pixel_scale)
 if lighting.synchronize(state,delta):
  sky_layer.queue_redraw();base_layer.queue_redraw();overlay_layer.queue_redraw();cloud_layer.queue_redraw()
 continuous_view.synchronize(state,delta,self)
 if changed_size or last_revision!=int(state.render_revision):
  last_revision=int(state.render_revision);last_commands=state.render_commands
  if continuous_view.scene.identity==-1:rebuild_background(state.render_commands)
 if changed_size or last_overlay_revision!=int(state.get("overlay_revision",-1)):
  last_overlay_revision=int(state.get("overlay_revision",-1))
  overlay_layer.plan=prepare(state.get("overlay_commands",[]),true);overlay_layer.queue_redraw()
  var full_map: Array=[]
  for cmd: Dictionary in state.get("overlay_commands",[]):
   if cmd.get("phase","")=="map":full_map.append(cmd)
  var world_projection: Vector2=projection;var world_scale: float=pixel_scale
  var ui_scale: float=float(state.get("ui_scale",1.0));var top: float=float(state.get("ui_top_reserve",78))*ui_scale;var available: float=maxf(1,size.y-top-18*ui_scale)
  pixel_scale=minf(size.x/240.0,available/320.0);projection=Vector2.ONE*pixel_scale;logical_height=320.0
  map_layer.position=Vector2((size.x-240*pixel_scale)/2,top+(available-320*pixel_scale)/2)
  map_layer.plan=prepare(full_map,false)
  map_layer.plan.push_front({"kind":"rect","rect":Rect2(-map_layer.position,size),"color":Color("080e12")})
  map_layer.queue_redraw();projection=world_projection;pixel_scale=world_scale;logical_height=281.0
 var show_map: bool=state.get("full_map",false)
 var continuous: bool=continuous_view.scene.identity!=-1
 map_layer.visible=show_map;base_layer.visible=not show_map and not continuous;overlay_layer.visible=not show_map
 sky_layer.visible=not show_map and not continuous;cloud_layer.visible=not show_map and not continuous
 continuous_view.visible=not show_map and continuous
 cloud_layer.animating=state.get("screen","") in ["i","b"]
 state.visual_wind_gust=vegetation_wind.gust
 rain_layer.configure(state,size,pixel_scale)
 last_size=size
 render_signature="World camera: %s / %d overlay"%[continuous_view.camera.position,overlay_layer.plan.size()]

func rebuild_background(commands: Array) -> void:
 var prepared: Array[Dictionary]=prepare(commands,false)
 var before_clouds: Array[Dictionary]=[];var foreground: Array[Dictionary]=[];var clouds: Array[Dictionary]=[]
 var found_cloud: bool=false
 for item: Dictionary in prepared:
  if item.kind=="cloud":clouds.append(item);found_cloud=true
  elif found_cloud:foreground.append(item)
  else:before_clouds.append(item)
 sky_layer.plan=before_clouds if found_cloud else []
 base_layer.plan=foreground if found_cloud else before_clouds
 cloud_layer.synchronize(clouds,pixel_scale)
 sky_layer.queue_redraw();cloud_layer.queue_redraw();base_layer.queue_redraw()
func texture_for(id: int) -> Texture2D:
 if not textures.has(id):
  var path: String="res://assets/sprites/%03d.png"%id
  if not ResourceLoader.exists(path):return null
  textures[id]=load(path)
 return textures[id]
func project(point: Vector2,group: Vector2=Vector2(-9999,-9999)) -> Vector2:
 return Vector2(group.x*projection.x+(point.x-group.x)*pixel_scale,point.y*pixel_scale) if group.x>-9000 else point*projection
func add_texture(plan: Array[Dictionary],texture: Texture2D,pos: Vector2,dims: Vector2,clip: Rect2,sprite_id: int=-1,wind: Dictionary={}) -> void:
 var visible: Rect2=Rect2(pos,dims).intersection(clip)
 if not visible.has_area():return
 var item: Dictionary={"kind":"texture","texture":texture,"rect":visible,"source":Rect2((visible.position-pos)/pixel_scale,visible.size/pixel_scale)}
 if not wind.is_empty():item.wind_quad=WolfVegetationWind.quad(visible,item.source,texture,wind)
 if sprite_id>=235 and sprite_id<=261:
  var family: int=(sprite_id-235)%9
  item.foliage=[texture_for(235+family),texture_for(244+family),texture_for(253+family)]
 plan.append(item)
func grass_texture(id: int) -> Texture2D:
 if grass_textures.has(id):return grass_textures[id]
 var source: Image=texture_for(id).get_image();source.convert(Image.FORMAT_RGBA8)
 var palette: Array[Color]=[]
 for y: int in source.get_height():
  for x: int in source.get_width():
   var color: Color=source.get_pixel(x,y)
   if color.a>0.5:palette.append(Color(color,1.0))
 if palette.is_empty():palette.append(Color("40442a"))
 palette.sort_custom(func(a: Color,b: Color) -> bool:return a.get_luminance()<b.get_luminance())
 var image: Image=Image.create(128,128,false,Image.FORMAT_RGBA8)
 for y: int in 128:
  for x: int in 128:
   var hash: int=(x*73856093)^(y*19349663)^((x/3+y/2)*83492791)
   image.set_pixel(x,y,palette[posmod(hash,maxi(1,palette.size()/2))])
 var sx: int=maxi(2,source.get_width()/2);var sy: int=maxi(1,source.get_height()/3)
 for y: int in range(-source.get_height(),128,sy):
  for x: int in range(-source.get_width(),128,sx):
   var hash: int=absi((x*73856093)^(y*19349663))
   var sprig: Image=texture_for(id+hash%3).get_image()
   image.blend_rect(sprig,Rect2i(Vector2i.ZERO,sprig.get_size()),Vector2i(x+(hash%9)-4,y+(hash%5)-2))
 var pixels: PackedByteArray=image.get_data()
 for index: int in range(0,pixels.size(),4):
  pixels[index]=int(pixels[index]*0.48);pixels[index+1]=int(pixels[index+1]*0.55);pixels[index+2]=int(pixels[index+2]*0.48)
 image=Image.create_from_data(128,128,false,Image.FORMAT_RGBA8,pixels)
 grass_textures[id]=ImageTexture.create_from_image(image)
 return grass_textures[id]
func prepare(commands: Array,overlay: bool) -> Array[Dictionary]:
 var plan: Array[Dictionary]=[];var tiled: Dictionary={}
 var tree_tops: Dictionary={}
 if not overlay:
  for part: Dictionary in commands:
   if part.kind!="sprite" or part.get("phase","")!="base":continue
   var id: int=int(part.id)
   if id<105 or id>142 or int(part.group_type)<0:continue
   var key: String=str(part.group)+":"+str(part.group_type)
   var top: float=float(part.y)-float(sprites[str(id)].origin[1])
   tree_tops[key]=minf(float(tree_tops.get(key,top)),top)
 var grass_plan: Array[Dictionary]=[]
 if not overlay:
  for band: Dictionary in commands:
   if band.kind=="grass_band":append_grass(grass_plan,band)
 var grass_added: bool=false
 var horizon_groups: Dictionary={}
 var horizon_keys: Array=[]
 if not overlay:
  for part: Dictionary in commands:
   if part.kind!="sprite" or part.get("phase","")!="sky" or int(part.group_type)<0:continue
   var key: String=str(part.group)+":"+str(part.group_type)
   if not horizon_groups.has(key):horizon_groups[key]=[];horizon_keys.append(key)
   horizon_groups[key].append(part)
 var horizon_drawn: Dictionary={}
 var panel_group: Vector2=Vector2(-9999,-9999);var previous_phase: String=""
 for cmd: Dictionary in commands:
  var phase: String=str(cmd.get("phase",""))
  if overlay and (phase in ["hud","map","weather"] or cmd.kind=="image"):continue
  if phase!=previous_phase:panel_group=Vector2(-9999,-9999);previous_phase=phase
  var interaction: bool=phase.begins_with("interaction_")
  if interaction and cmd.kind=="rect" and cmd.rect.size.x>=14 and cmd.rect.size.y>=14 and cmd.color==Color.BLACK:panel_group=Rect2(cmd.rect).get_center()
  var group: Vector2=panel_group if interaction else Vector2(-9999,-9999)
  var clip: Rect2=Rect2(cmd.clip).intersection(Rect2(0,0,240,logical_height))
  if not clip.has_area():continue
  var bounds: Rect2=Rect2(clip.position*projection,clip.size*projection)
  if not grass_added and (cmd.kind=="grass_band" or (cmd.kind=="sprite" and int(cmd.id)>=147 and int(cmd.id)<=206)):
   plan.append_array(grass_plan);grass_added=true
  if not overlay and cmd.kind=="sprite" and phase=="sky" and int(cmd.group_type)>=0:
   var key: String=str(cmd.group)+":"+str(cmd.group_type)
   if not horizon_drawn.has(key):
    horizon_drawn[key]=true
    var index: int=horizon_keys.find(key)
    var until: float=float(horizon_groups[horizon_keys[index+1]][0].group.x)*projection.x if index+1<horizon_keys.size() else size.x
    append_horizon(plan,horizon_groups[key],until,index==0)
   continue
  match cmd.kind:
   "image":
    var image: Image=cmd.image;var key: String="image:"+str(image.get_instance_id())
    if not textures.has(key):textures[key]=ImageTexture.create_from_image(image)
    add_texture(plan,textures[key],project(Vector2(cmd.rect.position)),Vector2(image.get_size())*pixel_scale,bounds)
   "grass_band":
    continue
   "sprite":
    var id: int=int(cmd.id)
    if overlay and continuous_view.scene.identity!=-1 and id>=407 and id<=416:continue
    if overlay and id in [216,217,218,219,220,221]:continue
    var meta: Dictionary=sprites.get(str(id),{});var texture: Texture2D=texture_for(id)
    if meta.is_empty() or texture==null:continue
    if not interaction:group=cmd.group
    var pos: Vector2=project(Vector2(cmd.x,cmd.y),group)-Vector2(float(meta.origin[0]),float(meta.origin[1]))*pixel_scale
    var dims: Vector2=Vector2(float(meta.rect[2]),float(meta.rect[3]))*pixel_scale
    if dims.x<=0 or dims.y<=0:continue
    if not overlay and phase=="sky" and id>=270 and id<=287:
     # Loop clouds that are actually in this view. Off-screen source records
     # must not wrap into the picture as extra copies.
     if not Rect2(pos,dims).intersects(bounds):continue
     var cloud_key: String=str(cmd.x)+":"+str(clip)
     if id<282:cloud_styles[cloud_key]=270 if id<276 else 276
     var day_id: int=int(cloud_styles.get(cloud_key,270))+id%6
     plan.append({"kind":"cloud","texture":texture,"day_texture":texture_for(day_id),"night_texture":texture_for(282+id%6),"rect":Rect2(pos,dims),"clip":bounds,"depth":id%6})
     continue
    var coverage: Rect2=Rect2(cmd.get("coverage",Rect2i()));var fill: Rect2=bounds
    if coverage.has_area():fill=Rect2(Vector2(coverage.position.x*projection.x,bounds.position.y),Vector2(coverage.size.x*projection.x,bounds.size.y)).intersection(bounds)
    if id==269 or phase=="transition":
     var key: String=str(id)+str(clip)
     if tiled.has(key):continue
     tiled[key]=true
     for yy: int in range(0,ceili(bounds.size.y/dims.y)+1):
      for xx: int in range(0,ceili(bounds.size.x/dims.x)+1):add_texture(plan,texture,bounds.position+Vector2(xx*dims.x,yy*dims.y),dims,bounds)
    elif id in [262,263,264,265] and coverage.has_area() and fill.size.x>dims.x:
     var step: float=dims.x*0.75;var x: float=pos.x
     while x>fill.position.x:x-=step
     while x<fill.end.x:add_texture(plan,texture,Vector2(x,pos.y),dims,bounds);x+=step
    else:
     var wind: Dictionary={}
     if not overlay and phase=="base" and id>=105 and id<=206:
      var grass: bool=id>=147
      # Fallen needles and the opaque ground cover remain still.
      if grass or id<=142:
       var root: float=pos.y+dims.y
       var height: float=dims.y
       var anchor: Vector2=Vector2(cmd.x,cmd.y)
       var seed: int=id
       if grass:
        root=pos.y+(float(meta.origin[1]) if float(meta.origin[1])>0 else float(meta.rect[3]))*pixel_scale
        height=maxf(pixel_scale,root-pos.y)
       elif int(cmd.group_type)>=0:
        var key: String=str(cmd.group)+":"+str(cmd.group_type)
        root=group.y*pixel_scale
        height=maxf(pixel_scale,(group.y-float(tree_tops.get(key,group.y-20)))*pixel_scale)
        anchor=group;seed=int(cmd.group_type)
       var amplitude: float=clampf(height/pixel_scale*(0.055 if grass else 0.016),0.1,1.1 if grass else 1.8)
       wind={"grass":grass,"root":root,"height":height,"amplitude":amplitude,"phase":WolfVegetationWind.phase_for(anchor,seed)}
     add_texture(plan,texture,pos,dims,bounds,id,wind)
   "rect":
    var rect: Rect2=Rect2(cmd.rect).intersection(clip)
    if rect.has_area():plan.append({"kind":"rect","rect":Rect2(project(rect.position,group),rect.size*(Vector2.ONE*pixel_scale if interaction else projection)),"color":cmd.color})
   "line":
    var a: Vector2=cmd.a;var b: Vector2=cmd.b;var d: Vector2=b-a
    var low: float=0;var high: float=1;var valid: bool=true
    var ps: Array[float]=[-d.x,d.x,-d.y,d.y];var qs: Array[float]=[a.x-clip.position.x,clip.end.x-a.x,a.y-clip.position.y,clip.end.y-a.y]
    for n: int in 4:
     if is_zero_approx(ps[n]):
      if qs[n]<0:valid=false
     else:
      var t: float=qs[n]/ps[n]
      if ps[n]<0:low=maxf(low,t)
      else:high=minf(high,t)
    if valid and low<=high:
     var item: Dictionary={"kind":"line","a":project(a+d*low,group),"b":project(a+d*high,group),"color":cmd.color,"width":maxf(1,pixel_scale)}
     if cmd.has("lighting"):item.lighting=cmd.lighting
     plan.append(item)
   "arc":
    var args: Array=cmd.args;var center: Vector2=Vector2(float(args[0])+float(args[2])/2,float(args[1])+float(args[3])/2)+Vector2(cmd.offset)
    var points: PackedVector2Array=[]
    if cmd.filled:points.append(project(center,group))
    for n: int in 49:
     var angle: float=deg_to_rad(float(args[4])+float(args[5])*n/48.0)
     points.append(project(center+Vector2(cos(angle)*float(args[2])/2,-sin(angle)*float(args[3])/2),group))
    plan.append({"kind":"polygon" if cmd.filled else "polyline","points":points,"color":cmd.color,"width":maxf(1,pixel_scale)})
 return plan

func append_horizon(plan: Array[Dictionary],parts: Array,until: float,first: bool) -> void:
 var left: float=INF;var right: float=-INF
 for cmd: Dictionary in parts:
  var meta: Dictionary=sprites[str(cmd.id)]
  left=minf(left,float(cmd.x)-float(meta.origin[0]));right=maxf(right,float(cmd.x)-float(meta.origin[0])+float(meta.rect[2]))
 var group: Vector2=parts[0].group
 var initial: float=project(Vector2(left,0),group).x
 var width: float=(right-left)*pixel_scale
 if width<=0:return
 var step: float=width*0.62;var x: float=initial
 if first:
  while x>0:x-=step
 while x<until+width*0.2:
  for cmd: Dictionary in parts:
   var meta: Dictionary=sprites[str(cmd.id)];var tex: Texture2D=texture_for(int(cmd.id))
   if tex==null:continue
   var pos: Vector2=project(Vector2(cmd.x,cmd.y),group)-Vector2(float(meta.origin[0]),float(meta.origin[1]))*pixel_scale+Vector2(x-initial,0)
   var dims: Vector2=Vector2(float(meta.rect[2]),float(meta.rect[3]))*pixel_scale
   var clip: Rect2=Rect2(cmd.clip).intersection(Rect2(0,0,240,281))
   add_texture(plan,tex,pos,dims,Rect2(clip.position*projection,clip.size*projection),int(cmd.id))
  x+=step

func append_grass(plan: Array[Dictionary],cmd: Dictionary) -> void:
 var rect: Rect2=Rect2(cmd.rect).intersection(Rect2(cmd.clip)).intersection(Rect2(0,0,240,281))
 var parts: Array[Rect2]=[rect];var water: Vector2=cmd.water
 if water.y>=0:parts=[rect.intersection(Rect2(-500,rect.position.y,maxf(0,water.x+500),rect.size.y)),rect.intersection(Rect2(water.y,rect.position.y,1000,rect.size.y))]
 for part: Rect2 in parts:
  if not part.has_area():continue
  var dst: Rect2=Rect2(part.position*projection,part.size*projection)
  plan.append({"kind":"texture","texture":grass_texture(int(cmd.sprite)),"rect":dst,"source":Rect2(dst.position/pixel_scale,dst.size/pixel_scale)})
