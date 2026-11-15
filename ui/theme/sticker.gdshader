shader_type canvas_item;
// Mobile "sticker" look for HUD art: a thin light rim around the sprite's
// silhouette plus a small drop shadow. Widths are in screen pixels, so the
// rim stays even no matter how far the source art is scaled down.

uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_width = 2.0;
uniform vec4 shadow_color : source_color = vec4(0.04, 0.07, 0.21, 0.45);
uniform float shadow_offset = 3.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = fwidth(UV);
	// Max alpha in a ring around the pixel (TEXTURE can't be passed to a
	// helper function on every renderer, so the loop lives here).
	float rim = 0.0;
	float shadow = 0.0;
	vec2 down = vec2(0.0, px.y * shadow_offset);
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * TAU / 12.0;
		vec2 o = vec2(cos(ang), sin(ang)) * px * rim_width;
		rim = max(rim, texture(TEXTURE, UV + o).a);
		shadow = max(shadow, texture(TEXTURE, UV - down + o).a);
	}
	vec4 under = mix(vec4(shadow_color.rgb, shadow_color.a * shadow), rim_color, rim);
	COLOR = mix(under, c, c.a);
	COLOR.a = max(c.a, max(rim, shadow * shadow_color.a));
}
