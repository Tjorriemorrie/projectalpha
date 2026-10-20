shader_type spatial;
// The material of a weapon held in view: plain PBR colours, with the weapon drawn in front of the world so it never
// pokes into walls. WeaponViewmodel copies each imported material's colours into one of these.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// How far depth is pulled towards the near plane: 0 leaves it alone, 1 flattens the weapon onto the near plane.
uniform float depth_pull : hint_range(0.0, 1.0) = 0.9;

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Depth is reversed (the near plane is at 1), so pulling z towards w draws the weapon in front of the world
	// while keeping its own parts in order. Lighting still uses the real view-space position.
	POSITION.z = mix(POSITION.z, POSITION.w, depth_pull);
}

void fragment() {
	ALBEDO = albedo.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = emission.rgb * emission_energy;
}
