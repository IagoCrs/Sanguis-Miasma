shader_type canvas_item;

// Shader de Névoa Volumétrica de Miasma para primeiro plano
// Sanguis & Miasma: O Preço da Cura

uniform vec4 fog_color : source_color = vec4(0.22, 0.05, 0.32, 0.45);
uniform vec4 toxic_color : source_color = vec4(0.08, 0.42, 0.18, 0.55);
uniform float speed : hint_range(0.0, 5.0) = 0.4;
uniform float density : hint_range(0.1, 5.0) = 1.8;

// Ruído pseudo-aleatório procedural otimizado para 2D
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.5)));
    for (int i = 0; i < 3; ++i) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 coord = UV * density;
    coord.x += TIME * speed * 0.08;
    coord.y += sin(TIME * speed * 0.04) * 0.05;
    
    float q = fbm(coord);
    float r = fbm(coord + q + vec2(TIME * speed * 0.06, TIME * speed * 0.03));
    
    vec4 final_color = mix(fog_color, toxic_color, r);
    COLOR = vec4(final_color.rgb, final_color.a * r * 0.7);
}
