shader_type canvas_item;

uniform sampler2D y_data;
uniform sampler2D u_data;
uniform sampler2D v_data;
uniform sampler2D a_data;

uniform vec2 resolution;
uniform vec4 color_profile;
uniform bool full_color;
uniform int interlaced; // 0 = no, 1 = top first, 2 = bottom first
uniform float rotation;

uniform vec4 modulate;

varying vec2 tex_uv;
varying vec2 chroma_uv;

const vec3 LIMITED_Y_OFFSET = vec3(16.0/255.0, 128.0/255.0, 128.0/255.0);
const vec3 LIMITED_SCALE = vec3(255.0/219.0, 255.0/224.0, 255.0/224.0);



void vertex() {
	// Handling rotation in vertex
	float c = cos(rotation);
	float s = sin(rotation);
	mat2 rot_mat = mat2(vec2(c, s), vec2(-s, c));
	
	vec2 centered_uv = UV - 0.5;
	vec2 rotated_uv = rot_mat * centered_uv;

	tex_uv = rotated_uv + 0.5;
	chroma_uv = tex_uv; 
}


void fragment() {
	if (tex_uv.x < 0.0 || tex_uv.x > 1.0 || tex_uv.y < 0.0 || tex_uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		float y_val;
		
		// Deinterlacing by blending (slight blur, but viewable image)
		if (interlaced > 0) {
			float pixel_h = 1.0 / resolution.y;
			float offset_dir = (interlaced == 1) ? -pixel_h : pixel_h;
			vec2 offset_uv = clamp(tex_uv + vec2(0.0, offset_dir), 0.0, 1.0);
			float y_neighbor = texture(y_data, offset_uv).r;
			
			y_val = mix(texture(y_data, tex_uv).r, y_neighbor, 0.5);
		} else y_val = texture(y_data, tex_uv).r;

		vec3 yuv = vec3(y_val, texture(u_data, tex_uv).r, texture(v_data, tex_uv).r);

		if (full_color) yuv.yz -= 0.5; // Full range just needs Chroma offset
		else yuv = (yuv - LIMITED_Y_OFFSET) * LIMITED_SCALE;
		
		COLOR = vec4( // Applying color profile and returning color
				yuv.x + (yuv.z * color_profile.x),
				yuv.x - (yuv.y * color_profile.y) - (yuv.z * color_profile.z),
				yuv.x + (yuv.y * color_profile.w),
				texture(a_data, tex_uv).r) * modulate;
	}
}
