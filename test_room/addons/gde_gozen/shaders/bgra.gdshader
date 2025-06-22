shader_type canvas_item;


// These have the same naming to not complicate the video playback script since
// this shader is most likely only going to be used by gif images.
uniform sampler2D y_data; // Contains the full RGBA, but backwards 


void fragment() {
	COLOR = texture(y_data, UV).bgra;
}

