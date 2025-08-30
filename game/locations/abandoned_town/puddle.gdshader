shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture: hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D distortion_texture: repeat_enable;
uniform vec4 modulate: source_color = vec4(1.0);
uniform vec4 tint: source_color = vec4(1.0);
uniform float distortion_power = 0.01;
uniform float time_multiplier = 1.0;

void fragment() {
	vec2 distortion = texture(distortion_texture, UV + vec2(TIME * time_multiplier)).rg - vec2(0.5, 0.1);
	COLOR.rgb = textureLod(screen_texture, SCREEN_UV + distortion * distortion_power, 0.0).rgb;
	COLOR *= modulate;
	COLOR.rgb = mix(COLOR.rgb, tint.rgb, tint.a);
}