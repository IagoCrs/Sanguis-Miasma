shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.6;
uniform vec4 tint_color : source_color = vec4(0.04, 0.02, 0.07, 0.48);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * 2.0;
	vec4 c = textureLod(screen_tex, SCREEN_UV, blur_amount) * 0.4;
	c += textureLod(screen_tex, SCREEN_UV + vec2(px.x, 0.0), blur_amount) * 0.15;
	c += textureLod(screen_tex, SCREEN_UV - vec2(px.x, 0.0), blur_amount) * 0.15;
	c += textureLod(screen_tex, SCREEN_UV + vec2(0.0, px.y), blur_amount) * 0.15;
	c += textureLod(screen_tex, SCREEN_UV - vec2(0.0, px.y), blur_amount) * 0.15;
	COLOR = vec4(mix(c.rgb, tint_color.rgb, tint_color.a), 1.0);
}
