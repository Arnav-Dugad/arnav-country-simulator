shader_type canvas_item;
// Tour spotlight: dims the screen except a rounded "hole" around the target,
// with a soft glowing rim. hole = (x, y, w, h) in local pixels.

uniform vec2 rect_size = vec2(390.0, 844.0);
uniform vec4 hole = vec4(0.0);
uniform float radius = 18.0;
uniform float dim = 0.62;
uniform vec4 rim_color : source_color = vec4(0.30, 0.64, 1.0, 1.0);

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 half_size = hole.zw * 0.5;
	float d = hole.z <= 0.0 ? 1e4 : sd_round_box(p - (hole.xy + half_size), half_size, min(radius, min(half_size.x, half_size.y)));
	float outside = smoothstep(-1.0, 1.0, d);
	float rim = exp(-abs(d) * 0.35) * (1.0 - step(1e3, d));
	vec3 col = mix(vec3(0.0, 0.01, 0.03), rim_color.rgb, rim * 0.9);
	float a = max(outside * dim, rim * 0.55);
	COLOR = vec4(col, a * COLOR.a);
}
