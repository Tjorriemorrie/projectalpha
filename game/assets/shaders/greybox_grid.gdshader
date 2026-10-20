shader_type spatial;
// Greybox material: a world-space grid of 1 m cells, so distances, heights and speeds can be judged
// while playtesting.

uniform vec3 base_color : source_color = vec3(0.4);
uniform vec3 line_color : source_color = vec3(0.15);
uniform float cell_size = 1.0;
uniform float line_width = 0.03;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
}

void fragment() {
	// Project the grid along the axis the surface faces most.
	vec2 coord = world_normal.y > 0.5 ? world_position.xz : (world_normal.x > 0.5 ? world_position.zy : world_position.xy);
	vec2 distance_to_line = abs(fract(coord / cell_size - 0.5) - 0.5) * cell_size;
	float line = 1.0 - step(line_width * 0.5, min(distance_to_line.x, distance_to_line.y));
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 0.8;
}
