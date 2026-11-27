shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(0.82, 0.18, 0.96, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.86;

void fragment() {
	vec4 vertex_col = COLOR;
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 recolored = tint_color.rgb * (pow(lum, 0.85) * 1.85);
	vec3 final_rgb = mix(tex.rgb, recolored, strength);
	COLOR = vec4(final_rgb * vertex_col.rgb, tex.a * vertex_col.a);
}
