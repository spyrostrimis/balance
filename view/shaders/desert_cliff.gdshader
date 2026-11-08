shader_type spatial;
// Layered sandstone for cliffs (world-space strata bands), with a darker
// weathered crust on top faces.

uniform vec3 band_a : source_color = vec3(0.70, 0.36, 0.20);
uniform vec3 band_b : source_color = vec3(0.82, 0.52, 0.30);
uniform vec3 band_c : source_color = vec3(0.55, 0.28, 0.17);
uniform vec3 crust : source_color = vec3(0.45, 0.26, 0.17);

varying vec3 wpos;
varying vec3 wnormal;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float wobble = noise(wpos.xz * 0.6) * 0.35;
	float band = fract(wpos.y * 1.3 + wobble);
	vec3 col = band < 0.33 ? band_a : (band < 0.66 ? band_b : band_c);
	col *= 0.9 + 0.2 * noise(wpos.xz * 3.0 + wpos.y);
	float top = smoothstep(0.55, 0.85, wnormal.y);
	col = mix(col, crust * (0.85 + 0.3 * noise(wpos.xz * 2.0)), top);
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
