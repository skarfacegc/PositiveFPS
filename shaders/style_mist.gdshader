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

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
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
	float n = vn(q) * 0.6 + vn(q * 2.3 + vec2(TIME * 0.02, 0.0)) * 0.4;
	// 0.3.1: wider banks (they start at a lower noise level), so the mist reads outside the zone at mid-night
	float bank = smoothstep(0.22, 0.62, n);
	float edge = 1.0 - smoothstep(plaza * 0.5, plaza * 0.5 + 25.0, max(abs(p.x), abs(p.y)));
	ALBEDO = mist_col.rgb;
	ALPHA = bank * (1.0 - clear_) * strength * mix(0.55, 1.0, edge);}
