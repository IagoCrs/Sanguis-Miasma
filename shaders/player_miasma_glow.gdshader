shader_type canvas_item;

// Shader de Brilho/Pulsação Roxa para Jogadores com Miasma > 70%
// Sanguis & Miasma: O Preço da Cura

uniform bool is_active = false;
uniform vec4 aura_color : source_color = vec4(0.68, 0.12, 0.88, 1.0);
uniform float pulse_speed : hint_range(0.5, 10.0) = 4.0;
uniform float aura_width : hint_range(0.0, 5.0) = 1.5;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    if (is_active) {
        vec2 size = TEXTURE_PIXEL_SIZE * aura_width;
        
        // Detecção de contorno (Outline)
        float outline = texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
        outline += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
        outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
        outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
        
        float pulse = (sin(TIME * pulse_speed) + 1.0) * 0.5;
        float alpha_glow = mix(0.3, 0.85, pulse);
        
        if (tex_color.a < 0.1 && outline > 0.0) {
            COLOR = vec4(aura_color.rgb, alpha_glow);
        } else if (tex_color.a >= 0.1) {
            vec3 tinted = mix(tex_color.rgb, aura_color.rgb, 0.3 * pulse);
            COLOR = vec4(tinted, tex_color.a);
        } else {
            COLOR = tex_color;
        }
    } else {
        COLOR = tex_color;
    }
}
