shader_type canvas_item;
render_mode unshaded;

uniform sampler2D distortion;
instance uniform float screen_zoom = 1.0;
uniform float dist_power = 0.05;
uniform sampler2D screen_texture: hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec3 color = vec3(1.0) - textureLod(screen_texture, (SCREEN_UV - 0.5) * (1.0 / screen_zoom)
			+ 0.5 + texture(distortion, UV).b * dist_power / screen_zoom, 0.0).rgb;
	color = mix(color, vec3(1.0), length(UV - vec2(0.5)) * 2.0);
	COLOR.rgb = color;
}