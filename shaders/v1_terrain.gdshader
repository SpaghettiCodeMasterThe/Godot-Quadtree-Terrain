shader_type spatial;
render_mode cull_back, depth_draw_opaque, world_vertex_coords;

// ─────────────────────────────
// Terrain controls
// ─────────────────────────────
uniform float deep_water_max = -1000.0;
uniform float shallow_water_max = 0.0;
uniform float beach_max = 15.0;
uniform float low_land_max = 500;
uniform float mid_hill_max = 1000;
uniform float mountain_max = 2000;
uniform float rock_max = 3000;

uniform float beach_max_slope = 0.05;

uniform float terrain_size = 200000.0;
uniform sampler2D forest_mask : repeat_disable, filter_nearest;
uniform sampler2D cities_mask : repeat_disable, filter_nearest;

// ─────────────────────────────
// Textures
// ─────────────────────────────
uniform sampler2D sand_albedo : repeat_enable, filter_linear_mipmap;
uniform sampler2D sand_normal : repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_albedo : repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_normal : repeat_enable, filter_linear_mipmap;
uniform sampler2D rock_albedo : repeat_enable, filter_linear_mipmap;
uniform sampler2D rock_normal : repeat_enable, filter_linear_mipmap;
uniform sampler2D snow_albedo : repeat_enable, filter_linear_mipmap;
uniform sampler2D snow_normal : repeat_enable, filter_linear_mipmap;

uniform float close_uv_scale = 10.0;
uniform float far_uv_scale = 1.0;
uniform float close_texture_distance = 1000.0;
uniform float far_texture_distance = 2000.0;

// ─────────────────────────────
// Sliders
// ─────────────────────────────
uniform float texture_blend : hint_range(0.0, 1.0) = 0.8;
uniform float normal_map_boost = 2.0;

// ─────────────────────────────
// Colors
// ─────────────────────────────
uniform vec4 color_beach : source_color = vec4(0.93, 0.86, 0.60, 1.0);
uniform vec4 color_lowland : source_color = vec4(0.15, 0.45, 0.15, 1.0);
uniform vec4 color_mid_hill : source_color = vec4(0.3, 0.5, 0.2, 1.0);
uniform vec4 color_high_mountain : source_color = vec4(0.4, 0.35, 0.25, 1.0);
uniform vec4 color_rock : source_color = vec4(0.45, 0.45, 0.45, 1.0);
uniform vec4 color_snow : source_color = vec4(0.95, 0.95, 1.0, 1.0);
uniform vec4 color_forest : source_color = vec4(0.02, 0.22, 0.02, 1.0);
uniform vec4 color_deep_water : source_color = vec4(0.0, 0.05, 0.15, 1.0);
uniform vec4 color_shallow_water : source_color = vec4(0.0, 0.3, 0.5, 1.0);

// ─────────────────────────────
// Varyings
// ─────────────────────────────
varying vec3 world_pos;
varying float slope;
varying float cam_distance;
varying vec4 world_normal;

void vertex() {
	world_pos = VERTEX;
	
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0));
	// slope = 1 - dot(normal, up)
	float up_dot = clamp(dot(normalize(world_normal.xyz), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	slope = 1.0 - up_dot;
	
	cam_distance = length((VIEW_MATRIX * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec4 color = color_snow;
	vec4 normal = world_normal;
	float uv_scale = close_uv_scale;
	float last_color_weight = 0.0;
	
	if (world_pos.y < deep_water_max) {
		color = color_deep_water;
	}
	else if (world_pos.y < shallow_water_max) {
		color = color_shallow_water;
	}
	// Beach
	else if (world_pos.y < beach_max) {
		if (slope < beach_max_slope){
			color = color_beach;
			if (cam_distance < close_texture_distance) {
				color = mix(texture(sand_albedo, UV * close_uv_scale), color, texture_blend);
				normal = texture(sand_normal, UV * close_uv_scale);
			}
		}
		else {
			color = color_rock;
			if (cam_distance < close_texture_distance) {
				color = mix(texture(rock_albedo, UV * close_uv_scale), color, texture_blend);
				normal = texture(rock_normal, UV * close_uv_scale);
			}
		}
	}
	// Plain
	else if (world_pos.y < low_land_max) {
		color = color_lowland;
		
		if (cam_distance < close_texture_distance) {
			color = mix(texture(grass_albedo, UV * close_uv_scale), color, texture_blend);
			normal = texture(grass_normal, UV * close_uv_scale);
		}
	}
	// Hill
	else if (world_pos.y < mid_hill_max) {
		last_color_weight = smoothstep(low_land_max,mid_hill_max,world_pos.y);
		color = mix(color_lowland, color_mid_hill, last_color_weight);
		
		if (cam_distance < close_texture_distance) {
			color = mix(texture(grass_albedo, UV * close_uv_scale), color, texture_blend);
			normal = texture(grass_normal, UV * close_uv_scale);
		}
	}
	// Moutain
	else if (world_pos.y < mountain_max) {
		last_color_weight = smoothstep(mid_hill_max,mountain_max,world_pos.y);
		color = mix(color_mid_hill, color_high_mountain, last_color_weight);
		
		if (cam_distance < close_texture_distance) {
			color = mix(texture(grass_albedo, UV * close_uv_scale), color, texture_blend);
			normal = texture(grass_normal, UV * close_uv_scale);
		}
	}
	// Rock
	else if (world_pos.y < rock_max) {
		last_color_weight = smoothstep(mountain_max,rock_max,world_pos.y);
		color = mix(color_high_mountain, color_rock, last_color_weight);
		
		if (cam_distance < close_texture_distance) {
			color = mix(texture(rock_albedo, UV * close_uv_scale), color, texture_blend);
			normal = texture(rock_normal, UV * close_uv_scale);
		}
	}
	
	vec2 full_terrain_uv = world_pos.xz / terrain_size;
	float forest_strenght = texture(forest_mask, full_terrain_uv).r;
	color = mix(color, color_forest, forest_strenght);
	float cities_strenght = texture(cities_mask, full_terrain_uv).r;
	color = mix(color, vec4(0.25, 0.25, 0.25, 1.0), cities_strenght);
	
	ALBEDO = color.rgb;
	if (cam_distance < close_texture_distance && world_pos.y > 0.0) {
    	NORMAL_MAP = normal.xyz;
		NORMAL_MAP_DEPTH = normal_map_boost;
	}
}