shader_type spatial;
// Textured unit models in team colours: texels above a saturation threshold get
// the team's hue (keeping their brightness), greys stay grey. Also darkens
// downed heroes. Supports the glTF albedo / normal / ORM maps.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool has_orm = false;
uniform float roughness = 0.7;
uniform float metallic = 0.0;
uniform vec3 team_color : source_color = vec3(1.0, 0.1, 0.1);
uniform float hue_strength = 1.0;
uniform float sat_min = 0.2;
// Also paint light grey parts (not dark ones) in the team colour (0..1).
uniform float paint_greys = 0.0;
uniform float darken = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 a = albedo_color * texture(albedo_tex, UV);
	vec3 hsv = rgb2hsv(a.rgb);
	vec3 team = rgb2hsv(team_color);
	float w = smoothstep(sat_min, sat_min + 0.15, hsv.y) * hue_strength;
	vec3 recoloured = hsv2rgb(vec3(team.x, max(hsv.y, team.y * 0.85), hsv.z));
	vec3 col = mix(a.rgb, recoloured, w);
	float grey = (1.0 - smoothstep(sat_min * 0.5, sat_min, hsv.y)) * smoothstep(0.1, 0.3, hsv.z) * paint_greys;
	col = mix(col, hsv2rgb(vec3(team.x, team.y * 0.85, clamp(hsv.z * 1.25, 0.25, 0.9))), grey);
	ALBEDO = col * (1.0 - darken);
	if (has_orm) {
		vec3 orm = texture(orm_tex, UV).rgb;
		AO = orm.r;
		ROUGHNESS = orm.g;
		METALLIC = orm.b;
	} else {
		ROUGHNESS = roughness;
		METALLIC = metallic;
	}
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
