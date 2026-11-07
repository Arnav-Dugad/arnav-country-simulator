shader_type canvas_item;
// Rounded-rect / circle mask with a soft anti-aliased edge, for photos
// (portraits and scene banners). Works in local space, so cropped texture
// regions still get a correct shape. radius >= half the size = circle.

uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float radius = 16.0;
uniform float fade_bottom = 0.0;   // 0..1: darken toward the bottom (text legibility)

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 h = rect_size * 0.5;
	float r = min(radius, min(h.x, h.y));
	vec2 q = abs(local - h) - (h - vec2(r));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	float a = 1.0 - smoothstep(-1.0, 0.5, d);
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb *= 1.0 - fade_bottom * smoothstep(0.35, 1.0, local.y / rect_size.y) * 0.75;
	COLOR = vec4(c.rgb, c.a * a);
}
