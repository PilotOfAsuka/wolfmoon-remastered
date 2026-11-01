class_name WolfSceneLayer
extends Node2D
var plan: Array[Dictionary]=[]
var lighting: WolfLightPalette
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
func _draw() -> void:
	for item: Dictionary in plan:
		match item.kind:
			"texture":
				if item.has("wind_quad"):
					var mesh: Dictionary=item.wind_quad
					draw_polygon(mesh.points,mesh.colors,mesh.uvs,item.texture)
					if not mesh.fixed.is_empty():draw_texture_rect_region(item.texture,mesh.fixed.rect,mesh.fixed.source,Color.WHITE,false,false)
				elif lighting!=null and item.has("foliage"):
					var weights: Vector3=lighting.foliage
					draw_texture_rect_region(item.foliage[0],item.rect,item.source,Color.WHITE,false,false)
					if weights.y>0.001:draw_texture_rect_region(item.foliage[1],item.rect,item.source,Color(1,1,1,weights.y/maxf(0.001,weights.x+weights.y)),false,false)
					if weights.z>0.001:draw_texture_rect_region(item.foliage[2],item.rect,item.source,Color(1,1,1,weights.z),false,false)
				else:draw_texture_rect_region(item.texture,item.rect,item.source,Color.WHITE,false,false)
			"rect":draw_rect(item.rect,item.color)
			"line":draw_line(item.a,item.b,lighting.color_for(item) if lighting!=null else item.color,item.width,false)
			"polygon":draw_colored_polygon(item.points,item.color)
			"polyline":draw_polyline(item.points,item.color,item.width,false)
