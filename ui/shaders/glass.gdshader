shader_type canvas_item;
render_mode unshaded;
// Frosted glass ("glassmorphism") surface.
// - Blurs what is behind it: samples the screen texture at a mip level, then
//   averages a 12-tap golden-angle disc on top. The disc keeps the blur smooth
//   even on GPUs/backends where screen-texture mips are coarse or missing.
// - Boosts saturation slightly (iOS "vibrancy"), applies a tint, adds fine
//   noise to kill banding, and draws a 1 px inner border (~15 % white) that is
//   brighter at the top edge, like light catching the rim.
// Used by ui/components/glass_panel.gd; rect_size/corner_radius set from script.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float corner_radius = 28.0;
uniform float blur_lod = 3.0;
uniform float blur_radius_px = 14.0;
uniform vec4 tint : source_color = vec4(0.075, 0.09, 0.13, 0.56);
uniform float saturation = 1.3;
uniform float border_opacity = 0.15;
uniform float noise_strength = 0.03;
uniform float highlight = 0.06;

float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float in_alpha = COLOR.a; // carries the node's modulate (used for fades)
	vec2 p = (UV - 0.5) * rect_size;
	float r = min(corner_radius, 0.5 * min(rect_size.x, rect_size.y));
	float d = sd_round_box(p, rect_size * 0.5, r);
	float aa = max(fwidth(d), 0.0001);
	float mask = 1.0 - smoothstep(-aa, aa, d);

	// Blur
	vec3 acc = vec3(0.0);
	vec2 spread = SCREEN_PIXEL_SIZE * blur_radius_px;
	for (int i = 0; i < 12; i++) {
		float fi = float(i);
		float ang = fi * 2.39996323;
		float rad = sqrt((fi + 0.5) / 12.0);
		vec2 o = vec2(cos(ang), sin(ang)) * rad * spread;
		acc += textureLod(screen_tex, SCREEN_UV + o, blur_lod).rgb;
	}
	vec3 col = acc / 12.0;

	// Vibrancy + tint
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = mix(col, tint.rgb, tint.a);

	// Soft top-down sheen
	col += highlight * (1.0 - UV.y) * (1.0 - UV.y);

	// Grain
	col += (hash12(FRAGCOORD.xy) - 0.5) * noise_strength;

	// Inner rim
	float rim = 1.0 - smoothstep(0.0, aa * 1.6, abs(d + aa * 1.2) - aa * 0.4);
	float rim_light = border_opacity * mix(1.6, 0.6, UV.y);
	col = mix(col, vec3(1.0), clamp(rim * rim_light, 0.0, 1.0));

	COLOR = vec4(col, mask * in_alpha);
}
