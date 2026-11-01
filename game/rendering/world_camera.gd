class_name WolfWorldCamera
extends RefCounted
## Render pose follows discrete game poses; it never changes the original map.
var position: Vector2
var yaw: float=0.0
var destination: Vector2
var destination_yaw: float=0.0
var origin: Vector2
var origin_yaw: float=0.0
var elapsed: float=1.0
var duration: float=0.28
var world_id: int=-1
var moving: bool=false

func synchronize(state: Dictionary,delta: float) -> bool:
 var target: Vector2=Vector2(float(state.x)+0.5,float(state.y)+0.5)
 var angle: float=float(state.facing)*TAU/8.0
 var identity: int=int(state.world_id)
 if world_id!=identity or destination.distance_to(target)>1.5:
  world_id=identity;position=target;destination=target;origin=target
  yaw=angle;destination_yaw=angle;origin_yaw=angle;elapsed=1.0;moving=false
  return true
 var changed: bool=destination!=target or absf(angle_difference(destination_yaw,angle))>0.001
 if changed:
  origin=position;origin_yaw=yaw;destination=target
  destination_yaw=yaw+angle_difference(yaw,angle)
  var turn: float=absf(destination_yaw-yaw)
  duration=clampf(turn*0.19,0.19,0.36) if origin.distance_to(destination)<0.01 else 0.30
  elapsed=0.0;moving=true
 if moving:
  elapsed=minf(duration,elapsed+minf(delta,0.05))
  var phase: float=elapsed/duration
  var blend: float=phase*phase*(3.0-2.0*phase)
  position=origin.lerp(destination,blend);yaw=lerpf(origin_yaw,destination_yaw,blend)
  moving=elapsed<duration
  if not moving:position=destination;yaw=destination_yaw
  return true
 return changed

func forward() -> Vector2:return Vector2(sin(yaw),-cos(yaw))
func right() -> Vector2:return Vector2(cos(yaw),sin(yaw))
