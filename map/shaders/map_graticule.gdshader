shader_type canvas_item;
render_mode unshaded;
// Latitude/longitude lines (Line2D): they follow the map into globe mode.

#include "res://map/shaders/globe.gdshaderinc"

varying float v_vis;

void vertex() {
	v_vis = globe_vertex(VERTEX);
}

void fragment() {
	COLOR.a *= v_vis;
}
