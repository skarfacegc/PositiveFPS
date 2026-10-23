uniform vec4 circles[24];
uniform int circle_count = 0;
uniform float dither_amt = 0.16;
uniform float smooth_mode = 0.0;
uniform float edge_w = 0.9;

const float M4[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (M4[y * 4 + x] + 0.5) / 16.0;
}
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
vec3 S(vec3 c) { return pow(c, vec3(2.2)); }

// signed field: >0 inside the joy wash, <0 outside. xz of world position.
float joy_field(vec2 p) {
	float m = -100.0;
	for (int i = 0; i < circle_count; i++) {
		m = max(m, circles[i].z - length(p - circles[i].xy));
	}
	m += (vnoise(p * 0.55) - 0.5) * 2.0 + (vnoise(p * 1.7) - 0.5) * 0.55;
	return m;
}
float joy_field_smooth(vec2 p) {
	float m = -100.0;
	for (int i = 0; i < circle_count; i++) {
		m = max(m, circles[i].z - length(p - circles[i].xy));
	}
	return m + (vnoise(p * 0.55) - 0.5) * 2.0;
}
float joy_dither(float m, vec2 frag) {
	if (smooth_mode > 0.5) return smoothstep(-0.9, 0.9, m);
	return step(bayer4(frag), smoothstep(-edge_w, edge_w, m));
}

// grey grime pushed into rippling ridges just outside the wash edge ("sand wave")
vec3 sand_ridges(vec3 c, float m, vec2 p, vec2 frag) {
	float w = vnoise(p * 0.5) * 0.9;
	float rp = sin(m * 3.3 + w);
	float fade = smoothstep(-4.6, -2.0, m) * (1.0 - smoothstep(-0.9, -0.4, m));
	float bay = (smooth_mode > 0.5) ? 0.5 : bayer4(frag);
	float dsm = smoothstep(0.05, 0.75, rp);
	float lsm = smoothstep(0.55, 0.95, -rp);
	float dark = ((smooth_mode > 0.5) ? dsm : step(bay, dsm)) * fade;
	float lite = ((smooth_mode > 0.5) ? lsm : step(bay, lsm)) * fade;
	c = mix(c, S(vec3(0.22, 0.22, 0.25)), dark * 0.7);
	c = mix(c, c + S(vec3(0.12)), lite * 0.6);
	return c;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band;
	if (smooth_mode > 0.5) {
		band = nl;
	} else {
		float t = nl + (bayer4(FRAGCOORD.xy) - 0.5) * dither_amt;
		band = t < 0.10 ? 0.0 : (t < 0.44 ? 0.55 : 1.0);
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
}
