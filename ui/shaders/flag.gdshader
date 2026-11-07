shader_type canvas_item;
// Flag with rounded corners, a hairline inner edge (so white flags read on glass)
// and a faint top sheen. rect_size / radius are in logical pixels (set by Flag).

uniform vec2 rect_size = vec2(28.0, 21.0);
uniform float radius = 4.0;
uniform float edge_opacity = 0.18;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = (UV - 0.5) * rect_size;
	float d = sd_round_box(p, rect_size * 0.5, radius);
	float aa = max(fwidth(d), 0.0001);
	float mask = 1.0 - smoothstep(-aa, aa, d);
	float edge = 1.0 - smoothstep(0.0, aa * 1.5, abs(d + aa));
	c.rgb = mix(c.rgb, vec3(0.0), edge * edge_opacity);
	c.rgb += (1.0 - UV.y) * 0.05;
	COLOR = vec4(c.rgb, c.a * mask * COLOR.a);
}
