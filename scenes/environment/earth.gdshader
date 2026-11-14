shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
// Earth seen from the Moon: day texture lit by the sun, a dark night side,
// a bright ocean glint and a thin blue atmosphere rim.

uniform sampler2D day_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction = vec3(-0.6, 0.45, 0.66); // world space, towards the sun
uniform vec3 atmosphere_color : source_color = vec3(0.35, 0.6, 1.0);
uniform float rotation = 0.35;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = vec2(fract(UV.x + rotation), UV.y);
	vec3 day = texture(day_texture, uv).rgb;
	vec3 n = normalize(world_normal);
	vec3 l = normalize(sun_direction);
	float ndl = dot(n, l);
	float lit = smoothstep(-0.08, 0.25, ndl);
	vec3 col = day * lit * 1.25;

	// Ocean glint: oceans are the darkest/bluest texels.
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float ocean = smoothstep(0.12, 0.0, day.r) * step(day.r, day.b);
	float spec = pow(max(dot(reflect(-l, n), v), 0.0), 40.0);
	col += vec3(1.0, 0.95, 0.85) * spec * ocean * lit * 0.6;

	// Atmosphere: fresnel rim on the lit side.
	float fres = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	col = mix(col, atmosphere_color, fres * smoothstep(-0.2, 0.4, ndl) * 0.85);
	ALBEDO = col;
}
