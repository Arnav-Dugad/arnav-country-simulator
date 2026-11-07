// Flat map <-> globe morph, shared by every map shader.
// World units are Equal Earth (1000 units/rad, y down; see Geo.equal_earth).
// globe = 0: flat map (vertices untouched). globe = 1: orthographic globe of
// radius globe_radius at globe_center, looking at globe_rot (lon, lat in radians).

uniform float globe = 0.0;
uniform vec2 globe_rot = vec2(0.0, 0.0);
uniform float globe_radius = 1000.0;
uniform vec2 globe_center = vec2(0.0, 0.0);

const float EE_A1 = 1.340264;
const float EE_A2 = -0.081106;
const float EE_A3 = 0.000893;
const float EE_A4 = 0.003796;
const float EE_M = 0.8660254;

// Equal Earth inverse: world point -> (lon, lat) radians (Newton on theta).
vec2 ee_inverse(vec2 p) {
	float x = p.x / 1000.0;
	float y = -p.y / 1000.0;
	float th = y / EE_A1;
	for (int i = 0; i < 5; i++) {
		float t2 = th * th;
		float t6 = t2 * t2 * t2;
		float f = th * (EE_A1 + EE_A2 * t2 + t6 * (EE_A3 + EE_A4 * t2)) - y;
		float fp = EE_A1 + 3.0 * EE_A2 * t2 + t6 * (7.0 * EE_A3 + 9.0 * EE_A4 * t2);
		th -= f / fp;
	}
	float t2 = th * th;
	float t6 = t2 * t2 * t2;
	float lam = x * EE_M * (EE_A1 + 3.0 * EE_A2 * t2 + t6 * (7.0 * EE_A3 + 9.0 * EE_A4 * t2)) / max(cos(th), 1e-4);
	float phi = asin(clamp(sin(th) / EE_M, -1.0, 1.0));
	return vec2(lam, phi);
}

// Globe position (xy, world units) and depth z (> 0 = facing you).
vec3 globe_project(vec2 world) {
	vec2 ll = ee_inverse(world);
	float dl = ll.x - globe_rot.x;
	float cphi = cos(ll.y);
	float gx = cphi * sin(dl);
	float gy = cos(globe_rot.y) * sin(ll.y) - sin(globe_rot.y) * cphi * cos(dl);
	float gz = sin(globe_rot.y) * sin(ll.y) + cos(globe_rot.y) * cphi * cos(dl);
	return vec3(globe_center + vec2(gx, -gy) * globe_radius, gz);
}

// Moves a vertex toward its globe position; returns the far-side visibility (0..1).
float globe_vertex(inout vec2 v) {
	if (globe <= 0.0) {
		return 1.0;
	}
	vec3 g = globe_project(v);
	v = mix(v, g.xy, globe);
	// The far side fades as the globe forms, so it never shows through.
	return mix(1.0, smoothstep(-0.02, 0.06, g.z), smoothstep(0.0, 0.45, globe));
}
