shader_type canvas_item;
render_mode unshaded;

uniform float outline_width = 2.0;
instance uniform vec4 outline_color: source_color;
varying flat vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	color.rgb *= modulate.rgb;
	
	float a;
	float maxa = color.a;
	float mina = color.a;

	a = texture(TEXTURE, UV + vec2(0.0, -outline_width) * TEXTURE_PIXEL_SIZE).a;
	maxa = max(a, maxa);
	mina = min(a, mina);

	a = texture(TEXTURE, UV + vec2(0.0, outline_width) * TEXTURE_PIXEL_SIZE).a;
	maxa = max(a, maxa);
	mina = min(a, mina);

	a = texture(TEXTURE, UV + vec2(-outline_width, 0.0) * TEXTURE_PIXEL_SIZE).a;
	maxa = max(a, maxa);
	mina = min(a, mina);

	a = texture(TEXTURE, UV + vec2(outline_width, 0.0) * TEXTURE_PIXEL_SIZE).a;
	maxa = max(a, maxa);
	mina = min(a, mina);

	COLOR = mix(color, outline_color, maxa - mina);
	COLOR.a *= modulate.a;
}