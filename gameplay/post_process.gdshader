// The artist's post-process (docs/art/Readme_SettingsV3.txt), on the kitchen as the camera sees
// it, under the overlays: exposure, contrast and saturation, then a vignette. Unity's values,
// converted: post exposure 0.14 EV, contrast 2 and saturation 13 (out of 100), vignette 0.2.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float exposure = 0.14;
uniform float contrast = 1.02;
uniform float saturation = 1.13;
// Unity's vignette: intensity × 3, smoothness 0.2 × 5, black, centred.
uniform float vignette = 0.6;
uniform float smoothness = 1.0;

void fragment() {
	vec3 color = texture(screen, SCREEN_UV).rgb * exp2(exposure);
	color = (color - 0.5) * contrast + 0.5;
	float grey = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(grey), color, saturation);
	vec2 from_centre = abs(SCREEN_UV - 0.5) * vignette;
	color *= pow(clamp(1.0 - dot(from_centre, from_centre), 0.0, 1.0), smoothness);
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
