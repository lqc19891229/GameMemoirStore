shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_height = 400.0;
void fragment() {
	vec2 resolution = vec2(pixel_height * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, pixel_height);
	vec2 uv = (floor(SCREEN_UV * resolution) + 0.5) / resolution;
	vec4 scene = texture(screen_texture, uv);
	COLOR = vec4(floor(scene.rgb * 31.0 + 0.5) / 31.0, 1.0);
}
