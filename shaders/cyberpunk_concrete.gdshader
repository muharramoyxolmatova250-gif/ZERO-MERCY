shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform vec4 wall_tint : source_color = vec4(0.035, 0.045, 0.065, 1.0);
uniform float roughness_base : hint_range(0.2, 1.0) = 0.78;
uniform float grain_scale : hint_range(1.0, 100.0) = 28.0;
uniform float panel_scale : hint_range(0.1, 20.0) = 4.0;

varying vec3 world_position;
varying vec3 world_normal;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash31(i);
	float b = hash31(i + vec3(1.0, 0.0, 0.0));
	float c = hash31(i + vec3(0.0, 1.0, 0.0));
	float d = hash31(i + vec3(1.0, 1.0, 0.0));
	float e = hash31(i + vec3(0.0, 0.0, 1.0));
	float f1 = hash31(i + vec3(1.0, 0.0, 1.0));
	float g = hash31(i + vec3(0.0, 1.0, 1.0));
	float h = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a,b,f.x),mix(c,d,f.x),f.y),mix(mix(e,f1,f.x),mix(g,h,f.x),f.y),f.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	float grain = noise3(world_position * grain_scale);
	float broad = noise3(world_position * panel_scale);
	float fleck = (grain - 0.5) * 0.11;
	float panel_variation = (broad - 0.5) * 0.09;
	ALBEDO = max(wall_tint.rgb * (1.0 + fleck + panel_variation), vec3(0.0));
	METALLIC = 0.12;
	ROUGHNESS = clamp(roughness_base + (grain - 0.5) * 0.08, 0.2, 1.0);
}
