shader_type canvas_item;

uniform sampler2D noise;
instance uniform float power: hint_range(0.0, 1.0) = 0.5;
uniform float down_multiplier: hint_range(0.0, 1.0) = 0.5;

void fragment() {
	COLOR = texture(TEXTURE, UV);
	float noise_power = mix(texture(noise, UV).r, 1.0, UV.y * down_multiplier);
	COLOR.a *= step(power, noise_power);
}