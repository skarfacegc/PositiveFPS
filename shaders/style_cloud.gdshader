shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// 0.3.1: the storm cloud of the gloom tide. Every puff is a soft blob that always faces the camera: its alpha is highest
// in the middle and falls off smoothly to nothing at its rim (a soft edge, no dither). Each puff rolls about slowly (its
// own phase comes from where it stands). A puff's size says how deep in the cloud it is: the biggest puffs are the dark,
// opaque core, the small ones the pale edge (the layout in style_push.gd sizes them from 0.6 to 1.1 of puff_ref).
// Scenery only.

uniform float churn = 0.55;
uniform float alpha_max = 0.9;
uniform vec4 edge_col : source_color = vec4(0.45, 0.42, 0.56, 1.0);
uniform vec4 core_col : source_color = vec4(0.15, 0.14, 0.24, 1.0);
uniform float puff_ref = 4.6;  // the size of a full puff (metres)

varying vec4 puff;
varying vec3 wpos;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float t = TIME * 0.7 + ph * 6.2831;
	float w = length(MODEL_MATRIX[0].xyz);
	float h = length(MODEL_MATRIX[1].xyz);
	float heart = clamp((w / puff_ref - 0.6) / 0.5, 0.0, 1.0);
	puff = vec4(mix(edge_col.rgb, core_col.rgb, heart), mix(0.55, 1.0, heart));
	wpos = o;
	// face the camera, keep the puff's own width and height
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(w, 0.0, 0.0, 0.0), vec4(0.0, h, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	VERTEX.x += sin(t) * churn * 0.12;
	VERTEX.y += cos(t * 1.3) * churn * 0.06;
	VERTEX.x *= 1.0 + 0.08 * sin(t * 1.7 + 1.0);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = clamp(length(q), 0.0, 1.0);
	float soft = 1.0 - smoothstep(0.1, 1.0, r);
	float roll = 0.5 + 0.5 * sin(wpos.x * 1.1 + TIME * 0.9) * sin(wpos.z * 1.5 - TIME * 0.7);
	ALBEDO = puff.rgb * (0.8 + 0.2 * roll);
	ALPHA = puff.a * alpha_max * soft;
}
