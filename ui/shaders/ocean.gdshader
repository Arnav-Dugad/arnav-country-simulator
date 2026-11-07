shader_type canvas_item;
render_mode unshaded;
// Deep-ocean backdrop: vertical gradient, a soft off-centre glow, vignette and
// fine grain (to prevent banding on 8-bit displays).

uniform vec4 top_color : source_color = vec4(0.047, 0.106, 0.188, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.012, 0.031, 0.071, 1.0);
uniform vec4 glow_color : source_color = vec4(0.10, 0.32, 0.62, 1.0);
uniform vec2 glow_center = vec2(0.5, 0.18);
uniform float glow_strength = 0.22;
uniform float vignette = 0.35;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float g = 1.0 - smoothstep(0.0, 0.75, length((uv - glow_center) * aspect));
	col += glow_color.rgb * g * g * glow_strength;
	float v = smoothstep(0.35, 1.05, length((uv - 0.5) * vec2(1.0, 0.9)));
	col *= 1.0 - v * vignette;
	col += (hash12(FRAGCOORD.xy) - 0.5) * 0.012;
	COLOR = vec4(col, 1.0);
}
