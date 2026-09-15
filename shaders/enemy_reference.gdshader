shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;
uniform sampler2D artwork : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 source_rect=vec4(0.0,0.0,1.0,1.0);
uniform float heat=0.0;
uniform float charred=0.0;
uniform float elapsed=0.0;
uniform float opacity=1.0;
void fragment() {
 vec4 art=texture(artwork,source_rect.xy+UV*source_rect.zw);
 float green=max(0.0,art.g-max(art.r,art.b));
 float alpha=1.0-smoothstep(.04,.32,green);
 vec3 color=art.rgb;
 color.g=min(color.g,max(color.r,color.b)+.04);
 float side=smoothstep(.24,.44,abs(UV.x-.5));
 float crown=1.0-smoothstep(.18,.43,UV.y);
 float patch=max(side,crown)*(.68+.32*sin(UV.x*25.0+UV.y*17.0));
 color=mix(color,color*vec3(.28,.20,.14),charred*patch*.68);
 float fiber=dot(color,vec3(.299,.587,.114));
 float ember=heat*patch*smoothstep(.015,.055,fiber)*(1.0-smoothstep(.08,.24,fiber));
 ALBEDO=color;
 EMISSION=vec3(1.0,.19,.012)*ember*(.24+.06*sin(elapsed*6.2+UV.y*21.0));
 ALPHA=art.a*alpha*opacity;
}
