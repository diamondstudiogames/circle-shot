shader_type canvas_item;

instance uniform vec3 color: source_color = vec3(1.0);
instance uniform float power: hint_range(0.0, 1.0, 0.001) = 1.0;
varying flat vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.rgb = mix(COLOR.rgb, color.rgb, power);
	COLOR *= modulate;
}
