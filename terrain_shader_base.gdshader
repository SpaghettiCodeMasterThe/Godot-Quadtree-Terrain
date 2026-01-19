shader_type spatial;
// render_mode depth_prepass_alpha, specular_schlick_ggx;

// Terrain world_pos.y ranges (meters)
const float DEEP_OCEAN = -4000.0;
const float SHALLOW_WATER = -50.0;
const float BEACH = 20.0;
const float PLAINS = 300.0;
const float HILLS = 800.0;
const float MOUNTAINS = 2000.0;
const float HIGH_MOUNTAINS = 4000.0;

// Central European color palette
uniform vec3 DEEP_OCEAN_COLOR : source_color = vec3(0.05, 0.1, 0.2);
uniform vec3 SHALLOW_WATER_COLOR : source_color = vec3(0.2, 0.4, 0.6);
uniform vec3 BEACH_COLOR : source_color = vec3(0.85, 0.8, 0.6);
uniform vec3 SNOW_COLOR : source_color = vec3(0.95, 0.95, 0.98);

uniform sampler2D ao_mask : filter_nearest;
uniform sampler2D city_mask : filter_nearest;
uniform float terrain_size = 200000;
uniform sampler2D plain_mask : filter_nearest;
uniform sampler2D hill_mask: filter_nearest;
uniform sampler2D mountain_mask: filter_nearest;
uniform sampler2D high_mountain_mask: filter_nearest;
varying vec3 world_pos;


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 color;
	vec2 full_terrain_uv = world_pos.xz / terrain_size;
    
    if (world_pos.y < SHALLOW_WATER) {
        // Water
        float water_depth = smoothstep(DEEP_OCEAN, SHALLOW_WATER, world_pos.y);
        color = mix(DEEP_OCEAN_COLOR, SHALLOW_WATER_COLOR, water_depth);
    }
    else if (world_pos.y < 0.0) {
        color = SHALLOW_WATER_COLOR;
    }
	else if (world_pos.y < BEACH) {
        color = BEACH_COLOR;
    }
    else if (world_pos.y < PLAINS) {
        color = texture(plain_mask, full_terrain_uv).rgb;
    }
    else if (world_pos.y < HILLS) {
        // Uplands (forested hills and plateaus)
        float upland_blend = smoothstep(PLAINS, HILLS - 400.0, world_pos.y);
        color = mix(texture(plain_mask, full_terrain_uv).rgb, texture(hill_mask, full_terrain_uv).rgb, upland_blend);
		// color = texture(hill_mask, full_terrain_uv).rgb;
    }
    else if (world_pos.y < MOUNTAINS) {
        // Subalpine zone (mountain meadows)
        float subalpine_blend = smoothstep(HILLS, MOUNTAINS - 500.0, world_pos.y);
        color = mix(texture(hill_mask, full_terrain_uv).rgb, texture(mountain_mask, full_terrain_uv).rgb, subalpine_blend);
		// color = texture(mountain_mask, full_terrain_uv).rgb;
    }
    else if (world_pos.y < HIGH_MOUNTAINS) { 
        // Alpine zone (rocky terrain)
		// Sharp tree line at 2000m, use same altitude with + 200 offset !!
        float alpine_blend = smoothstep(MOUNTAINS, MOUNTAINS + 200.0, world_pos.y);
        color = mix(texture(mountain_mask, full_terrain_uv).rgb, texture(high_mountain_mask, full_terrain_uv).rgb, alpine_blend);
		// color = texture(high_mountain_mask, full_terrain_uv).rgb; 
    }
    else {
        // Snow caps
        color = SNOW_COLOR;
    }
    
	float city_mask_value = texture(city_mask, full_terrain_uv).r;
	if (city_mask_value > 0.5) {
		color = vec3(1.0, 0.0, 0.0);
	}
	
	float ao = texture(ao_mask, full_terrain_uv).r;
	float blend = smoothstep(0.5, 0.0, ao) * 0.5;
	color = mix(color, vec3(0.1, 0.2, 0.35), blend);
	
    ALBEDO = color;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
}