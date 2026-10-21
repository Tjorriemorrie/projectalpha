// The space outside the ship's window: black, with a faint band of dust and two layers of stars, small and many,
// and fewer, brighter ones. Stars sit at random points of a grid of cells round the view, so they stay put.
shader_type sky;

uniform vec3 dust_color : source_color = vec3(0.035, 0.04, 0.07);
uniform float near_stars = 0.035;
uniform float far_stars = 0.08;
uniform float brightness = 2.2;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// One layer of stars: a star in a share of the cells, nearest its point; brighter stars are bigger.
float stars(vec3 direction, float scale, float share) {
	vec3 p = direction * scale;
	vec3 cell = floor(p);
	float h = hash(cell);
	if (h > share) {
		return 0.0;
	}
	vec3 point = cell + 0.5 + (vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 4.1)) - 0.5) * 0.7;
	float strength = 1.0 - h / share;
	float size = mix(0.12, 0.32, strength * strength);
	return smoothstep(size, 0.0, length(p - point)) * (0.25 + strength);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float band = pow(max(1.0 - abs(dot(direction, normalize(vec3(0.3, 0.9, -0.3)))), 0.0), 6.0);
	vec3 color = dust_color * band;
	float light = stars(direction, 160.0, near_stars) + stars(direction, 420.0, far_stars) * 0.6;
	vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.75), hash(floor(direction * 160.0) + 7.0));
	COLOR = color + tint * light * brightness;
}
