shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// Checkpoint 7: the gloom's low drifting mist. A big flat plane just above the ground; its alpha is soft drifting noise
// that is strongest over ground outside the painted zone and clears away inside it (the paint weight texture is the same
// one the ground uses). No dithering: the alpha just falls off smoothly. Scenery only.

uniform sampler2D weights : filter_linear, repeat_disable;
uniform float plaza = 100.0;
uniform vec4 mist_col : source_color = vec4(0.62, 0.68, 0.78, 1.0);
uniform float strength = 0.42;
uniform vec2 drift = vec2(0.45, 0.18);
uniform float scale = 0.07;
uniform float seed = 0.0;

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

// 0.3.1 seams: the first version hashed each lattice corner with a sine hash (fract of a sine times 43758): that multiplies
// any rounding difference in the sine by 43758, so the same corner got different values from its four neighbouring cells
// and the noise broke into hard square blocks. An integer hash gives every corner one exact value, so the noise is
// continuous (smooth in value and slope) everywhere.
float ih(ivec2 q) {
	uint h = uint(q.x) * 374761393u + uint(q.y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 65535u) / 65535.0;
}
float vn(vec2 p) {
	vec2 fl = floor(p);
	ivec2 i = ivec2(fl);
	vec2 f = p - fl;
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(ih(i), ih(i + ivec2(1, 0)), f.x), mix(ih(i + ivec2(0, 1)), ih(i + ivec2(1, 1)), f.x), f.y);
}

float painted(vec2 p) {
	vec2 uv = p / plaza + 0.5;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return 0.0;
	}
	return texture(weights, uv).r;
}

void fragment() {
	vec2 p = wpos.xz;
	// a wider soft look at the paint, so the mist backs away from the zone's edge rather than at the tile
	float w = painted(p) * 0.4;
	w += painted(p + vec2(2.0, 0.0)) * 0.15 + painted(p - vec2(2.0, 0.0)) * 0.15;
	w += painted(p + vec2(0.0, 2.0)) * 0.15 + painted(p - vec2(0.0, 2.0)) * 0.15;
	float clear_ = smoothstep(0.25, 0.8, w);
	vec2 q = p * scale + drift * TIME * 0.05 + seed;
	// three smooth octaves, the finer ones drifting the other way, so the banks roll rather than slide
	float n = vn(q) * 0.55 + vn(q * 2.1 + vec2(TIME * 0.02, 7.3)) * 0.3 + vn(q * 4.3 - vec2(TIME * 0.03, 3.1)) * 0.15;
	// 0.3.1: wide, soft banks (a long smoothstep ramp, so there is no visible edge anywhere)
	float bank = smoothstep(0.3, 0.8, n);
	float edge = 1.0 - smoothstep(plaza * 0.5, plaza * 0.5 + 25.0, max(abs(p.x), abs(p.y)));
	ALBEDO = mist_col.rgb;
	ALPHA = bank * (1.0 - clear_) * strength * mix(0.55, 1.0, edge);}
