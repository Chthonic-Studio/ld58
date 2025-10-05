// File: Shaders/synergy_link.gdshader
// How to use:
// 1. Apply as a ShaderMaterial to a Line2D node.
// 2. The line's Gradient property will control the base color and alpha.
//    A gradient that is transparent at the ends and opaque in the middle is best.
shader_type canvas_item;

// --- UNIFORMS (Editable in Inspector) ---
uniform vec4 glow_color : source_color = vec4(0.5, 1.0, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_width : hint_range(0.0, 1.0) = 0.3;
uniform float intensity : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	// COLOR is the interpolated color from the Line2D's gradient.
	vec4 base_color = COLOR;
	
	// --- Pulse Calculation ---
	// Create a repeating wave that travels along the line's length (UV.x) over time.
	float pulse = fract(UV.x - TIME * pulse_speed);
	
	// Use smoothstep to shape the wave into a smooth pulse with a defined width.
	// This creates a "band" of light.
	float pulse_shape = smoothstep(0.0, pulse_width / 2.0, pulse) - smoothstep(pulse_width / 2.0, pulse_width, pulse);
	
	// Combine the base color (from the gradient) with the glowing pulse.
	// The intensity uniform makes the pulse brighter than the base line.
	vec4 final_color = base_color + (pulse_shape * glow_color * intensity);
	
	// The final alpha is the base alpha from the gradient, ensuring the line
	// still fades at the ends as defined by the gradient.
	final_color.a = base_color.a;
	
	COLOR = final_color;
}