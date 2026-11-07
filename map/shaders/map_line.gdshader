shader_type canvas_item;
render_mode unshaded;
// Constant-screen-width anti-aliased lines. Each vertex carries its miter offset
// in UV and its side (0/1) in COLOR.r; the script sets half_width in world units
// (pixels / zoom) whenever the camera zooms.

#include "res://map/shaders/globe.gdshaderinc"

uniform float half_width = 0.5;
uniform float aa = 0.5;          // fraction of the half-width used for the soft edge
uniform vec4 line_color : source_color = vec4(0.78, 0.86, 1.0, 0.22);
uniform float pulse = 0.0;       // 0 = steady, >0 = breathing alpha
uniform float grow = 1.0;        // 0..1 animated reveal of the width

varying float v_side;
varying float v_vis;

void vertex() {
	v_vis = globe_vertex(VERTEX);
	VERTEX += UV * half_width * grow;
	v_side = COLOR.r * 2.0 - 1.0;
}

void fragment() {
	float d = abs(v_side);
	float a = 1.0 - smoothstep(1.0 - aa, 1.0, d);
	float breathe = 1.0 - pulse * (0.5 + 0.5 * sin(TIME * 2.2));
	COLOR = vec4(line_color.rgb, line_color.a * a * breathe * v_vis);
}
