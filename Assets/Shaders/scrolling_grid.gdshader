// File: Shaders/scrolling_grid.gdshader
// How to use:
// 1. Create a ShaderMaterial in the inspector of a TextureRect.
// 2. Load this shader file into the ShaderMaterial's "Shader" property.
// 3. Set the TextureRect to "Full Rect" to cover the screen.
shader_type canvas_item;

// --- UNIFORMS (Editable in Inspector) ---
uniform vec4 background_color : source_color = vec4(0.01, 0.02, 0.05, 1.0);
uniform vec4 grid_color : source_color = vec4(0.1, 0.5, 0.8, 1.0);
uniform float speed : hint_range(0.0, 5.0) = 0.1;
// --- FIX: Removed the 'fov' uniform as it's for perspective, which we don't want.
uniform float line_sharpness : hint_range(0.001, 0.05) = 0.005; // Renamed for clarity
uniform vec2 grid_scale = vec2(10.0, 10.0); // Controls how many grid cells are on screen

// --- FRAGMENT SHADER (Main Logic) ---
void fragment() {
	// --- FIX: Simplified UV and grid logic for a uniform, top-down grid. ---
	
	// Scale the UV coordinates to control the size of the grid cells.
	vec2 uv = UV * grid_scale;
	
	// Animate the grid by scrolling it over time.
	uv += vec2(0.0, TIME * speed);
	
	// Use absolute value and fract to create repeating lines.
	uv = abs(fract(uv) - 0.5);
	
	// Use smoothstep to draw the lines with anti-aliasing.
	// The sharpness uniform controls the thickness of the lines.
	vec2 lines = smoothstep(vec2(line_sharpness), vec2(0.0), uv);
	
	// Combine the horizontal and vertical lines into a single value.
	float grid_value = max(lines.x, lines.y);
	
	// Mix the background and grid colors based on the grid value.
	vec4 final_color = mix(background_color, grid_color, grid_value);
	
	// Set the final pixel color.
	COLOR = final_color;
}