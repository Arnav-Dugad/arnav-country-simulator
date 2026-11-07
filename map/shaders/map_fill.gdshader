shader_type canvas_item;
render_mode unshaded;
// All country fills in one mesh. UV.x encodes the country index; colours come
// from two 1-row palette textures and cross-fade with `blend` (map-mode change).

uniform sampler2D colors_from : filter_nearest;
uniform sampler2D colors_to : filter_nearest;
uniform float blend = 1.0;
uniform float tex_width = 256.0;
uniform float player_index = -1.0;
uniform float selected_index = -1.0;
uniform vec4 player_tint : source_color = vec4(0.95, 0.78, 0.42, 1.0);
uniform float world_half_height = 1310.0;

varying float v_idx;
varying float v_lat;

void vertex() {
	v_idx = floor(UV.x * tex_width);
	v_lat = -VERTEX.y / world_half_height;
}

void fragment() {
	vec2 uv = vec2((v_idx + 0.5) / tex_width, 0.5);
	vec4 c = mix(texture(colors_from, uv), texture(colors_to, uv), blend);
	c.rgb *= 1.0 + v_lat * 0.07; // faint north light
	if (abs(v_idx - player_index) < 0.5) {
		float pulse = 0.5 + 0.5 * sin(TIME * 1.6);
		c.rgb = mix(c.rgb, player_tint.rgb, 0.16 + 0.06 * pulse);
	}
	if (abs(v_idx - selected_index) < 0.5) {
		c.rgb = mix(c.rgb, vec3(1.0), 0.10);
	}
	COLOR = c;
}
