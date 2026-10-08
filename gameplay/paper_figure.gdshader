// A paper cut-out character (PaperFigure): drawn facing the camera square on, as on the
// artist's concept, but as deep as a card standing upright at its feet. So it never sinks into
// the counters behind it, and what stands in front of it (a counter) still hides it.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D picture : source_color, filter_linear_mipmap, repeat_disable;
// Width and height of the drawing, in metres; girth widens it.
uniform vec2 size = vec2(0.5, 1.55);
uniform float girth = 1.0;
// Standing: facing the camera. Otherwise the quad lies as the node is turned (knocked out).
uniform bool standing = true;
// Walking towards the left of the screen: the drawing is flipped (the artist's rule).
uniform bool mirrored = false;

void vertex() {
	// The quad spans -0.5..0.5: centred on the feet, drawn upwards from them.
	vec2 local = vec2(VERTEX.x * size.x * girth, (VERTEX.y + 0.5) * size.y);
	if (standing) {
		vec3 feet = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		// Facing the camera: a card in view space, up along the screen's up.
		vec3 card = feet + vec3(local, 0.0);
		// The same point of a card standing upright at the feet, for its depth.
		vec3 upright = feet + vec3(local.x, 0.0, 0.0) + (VIEW_MATRIX * vec4(0.0, local.y, 0.0, 0.0)).xyz;
		// Slid along its own ray, it stays where it is on screen but gets the upright depth.
		card *= upright.z / card.z;
		POSITION = PROJECTION_MATRIX * vec4(card, 1.0);
	} else {
		POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(local, 0.0, 1.0));
	}
}

void fragment() {
	vec4 color = texture(picture, mirrored ? vec2(1.0 - UV.x, UV.y) : UV);
	ALBEDO = color.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
