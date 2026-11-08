shader_type spatial;
// Desert ground in world space (seamless across GridMap tiles): sand with dunes
// and wind ripples, dark rock plateaus and a copper Orichalcum field from a
// per-cell mask (R = rock, G = Orichalcum), slightly bumped by the ripples.

uniform sampler2D mask : filter_linear, repeat_disable;
uniform bool use_mask = true;
uniform vec2 map_size_world = vec2(64.0, 64.0);
uniform vec3 sand_light : source_color = vec3(0.95, 0.72, 0.43);
uniform vec3 sand_dark : source_color = vec3(0.80, 0.53, 0.29);
uniform vec3 rock_light : source_color = vec3(0.47, 0.38, 0.31);
uniform vec3 rock_dark : source_color = vec3(0.27, 0.22, 0.19);
uniform vec3 ore_color : source_color = vec3(0.86, 0.34, 0.14);

varying vec3 wpos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

float ripples(vec2 p) {
	return sin(dot(p, vec2(0.83, 0.55)) * 3.4 + fbm(p * 0.25) * 7.0) * 0.5 + 0.5;
}

float height(vec2 p, float rock) {
	return fbm(p * 0.035) * 0.6 + ripples(p) * 0.05 * (1.0 - rock) + fbm(p * 1.1) * 0.04 * rock;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float dunes = fbm(p * 0.035);
	vec3 sand = mix(sand_dark, sand_light, smoothstep(0.25, 0.8, dunes));
	sand *= 0.93 + 0.09 * ripples(p);
	sand *= 0.96 + 0.08 * noise(p * 7.0);
	vec3 col = sand;
	float rock = 0.0;
	float ore = 0.0;
	if (use_mask) {
		vec4 m = texture(mask, p / map_size_world);
		rock = smoothstep(0.35, 0.65, m.r + (fbm(p * 0.45) - 0.5) * 0.55);
		float cracks = 1.0 - smoothstep(0.0, 0.04, abs(noise(p * 1.4) - 0.5));
		vec3 rock_col = mix(rock_dark, rock_light, fbm(p * 0.8));
		rock_col *= 1.0 - 0.35 * cracks;
		col = mix(col, rock_col, rock);
		ore = smoothstep(0.2, 0.75, m.g + (noise(p * 0.9) - 0.5) * 0.45) * (1.0 - rock);
		col = mix(col, ore_color * (0.75 + 0.45 * noise(p * 3.0)), ore * 0.8);
		EMISSION = ore_color * ore * step(0.93, noise(p * 11.0)) * 1.5;
	}
	// Bump from the height field (world-space normal, then to view space).
	float e = 0.15;
	float h0 = height(p, rock);
	float hx = height(p + vec2(e, 0.0), rock);
	float hz = height(p + vec2(0.0, e), rock);
	vec3 n = normalize(vec3(h0 - hx, e, h0 - hz));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.85, rock);
}
