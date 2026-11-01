class_name WolfWorldScene
extends RefCounted
## Stable visual scenery. Seeds depend on map coordinates, never on the view.
var identity: int=-1
var width: int=0
var height: int=0
var cells: Array=[]
var groups: Array=[]
var source: WolfRemasteredWorld
var cache: Dictionary={}
var prefabs: Dictionary={}
var sprite_cache: Dictionary={}
var water_texture: ImageTexture
var map_texture: ImageTexture
var ground_texture: ImageTexture
var grass_texture: ImageTexture
var panoramas: Array[Texture2D]=[]
var material_for: Array[int]=[]

static func coordinate_noise(x: int,y: int,salt: int) -> float:
 var value: int=((x*73856093)^(y*19349663)^(salt*83492791))&0x7fffffff
 value=((value^(value>>13))*1274126177)&0x7fffffff
 return float(value^(value>>16))/2147483647.0

func configure(state: Dictionary,owner: WolfRemasteredWorld) -> bool:
 if identity==int(state.world_id):return false
 identity=int(state.world_id);source=owner;width=int(state.world_width);height=int(state.world_height)
 cells=state.world_cells;groups=state.scene_groups;cache.clear();prefabs.clear();sprite_cache.clear();panoramas.clear();material_for.clear()
 for terrain: int in 8:
  var best: int=0
  for type: int in 4:
   if int(state.grass_weights[terrain*4+type])>int(state.grass_weights[terrain*4+best]):best=type
  material_for.append(best)
 var ground: Image=Image.create(512,128,false,Image.FORMAT_RGBA8)
 var grass: Image=Image.create(96,96,false,Image.FORMAT_RGBA8)
 for type: int in 4:
  ground.blit_rect(source.grass_texture(147+type*15).get_image(),Rect2i(0,0,128,128),Vector2i(type*128,0))
  for variant: int in 3:
   var image: Image=source.texture_for(147+type*15+variant).get_image()
   grass.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(variant*32,type*24))
 ground.generate_mipmaps()
 ground_texture=ImageTexture.create_from_image(ground);grass_texture=ImageTexture.create_from_image(grass)
 var map_image: Image=Image.create(width,height,false,Image.FORMAT_RGBA8)
 var water: Image=Image.create(width*8,height*8,false,Image.FORMAT_L8)
 for y: int in height:
  for x: int in width:
   var value: int=tile(x,y);var terrain: int=value&7
   map_image.set_pixel(x,y,Color(float(material_for[terrain])/255.0,float((value>>13)&7)/255.0,float(terrain)/255.0,1))
   if terrain!=7:continue
   for sy: int in 8:
    for sx: int in 8:
     var point: Vector2=Vector2(x+(sx+0.5)/8.0,y+(sy+0.5)/8.0)
     var amount: float=water_at(point)
     water.set_pixel(x*8+sx,y*8+sy,Color(amount,amount,amount,1))
 map_texture=ImageTexture.create_from_image(map_image);water_texture=ImageTexture.create_from_image(water)
 for phase: int in 3:panoramas.append(build_panorama(phase))
 return true

func tile(x: int,y: int) -> int:
 if x<0 or y<0 or x>=width or y>=height:return 24582 # impassable mountain rim
 return int(cells[x+y*width])

func water_at(point: Vector2) -> float:
 var x: int=floori(point.x);var y: int=floori(point.y)
 if (tile(x,y)&7)!=7:return 0.0
 var p: Vector2=point-Vector2(x+0.5,y+0.5)
 var north: bool=(tile(x,y-1)&7)==7;var south: bool=(tile(x,y+1)&7)==7
 var west: bool=(tile(x-1,y)&7)==7;var east: bool=(tile(x+1,y)&7)==7
 if north and south and east and west:return 1.0
 var distance: float=p.length()-0.31
 if north and p.y<0:distance=minf(distance,absf(p.x)-0.26)
 if south and p.y>0:distance=minf(distance,absf(p.x)-0.26)
 if west and p.x<0:distance=minf(distance,absf(p.y)-0.26)
 if east and p.x>0:distance=minf(distance,absf(p.y)-0.26)
 return 1.0-smoothstep(-0.045,0.045,distance)

func prefab(id: int) -> Dictionary:
 if prefabs.has(id):return prefabs[id]
 var row: Array=groups[id].data
 var bounds: Rect2i=Rect2i();var first: bool=true
 for n: int in range(0,row.size(),3):
  var sprite: int=int(row[n+2])
  if sprite<0:continue
  var meta: Dictionary=source.sprites[str(sprite)]
  var rect: Rect2i=Rect2i(int(row[n])-int(meta.origin[0]),int(row[n+1])-int(meta.origin[1]),int(meta.rect[2]),int(meta.rect[3]))
  bounds=rect if first else bounds.merge(rect);first=false
 var image: Image=Image.create(maxi(1,bounds.size.x),maxi(1,bounds.size.y),false,Image.FORMAT_RGBA8)
 for n: int in range(0,row.size(),3):
  var sprite: int=int(row[n+2])
  if sprite<0:continue
  var meta: Dictionary=source.sprites[str(sprite)];var part: Image=source.texture_for(sprite).get_image()
  image.blend_rect(part,Rect2i(Vector2i.ZERO,part.get_size()),Vector2i(int(row[n])-int(meta.origin[0]),int(row[n+1])-int(meta.origin[1]))-bounds.position)
 prefabs[id]={"texture":ImageTexture.create_from_image(image),"origin":-Vector2(bounds.position),"size":Vector2(bounds.size)}
 return prefabs[id]

func sprite(id: int) -> Dictionary:
 if sprite_cache.has(id):return sprite_cache[id]
 var meta: Dictionary=source.sprites[str(id)]
 var texture: Texture2D=source.texture_for(id)
 if id in [262,264]:
  # Blend the rock's foot into the ground instead of exposing its raster edge.
  var image: Image=texture.get_image()
  for y: int in range(image.get_height()-7,image.get_height()):
   for x: int in image.get_width():
    var color: Color=image.get_pixel(x,y);color.a*=float(image.get_height()-1-y)/7.0;image.set_pixel(x,y,color)
  texture=ImageTexture.create_from_image(image)
 sprite_cache[id]={"texture":texture,"origin":Vector2(meta.origin[0],meta.origin[1]),"size":Vector2(meta.rect[2],meta.rect[3])}
 return sprite_cache[id]

func decoration(x: int,y: int) -> Array:
 var key: Vector2i=Vector2i(x,y)
 if cache.has(key):return cache[key]
 var output: Array=[];var value: int=tile(x,y);var terrain: int=value&7;var feature: int=(value>>13)&7
 if terrain==6:
  for n: int in 3:
   output.append({"position":Vector2(x+0.15+n*0.35,y+0.35+coordinate_noise(x,y,n)*0.3),"sprite":262 if n%2==0 else 264,"height":0.24+coordinate_noise(x,y,n+18)*0.08,"tree":false,"key":str(key)+":rock:"+str(n)})
 elif feature not in [2,4]:
  var count: int=3 if terrain in [1,2,4,5] else 0
  if feature in [0,1]:count=1
  for n: int in count:
   # Keep axial and diagonal routes between cell centres clear of trunks.
   var corners: Array[Vector2]=[Vector2(0.15,0.34),Vector2(0.66,0.15),Vector2(0.85,0.66),Vector2(0.34,0.85)]
   var offset: Vector2=corners[(n+int(coordinate_noise(x,y,8)*4))%4]
   offset+=Vector2(coordinate_noise(x,y,n+10)-0.5,coordinate_noise(x,y,n+20)-0.5)*0.06
   output.append({"position":Vector2(x,y)+offset,"prefab":0 if terrain in [1,2] else 1,"height":0.66+coordinate_noise(x,y,n+30)*0.28,"tree":true,"phase":coordinate_noise(x,y,n+40),"key":str(key)+":tree:"+str(n)})
  if feature in [0,1]:output.append({"position":Vector2(x+0.08,y+0.15),"house":true,"height":0.34,"tree":false,"key":str(key)+":cabin"})
 cache[key]=output
 return output

func house() -> Dictionary:
 return sprite(266)

func puzzle(stage: int) -> Dictionary:
 var key: int=100+stage
 if prefabs.has(key):return prefabs[key]
 var parts: Array[Dictionary]=[sprite(305),prefab(22+clampi(stage,0,2))]
 for index: int in mini(stage,3):parts.append(sprite(315+index))
 var bounds: Rect2i=Rect2i()
 for part: Dictionary in parts:
  var rect: Rect2i=Rect2i(-Vector2i(part.origin),Vector2i(part.size))
  bounds=rect if bounds.size==Vector2i.ZERO else bounds.merge(rect)
 var image: Image=Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8)
 for part: Dictionary in parts:image.blend_rect(part.texture.get_image(),Rect2i(Vector2i.ZERO,Vector2i(part.size)),-Vector2i(part.origin)-bounds.position)
 prefabs[key]={"texture":ImageTexture.create_from_image(image),"origin":Vector2(-bounds.position.x,bounds.size.y),"size":Vector2(bounds.size)}
 return prefabs[key]

func stone() -> Texture2D:
 if prefabs.has(-2):return prefabs[-2]
 var image: Image=Image.create(64,22,false,Image.FORMAT_RGBA8);image.fill(Color("514f47"))
 image.blend_rect(source.texture_for(262).get_image(),Rect2i(16,18,64,22),Vector2i.ZERO)
 var texture: ImageTexture=ImageTexture.create_from_image(image);prefabs[-2]=texture
 return texture

func grass_instances(center: Vector2i) -> Array:
 var output: Array=[]
 for y: int in range(maxi(0,center.y-7),mini(height,center.y+8)):
  for x: int in range(maxi(0,center.x-7),mini(width,center.x+8)):
   var value: int=tile(x,y);var terrain: int=value&7
   if terrain==6 or ((value>>13)&7) in [2,4]:continue
   var material: int=material_for[terrain]
   for n: int in 49:
    var point: Vector2=Vector2(x+(n%7+0.15+coordinate_noise(x,y,n+50)*0.7)/7.0,y+(n/7+0.15+coordinate_noise(x,y,n+110)*0.7)/7.0)
    if terrain==7 and water_at(point)>0.25:continue
    output.append({"position":point,"data":Color(0.13+coordinate_noise(x,y,n+170)*0.035,0.090+coordinate_noise(x,y,n+230)*0.022,coordinate_noise(x,y,n+290),float(material*3+int(coordinate_noise(x,y,n+350)*3))/12.0)})
 return output

func build_panorama(phase: int) -> Texture2D:
 var image: Image=Image.create(960,32,false,Image.FORMAT_RGBA8)
 var types: Array[int]=[11,14,12,11,13,12];var widths: Array[int]=[88,176,88,88,176,88]
 var x: int=0;var index: int=0
 while x<960:
  var row: Array=groups[types[mini(index,types.size()-1)]].data
  for n: int in range(0,row.size(),3):
   var id: int=int(row[n+2])+phase*9;var meta: Dictionary=source.sprites[str(id)]
   var part: Image=source.texture_for(id).get_image()
   image.blend_rect(part,Rect2i(Vector2i.ZERO,part.get_size()),Vector2i(x+int(row[n])-int(meta.origin[0]),32+int(row[n+1])-int(meta.origin[1])))
  x+=widths[mini(index,widths.size()-1)];index+=1
 return ImageTexture.create_from_image(image)
