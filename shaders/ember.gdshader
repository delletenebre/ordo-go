shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, shadows_disabled;
uniform float elapsed=0.0;
varying float height;
void vertex(){
  height=VERTEX.y;
  VERTEX.x+=sin(elapsed*2.8+height*2.0)*height*height*.012;
}
void fragment(){
  float facet=.55+.45*abs(NORMAL.x);
  vec3 amber=mix(vec3(1.0,.27,.018),vec3(1.0,.68,.16),facet);
  vec3 heat=mix(amber,vec3(1.0,.92,.58),pow(1.0-clamp(height/1.5,0.0,1.0),2.0)*.7);
  ALBEDO=heat;EMISSION=heat*1.2;ALPHA=.90;
}
