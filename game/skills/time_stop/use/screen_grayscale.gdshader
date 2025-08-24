shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture: hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec3 scr_tex = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float color = (scr_tex.r + scr_tex.g + scr_tex.b) / 3.0;
	COLOR.rgb = vec3(color);
}