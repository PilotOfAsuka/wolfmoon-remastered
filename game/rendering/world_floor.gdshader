shader_type canvas_item;
render_mode unshaded;
uniform vec2 view_size = vec2(1.0);
uniform vec2 camera_position = vec2(0.0);
uniform vec2 camera_forward = vec2(0.0,-1.0);
uniform vec2 camera_right = vec2(1.0,0.0);
uniform vec2 map_size = vec2(1.0);
uniform float horizon = 120.0;
uniform float focal = 180.0;
uniform float eye_height = 0.34;
uniform float clock_time = 0.0;
uniform vec4 sky_top = vec4(0.2,0.4,0.7,1.0);
uniform vec4 sky_mid = vec4(0.4,0.6,0.8,1.0);
uniform vec4 sky_bottom = vec4(0.6,0.7,0.7,1.0);
uniform vec4 land_far = vec4(0.2,0.25,0.15,1.0);
uniform vec4 water_far = vec4(0.04,0.1,0.16,1.0);
uniform vec4 water_near = vec4(0.0,0.02,0.04,1.0);
uniform float ambient = 1.0;
uniform float room_blend = 0.0;
uniform float room_kind = 0.0;
uniform float flashlight = 0.0;
uniform vec2 room_cell = vec2(0.0);
uniform sampler2D ground_atlas : filter_nearest_mipmap, repeat_enable;
uniform sampler2D map_cells : filter_nearest, repeat_disable;
uniform sampler2D water_mask : filter_linear, repeat_disable;
uniform sampler2D wood : filter_nearest, repeat_enable;
uniform sampler2D stone : filter_nearest, repeat_enable;

float indoors(vec2 world) {
 if (room_kind < 1.5) {
  vec2 local = world-room_cell;
  return step(0.02,local.x)*step(local.x,0.98)*step(0.02,local.y)*step(local.y,0.98);
 }
 float feature = floor(texture(map_cells,world/map_size).g*255.0+0.5);
 return (feature == 2.0 || feature == 4.0) ? 1.0 : 0.0;
}

void fragment() {
 vec2 pixel = UV*view_size;
 vec2 ray = camera_forward+camera_right*((pixel.x-view_size.x*0.5)/focal);
 vec3 color;
 if (pixel.y < horizon) {
  float split = horizon*0.7;
  color = pixel.y < split ? mix(sky_top.rgb,sky_mid.rgb,pixel.y/max(1.0,split)) : mix(sky_mid.rgb,sky_bottom.rgb,(pixel.y-split)/max(1.0,horizon-split));
  if (room_blend > 0.001) {
   float distance = focal*(0.78-eye_height)/max(1.0,horizon-pixel.y);
   float ceiling = indoors(camera_position+ray*distance)*room_blend;
   color = mix(color,vec3(0.055,0.06,0.05),ceiling);
  }
 } else {
  float distance = focal*eye_height/max(0.5,pixel.y-horizon);
  vec2 world = camera_position+ray*distance;
  vec4 tile = texture(map_cells,world/map_size);
  float material_id = floor(tile.r*255.0+0.5);
  vec2 detail = fract(world*2.0);
  color = textureGrad(ground_atlas,vec2((material_id+detail.x)*0.25,detail.y),dFdx(world*vec2(0.5,2.0)),dFdy(world*vec2(0.5,2.0))).rgb*ambient;
  color = mix(color,land_far.rgb,smoothstep(3.0,14.0,distance)*0.8);
  float water = texture(water_mask,world/map_size).r;
  vec3 lake = mix(water_near.rgb,water_far.rgb,clamp(distance/6.0,0.0,1.0));
  vec2 ripple = floor(world*36.0+vec2(clock_time*0.23,0.0));
  float sparkle = fract(sin(dot(ripple,vec2(12.9898,78.233)))*43758.5453);
  lake += step(0.995,sparkle)*vec3(0.08,0.12,0.17);
  color = mix(color,lake,water);
  if (room_blend > 0.001) {
   vec3 floor_color = texture(wood,world*4.0).rgb*0.62;
   if (room_kind > 1.5) floor_color = texture(stone,world*3.0).rgb*mix(0.06,0.50,flashlight);
   color = mix(color,floor_color,indoors(world)*room_blend);
  }
 }
 COLOR = vec4(color,COLOR.a);
}
