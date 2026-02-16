shader_type sky;

// --- Configuration ---
uniform float sun_glow_scale : hint_range(0.01, 10.0) = 0.1;
uniform float star_density : hint_range(0.0, 0.01) = 0.003;

// --- Colors (vec3 for sky shader) ---
uniform vec3 day_sky_color : source_color = vec3(0.4, 0.7, 1.0);
uniform vec3 day_horizon_color : source_color = vec3(0.8, 0.9, 1.0);
uniform vec3 sunset_color : source_color = vec3(1.0, 0.4, 0.1);
uniform vec3 sunset_sky_color : source_color = vec3(0.6, 0.3, 0.5);
uniform vec3 night_sky_color : source_color = vec3(0.02, 0.02, 0.05);
uniform vec3 night_horizon_color : source_color = vec3(0.1, 0.1, 0.2);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.9, 0.7);

// Stable 3D hash function
float hash(vec3 p) {
    vec3 p3 = fract(p * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void sky() {
    // 1. Get View Direction and Sun Direction from Scene
    vec3 view_dir = EYEDIR;
    vec3 sun_dir = LIGHT0_DIRECTION;
    
    // 2. Calculate Time of Day based on Sun Elevation (Y axis)
    float sun_elevation = sun_dir.y;
    
    // Mix factors for smooth transitions
    float day_factor = smoothstep(-0.2, 0.4, sun_elevation);
    float night_factor = smoothstep(0.2, -0.4, sun_elevation);
    float sunset_factor = 1.0 - max(day_factor, night_factor);
    
    // 3. Calculate Sky Gradient (Zenith to Horizon)
    float horizon_blend = 1.0 - abs(view_dir.y);
    horizon_blend = pow(horizon_blend, 3.0);
    
    // 4. Determine base sky color (FIXED: Horizon doesn't take sunset color)
    // Sky top: day → sunset_sky → night
    vec3 sky_top = mix(day_sky_color, sunset_sky_color, sunset_factor);
    sky_top = mix(sky_top, night_sky_color, night_factor);
    
    // Horizon: day → night ONLY (no sunset color!)
    vec3 sky_horizon = mix(day_horizon_color, night_horizon_color, 1.0 - day_factor);
    
    vec3 final_sky = mix(sky_top, sky_horizon, horizon_blend);
    
    // 5. Sunset Glow - Only around the sun direction (NOT entire horizon)
    float sun_proximity = dot(view_dir, normalize(sun_dir));
    sun_proximity = smoothstep(0.0, 0.5, sun_proximity);
    
    // Add sunset color only near the sun, not the whole horizon
    float sunset_glow = sunset_factor * sun_proximity;
    final_sky = mix(final_sky, sunset_color, sunset_glow * 0.8);
    
    // 6. Calculate Sun Glow (Only when sun is above horizon)
    float sun_glow = 0.0;
    
    if (sun_elevation > -0.1 && sun_glow_scale > 0.01) {
        float sun_intensity = dot(view_dir, normalize(sun_dir));
        float exponent = 100.0 / sun_glow_scale;
        sun_glow = pow(max(0.0, sun_intensity), exponent);
        final_sky += sun_glow_color * sun_glow * 2.0;
    }
    
    // 7. Handle Night Stars
    if (night_factor > 0.5) {
        vec3 star_pos = floor(view_dir * 500.0);
        float stars = hash(star_pos);
        stars = step(1.0 - star_density, stars) * night_factor;
        
        float brightness = hash(star_pos + 1.0);
        stars *= mix(0.5, 1.0, brightness);
        
        final_sky += vec3(stars);
    }
    
    // Output color (vec3 for sky shader)
    COLOR = final_sky;
}