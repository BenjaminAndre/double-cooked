// The room's walls on the camera's side, drawn with depth over the backdrop (Backdrop): they
// hide the characters behind them. The floor and the far walls are left to the backdrop, so
// the paper figures never sink into them.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D picture : source_color, filter_linear_mipmap;
// Where the camera looks at on the floor, and its direction on the floor (x, z).
uniform vec2 looked_at;
uniform vec2 forward = vec2(0.0, -1.0);
// Under this, it is floor.
uniform float floor_height = 0.05;

varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    if (world_position.y < floor_height || dot(world_position.xz - looked_at, forward) > 0.0) {
        discard;
    }
    ALBEDO = texture(picture, UV).rgb;
}
