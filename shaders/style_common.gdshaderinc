// Shared by the styled look's spatial shaders (ported from design/style_test/common.gdshaderinc).
// Toon light with three bands and a 4x4 Bayer dither, plus the noise helpers.
uniform float dither_amt = 0.16;

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
float ihash(ivec2 q) {
	uint h = uint(q.x) * 374761393u + uint(q.y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 65535u) / 65535.0;
}
float vnoise_i(vec2 p) {
	vec2 fl = floor(p);
	ivec2 i = ivec2(fl);
	vec2 f = p - fl;
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ihash(i), ihash(i + ivec2(1, 0)), f.x), mix(ihash(i + ivec2(0, 1)), ihash(i + ivec2(1, 1)), f.x), f.y);
}
vec3 S(vec3 c) { return pow(c, vec3(2.2)); }

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float t = nl + (bayer4(FRAGCOORD.xy) - 0.5) * dither_amt;
	float band = t < 0.10 ? 0.0 : (t < 0.44 ? 0.55 : 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
}
