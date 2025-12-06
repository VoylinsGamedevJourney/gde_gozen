using Godot;

public partial class AudioTestRoom : Control
{
	private AudioStreamPlayer _player;
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		GetWindow().FilesDropped += HandleAudioDrop;
		_player = GetNode<AudioStreamPlayer>("AudioStreamPlayer");
	}

	private void HandleAudioDrop(string[] files)
	{
		GD.Print($"Loading audio: {files[0]}");
		var stream = new AudioStreamFFmpeg();
		stream.Open(files[0]);
		_player.Stream = stream;
		_player.Play();
	}
}
