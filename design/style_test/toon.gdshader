shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform int mode = 0;          // 0 always, 1 industrial/grey only, 2 whimsical/joy only
uniform float use_anchor = 0.0;
uniform vec3 anchor = vec3(0.0);
uniform float grime = 0.0;
uniform float emit = 0.0;
uniform int pat = 0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (mode != 0) {
		float joy;
		if (use_anchor > 0.5) {
			joy = step(0.0, joy_field(anchor.xz));
		} else {
			joy = joy_dither(joy_field(wpos.xz), FRAGCOORD.xy);
			if (smooth_mode > 0.5) joy = step(0.0, joy_field(wpos.xz));
		}
		if (mode == 1 && joy > 0.5) discard;
		if (mode == 2 && joy < 0.5) discard;
	}
	vec3 c = albedo.rgb;
	if (mode == 1 && grime > 0.0) {
		float st = vnoise(vec2((wpos.x + wpos.z) * 3.1, wpos.y * 0.22));
		float rust = smoothstep(0.62, 0.8, st) * smoothstep(4.5, 0.6, wpos.y);
		c = mix(c, S(vec3(0.42, 0.26, 0.17)), rust * 0.6 * grime);
		float mud = smoothstep(1.0, 0.0, wpos.y) * smoothstep(0.35, 0.7, vnoise(wpos.xz * 1.6 + wpos.y));
		c = mix(c, S(vec3(0.26, 0.20, 0.16)), mud * 0.55 * grime);
		float soot = vnoise(wpos.xz * 1.1 + wpos.y * 0.5 + 7.0);
		c *= 1.0 - 0.28 * grime * soot;
	}
	if (mode == 2) {
		c *= 0.94 + 0.12 * vnoise(wpos.xz * 2.0 + wpos.y * 3.0);
	}
	if (pat == 1) {
		float row = floor(wpos.y * 3.2);
		float u = fract(wpos.y * 3.2);
		float v = fract(wpos.x * 1.5 + row * 0.5);
		float ln = max(step(u, 0.14), step(v, 0.07) * step(0.14, u));
		c *= 1.0 - 0.24 * ln;
		c *= 0.94 + 0.12 * hash21(vec2(floor(wpos.x * 1.5 + row * 0.5), row));
	} else if (pat == 2) {
		float v = fract(wpos.x * 0.8);
		c *= 1.0 - 0.35 * max(step(v, 0.06), step(fract(wpos.z * 0.8), 0.04));
	}
	ALBEDO = c;
	EMISSION = c * emit;
	ROUGHNESS = 1.0;
}
