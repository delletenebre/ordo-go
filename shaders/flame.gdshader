shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform float elapsed = 0.0;
uniform float phase = 0.0;
uniform float heat = 1.0;
uniform vec4 tint : source_color = vec4(1.0,.35,.025,1.0);
void vertex(){
 float h=UV.y;
 float t=elapsed+phase;
 VERTEX.x+=h*h*(sin(t*4.1-h*5.5)*.095+sin(t*7.3-h*9.0)*.038);
 VERTEX.z+=h*h*sin(t*3.5-h*6.0+phase)*.07;
 VERTEX.y*=1.0+sin(t*5.4-h*3.0)*h*.13;
}
void fragment(){
 float t=elapsed+phase;
 float h=UV.y;
 float wave=sin(h*13.0-t*6.0)*.08+sin(h*24.0-t*9.5+phase)*.035;
 float x=abs((UV.x-.5)*2.0+wave*h);
 float rim=1.0-smoothstep(.52,.96,x);
 float inner=(1.0-smoothstep(.05,.80,x))*pow(1.0-h,.60);
 vec3 color=mix(tint.rgb,vec3(1.0,.85,.36),inner);
 color=mix(color,vec3(1.0,.96,.72),pow(inner,3.0));
 ALBEDO=color;EMISSION=color*heat*(1.1+inner*.5);
 ALPHA=rim*smoothstep(0.0,.10,h)*(1.0-smoothstep(.84,1.0,h))*.94;
}
