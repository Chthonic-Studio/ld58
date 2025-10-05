// File: Assets/Shaders/synergy_glow.gdshader
// How to use:
// 1. Apply as a ShaderMaterial to a Sprite2D. The sprite's texture can be a soft-edged
//    circle or a radial gradient to define the glow's shape. A simple white-to-transparent
//    radial gradient texture is recommended.
// 2. Set the Sprite2D's material blend mode to "Add" for a nice glowing effect.
shader_type canvas_item;
render_mode blend_add; // Use additive blending for a bright glow effect.

// --- UNIFORMS (Editable in Inspector) ---
uniform vec4 glow_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_width : hint_range(0.01, 1.0) = 0.5;
uniform float intensity : hint_range(0.0, 10.0) = 1.5;


// --- FRAGMENT SHADER (Main Logic) ---
void fragment() {
	// The base color and alpha come from the Sprite2D's texture.
	// A soft radial gradient texture works best.
	vec4 base_color = texture(TEXTURE, UV);
	
	// --- RADIAL PULSE CALCULATION ---
	// REASONING: Instead of a directional pulse (UV.x), we calculate the distance
	// from the center of the UV space (0.5, 0.5) to create a radial effect.
	float dist_from_center = distance(UV, vec2(0.5));
	
	// Create a repeating wave that travels outwards from the center over time.
	// The `dist_from_center * 2.0` maps the 0.0-0.5 distance to a 0.0-1.0 range for the pulse.
	float pulse = fract((dist_from_center * 2.0) - TIME * pulse_speed);
	
	// Use smoothstep to shape the wave into a smooth ring-like pulse.
	float pulse_shape = smoothstep(0.0, pulse_width / 2.0, pulse) - smoothstep(pulse_width / 2.0, pulse_width, pulse);
	
	// Combine the base texture color with the glowing pulse.
	// The intensity uniform makes the pulse brighter.
	vec4 final_color = base_color + (pulse_shape * glow_color * intensity);
	
	// The final alpha is determined by the texture's alpha and the pulse.
	// We use the max to ensure the base glow from the texture is always visible.
	final_color.a = max(base_color.a, pulse_shape);
	
	COLOR = final_color;
}