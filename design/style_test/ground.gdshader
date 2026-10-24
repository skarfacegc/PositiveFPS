shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://common.gdshaderinc"

// Review 2: the regular brick grid is gone. The ground is now irregular cobbles (cellular / Voronoi),
// some cells split into smaller stones, with faint low-contrast gaps and no long straight lines.

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + vec2(37.17, 11.73)));
}

// x = distance to the nearest cell edge, yw = id of the cell
vec3 voro(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = 0.1 + 0.8 * hash22(n + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) { md = d; mr = r; mg = g; }
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = 0.1 + 0.8 * hash22(n + g);
			vec2 r = g + o - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec3(md, n + mg);
}

void fragment() {
	vec2 p = wpos.xz;
	// gentle domain warp so even the gaps never run straight
	vec2 q = p + vec2(vnoise(p * 0.7), vnoise(p * 0.7 + 11.0)) * 0.6;

	const float BIG = 0.78;
	const float FINE = 1.95;
	vec3 v1 = voro(q * BIG);
	float e1 = v1.x / BIG;                      // world-unit distance to the edge
	float split = step(0.66, hash21(v1.yz + 3.7));
	vec3 v2 = voro(q * FINE + v1.yz * 7.3);
	float e2 = mix(9.0, v2.x / FINE, split);
	float e = min(e1, e2);
	float h = hash21(v1.yz + 0.5) * (1.0 - split) + hash21(v2.yz + 9.1) * split;
	float h2 = hash21(v1.yz + 17.3 + split * v2.yz);

	float fade = (PROJECTION_MATRIX[3][3] > 0.5) ? 0.0 : smoothstep(10.0, 34.0, length(VERTEX));
	float gap = (1.0 - smoothstep(0.025, 0.065, e)) * (1.0 - fade);
	float dome = mix(0.95 + 0.07 * smoothstep(0.04, 0.35, e), 1.0, fade);

	// grey world: cool stones, very small variation, grime
	vec3 gc = mix(S(vec3(0.47, 0.52, 0.60)), S(vec3(0.52, 0.57, 0.65)), h);
	float soot = vnoise(p * 0.8 + 5.0);
	gc *= 1.0 - 0.14 * smoothstep(0.35, 0.8, soot);
	float mud = smoothstep(0.58, 0.78, vnoise(p * 0.33));
	gc = mix(gc, S(vec3(0.32, 0.27, 0.22)), mud * 0.35);
	gc = mix(gc, S(vec3(0.44, 0.31, 0.22)), step(0.95, h2) * 0.35);
	vec3 gmort = gc * 0.9 * mix(vec3(1.0), S(vec3(0.85, 0.8, 0.76)), smoothstep(0.4, 0.8, vnoise(p * 1.3)) * 0.6);
	gc = mix(gc * dome, gmort, gap);

	// warm world: sandy stones, moss and tiny flowers in some gaps
	vec3 wc = mix(S(vec3(0.80, 0.68, 0.52)), S(vec3(0.74, 0.60, 0.46)), h);
	wc = mix(wc, S(vec3(0.82, 0.58, 0.45)), step(0.85, h2) * 0.35);
	wc = mix(wc, S(vec3(0.90, 0.80, 0.62)), step(0.92, h) * 0.4);
	float moss_n = smoothstep(0.38, 0.70, vnoise(p * 0.55 + 9.0));
	vec3 mossc = S(vec3(0.46, 0.60, 0.34));
	float near_gap = 1.0 - smoothstep(0.03, 0.26, e);
	wc = mix(wc, mossc, moss_n * near_gap * 0.3 * (1.0 - fade));
	vec3 wmort = mix(wc * 0.9, mossc, 0.22 * smoothstep(0.35, 0.7, vnoise(p * 1.3 + 3.0)));
	wc = mix(wc * dome, wmort, gap);

	// tiny flowers, only where the cell edges are close (i.e. in the gaps)
	vec2 fcell = floor(q * 2.2);
	vec2 fcen = (fcell + 0.15 + 0.7 * hash22(fcell + 4.4)) / 2.2;
	float fl = 0.0;
	vec3 fcol = vec3(0.0);
	if (hash21(fcell + 8.8) > 0.8 && length(q - fcen) < 0.075) {
		vec3 c1 = voro(fcen * BIG);
		vec3 c2 = voro(fcen * FINE + c1.yz * 7.3);
		float sp = step(0.66, hash21(c1.yz + 3.7));
		float ec = min(c1.x / BIG, mix(9.0, c2.x / FINE, sp));
		fl = step(ec, 0.16) * (1.0 - fade);
		float k = hash21(fcell + 1.9);
		fcol = k > 0.66 ? S(vec3(0.86, 0.42, 0.42)) : (k > 0.33 ? S(vec3(0.93, 0.74, 0.30)) : S(vec3(0.95, 0.90, 0.78)));
	}
	wc = mix(wc, fcol, fl);

	float m = joy_field(p);
	float joy = joy_dither(m, FRAGCOORD.xy);
	gc = sand_ridges(gc, joy_field_smooth(p), p, FRAGCOORD.xy);
	float rim = smoothstep(0.0, 0.5, m) * (1.0 - smoothstep(0.5, 1.3, m));
	wc += S(vec3(0.20, 0.14, 0.05)) * rim * 0.5;
	ALBEDO = mix(gc, wc, joy);
	ROUGHNESS = 1.0;
}
