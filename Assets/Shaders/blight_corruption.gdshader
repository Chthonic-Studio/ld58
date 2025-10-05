// File: Assets/Shaders/blight_corruption.gdshader
// How to use:
// Apply as the 'material' property on the Sprite2D of a Tile scene.
// The Tile's script will get this material and update the 'progress' uniform.
shader_type canvas_item;

// The progress of the blight corruption, from 0.0 (clean) to 1.0 (fully blighted).
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// The color of the blight overlay. A sickly green or purple works well.
uniform vec4 blight_color : source_color = vec4(0.5, 0.1, 0.8, 0.6);

// The direction the blight "grows" across the tile. (0, -1) is a nice top-to-bottom effect.
uniform vec2 fill_direction = vec2(0.0, -1.0);

// Use noise to create a more organic, creeping edge instead of a straight line.
uniform sampler2D noise_texture : hint_albedo;

// Controls the jaggedness of the blight's edge.
uniform float noise_strength : hint_range(0.0, 0.5) = 0.1;


void fragment() {
	// Get the base texture of the tile's sprite.
	vec4 original_color = texture(TEXTURE, UV);

	// Normalize the fill direction to ensure consistent calculations.
	vec2 dir = normalize(fill_direction);
	
	// Read the noise texture. Scrolling it with TIME gives it a subtle animation.
	float noise = texture(noise_texture, UV + TIME * 0.1).r * noise_strength;

	// Project the UV coordinate onto the fill direction vector. This gives us a
	// value from 0 to 1 representing how far along the fill direction this pixel is.
	// We subtract the noise to make the dividing line jagged and irregular.
	float fill_value = dot(UV, dir) - noise;
	
	// Remap the fill_value to be cleanly between 0 and 1.
	fill_value = (fill_value - dot(vec2(0.0), dir)) / (dot(vec2(1.0), dir) - dot(vec2(0.0), dir));

	// If the pixel's fill_value is less than the blight's progress, it's corrupted.
	if (fill_value < progress) {
		// Mix the original tile color with the blight color.
		COLOR = mix(original_color, blight_color, blight_color.a);
	} else {
		// Otherwise, show the original tile color.
		COLOR = original_color;
	}
	
	// Preserve the original texture's alpha to maintain its shape.
	COLOR.a = original_color.a;
}