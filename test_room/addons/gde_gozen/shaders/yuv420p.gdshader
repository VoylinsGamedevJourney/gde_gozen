shader_type canvas_item;


uniform sampler2D y_data;
uniform sampler2D u_data;
uniform sampler2D v_data;



void fragment() {
	vec2 uv = UV;

    float Y = texture(y_data, uv).r;
    float U = texture(u_data, uv).r - 0.5;
    float V = texture(v_data, uv).r - 0.5;

    float R = Y + 1.402 * V;
    float G = Y - 0.344136 * U - 0.714136 * V;
    float B = Y + 1.772 * U;

    COLOR = vec4(R, G, B, 1.0);
}

