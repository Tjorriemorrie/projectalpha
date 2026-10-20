shader_type canvas_item;
// Tints the edges of the screen, fading out towards the centre: red when the player is hit or close to death.

uniform vec4 tint : source_color = vec4(1.0, 0.12, 0.08, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 from_centre = (UV - 0.5) * 2.0;
	// Squash the corners a little, so the tint hugs all four edges rather than only the corners.
	float edge = smoothstep(0.55, 1.25, length(from_centre * vec2(0.9, 1.0)));
	COLOR = vec4(tint.rgb, tint.a * edge * intensity);
}
