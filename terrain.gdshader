shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// ─────────────────────────────
// Terrain controls
// ─────────────────────────────
uniform float water_level = 0.0;
uniform float max_height = 4000.0;
uniform float tree_line = 2200.0;

// Beach
uniform float beach_max_height = 15.0;
uniform float beach_min_flatness = 0.95;

// Forest
uniform sampler2D forest_mask: filter_linear_mipmap, repeat_disable;
uniform float terrain_size = 200000;

// ─────────────────────────────
// Colors (from your original shader)
// ─────────────────────────────
uniform vec4 color_deep_water     : source_color = vec4(0.0, 0.05, 0.15, 1.0);
uniform vec4 color_shallow_water  : source_color = vec4(0.0, 0.3, 0.5, 1.0);
uniform vec4 color_beach          : source_color = vec4(0.93, 0.86, 0.60, 1.0);
uniform vec4 color_lowland        : source_color = vec4(0.15, 0.45, 0.15, 1.0);
uniform vec4 color_mid_hill       : source_color = vec4(0.3, 0.5, 0.2, 1.0);
uniform vec4 color_high_mountain  : source_color = vec4(0.4, 0.35, 0.25, 1.0);
uniform vec4 color_rock           : source_color = vec4(0.45, 0.45, 0.45, 1.0);
uniform vec4 color_snow           : source_color = vec4(0.95, 0.95, 1.0, 1.0);
uniform vec4 color_forest         : source_color = vec4(0.02, 0.22, 0.02, 1.0);

// ─────────────────────────────
// Varyings
// ─────────────────────────────
varying float v_height;
varying float v_flatness;
varying float v_slope;
varying vec3 world_pos;

void vertex() {
    // World height
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_height = world_pos.y;

    // NORMAL is already world-space in Godot 4
    vec3 n = normalize(NORMAL);

    v_flatness = clamp(dot(n, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
    v_slope = 1.0 - v_flatness; // 0 = flat, 1 = vertical
}

void fragment() {
    float height = v_height;
    float flatness = v_flatness;

    float land_norm = clamp(
        (height - water_level) / (max_height - water_level),
        0.0,
        1.0
    );

    vec4 base_color;

    // ───────── Water ─────────
    if (height <= water_level) {
        float depth = clamp((height - (water_level - 1000.0)) / 1000.0, 0.0, 1.0);
        base_color = mix(color_deep_water, color_shallow_water, depth);
    }
    // ───────── Land ─────────
    else {
        // Beach
        if (height < beach_max_height && flatness > beach_min_flatness) {
            float wet = 1.0 - clamp((height - water_level) / beach_max_height, 0.0, 1.0);
            base_color = mix(color_beach, color_shallow_water, wet * 0.4);
        }
        // Lowlands → hills → mountains → rock → snow
        else if (land_norm < 0.20) {
            base_color = color_lowland;
        }
        else if (land_norm < 0.40) {
            float t = (land_norm - 0.20) / 0.20;
            base_color = mix(color_lowland, color_mid_hill, t);
        }
        else if (land_norm < 0.60) {
            float t = (land_norm - 0.40) / 0.20;
            base_color = mix(color_mid_hill, color_high_mountain, t);
        }
        else if (land_norm < 0.85) {
            float t = (land_norm - 0.60) / 0.25;
            base_color = mix(color_high_mountain, color_rock, t);
        }
        else {
            float t = (land_norm - 0.85) / 0.15;
            base_color = mix(color_rock, color_snow, t);
        }
    }

    // ───────── Forest overlay (exclude beach + smooth treeline fade) ─────────
	
	vec2 mask_uv = world_pos.xz / terrain_size;
	float forest_strength = texture(forest_mask, mask_uv).r;

	// Apply forest
	base_color = mix(base_color, color_forest, forest_strength);

    ALBEDO = base_color.rgb;
    ROUGHNESS = mix(0.9, 1.0, v_slope);
    METALLIC = 0.0;
}
