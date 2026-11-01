shader_type canvas_item;
render_mode unshaded;

uniform vec2 view_size = vec2(1.0);
uniform float pixel_scale = 1.0;
uniform float rain_time = 0.0;
uniform float rain_strength = 0.0;
uniform float rain_wind = 0.0;
uniform vec4 rain_tint : source_color = vec4(0.72, 0.80, 0.86, 1.0);

void vertex() {
	// Per-drop seeds and speed are baked once into vertex colors.
	VERTEX -= vec2(COLOR.g * view_size.x, COLOR.b * view_size.y);
	float padding = 20.0 * pixel_scale;
	float travel = view_size.y + padding * 2.0;
	float y = mod(COLOR.b * travel + rain_time * COLOR.r * 490.0 * pixel_scale, travel) - padding;
	float margin = padding + abs(rain_wind) * view_size.y;
	float x = mod(COLOR.g * (view_size.x + margin * 2.0) + rain_wind * y, view_size.x + margin * 2.0) - margin;
	VERTEX.x += x + rain_wind * VERTEX.y;
	VERTEX.y += y;
	COLOR.rgb = vec3(1.0);
}

void fragment() {
	float edge = smoothstep(0.0, 0.28, UV.x) * smoothstep(0.0, 0.28, 1.0 - UV.x);
	float tail = mix(0.12, 1.0, UV.y);
	COLOR = vec4(rain_tint.rgb, COLOR.a * rain_strength * edge * tail);
}
