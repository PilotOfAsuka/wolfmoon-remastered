shader_type canvas_item;
render_mode skip_vertex_transform, unshaded;
uniform vec2 view_size = vec2(1.0);
uniform vec2 camera_position = vec2(0.0);
uniform vec2 camera_forward = vec2(0.0,-1.0);
uniform vec2 camera_right = vec2(1.0,0.0);
uniform float horizon = 120.0;
uniform float focal = 180.0;
uniform float eye_height = 0.34;
uniform float band_near = 0.1;
uniform float band_far = 9.0;
uniform float wind_time = 0.0;
uniform float wind_direction = 0.65;
uniform float wind_gust = 0.0;
uniform float ambient = 1.0;
uniform vec2 room_cell = vec2(-100.0);
uniform float room_blend = 0.0;
void vertex() {
 vec2 world = MODEL_MATRIX[3].xy;
 vec2 delta = world-camera_position;
 float depth = dot(delta,camera_forward);
 if (depth < band_near || depth >= band_far || depth < 0.15) {
  VERTEX=vec2(-10000.0);COLOR=vec4(0.0);
 } else {
  vec2 uv = UV;
  float pin = pow(max(0.0,(0.708333-uv.y)/0.708333),2.0);
  float phase = INSTANCE_CUSTOM.b*TAU;
  float sway = sin(wind_time*(1.35+INSTANCE_CUSTOM.b*0.45)+phase)*0.52;
  sway += sin(wind_time*0.81+phase*1.61)*0.16;
  float bend = wind_direction*(0.18+wind_gust*0.48)+sway*(0.48+wind_gust*0.38);
  float scale = focal/depth;
  vec2 offset = vec2((uv.x-0.5)*INSTANCE_CUSTOM.r,(uv.y-0.708333)*INSTANCE_CUSTOM.g);
  offset.x += pin*bend*0.0038;
  VERTEX=vec2(view_size.x*0.5+dot(delta,camera_right)*scale,horizon+eye_height*scale)+offset*scale;
  int variant = int(floor(INSTANCE_CUSTOM.a*12.0+0.5));
  UV = (vec2(float(variant%3),float(variant/3))+uv)/vec2(3.0,4.0);
  float room = (floor(world.x)==room_cell.x && floor(world.y)==room_cell.y) ? room_blend : 0.0;
  COLOR=vec4(COLOR.rgb*ambient,COLOR.a*(1.0-smoothstep(5.0,7.3,depth))*(1.0-room));
 }
}
