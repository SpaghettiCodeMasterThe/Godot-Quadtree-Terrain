shader_type spatial;

varying float altitude;

void vertex() {
	altitude = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 color = vec3(1.0, 1.0, 1.0);
	
	// Deep ocean (< -2000m) - abyssal plain
	if (altitude < -2000.0) {
		color = vec3(0.05, 0.08, 0.15); // Dark navy blue
	}
	// Ocean (-2000m to -100m)
	else if (altitude < -100.0) {
		color = vec3(0.08, 0.15, 0.25); // Deep ocean blue
	}
	// Shallow water (-100m to 0m) - continental shelf
	else if (altitude < 0.0) {
		color = vec3(0.15, 0.28, 0.38); // Turquoise/aquamarine
	}
	// Beach (0m to 20m) - sandy shores of North/Baltic Seas
	else if (altitude < 20.0) {
		color = vec3(0.88, 0.85, 0.75); // Light sand/beige
	}
	// Plain (20m to 300m) - agricultural lowlands & deciduous forest
	else if (altitude < 300.0) {
		color = vec3(0.38, 0.58, 0.28); // Lush green (crop/forest mix)
	}
	// Hill (300m to 800m) - Central Uplands, mixed forest
	else if (altitude < 800.0) {
		color = vec3(0.32, 0.48, 0.26); // Darker forest green
	}
	// Mountain (800m to 2000m) - Alpine foothills, coniferous forest
	else if (altitude < 2000.0) {
		color = vec3(0.26, 0.38, 0.22); // Deep green/brown forest
	}
	// Peak (2000m to 4000m) - high Alps, exposed rock/gravel
	else if (altitude < 4000.0) {
		color = vec3(0.48, 0.44, 0.38); // Grayish brown (scree/rock)
	}
	// Snow (> 4000m) - permanent snow/glaciers (Mont Blanc area)
	else {
		color = vec3(0.96, 0.96, 0.98); // Clean snow white
	}
	
	ALBEDO = color;
}
