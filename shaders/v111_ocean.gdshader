shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 albedo : source_color = vec3(0.07, 0.15, 0.2);
uniform vec3 albedo_fresnel : source_color = vec3(0.4, 0.7, 0.9);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.02;

uniform sampler2D first_normal_texture : repeat_enable, filter_linear_mipmap;
uniform sampler2D second_normal_texture : repeat_enable, filter_linear_mipmap;

uniform vec2 first_wave_direction = vec2(2.0, 0.0);
uniform vec2 second_wave_direction = vec2(0.0, 1.0);
uniform float time_scale : hint_range(0.0, 1.0, 0.005) = 0.025;

// UV scales for the three distance levels
uniform float uv_scale_close : hint_range(0.1, 100.0) = 10.0;
uniform float uv_scale_middle : hint_range(0.1, 10.0) = 1.0;
uniform float uv_scale_far : hint_range(0.1, 1.0) = 0.1;

// Distance thresholds (feel free to tweak)
uniform float middle_start = 2000.0;
uniform float far_start  = 10000.0;

float fresnel_func(float power, vec3 normal, vec3 view_dir) {
    return pow(1.0 - clamp(dot(normalize(normal), normalize(view_dir)), 0.0, 1.0), power);
}

void fragment() {
    // Distance from camera (Godot 4: VERTEX is in view space)
    float dist = length(VERTEX);
	vec2 scaled_uv = UV * uv_scale_close;
	
	float final_time_scale = time_scale;
	float bump_scale = 1.0;
	
	if (dist > middle_start) {
		scaled_uv = UV * uv_scale_middle;
		final_time_scale = time_scale * 0.5;
		bump_scale = 0.5;
	}
	if (dist > far_start) {
		scaled_uv = UV * uv_scale_far;
		final_time_scale = time_scale * 0.1;
		bump_scale = 0.1;
	}
	scaled_uv *= 0.001;

    // Wave animation
    vec2 first_offset  = TIME * first_wave_direction  * final_time_scale;
    vec2 second_offset = TIME * second_wave_direction * final_time_scale;

    // Sample normals
    vec3 n1 = texture(first_normal_texture,  scaled_uv + first_offset).rgb;
    vec3 n2 = texture(second_normal_texture, scaled_uv + second_offset).rgb;

    vec3 normal_blend = mix(n1, n2, 0.5);
    // Make sure normals are in proper range before assigning
	vec3 _flat = vec3(0.5,0.5,1.0); // Flat tangent normal (mid-gray in RG, white in B)
    NORMAL_MAP = mix(_flat, normal_blend, bump_scale);

    // Fresnel
    float fresnel_val = fresnel_func(5.0, NORMAL, -VIEW);
    vec3 surface_color = mix(albedo, albedo_fresnel, fresnel_val);

    ALBEDO = surface_color;
    METALLIC = metallic;
    ROUGHNESS = roughness;
}