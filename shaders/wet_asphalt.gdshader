shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 asphalt_tint : source_color = vec3(0.012, 0.022, 0.038);
uniform float wetness : hint_range(0.0, 1.0) = 0.82;
uniform float grain_scale : hint_range(2.0, 160.0) = 54.0;
uniform float puddle_scale : hint_range(0.5, 30.0) = 8.0;
uniform float puddle_strength : hint_range(0.0, 1.0) = 0.32;

varying vec3 world_position;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float x00 = mix(n000, n100, f.x);
	float x10 = mix(n010, n110, f.x);
	float x01 = mix(n001, n101, f.x);
	float x11 = mix(n011, n111, f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grain = noise3(world_position * grain_scale);
	float broad = noise3(world_position * puddle_scale);
	float puddles = smoothstep(0.42, 0.78, broad) * puddle_strength;
	float wet_factor = clamp(wetness + puddles * 0.2, 0.0, 1.0);
	float micro = (grain - 0.5) * 0.075;
	ALBEDO = max(asphalt_tint + vec3(micro), vec3(0.0));
	METALLIC = mix(0.18, 0.48, wet_factor);
	ROUGHNESS = mix(0.78, 0.12, wet_factor) + (grain - 0.5) * 0.06;
	SPECULAR = mix(0.35, 0.9, wet_factor);
	CLEARCOAT = wet_factor;
	CLEARCOAT_ROUGHNESS = mix(0.32, 0.06, wet_factor);
}
