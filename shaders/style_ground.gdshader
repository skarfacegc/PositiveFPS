shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://shaders/style_common.gdshaderinc"

// The styled ground (ported from design/style_test/ground.gdshader): irregular Voronoi cobbles, cool grey with grime
// where the ground is unpainted, warm and sandy where it is painted. The game feeds the paint weight of every 1 m
// tile in `weights` (R, 0 = unpainted, 1 = painted); the edge between the two worlds is a smooth blend.

uniform sampler2D weights : filter_linear, repeat_disable;
uniform float plaza = 70.0;
uniform float edge_w = 1.6;
// Checkpoint 7: no dithering anywhere on the ground. The painted/unpainted edge, the sand ridges and the dawn wash are
// smooth toon falloffs now. `gloom_amt` is how far the cold desaturated tint reaches over unpainted ground, `life_amt`
// scales the living-ground pieces (tufts, flowers, moss, puddles; litter, cracks and leaves outside), both 0..1.
uniform float gloom_amt = 0.55;
uniform float life_amt = 1.0;
// 0.3.1: at play zoom (19.5) a tuft the size of a hand is one pixel. `life_size` draws tufts, flowers and moss this many
// times bigger than the first version, and `life_bold` (0..1) pushes their colours toward bold so they read on the sand.
uniform float life_size = 1.0;
uniform float life_bold = 0.0;
// Checkpoint 5: first light. `dawn_front` is the radius (metres) of the circle the dawn front has reached; the ground
// outside it (round distance from the centre at least that) is lit. 1000 = no front yet (nothing changes).
uniform float dawn_front = 1000.0;

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

// >0 where the ground is painted, <0 where it is not (a rough signed field built from the paint weight).
float joy_field(vec2 p) {
	vec2 uv = p / plaza + 0.5;
	float w = 0.0;
	if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
		w = texture(weights, uv).r;
	}
	float m = (w - 0.5) * 9.0;
	m += (vnoise_i(p * 0.55) - 0.5) * 1.4 + (vnoise_i(p * 1.7) - 0.5) * 0.4;
	return m;
}

// grey grime pushed into soft rippling ridges just outside the painted edge (two smooth toon tones)
vec3 sand_ridges(vec3 c, float m, vec2 p) {
	float w = vnoise(p * 0.5) * 0.9;
	float rp = sin(m * 3.3 + w);
	float fade = smoothstep(-4.6, -2.0, m) * (1.0 - smoothstep(-0.9, -0.4, m));
	float dark = smoothstep(0.05, 0.75, rp) * fade;
	float lite = smoothstep(0.55, 0.95, -rp) * fade;
	c = mix(c, S(vec3(0.22, 0.22, 0.25)), dark * 0.3);
	c = mix(c, c + S(vec3(0.12)), lite * 0.4);
	return c;
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + vec2(37.17, 11.73)));
}

mat2 rot2(float a) {
	float cs = cos(a);
	float sn = sin(a);
	return mat2(vec2(cs, -sn), vec2(sn, cs));
}

// Grass tufts and wildflowers on the painted ground. `bloom` (0..1) follows how deep inside the zone the point is, so
// more of them show as the paint grows and fewer when it is lost.
vec3 punch(vec3 c) {
	float luma = dot(c, vec3(0.3, 0.59, 0.11));
	return clamp(mix(vec3(luma), c, 1.0 + life_bold * 0.9), 0.0, 1.0);
}

vec3 grass_and_flowers(vec3 c, vec2 p, float bloom) {
	float CELL = 0.7 * life_size;
	vec2 g = p / CELL;
	vec2 cell = floor(g);
	float h = hash21(cell + 2.3);
	vec2 cen = 0.5 + (hash22(cell + 5.5) - 0.5) * 0.4;
	vec2 d = (fract(g) - cen) * CELL;
	d.x += sin(TIME * 1.6 + h * 40.0) * 0.012 * clamp(0.1 - d.y, 0.0, 0.2) * 5.0;
	float on = step(h, 0.4 * bloom * life_amt);
	float r = length(d);
	float a = atan(d.y, d.x);
	float sz = life_size;
	float blade = (0.075 + 0.055 * pow(abs(sin(a * 2.5 + h * 6.0)), 3.0)) * sz;
	float t = on * (1.0 - smoothstep(blade - 0.02 * sz, blade, r));
	vec3 gdark = punch(S(vec3(0.26, 0.46, 0.18)));
	vec3 glite = punch(S(vec3(0.56, 0.76, 0.34)));
	c = mix(c, mix(gdark, glite, step(0.55, r / blade)), t);
	float k = hash21(cell + 1.9);
	vec3 fcol = k > 0.66 ? S(vec3(0.90, 0.40, 0.42)) : (k > 0.33 ? S(vec3(0.97, 0.78, 0.30)) : S(vec3(0.96, 0.92, 0.82)));
	fcol = punch(fcol);
	vec2 fat = d - vec2(0.035, -0.03) * sz * 1.5;
	float fs = sz * 1.5;
	float fl = on * step(0.5, hash21(cell + 9.1)) * (1.0 - smoothstep(0.022 * fs, 0.034 * fs, length(fat)));
	c = mix(c, fcol, fl);
	float fc = on * step(0.5, hash21(cell + 9.1)) * (1.0 - smoothstep(0.008 * fs, 0.014 * fs, length(fat)));
	c = mix(c, S(vec3(0.99, 0.88, 0.45)), fc);
	return c;
}

// Puddles that catch the warm light: a cool body with a warm glint that slides across, in two smooth toon tones.
vec3 puddles(vec3 c, vec2 p, float bloom) {
	float pn = vnoise(p * 0.45 + 17.0);
	float edge = smoothstep(0.71, 0.74, pn) * bloom * life_amt;
	float core = smoothstep(0.76, 0.79, pn) * bloom * life_amt;
	vec3 water = S(vec3(0.52, 0.64, 0.74));
	vec3 deep = S(vec3(0.40, 0.52, 0.64));
	float glint = smoothstep(0.62, 0.9, vnoise(p * 1.3 + vec2(TIME * 0.12, 0.0)));
	vec3 pc = mix(water, deep, core);
	pc = mix(pc, S(vec3(1.0, 0.84, 0.52)), glint * 0.55 * core);
	return mix(c, pc, edge * 0.92);
}

// Litter (scraps of paper, tins) and dead leaves on the unpainted ground; `lw` (0..1) is how far outside the zone it is.
vec3 litter_and_leaves(vec3 c, vec2 p, float lw) {
	vec2 g = p / 0.9;
	vec2 cell = floor(g);
	float h = hash21(cell + 6.6);
	vec2 d = (fract(g) - (0.5 + (hash22(cell + 1.3) - 0.5) * 0.4)) * 0.9;
	d = rot2(h * 6.28) * d;
	float on = step(0.9, h) * lw * life_amt;
	float rect = on * (1.0 - smoothstep(0.0, 0.012, max(abs(d.x) - 0.08, abs(d.y) - 0.045)));
	vec3 paper = hash21(cell + 2.2) > 0.5 ? S(vec3(0.80, 0.80, 0.76)) : S(vec3(0.38, 0.40, 0.44));
	c = mix(c, paper, rect);
	vec2 g2 = p / 0.6 + 3.3;
	vec2 cell2 = floor(g2);
	float h2 = hash21(cell2 + 4.1);
	vec2 d2 = (fract(g2) - (0.5 + (hash22(cell2 + 8.8) - 0.5) * 0.4)) * 0.6;
	d2 = rot2(h2 * 6.28) * d2;
	float leaf = step(0.86, h2) * lw * life_amt * (1.0 - smoothstep(0.0, 0.012, abs(d2.x) / 0.1 * 0.5 + abs(d2.y) / 0.05 * 0.5 - 0.5));
	vec3 lcol = hash21(cell2 + 7.7) > 0.5 ? S(vec3(0.52, 0.34, 0.17)) : S(vec3(0.64, 0.46, 0.20));
	return mix(c, lcol, leaf);
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
	float e1 = v1.x / BIG;
	float split = step(0.66, hash21(v1.yz + 3.7));
	vec3 v2 = voro(q * FINE + v1.yz * 7.3);
	float e2 = mix(9.0, v2.x / FINE, split);
	float e = min(e1, e2);
	float h = hash21(v1.yz + 0.5) * (1.0 - split) + hash21(v2.yz + 9.1) * split;
	float h2 = hash21(v1.yz + 17.3 + split * v2.yz);

	float gap = 1.0 - smoothstep(0.025, 0.065, e);
	float dome = 0.95 + 0.07 * smoothstep(0.04, 0.35, e);

	float m = joy_field(p);
	float joy = smoothstep(-edge_w, edge_w, m);
	// 0 at the edge of the painted ground, 1 well inside it: the living pieces grow with it.
	float bloom = smoothstep(0.2, 3.5, m);
	// 0 at the edge, 1 well outside it: the decay grows with it.
	float decay = 1.0 - smoothstep(-3.5, -0.4, m);

	// grey world: cool stones, very small variation, grime
	vec3 gc = mix(S(vec3(0.47, 0.52, 0.60)), S(vec3(0.52, 0.57, 0.65)), h);
	float soot = vnoise(p * 0.8 + 5.0);
	gc *= 1.0 - 0.14 * smoothstep(0.35, 0.8, soot);
	float mud = smoothstep(0.58, 0.78, vnoise(p * 0.33));
	gc = mix(gc, S(vec3(0.32, 0.27, 0.22)), mud * 0.35);
	gc = mix(gc, S(vec3(0.44, 0.31, 0.22)), step(0.95, h2) * 0.35);
	vec3 gmort = gc * 0.9 * mix(vec3(1.0), S(vec3(0.85, 0.8, 0.76)), smoothstep(0.4, 0.8, vnoise(p * 1.3)) * 0.6);
	gc = mix(gc * dome, gmort, gap);
	// cracked grey slabs: meandering dark cracks in patches, a few paler slabs
	float crack = 1.0 - smoothstep(0.012, 0.034, abs(vnoise(p * 0.8 + 31.0) - 0.5));
	crack *= smoothstep(0.30, 0.55, vnoise(p * 0.2 + 3.0)) * decay * life_amt;
	gc = mix(gc, gc * 0.42, crack * 0.85);
	gc = mix(gc, S(vec3(0.60, 0.62, 0.66)), step(0.82, h) * 0.25 * decay * life_amt);
	// the cold desaturated gloom tint
	float luma = dot(gc, vec3(0.3, 0.59, 0.11));
	gc = mix(gc, vec3(luma) * vec3(0.86, 0.94, 1.1), gloom_amt * decay);
	gc = litter_and_leaves(gc, p, decay);

	// warm world: sandy stones, moss and tiny flowers in some gaps
	vec3 wc = mix(S(vec3(0.80, 0.68, 0.52)), S(vec3(0.74, 0.60, 0.46)), h);
	wc = mix(wc, S(vec3(0.82, 0.58, 0.45)), step(0.85, h2) * 0.35);
	wc = mix(wc, S(vec3(0.90, 0.80, 0.62)), step(0.92, h) * 0.4);
	// 0.3.1: moss grows in patches over the cobbles (thickest at the cobble rims), not only in the thin gaps
	float moss_n = smoothstep(0.38, 0.70, vnoise(p * 0.55 / life_size * 1.6 + 9.0));
	vec3 mossc = punch(S(vec3(0.40, 0.58, 0.28)));
	float near_gap = mix(1.0 - smoothstep(0.03, 0.26 * life_size, e), 1.0, 0.3);
	wc = mix(wc, mossc, clamp(moss_n * near_gap * (0.35 + 0.55 * bloom * life_amt), 0.0, 0.9));
	// moss fills the cracks between the cobbles as the zone settles in
	vec3 wmort = mix(wc * 0.9, mossc, (0.22 + 0.6 * bloom * life_amt) * smoothstep(0.35, 0.7, vnoise(p * 1.3 + 3.0)));
	wc = mix(wc * dome, wmort, gap);

	// tiny flowers, only where the cell edges are close (i.e. in the gaps)
	// 0.3.1: flower clumps are round dabs of colour with a pale heart, big enough to read at play zoom
	float fgrid = 1.0 / (0.45 * life_size);
	vec2 fcell = floor(q * fgrid);
	vec2 fcen = (fcell + 0.25 + 0.5 * hash22(fcell + 4.4)) / fgrid;
	float fl = 0.0;
	float fheart = 0.0;
	vec3 fcol = vec3(0.0);
	float frad = 0.05 * life_size;
	if (hash21(fcell + 8.8) > 0.72) {
		float fd = length(q - fcen);
		fl = (1.0 - smoothstep(frad * 0.8, frad, fd)) * bloom * clamp(life_amt, 0.0, 1.0);
		fheart = 1.0 - smoothstep(frad * 0.3, frad * 0.4, fd);
		float k = hash21(fcell + 1.9);
		fcol = k > 0.66 ? S(vec3(0.86, 0.42, 0.42)) : (k > 0.33 ? S(vec3(0.93, 0.74, 0.30)) : S(vec3(0.95, 0.90, 0.78)));
		fcol = punch(fcol);
	}
	wc = mix(wc, fcol, fl);
	wc = mix(wc, S(vec3(0.99, 0.9, 0.5)), fheart * fl);
	wc = puddles(wc, p, bloom);
	wc = grass_and_flowers(wc, p, bloom);

	gc = sand_ridges(gc, m, p);
	float rim = smoothstep(0.0, 0.5, m) * (1.0 - smoothstep(0.5, 1.3, m));
	wc += S(vec3(0.20, 0.14, 0.05)) * rim * 0.5;
	vec3 col = mix(gc, wc, joy);
	if (dawn_front < 900.0) {
		// d > 0 behind the front (lit), < 0 ahead of it. Behind the front the cobbles take a warm gold wash (denser nearer
		// the front); a solid pale line sits on the front itself and a few glints twinkle just behind it.
		float d = length(p) - dawn_front;
		float wash = smoothstep(-0.4, 5.0, d) * 0.5 + smoothstep(-0.2, 0.6, d) * 0.3 + smoothstep(4.0, 14.0, d) * 0.15;
		col = mix(col, col * vec3(1.45, 1.22, 0.85) + S(vec3(0.16, 0.10, 0.02)), clamp(wash, 0.0, 1.0));
		float line = 1.0 - smoothstep(0.18, 0.62, abs(d - 0.2));
		col = mix(col, S(vec3(1.0, 0.93, 0.62)), line);
		vec2 cell = floor(p * 1.7);
		float tw = step(0.93, hash21(cell + 3.1)) * step(0.4, d) * (1.0 - smoothstep(4.0, 9.0, d));
		tw *= step(0.5, fract(TIME * 0.6 + hash21(cell)));
		col = mix(col, S(vec3(1.0, 0.95, 0.7)), tw);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
