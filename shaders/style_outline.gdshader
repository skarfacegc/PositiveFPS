shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, blend_mix, depth_draw_never;
// Checkpoint 5: a ribbon drawn flat on the ground in the pixel style (the shape preview's outline, the finish wave). The
// mesh is a strip: UV.x runs -1..1 across it, UV.y is the distance along it in metres. Ink edges, a two-tone body that
// marches along the ribbon (`speed` dashes a second), real gaps between the dashes when `gaps` is set, and (checkpoint 7,
// no dithering) a soft alpha `density` so a faded ribbon thins out smoothly.
uniform vec3 line_color : source_color = vec3(0.61, 0.94, 0.86);
uniform vec3 light_color : source_color = vec3(0.91, 1.0, 0.97);
uniform vec3 ink_color : source_color = vec3(0.23, 0.16, 0.125);
uniform float dash = 1.6;
uniform float speed = 0.8;
uniform float density = 1.0;
uniform float gaps = 0.0;
void fragment() {
	float seg = fract(UV.y / dash - TIME * speed);
	if (gaps > 0.5 && seg >= 0.5) discard;
	if (abs(UV.x) > 0.62) {
		ALBEDO = ink_color;
	} else {
		ALBEDO = seg < 0.5 ? line_color : light_color;
	}
	ALPHA = clamp(density, 0.0, 1.0);
}
