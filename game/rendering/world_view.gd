class_name WolfWorldView
extends Node2D
## Continuous 2.5D projection of fixed scenery and the original world entities.
const FLOOR_SHADER: Shader=preload("res://rendering/world_floor.gdshader")
const GRASS_SHADER: Shader=preload("res://rendering/world_grass.gdshader")
var camera: WolfWorldCamera=WolfWorldCamera.new()
var scene: WolfWorldScene=WolfWorldScene.new()
var owner_view: WolfRemasteredWorld
var floor_view: ColorRect
var floor_material: ShaderMaterial=ShaderMaterial.new()
var sprite_material: ShaderMaterial=ShaderMaterial.new()
var sky: WolfSceneLayer
var walls: WolfSceneLayer
var interior: WolfSceneLayer
var grass_nodes: Array[MultiMeshInstance2D]=[]
var layers: Array[WolfSceneLayer]=[]
var grass_materials: Array[ShaderMaterial]=[]
var grass_center: Vector2i=Vector2i(-999,-999)
var view_size: Vector2=Vector2.ZERO
var focal: float=180.0
var horizon: float=120.0
var eye: float=0.34
var room_blend: float=0.0
var room_kind: int=0
var entities_stamp: int=0
var last_fire_frame: int=-1
var clouds: Array=[]
var state: Dictionary={}
var bounds: Rect2
var ambient: float=1.0

func _ready() -> void:
 floor_view=ColorRect.new();floor_view.mouse_filter=Control.MOUSE_FILTER_IGNORE;floor_material.shader=FLOOR_SHADER;floor_view.material=floor_material;add_child(floor_view)
 sky=WolfSceneLayer.new();sky.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;add_child(sky)
 sprite_material.shader=WolfVegetationWind.WIND_SHADER
 for band: int in 3:
  var node: MultiMeshInstance2D=MultiMeshInstance2D.new();node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  var mat: ShaderMaterial=ShaderMaterial.new();mat.shader=GRASS_SHADER;node.material=mat
  grass_nodes.append(node);grass_materials.append(mat);add_child(node)
  var layer: WolfSceneLayer=WolfSceneLayer.new();layer.material=sprite_material;layers.append(layer);add_child(layer)
 walls=WolfSceneLayer.new();add_child(walls)
 interior=WolfSceneLayer.new();interior.material=sprite_material;add_child(interior)

func synchronize(next: Dictionary,delta: float,owner: WolfRemasteredWorld) -> void:
 owner_view=owner;state=next
 if int(state.get("world_width",0))<=0 or state.get("scene_groups",[]).size()<25 or state.get("grass_weights",[]).size()<32:return
 var reset: bool=scene.configure(state,owner)
 var resized: bool=view_size!=owner.size
 view_size=owner.size;bounds=Rect2(Vector2.ZERO,view_size)
 focal=view_size.y*0.68;horizon=view_size.y*0.42
 var camera_changed: bool=camera.synchronize(state,delta)
 var feature: int=(scene.tile(int(state.x),int(state.y))>>13)&7
 var kind: int=1 if state.inside else (2 if feature in [2,4] else 0)
 var old_room: float=room_blend;room_kind=kind if kind!=0 else room_kind
 room_blend=move_toward(room_blend,1.0 if kind!=0 else 0.0,delta*4.0)
 var room_changed: bool=not is_equal_approx(old_room,room_blend)
 if reset:
  grass_center=Vector2i(-999,-999);clouds.clear()
  for index: int in range(0,mini(state.sky_clouds.size(),state.sky_cloud_types.size()*2),2):
   var height: int=clampi(int(state.sky_clouds[index+1]),0,127)
   clouds.append({"bearing":(float(state.sky_clouds[index])+96.0)/256.0*TAU,"height":float(height)/128.0,"depth":clampi(height/21,0,5),"style":276 if int(state.sky_cloud_types[index/2])==0 else 270})
  floor_material.set_shader_parameter("ground_atlas",scene.ground_texture);floor_material.set_shader_parameter("map_cells",scene.map_texture)
  floor_material.set_shader_parameter("water_mask",scene.water_texture);floor_material.set_shader_parameter("map_size",Vector2(scene.width,scene.height))
  floor_material.set_shader_parameter("wood",owner.texture_for(269));floor_material.set_shader_parameter("stone",scene.stone())
 if resized:floor_view.size=view_size
 var center: Vector2i=Vector2i(floori(camera.destination.x),floori(camera.destination.y))
 if center!=grass_center:build_grass(center)
 var light: WolfLightPalette=owner.lighting
 if light.current.size()==12:
  var reference: Color=light.current[0]
  ambient=clampf(0.65+reference.get_luminance()*1.2,0.65,1.0)
  floor_material.set_shader_parameter("sky_top",light.current[8]);floor_material.set_shader_parameter("sky_mid",light.current[9]);floor_material.set_shader_parameter("sky_bottom",light.current[11])
  floor_material.set_shader_parameter("land_far",light.current[0]);floor_material.set_shader_parameter("water_far",light.current[4]);floor_material.set_shader_parameter("water_near",light.current[7])
 var wind: WolfVegetationWind=owner.vegetation_wind
 for mat: ShaderMaterial in [floor_material]+grass_materials:
  mat.set_shader_parameter("view_size",view_size);mat.set_shader_parameter("camera_position",camera.position)
  mat.set_shader_parameter("camera_forward",camera.forward());mat.set_shader_parameter("camera_right",camera.right())
  mat.set_shader_parameter("focal",focal);mat.set_shader_parameter("horizon",horizon);mat.set_shader_parameter("eye_height",eye);mat.set_shader_parameter("ambient",ambient)
  mat.set_shader_parameter("room_cell",Vector2(int(state.x),int(state.y)));mat.set_shader_parameter("room_blend",room_blend)
 floor_material.set_shader_parameter("flashlight",1.0 if state.flashlight else 0.0)
 floor_material.set_shader_parameter("clock_time",wind.elapsed);floor_material.set_shader_parameter("room_kind",float(room_kind))
 for mat: ShaderMaterial in grass_materials:
  mat.set_shader_parameter("wind_time",wind.elapsed);mat.set_shader_parameter("wind_direction",wind.direction);mat.set_shader_parameter("wind_gust",wind.gust)
 sprite_material.set_shader_parameter("wind_time",wind.elapsed);sprite_material.set_shader_parameter("wind_direction",wind.direction);sprite_material.set_shader_parameter("wind_gust",wind.gust)
 sprite_material.set_shader_parameter("wind_pixel_scale",view_size.y/281.0);sprite_material.set_shader_parameter("environment_tint",Color(ambient,ambient,ambient,1))
 var stamp: int=hash([state.objects,state.items,state.creatures,state.inside,state.battle,state.flashlight,state.corpse_present,state.puzzle_stage,state.in_vehicle])
 var fire_frame: int=int(wind.elapsed*7.0)
 if reset or resized or camera_changed or room_changed or stamp!=entities_stamp or fire_frame!=last_fire_frame:
  rebuild_sprites();entities_stamp=stamp;last_fire_frame=fire_frame
 rebuild_sky()

func build_grass(center: Vector2i) -> void:
 grass_center=center
 var instances: Array=scene.grass_instances(center)
 var mesh: QuadMesh=QuadMesh.new();mesh.size=Vector2.ONE
 var multimesh: MultiMesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_2D;multimesh.use_custom_data=true
 multimesh.mesh=mesh;multimesh.instance_count=instances.size();multimesh.custom_aabb=AABB(Vector3(-10000,-10000,-1),Vector3(20000,20000,2))
 for index: int in instances.size():
  multimesh.set_instance_transform_2d(index,Transform2D(0,instances[index].position));multimesh.set_instance_custom_data(index,instances[index].data)
 for band: int in 3:
  grass_nodes[band].multimesh=multimesh;grass_nodes[band].texture=scene.grass_texture
  grass_materials[band].set_shader_parameter("band_near",[2.8,1.1,0.12][band]);grass_materials[band].set_shader_parameter("band_far",[7.3,2.8,1.1][band])

func project(point: Vector2,z: float=0.0) -> Vector3:
 var delta: Vector2=point-camera.position;var depth: float=delta.dot(camera.forward())
 if depth<=0.075:return Vector3(-10000,-10000,depth)
 var scale: float=focal/depth
 return Vector3(view_size.x*0.5+delta.dot(camera.right())*scale,horizon+(eye-z)*scale,depth)

func band_for(depth: float) -> int:return 0 if depth>=2.8 else (1 if depth>=1.1 else 2)

func add_sprite(plan: Array[Dictionary],part: Dictionary,point: Vector2,height: float,z: float=0.0,wind: Dictionary={}) -> void:
 var projected: Vector3=project(point,z)
 if projected.z<0.08 or projected.z>10.0:return
 var dimensions: Vector2=part.size*(height/part.size.y*focal/projected.z)
 var position: Vector2=Vector2(projected.x,projected.y)-part.origin/part.size*dimensions
 var visible: Rect2=Rect2(position,dimensions).intersection(bounds)
 if not visible.has_area():return
 var texels: Vector2=part.size/dimensions
 var source: Rect2=Rect2((visible.position-position)*texels,visible.size*texels)
 var opacity: float=smoothstep(0.08,0.24,projected.z)
 var item: Dictionary={"kind":"texture","texture":part.texture,"rect":visible,"source":source,"tint":Color(1,1,1,opacity)}
 if not wind.is_empty():
  var hint: Dictionary={"grass":false,"root":projected.y,"height":maxf(1,projected.y-position.y),"amplitude":clampf(dimensions.y/(view_size.y/281.0)*0.016,0.1,1.8),"phase":wind.phase,"size_class":clampi(roundi(float(wind.height)*4),1,4)}
  item.wind_quad=WolfVegetationWind.quad(visible,source,part.texture,hint)
  for index: int in item.wind_quad.colors.size():item.wind_quad.colors[index].a*=opacity
 plan.append(item)

func rebuild_sprites() -> void:
 var entities: Array=[]
 var center: Vector2i=Vector2i(floori(camera.position.x),floori(camera.position.y))
 for y: int in range(maxi(-2,center.y-8),mini(scene.height+2,center.y+9)):
  for x: int in range(maxi(-2,center.x-8),mini(scene.width+2,center.x+9)):
   var relative: Vector2=Vector2(x+0.5,y+0.5)-camera.position
   var depth: float=relative.dot(camera.forward())
   if depth < -1.0 or depth>10.0 or absf(relative.dot(camera.right()))>maxf(depth,0.0)*view_size.x/(2*focal)+1.5:continue
   if ((scene.tile(x,y)>>13)&7) in [2,4]:continue
   if room_blend>0.99 and state.inside and x==int(state.x) and y==int(state.y):continue
   for entry: Dictionary in scene.decoration(x,y):entities.append(entry)
 for object: Dictionary in state.objects:
  var type: int=int(object.type)
  if type<0 or type>=state.object_icons.size():continue
  if type==5:
   if int(object.status) in [0,2]:entities.append({"position":Vector2(object.x+0.74,object.y+0.20),"prefab":18 if int(object.status)==0 else 19,"height":0.58,"tree":false})
   continue
  if int(object.status)==2:
   if type==4:entities.append({"position":Vector2(object.x+0.80,object.y+0.20),"sprite":357,"height":0.85,"tree":false})
   continue
  if type==0 and not state.inside:continue
  var offset: Vector2=Vector2(0.5,0.52)
  if type==0:offset=Vector2(0.28,0.16)
  elif type==2:offset=Vector2(0.78,0.72)
  var point: Vector2=Vector2(object.x,object.y)+offset
  entities.append({"position":point,"sprite":int(state.object_icons[type]),"height":0.22 if type in [0,2,3] else 0.10,"object_type":type,"status":int(object.status),"tree":false})
 for item: Dictionary in state.items:
  if int(item.status)!=1 or int(item.type)<0 or int(item.type)>=state.item_icons.size():continue
  var point: Vector2=Vector2(item.x+0.62,item.y+0.26)
  entities.append({"position":point,"sprite":int(state.item_icons[int(item.type)]),"height":0.055,"tree":false})
 if state.corpse_present:entities.append({"position":Vector2(27.55,36.08),"sprite":384,"height":0.075,"tree":false})
 if room_kind==2 and room_blend>0.0 and state.flashlight and ((scene.tile(int(state.x),int(state.y))>>13)&7)==4:
  var cell: Vector2i=Vector2i(int(state.x),int(state.y));var exit: Vector2i=Vector2i(0,1)
  for offset: Vector2i in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
   if (scene.tile(cell.x+offset.x,cell.y+offset.y)&7)!=6:exit=offset;break
  entities.append({"position":Vector2(cell)+Vector2(0.5,0.5)-Vector2(exit)*0.43,"puzzle":true,"height":0.29,"tree":false})
 for entity: Dictionary in entities:entity.depth=(Vector2(entity.position)-camera.position).dot(camera.forward())
 entities.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return float(a.depth)>float(b.depth))
 var plans: Array[Array]=[[],[],[]]
 var interior_plan: Array[Dictionary]=[]
 for entity: Dictionary in entities:
  var depth: float=float(entity.depth)
  if depth<0.08 or depth>9.0:continue
  var part: Dictionary
  if entity.get("puzzle",false):part=scene.puzzle(int(state.puzzle_stage))
  elif entity.get("house",false):part=scene.house()
  elif entity.has("prefab"):part=scene.prefab(int(entity.prefab))
  else:
   part=scene.sprite(int(entity.sprite))
   if entity.has("object_type") or not entity.get("tree",false):part=part.duplicate();part.origin=Vector2(part.size.x*0.5,part.size.y*0.85)
  var plan: Array[Dictionary]=[]
  add_sprite(plan,part,entity.position,float(entity.height),0.0,entity if entity.get("tree",false) else {})
  if int(entity.get("object_type",-1)) in [0,1,3] and int(entity.get("status",0))==1:
   var fire: Dictionary=scene.sprite(75+int(owner_view.vegetation_wind.elapsed*7)%3)
   fire=fire.duplicate();fire.origin=Vector2(fire.size.x*0.5,fire.size.y)
   add_sprite(plan,fire,entity.position,0.10,0.035)
  var cell: Vector2i=Vector2i(floori(entity.position.x),floori(entity.position.y))
  var indoors: bool=room_blend>0.001 and ((room_kind==1 and cell==Vector2i(int(state.x),int(state.y))) or (room_kind==2 and ((scene.tile(cell.x,cell.y)>>13)&7) in [2,4] and cave_line_clear(entity.position)))
  if indoors:interior_plan.append_array(plan)
  else:plans[band_for(depth)].append_array(plan)
 for band: int in 3:layers[band].plan.assign(plans[band]);layers[band].queue_redraw()
 rebuild_walls()
 if state.in_vehicle:
  var part: Dictionary=scene.sprite(382)
  var size: Vector2=part.size*view_size.y/281.0
  size*=minf(1.0,view_size.x/size.x)
  interior_plan.append({"kind":"texture","texture":part.texture,"rect":Rect2(Vector2((view_size.x-size.x)*0.5,view_size.y-size.y),size),"source":Rect2(Vector2.ZERO,part.size)})
 interior.plan=interior_plan;interior.queue_redraw()

func cave_line_clear(point: Vector2) -> bool:
 var distance: float=camera.position.distance_to(point)
 for step: int in range(1,ceili(distance*10)):
  var sample: Vector2=camera.position.lerp(point,float(step)/(distance*10))
  var tile: int=scene.tile(floori(sample.x),floori(sample.y))
  if (tile&7)==6 and not ((tile>>13)&7) in [2,4]:return false
 return true

func sky_position(bearing: float,elevation: float) -> Vector2:
 var angle: float=angle_difference(camera.yaw,bearing)
 if absf(angle)>PI*0.49:return Vector2(-10000,-10000)
 return Vector2(view_size.x*0.5+focal*tan(angle),horizon*elevation)

func sky_sprite(plan: Array[Dictionary],id: int,bearing: float,elevation: float,alpha: float=1.0) -> void:
 var part: Dictionary=scene.sprite(id);var scale: float=view_size.y/281.0
 var point: Vector2=sky_position(bearing,elevation);var rect: Rect2=Rect2(point-part.origin*scale,part.size*scale)
 var visible: Rect2=rect.intersection(bounds)
 if visible.has_area():plan.append({"kind":"texture","texture":part.texture,"rect":visible,"source":Rect2((visible.position-rect.position)/scale,visible.size/scale),"tint":Color(1,1,1,alpha)})

func rebuild_sky() -> void:
 var plan: Array[Dictionary]=[];var scale: float=view_size.y/281.0
 var light: WolfLightPalette=owner_view.lighting
 var star_alpha: float=1.0-smoothstep(0.02,0.15,light.current[8].get_luminance()) if light.current.size()==12 else 1.0
 if star_alpha>0.01:
  for n: int in range(0,state.sky_stars.size(),2):
   var point: Vector2=sky_position((float(state.sky_stars[n])+96.0)/256.0*TAU,float(state.sky_stars[n+1])/128.0)
   if bounds.has_point(point):plan.append({"kind":"rect","rect":Rect2(point,Vector2.ONE*scale),"color":Color(0.8,0.85,0.88,star_alpha)})
 var column: int=WolfLightPalette.column(int(state.hour))
 if column>=2:
  var n: int=(column-2)*2
  if n+1<state.sky_sun_points.size() and int(state.hour)!=19:sky_sprite(plan,374,(float(state.sky_sun_points[n])+96)/256.0*TAU,float(state.sky_sun_points[n+1])/128)
  var phase: int=posmod(int(state.moon_phase),8)
  if phase!=4 and n+1<state.sky_moon_points.size():sky_sprite(plan,[363,364,365,366,0,360,361,362][phase]+(7 if state.transformed else 0),(float(state.sky_moon_points[n])+96)/256.0*TAU,float(state.sky_moon_points[n+1])/128)
 for cloud: Dictionary in clouds:
  var bearing: float=float(cloud.bearing)-owner_view.vegetation_wind.elapsed*(0.0015+float(cloud.depth)*0.0004)
  sky_sprite(plan,int(cloud.style)+int(cloud.depth),bearing,float(cloud.height))
  if light.cloud_night>0.001:sky_sprite(plan,282+int(cloud.depth),bearing,float(cloud.height),light.cloud_night)
 # Cylindrical horizon uses fixed bearings; adjacent views share the same art.
 var step: float=24.0
 var x: float=0.0
 while x<view_size.x:
  var end: float=minf(view_size.x,x+step)
  var a: float=camera.yaw+atan((x-view_size.x*0.5)/focal)
  var b: float=camera.yaw+atan((end-view_size.x*0.5)/focal)
  var u: float=fposmod(120.0+a/TAU*960.0,960.0);var width: float=(b-a)/TAU*960.0
  var rect: Rect2=Rect2(x,horizon-32*scale,end-x,32*scale)
  var source: Rect2=Rect2(u,0,width,32)
  var weights: Vector3=light.foliage
  plan.append({"kind":"texture","texture":scene.panoramas[0],"rect":rect,"source":source,"foliage":scene.panoramas})
  x=end
 sky.lighting=light;sky.plan=plan;sky.queue_redraw()

func wall_quad(plan: Array[Dictionary],a: Vector2,b: Vector2,bottom: float,top: float,texture: Texture2D) -> void:
 for strip: int in 8:
  var from: Vector2=a.lerp(b,float(strip)/8);var to: Vector2=a.lerp(b,float(strip+1)/8)
  var da: float=(from-camera.position).dot(camera.forward());var db: float=(to-camera.position).dot(camera.forward())
  if da<=0.08 and db<=0.08:continue
  if da<0.08:from=from.lerp(to,(0.08-da)/(db-da))
  if db<0.08:to=to.lerp(from,(0.08-db)/((from-camera.position).dot(camera.forward())-db))
  var tl: Vector3=project(from,top);var tr: Vector3=project(to,top);var bl: Vector3=project(from,bottom);var br: Vector3=project(to,bottom)
  var points: PackedVector2Array=[Vector2(tl.x,tl.y),Vector2(tr.x,tr.y),Vector2(br.x,br.y),Vector2(bl.x,bl.y)]
  var repeats: float=a.distance_to(b)*2
  var u: float=float(strip)/8*repeats;var v: float=float(strip+1)/8*repeats
  var vertical: float=2.0*texture.get_width()/texture.get_height()
  var uv_top: float=(0.8-top)*vertical;var uv_bottom: float=(0.8-bottom)*vertical
  plan.append({"kind":"wall","texture":texture,"points":points,"uvs":PackedVector2Array([Vector2(u,uv_top),Vector2(v,uv_top),Vector2(v,uv_bottom),Vector2(u,uv_bottom)]),"tint":Color(0.72,0.72,0.65,room_blend)*(Color(0.18,0.18,0.18,1) if room_kind==2 and not state.flashlight else Color.WHITE)})

func rebuild_walls() -> void:
 var plan: Array[Dictionary]=[]
 if room_blend>0.001:
  var center: Vector2i=Vector2i(int(state.x),int(state.y))
  var texture: Texture2D=owner_view.texture_for(269) if room_kind==1 else scene.stone()
  var faces: Array[Dictionary]=[]
  var radius: int=3 if room_kind==2 else 0
  for y: int in range(center.y-radius,center.y+radius+1):
   for x: int in range(center.x-radius,center.x+radius+1):
    if room_kind==2 and not ((scene.tile(x,y)>>13)&7) in [2,4]:continue
    var cell: Vector2=Vector2(x,y)
    var inset: float=0.0 if room_kind==2 else 0.02
    var corners: Array[Vector2]=[cell+Vector2(inset,inset),cell+Vector2(1-inset,inset),cell+Vector2(1-inset,1-inset),cell+Vector2(inset,1-inset)]
    for side: int in 4:
     var neighbor: Vector2i=Vector2i(x,y)+[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)][side]
     if room_kind==2 and ((scene.tile(neighbor.x,neighbor.y)>>13)&7) in [2,4]:continue
     var a: Vector2=corners[side];var b: Vector2=corners[(side+1)%4]
     var opening: bool=room_kind==1 or (scene.tile(neighbor.x,neighbor.y)&7)!=6
     faces.append({"a":a,"b":b,"depth":((a+b)*0.5-camera.position).dot(camera.forward()),"opening":opening,"door":room_kind==2 or side==2})
  faces.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return float(a.depth)>float(b.depth))
  for face: Dictionary in faces:
   var a: Vector2=face.a;var b: Vector2=face.b
   if not face.opening:wall_quad(plan,a,b,0,0.8,texture);continue
   var left: Vector2=a.lerp(b,0.32);var right: Vector2=a.lerp(b,0.68)
   wall_quad(plan,a,left,0,0.8,texture);wall_quad(plan,right,b,0,0.8,texture)
   if not face.door:wall_quad(plan,left,right,0,0.25,texture)
   wall_quad(plan,left,right,0.60,0.8,texture)
 walls.plan=plan;walls.queue_redraw()
