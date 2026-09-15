shader_type spatial;
render_mode unshaded;
varying vec2 eye_position;
void vertex(){eye_position=VERTEX.xy*2.0;}
void fragment(){
  float edge=smoothstep(.18,1.0,length(eye_position));
  vec3 ember=mix(vec3(1.0,.83,.30),vec3(.70,.21,.018),edge);
  ALBEDO=ember;
  EMISSION=ember*(1.35+(1.0-edge)*1.15);
}
