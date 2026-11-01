class_name WolfVegetationWind
extends RefCounted
## GPU motion for marked foliage only; no original state or RNG changes.
const WIND_SHADER: Shader=preload("res://rendering/vegetation_wind.gdshader")
var material: ShaderMaterial=ShaderMaterial.new()
var elapsed: float=0.0
var last_tick: int=0
var direction: float=0.65
var gust: float=0.0

func _init() -> void:
	material.shader=WIND_SHADER

func synchronize(state: Dictionary,pixel_scale: float) -> void:
	var now: int=Time.get_ticks_usec()
	var step: float=float(now-last_tick)/1000000.0 if last_tick>0 else 0.0
	last_tick=now
	if state.get("screen","") not in ["i","b"] or state.get("full_map",false):return
	elapsed+=step
	var raining: bool=float(state.get("rain_strength",0.0))>0.01
	var target: float=clampf(float(state.get("rain_wind",0.0)),-1,1) if raining else 0.65
	direction=lerpf(direction,target,1.0-exp(-step*2.0))
	gust=smoothstep(0.35,1.15,sin(elapsed*0.23)+0.3*sin(elapsed*0.071+0.8))
	material.set_shader_parameter("wind_time",elapsed)
	material.set_shader_parameter("wind_pixel_scale",pixel_scale)
	material.set_shader_parameter("wind_direction",direction)
	material.set_shader_parameter("wind_gust",gust)

static func phase_for(anchor: Vector2,kind: int) -> float:
	var value: int=(int(anchor.x)*73856093)^(int(anchor.y)*19349663)^(kind*83492791)
	return float(posmod(value,65521))/65521.0

static func quad(rect: Rect2,source: Rect2,texture: Texture2D,hint: Dictionary) -> Dictionary:
	var moving: Rect2=rect
	var moving_source: Rect2=source
	var fixed: Dictionary={}
	# Some grass sprites extend below their root. Draw that tail separately so
	# the actual attachment row is pinned, not just the outer texture edge.
	if float(hint.root)>rect.position.y and float(hint.root)<rect.end.y:
		var ratio: float=(float(hint.root)-rect.position.y)/rect.size.y
		moving.size.y=rect.size.y*ratio;moving_source.size.y=source.size.y*ratio
		fixed={"rect":Rect2(Vector2(rect.position.x,hint.root),Vector2(rect.size.x,rect.end.y-float(hint.root))),"source":Rect2(Vector2(source.position.x,source.position.y+moving_source.size.y),Vector2(source.size.x,source.size.y-moving_source.size.y))}
	var points: PackedVector2Array=[moving.position,Vector2(moving.end.x,moving.position.y),moving.end,Vector2(moving.position.x,moving.end.y)]
	var texels: Vector2=Vector2(texture.get_size())
	var uvs: PackedVector2Array=[moving_source.position/texels,Vector2(moving_source.end.x,moving_source.position.y)/texels,moving_source.end/texels,Vector2(moving_source.position.x,moving_source.end.y)/texels]
	var colors: PackedColorArray=[]
	var tag: float=3.0 if hint.grass else 1.0
	for index: int in 4:
		var height: float=clampf((float(hint.root)-points[index].y)/float(hint.height),0,1)
		# All pieces of a tree use the same root, height and phase. Low trunk
		# sections barely bend; the root and everything below it stay fixed.
		var pin: float=pow(height,2.2) if not hint.grass else height*height
		colors.append(Color(float(hint.amplitude)*0.5,pin,float(hint.phase),1))
		uvs[index].y=-tag-uvs[index].y
		if not hint.grass:uvs[index].x+=2.0*int(hint.get("size_class",0))
	return {"points":points,"uvs":uvs,"colors":colors,"fixed":fixed}
