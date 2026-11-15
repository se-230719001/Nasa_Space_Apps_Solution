shader_type sky;
render_mode use_quarter_res_pass;
// Airless lunar sky: near-black space, a faint Milky Way band with dust lanes,
// and stars with a realistic brightness distribution and colour temperatures.

uniform vec3 space_color : source_color = vec3(0.006, 0.008, 0.02);
uniform vec3 milky_way_color : source_color = vec3(0.32, 0.30, 0.42);
uniform vec3 milky_way_pole = vec3(0.35, 0.55, 0.76);
uniform float star_density : hint_range(0.0, 0.05) = 0.022;

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = 0.0;
	for (int z = 0; z < 2; z++) for (int y = 0; y < 2; y++) for (int x = 0; x < 2; x++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 w = mix(1.0 - f, f, o);
		n += hash33(i + o).x * w.x * w.y * w.z;
	}
	return n;
}

float fbm(vec3 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 5; i++) { s += a * noise3(p); p *= 2.03; a *= 0.5; }
	return s;
}

vec3 star_layer(vec3 dir, float cells, float density) {
	vec3 p = dir * cells;
	vec3 c = floor(p);
	vec3 h = hash33(c);
	if (h.x > density) return vec3(0.0);
	vec3 centre = c + 0.5 + (hash33(c + 17.0) - 0.5) * 0.7;
	float d = length(p - centre);
	// Few bright stars, many faint ones.
	float mag = pow(h.y, 6.0) * 3.0 + 0.15;
	float core = exp(-d * d * 18.0);
	// Colour temperature: blue-white to warm orange.
	vec3 tint = mix(vec3(1.0, 0.78, 0.58), vec3(0.72, 0.82, 1.0), h.z);
	return tint * mag * core;
}

void sky() {
	vec3 dir = EYEDIR;
	float band = 1.0 - abs(dot(dir, normalize(milky_way_pole)));
	band = pow(band, 6.0);
	// Milky Way: soft band broken by dust lanes. The noise is costly and blurry
	// anyway, so it runs in the quarter-resolution pass; stars stay sharp.
	vec3 col;
	if (AT_QUARTER_RES_PASS) {
		float clouds = fbm(dir * 4.0);
		float dust = smoothstep(0.45, 0.7, fbm(dir * 9.0 + 3.0));
		col = space_color + milky_way_color * band * (0.35 + 0.65 * clouds) * (1.0 - 0.7 * dust) * 0.55;
	} else {
		col = QUARTER_RES_COLOR.rgb;

		// Two star layers; extra faint stars inside the Milky Way band.
		col += star_layer(dir, 180.0, star_density);
		col += star_layer(dir, 420.0, star_density * (0.6 + 2.5 * band)) * 0.7;
	}

	COLOR = col;
}
