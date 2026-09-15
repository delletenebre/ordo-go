shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool rim=false;
uniform vec2 mouth_size=vec2(.12,.04);
uniform float curve=0.0;
uniform float thickness=.008;
uniform vec4 mouth_color:source_color=vec4(.5,.2,.04,1.0);
varying vec3 lip_normal;
varying float inner_edge;
void vertex(){
 if(rim){
  float a=UV.x*6.2831853,b=UV.y*6.2831853;
  float x=cos(a),y=sin(a);
  vec3 centre=vec3(x*mouth_size.x,y*mouth_size.y+curve*(1.0-x*x),.008);
  vec3 tangent=vec3(-y*mouth_size.x,x*mouth_size.y+2.0*curve*x*y,0.0);
  vec3 outward=normalize(vec3(tangent.y,-tangent.x,0.0));
  NORMAL=outward*cos(b)+vec3(0.0,0.0,sin(b));
  lip_normal=NORMAL;inner_edge=1.0-smoothstep(-.8,.25,cos(b));
  VERTEX=centre+NORMAL*thickness;
 }else{
  float x=VERTEX.x;
  VERTEX=vec3(x*mouth_size.x,VERTEX.y*mouth_size.y+curve*(1.0-x*x),VERTEX.z*thickness*.6);
 }
}
void fragment(){
 if(rim){
  float lit=.28+.72*max(0.0,dot(normalize(lip_normal),normalize(vec3(-.5,.75,1.0))));
  vec3 bronze=vec3(.44,.16,.026)*lit;
  vec3 warm=vec3(1.0,.61,.13);
  ALBEDO=mix(bronze,warm,inner_edge*.82);
  EMISSION=warm*inner_edge*.70;
 }else{ALBEDO=vec3(.006,.004,.003);}
}
