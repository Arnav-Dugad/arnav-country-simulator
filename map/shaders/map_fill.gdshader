shader_type canvas_item;
render_mode unshaded;
// All country fills in one mesh. UV.x encodes the country index; colours come
// from two 1-row palette textures and cross-fade with `blend` (map-mode change).

#include "res://map/shaders/globe.gdshaderinc"

uniform sampler2D colors_from : filter_nearest;
uniform sampler2D colors_to : filter_nearest;
uniform float blend = 1.0;
uniform float tex_width = 256.0;
uniform float player_index = -1.0;
uniform float selected_index = -1.0;
uniform vec4 player_tint : source_color = vec4(0.95, 0.78, 0.42, 1.0);
uniform float world_half_height = 1310.0;
// Election night: everything but the player dims and greys; the player breathes.
uniform float spotlight = 0.0;
uniform vec4 spot_color : source_color = vec4(0.95, 0.78, 0.42, 1.0);
// War: 2-row float texture per country. Row 0: rgb = occupier colour, a = share
// held. Row 1: xy = unit direction toward the occupier, z = threshold along it;
// land beyond the threshold (the side facing the occupier) is striped.
uniform sampler2D war_marks : filter_nearest;
uniform float war_on = 0.0;

varying float v_idx;
varying float v_lat;
varying float v_vis;
varying float v_shade;
varying vec2 v_world;

void vertex() {
	v_idx = floor(UV.x * tex_width);
	v_world = VERTEX;
	v_lat = -VERTEX.y / world_half_height;
	v_vis = 1.0;
	v_shade = 1.0;
	if (globe > 0.0) {
		vec3 g = globe_project(VERTEX);
		VERTEX = mix(VERTEX, g.xy, globe);
		v_vis = mix(1.0, smoothstep(-0.02, 0.06, g.z), smoothstep(0.0, 0.45, globe));
		// Soft sphere shading: brighter toward you, darker at the edge.
		v_shade = mix(1.0, 0.5 + 0.6 * clamp(g.z, 0.0, 1.0), globe);
	}
}

void fragment() {
	vec2 uv = vec2((v_idx + 0.5) / tex_width, 0.5);
	vec4 c = mix(texture(colors_from, uv), texture(colors_to, uv), blend);
	c.rgb *= 1.0 + v_lat * 0.07; // faint north light
	if (abs(v_idx - player_index) < 0.5) {
		float pulse = 0.5 + 0.5 * sin(TIME * 1.6);
		c.rgb = mix(c.rgb, player_tint.rgb, 0.16 + 0.06 * pulse);
	}
	if (spotlight > 0.0) {
		if (abs(v_idx - player_index) < 0.5) {
			float b = 0.5 + 0.5 * sin(TIME * 2.4);
			c.rgb = mix(c.rgb, spot_color.rgb, spotlight * (0.35 + 0.25 * b));
		} else {
			float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
			c.rgb = mix(c.rgb, vec3(g) * 0.55, spotlight * 0.8);
		}
	}
	if (war_on > 0.5) {
		vec4 wm = texture(war_marks, vec2(uv.x, 0.25));
		if (wm.a > 0.001) {
			vec4 ax = texture(war_marks, vec2(uv.x, 0.75));
			float proj = dot(v_world, ax.xy);
			float held = smoothstep(ax.z - 3.0, ax.z + 3.0, proj);
			float s = fract((v_world.x + v_world.y) * 0.09);
			float band = step(0.5, s);
			c.rgb = mix(c.rgb, wm.rgb, band * 0.55 * held);
			// A bright front line where the held land ends.
			c.rgb = mix(c.rgb, wm.rgb, (1.0 - smoothstep(0.0, 2.5, abs(proj - ax.z))) * 0.8);
		}
	}
	if (abs(v_idx - selected_index) < 0.5) {
		c.rgb = mix(c.rgb, vec3(1.0), 0.10);
	}
	c.rgb *= v_shade;
	c.a *= v_vis;
	COLOR = c;
}
