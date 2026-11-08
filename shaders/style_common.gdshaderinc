// Shared by the styled look's spatial shaders (ported from design/style_test/common.gdshaderinc).
// Toon light with three smooth bands (checkpoint 7: no dither), plus the noise helpers. bayer4 stays for the shaders
// that still dither (ground, ribbon, outline).
uniform float band_soft = 0.05;

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
	float band = 0.55 * smoothstep(0.10 - band_soft, 0.10 + band_soft, nl)
		+ 0.45 * smoothstep(0.44 - band_soft, 0.44 + band_soft, nl);
	DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
}
