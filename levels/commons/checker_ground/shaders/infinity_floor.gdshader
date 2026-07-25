shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

// NOTE: 'uniform' exposes these variables to the Godot Inspector
uniform vec3 color1 : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 color2 : source_color = vec3(1.0, 1.0, 1.0);
uniform float checker_scale = 2.0;

// Tweakable reflections
uniform float roughness_value : hint_range(0.0, 1.0) = 0.1;
uniform float metallic_value  : hint_range(0.0, 1.0) = 0.8;

// 'varying' passes data from the vertex function to the fragment function
varying vec3 world_pos;

// Called for every vertex the material is visible on.
void vertex() {
	// Capture the exact 3D world coordinates of the floor
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; 
}

// Called for every pixel the material is visible on.
void fragment() {
	// Get the X and Z axes (flat ground) and scale them
	vec2 pos = world_pos.xz / checker_scale;
	
	// Core math
	vec2 grid = floor(pos);
	float checker = mod(grid.x + grid.y, 2.0);
	
	// Apply results
	ALBEDO = mix(color1, color2, checker);
	
	// Set the Bryce3D like glossy properties
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
