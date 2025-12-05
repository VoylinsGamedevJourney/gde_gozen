using Godot;
using System;

public partial class AudioStreamFFmpeg : AudioStream
{
    private Variant _backer;

    public AudioStreamFFmpeg()
    {
        _backer = ClassDB.Instantiate("AudioStreamFFmpeg");
    }

    public AudioStreamFFmpeg(Variant hndl)
    {
        _backer = hndl;
    }

    public int Open(string path, int streamIndex = -1) => _backer.AsGodotObject().Call("open", path, streamIndex).AsInt32();
    public override AudioStreamPlayback _InstantiatePlayback()
    {
        return _backer.AsGodotObject().Call("_instantiate_playback").As<AudioStreamPlayback>();
    }
}
