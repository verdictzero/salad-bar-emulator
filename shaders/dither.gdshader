shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float color_depth : hint_range(2.0, 32.0) = 4.0;

const mat4 BAYER = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0)
) / 16.0;

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);

	ivec2 pos = ivec2(mod(FRAGCOORD.xy, 4.0));
	float threshold = BAYER[pos.x][pos.y] - 0.5;

	vec3 dithered = color.rgb + threshold / color_depth;
	vec3 quantized = floor(dithered * color_depth + 0.5) / color_depth;

	COLOR = vec4(quantized, color.a);
}
