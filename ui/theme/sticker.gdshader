shader_type canvas_item;
// Mobile "sticker" look for HUD art: a thin light rim around the sprite's
// silhouette plus a small drop shadow. Widths are in screen pixels, so the
// rim stays even no matter how far the source art is scaled down.

uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_width = 2.0;
uniform vec4 shadow_color : source_color = vec4(0.04, 0.07, 0.21, 0.45);
uniform float shadow_offset = 3.0;

float alpha_max(sampler2D tex, vec2 uv, vec2 step_uv) {
	float a = 0.0;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * TAU / 12.0;
		a = max(a, texture(tex, uv + vec2(cos(ang), sin(ang)) * step_uv).a);
	}
	return a;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = fwidth(UV);
	float rim = alpha_max(TEXTURE, UV, px * rim_width);
	float shadow = alpha_max(TEXTURE, UV - vec2(0.0, px.y * shadow_offset), px * rim_width);
	vec4 under = mix(vec4(shadow_color.rgb, shadow_color.a * shadow), rim_color, rim);
	COLOR = mix(under, c, c.a);
	COLOR.a = max(c.a, max(rim, shadow * shadow_color.a));
}
