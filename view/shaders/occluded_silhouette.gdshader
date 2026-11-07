shader_type spatial;
// Draws a flat team-coloured silhouette only where the unit is hidden behind
// something else (cliffs, rocks), so units never disappear from view.
// Used as next_pass on unit materials.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 silhouette_color : source_color = vec4(0.3, 0.6, 1.0, 0.55);
// World units: how far behind the visible surface a fragment must be to count as hidden.
uniform float margin = 0.08;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_depth = -view.z / view.w;
	float own_depth = -VERTEX.z;
	if (own_depth <= scene_depth + margin) {
		discard;
	}
	ALBEDO = silhouette_color.rgb;
	ALPHA = silhouette_color.a;
}
