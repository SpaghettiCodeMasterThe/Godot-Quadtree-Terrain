shader_type spatial;

uniform vec3 albedo : source_color;
uniform vec3 albedo_fresnel : source_color;
uniform float metallic : hint_range(0.0, 1.0) = 0;
uniform float roughness : hint_range(0.0, 1.0) = 0.02;
uniform sampler2D first_normal_texture;
uniform sampler2D second_normal_texture;
uniform vec2 first_wave_direction = vec2(2.0, 0.0);
uniform vec2 second_wave_direction = vec2(0.0, 1.0);
uniform float time_scale : hint_range(0.0, 1.0, 0.005) = 0.025;

float fresnel(float amount, vec3 normal, vec3 view){
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void fragment() {
	vec2 first_time = (TIME * first_wave_direction) * time_scale;
	vec2 second_time = (TIME * second_wave_direction) * time_scale;

	vec3 normal_blend = mix(texture(first_normal_texture, UV + first_time).rgb, texture(second_normal_texture, UV + second_time).rgb, 0.5);

	float fresnel = fresnel(5.0, NORMAL, VIEW);
	vec3 surface_color = mix(albedo, albedo_fresnel, fresnel);

	ALBEDO = surface_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	NORMAL_MAP = normal_blend;
}