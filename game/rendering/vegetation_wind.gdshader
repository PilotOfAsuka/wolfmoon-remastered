shader_type canvas_item;
render_mode unshaded;

uniform float wind_time = 0.0;
uniform float wind_pixel_scale = 1.0;
uniform float wind_direction = 0.65;
uniform float wind_gust = 0.0;
uniform vec4 environment_tint : source_color = vec4(1.0);

void vertex() {
	// Only vegetation quads have tagged UVs. Other scene commands are untouched.
	if (UV.y < -0.5) {
		bool grass = UV.y < -2.5;
		UV.y = -UV.y - (grass ? 3.0 : 1.0);
		float phase = COLOR.b * TAU;
		float size_class = floor(UV.x * 0.5);
		if (!grass) { UV.x -= size_class * 2.0; }
		float tree_frequency = size_class > 0.5 ? (1.05 - size_class * 0.12) : (0.95 - COLOR.r * 0.45);
		float frequency = grass ? (1.35 + COLOR.b * 0.45) : tree_frequency;
		float sway = sin(wind_time * frequency + phase) * 0.52;
		sway += sin(wind_time * frequency * 0.53 + phase * 1.61) * 0.16;
		float bend = wind_direction * (0.18 + wind_gust * 0.48);
		bend += sway * (0.48 + wind_gust * 0.38);
		VERTEX.x += COLOR.r * 2.0 * wind_pixel_scale * COLOR.g * bend;
		COLOR.rgb = environment_tint.rgb;
	} else {
		COLOR.rgb *= environment_tint.rgb;
	}
}
