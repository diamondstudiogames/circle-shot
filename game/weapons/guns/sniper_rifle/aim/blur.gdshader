shader_type canvas_item;

const float DEFAULT_RADIUS = 10.0;

uniform vec2 unit = vec2(1.0, 1.0);
uniform float radius = 10.0;

void fragment() {
	vec2 s = radius / DEFAULT_RADIUS * unit / vec2(textureSize(TEXTURE, 0));
	COLOR =
		0.011194727 * texture(TEXTURE, UV - 10.000000000 * s) +
		0.039368696 * texture(TEXTURE, UV - 8.415809477 * s) +
		0.071308558 * texture(TEXTURE, UV - 6.435363708 * s) +
		0.110237219 * texture(TEXTURE, UV - 4.455121108 * s) +
		0.145451038 * texture(TEXTURE, UV - 2.475020813 * s) +
		0.163798995 * texture(TEXTURE, UV - 0.495000167 * s) +
		0.157439298 * texture(TEXTURE, UV + 1.485004498 * s) +
		0.129158204 * texture(TEXTURE, UV + 3.465057055 * s) +
		0.090434685 * texture(TEXTURE, UV + 5.445220765 * s) +
		0.054043977 * texture(TEXTURE, UV + 7.425557483 * s) +
		0.027564604 * texture(TEXTURE, UV + 9.406126897 * s);
}