shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, cull_disabled;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
uniform sampler2D dep : hint_depth_texture, filter_nearest;
uniform sampler2D nrm : hint_normal_roughness_texture, filter_nearest;
uniform float dthr = 0.3;
uniform float rel = 0.0;
uniform float nthr = 0.35;
uniform float line_dark = 0.14;
uniform float crease = 0.72;

varying flat mat4 inv_proj;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); inv_proj = INV_PROJECTION_MATRIX; }

float lin(vec2 uv) {
	float d = texture(dep, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	return min(-v.z, 500.0);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	vec3 col = texture(scr, uv).rgb;
	float d = lin(uv);
	float thr = dthr * (1.0 + rel * d);
	vec2 offs[4] = vec2[](vec2(1, 0), vec2(-1, 0), vec2(0, 1), vec2(0, -1));
	float best = 0.0;
	vec3 ncol = col;
	for (int ax = 0; ax < 2; ax++) {
		vec2 o = (ax == 0) ? vec2(px.x, 0.0) : vec2(0.0, px.y);
		float da = lin(uv + o);
		float db = lin(uv - o);
		float lap = da + db - 2.0 * d;
		if (-lap > best) {
			best = -lap;
			ncol = texture(scr, uv + (da < db ? o : -o)).rgb;
		}
	}
	float dr = lin(uv + vec2(px.x, 0.0));
	float dd = lin(uv + vec2(0.0, px.y));
	vec3 n0 = texture(nrm, uv).xyz;
	float cr = max(length(n0 - texture(nrm, uv + vec2(px.x, 0.0)).xyz), length(n0 - texture(nrm, uv + vec2(0.0, px.y)).xyz));
	if (best > thr) {
		col = ncol * line_dark;
	} else if (cr > nthr && abs(d - dr) < thr && abs(d - dd) < thr) {
		col *= crease;
	}
	ALBEDO = col;
}
