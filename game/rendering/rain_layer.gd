class_name WolfRainLayer
extends Node2D
## Static drop quads animate on the GPU, without rebuilding arrays each frame.
const RAIN_SHADER: Shader=preload("res://rendering/rain.gdshader")
var rain_material: ShaderMaterial=ShaderMaterial.new()
var view_size: Vector2=Vector2.ZERO
var pixel_scale: float=1.0
var strength: float=0.0
var target_strength: float=0.0
var wind: float=0.0
var target_wind: float=0.0
var night: bool=false
var animating: bool=true
var elapsed: float=0.0
var last_tick: int=0

func _ready() -> void:
	rain_material.shader=RAIN_SHADER;material=rain_material

func configure(state: Dictionary,dimensions: Vector2,scale_factor: float) -> void:
	if view_size!=dimensions or not is_equal_approx(pixel_scale,scale_factor):
		view_size=dimensions;pixel_scale=scale_factor
		rain_material.set_shader_parameter("view_size",view_size)
		rain_material.set_shader_parameter("pixel_scale",pixel_scale)
		queue_redraw()
	var exposed: bool=state.get("weather_exposed",false)
	animating=state.get("screen","") in ["i","b"]
	target_strength=float(state.get("rain_strength",0.0)) if exposed else 0.0
	target_wind=float(state.get("rain_wind",0.0))*0.22*lerpf(0.9,1.15,float(state.get("visual_wind_gust",0.4)))
	var hour: int=int(state.get("hour",12));night=hour>=19 or hour<=4
	rain_material.set_shader_parameter("rain_tint",Color(0.43,0.55,0.69) if night else Color(0.72,0.80,0.86))
	if not exposed:
		strength=0.0;rain_material.set_shader_parameter("rain_strength",0.0)
	visible=exposed and not state.get("full_map",false) and (strength>0.001 or target_strength>0.001)

func _process(_delta: float) -> void:
	var now: int=Time.get_ticks_usec()
	var step: float=float(now-last_tick)/1000000.0 if last_tick>0 else 0.0
	last_tick=now
	if not visible or not animating:return
	elapsed+=step
	strength=move_toward(strength,target_strength,step*0.8)
	wind=lerpf(wind,target_wind,1.0-exp(-step*2.0))
	rain_material.set_shader_parameter("rain_time",elapsed)
	rain_material.set_shader_parameter("rain_strength",strength)
	rain_material.set_shader_parameter("rain_wind",wind)
	if strength<=0.001 and target_strength<=0.001:hide()

static func seed_value(index: int,salt: int) -> float:
	var value: int=((index*73856093)^(salt*19349663))&0x7fffffff
	value=((value^(value>>13))*1274126177)&0x7fffffff
	return float(value^(value>>16))/2147483647.0

func _draw() -> void:
	if view_size.x<=0 or view_size.y<=0:return
	var per_layer: int=clampi(int(view_size.x/18.0),20,120)
	var uvs: PackedVector2Array=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	for layer: int in 3:
		var original_width: float=maxf(0.65,pixel_scale*(0.18+layer*0.1))
		var width: float=maxf(1.5,original_width)
		var alpha: float=(0.13+layer*0.085)*original_width/width*1.3
		for drop: int in per_layer:
			var index: int=drop+layer*131
			var fraction: float=seed_value(index,7)
			var length: float=(2.5+layer*2.0+fraction*3.5)*pixel_scale
			var seed: Color=Color((125.0+layer*100.0+fraction*65.0)/490.0,roundf(seed_value(index,31)*255.0)/255.0,roundf(seed_value(index,17)*255.0)/255.0,alpha)
			# Spread the baked quads over the view so canvas culling sees them;
			# the shader removes this origin before applying animated positions.
			var origin: Vector2=Vector2(seed.g*view_size.x,seed.b*view_size.y)
			var points: PackedVector2Array=[origin+Vector2(-width/2,-length),origin+Vector2(width/2,-length),origin+Vector2(width/2,0),origin+Vector2(-width/2,0)]
			draw_polygon(points,PackedColorArray([seed,seed,seed,seed]),uvs)
