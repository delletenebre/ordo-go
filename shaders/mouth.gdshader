shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform bool rim=false;
uniform vec2 mouth_size=vec2(.12,.04);
uniform float curve=0.0;
uniform float thickness=.008;
uniform vec4 mouth_color:source_color=vec4(.5,.2,.04,1.0);
void vertex(){
  if(rim){
    float a=UV.x*6.2831853,b=UV.y*6.2831853;
    float x=cos(a),y=sin(a);
    vec3 centre=vec3(x*mouth_size.x,y*mouth_size.y+curve*(1.0-x*x),.008);
    vec3 tangent=vec3(-y*mouth_size.x,x*mouth_size.y+2.0*curve*x*y,0.0);
    vec3 outward=normalize(vec3(tangent.y,-tangent.x,0.0));
    NORMAL=outward*cos(b)+vec3(0.0,0.0,sin(b));
    VERTEX=centre+NORMAL*thickness;
  }else{
    float x=VERTEX.x;
    VERTEX=vec3(x*mouth_size.x,VERTEX.y*mouth_size.y+curve*(1.0-x*x),VERTEX.z*thickness*.6);
  }
}
void fragment(){
  ALBEDO=mouth_color.rgb;
  ROUGHNESS=rim?.3:.85;SPECULAR=rim?.48:.12;
  EMISSION=rim?mouth_color.rgb*.48:vec3(0.0);
}
