shader_type canvas_item;

uniform bool enabled = true;
uniform float pixelation_scale : hint_range(1.0, 16.0, 0.1) = 4.0;
uniform float dithering_strength : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform int color_reduction : hint_range(8, 256, 1) = 64;
uniform float contrast_boost : hint_range(0.5, 2.0, 0.1) = 1.2;

// Bayer dithering matrix
const mat4 bayer_matrix = mat4(
	vec4(0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0),
	vec4(12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0),
	vec4(3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0),
	vec4(15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0)
);

float get_bayer_dither(vec2 pos) {
	int x = int(mod(pos.x, 4.0));
	int y = int(mod(pos.y, 4.0));
	return bayer_matrix[y][x];
}

vec3 apply_pixelation(vec2 uv, float scale) {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel_size = vec2(scale) / tex_size;
	vec2 pixelated_uv = floor(uv / pixel_size) * pixel_size;
	return texture(TEXTURE, pixelated_uv).rgb;
}

vec3 apply_color_reduction(vec3 color, int levels) {
	float step_size = 1.0 / float(levels - 1);
	return floor(color / step_size) * step_size;
}

vec3 apply_dithering(vec3 color, vec2 screen_pos, float strength) {
	float dither = get_bayer_dither(screen_pos);
	dither = (dither - 0.5) * strength;
	return clamp(color + vec3(dither), 0.0, 1.0);
}

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	
	if (!enabled) {
		COLOR = base_color;
		return;
	}
	
	// Apply pixelation
	vec3 color = apply_pixelation(UV, pixelation_scale);
	
	// Apply contrast boost
	color = pow(color, vec3(1.0 / contrast_boost));
	
	// Apply dithering before color reduction for better results
	color = apply_dithering(color, FRAGCOORD.xy, dithering_strength);
	
	// Apply color reduction (posterization)
	color = apply_color_reduction(color, color_reduction);
	
	// Ensure we stay in valid color range
	color = clamp(color, 0.0, 1.0);
	
	COLOR = vec4(color, base_color.a);
}