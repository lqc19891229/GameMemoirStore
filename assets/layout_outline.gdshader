shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 line_color : source_color = vec4(0.38, 0.85, 1.0, 1.0);
void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	ALBEDO = line_color.rgb;
	ALPHA = min(edge.x, edge.y) < 0.018 ? line_color.a : 0.0;
}
