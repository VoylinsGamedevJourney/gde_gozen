using System;
using System.Linq;
using Godot;
using Godot.Collections;

[GlobalClass, Icon("res://addons/gde_gozen/icon.webp")]
public partial class VideoPlayback : Control
{
    public enum StreamType { Video = 0, Audio = 1, Subtitle = 2 }

    [Signal]
    public delegate void FrameChangedEventHandler(int frame_nr);

    [Signal]
    public delegate void NextFrameCalledEventHandler(int frame_nr);

    [Signal]
    public delegate void VideoLoadedEventHandler();

    [Signal]
    public delegate void VideoEndedEventHandler();

    [Signal]
    public delegate void PlaybackStartedEventHandler();

    [Signal]
    public delegate void PlaybackPausedEventHandler();

    [Signal]
    public delegate void PlaybackReadyEventHandler();

    public const string SHADER_PATH_COMPATIBILITY = "res://addons/gde_gozen/shaders/yuv_to_rgb_compatibility.gdshader";
    public const string SHADER_PATH_FORWARD = "res://addons/gde_gozen/shaders/yuv_to_rgb_forward.gdshader";
    public const float PLAYBACK_SPEED_MIN = 0.25f;
    public const float PLAYBACK_SPEED_MAX = 4.0f;
    public const float AUDIO_OFFSET_THRESHOLD = 0.1f;

    [Export] public Vector2 PlaybackSpeedOverride = Vector2.Zero;

    private string _path = "";

    [Export(PropertyHint.File)]
    public string Path
    {
        get => _path;
        set => SetVideoPath(value);
    }
    [Export] public bool EnableAudio = true;
    [Export] public bool AudioSpeedToSync = false;
    [Export] public bool EnableAutoPlay = false;

    private float _playbackSpeed = 1.0f;

    [Export(PropertyHint.Range, "0.25,4.0,0.05,or_less,or_greater")]
    public float PlaybackSpeed
    {
        get => _playbackSpeed;
        set => SetPlaybackSpeed(value);
    }

    private bool _pitchAdjust = true;

    [Export]
    public bool PitchAdjust
    {
        get => _pitchAdjust;
        set => SetPitchAdjust(value);
    }
    [Export] public bool Loop = false;

    private ColorProfile _colorProfile = ColorProfile.Auto;

    [ExportGroup("Extra's")]
    [Export]
    public ColorProfile ColorProfile
    {
        get => _colorProfile;
        set => SetColorProfile(value);
    }

    [Export] public bool Debug = false;

    public GoZenVideo Video;

    public TextureRect VideoTexture = new TextureRect();
    public AudioStreamPlayer AudioStream = new AudioStreamPlayer();

    public bool IsPlaying = false;
    private int _currentFrame = 0;

    public int CurrentFrame
    {
        get => _currentFrame;
        set => SetCurrentFrame(value);
    }

    public int[] VideoStreams = [];
    public int[] AudioStreams = [];
    public int[] SubtitleStreams = [];
    public Array<Chapter> Chapters = new Array<Chapter>();

    private float _timeElapsed = 0.0f;
    private float _timeFrame = 0.0f;
    private int _skippedFrames = 0;

    private int _rotation = 0;
    private int _padding = 0;
    private float _frameRate = 0.0f;
    private int _frameCount = 0;
    private bool _hasAlpha = false;

    private Vector2I _resolution = Vector2I.Zero;
    private ShaderMaterial _shaderMaterial;

    private long _videoThread = -1;
    private AudioEffectPitchShift _audioPitchEffect = new AudioEffectPitchShift();

    private bool _ignorePathSetter = false;

    private ImageTexture _yTexture;
    private ImageTexture _uTexture;
    private ImageTexture _vTexture;
    private ImageTexture _aTexture;

    public partial class Chapter : GodotObject
    {
        public float Start;
        public float End;
        public string Title;

        public Chapter(float start, float end, string title)
        {
            Start = start;
            End = end;
            Title = title;
        }
    }

    #region Tree Functions
    public override void _EnterTree()
    {
        var emptyImage = Image.CreateEmpty(2, 2, false, Image.Format.R8);

        _yTexture = ImageTexture.CreateFromImage(emptyImage);
        _uTexture = ImageTexture.CreateFromImage(emptyImage);
        _vTexture = ImageTexture.CreateFromImage(emptyImage);
        _aTexture = ImageTexture.CreateFromImage(emptyImage);

        _shaderMaterial = new ShaderMaterial();
        if (RenderingServer.GetCurrentRenderingMethod() == "forward_plus" && (bool)ProjectSettings.GetSetting("rendering/viewport/hdr_2d", false))
            _shaderMaterial.Shader = GD.Load<Shader>(SHADER_PATH_FORWARD);
        else
            _shaderMaterial.Shader = GD.Load<Shader>(SHADER_PATH_COMPATIBILITY);

        VideoTexture.Material = _shaderMaterial;
        VideoTexture.Texture = new ImageTexture();
        VideoTexture.AnchorRight = (float)TextureRect.Anchor.End;
        VideoTexture.AnchorBottom = (float)TextureRect.Anchor.End;
        VideoTexture.StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered;
        VideoTexture.ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize;

        AddChild(VideoTexture);
        AddChild(AudioStream);

        AudioServer.AddBus();
        AudioStream.Bus = AudioServer.GetBusName(AudioServer.BusCount - 1);
        AudioServer.AddBusEffect(AudioServer.BusCount - 1, _audioPitchEffect);

        if (Debug && OS.GetName().ToLower() != "web")
            PrintSystemDebug();
    }

    public override void _ExitTree()
    {
        Close();
        AudioServer.RemoveBus(AudioServer.GetBusIndex(AudioStream.Bus));
    }

    public override void _Ready()
    {
        EmitSignalPlaybackReady();
    }
    #endregion

    #region Video Data Handling
    public async void SetVideoPath(string newPath)
    {
        if (_ignorePathSetter)
        {
            _path = newPath;
            return;
        }

        Close();

        if (!IsNodeReady())
            await ToSignal(this, SignalName.Ready);
        if (!GetTree().Root.IsNodeReady())
            await ToSignal(GetTree().Root, SignalName.Ready);

        if (newPath == "" || newPath.EndsWith(".tscn"))
            return;
        else if (newPath.Split(":")[0] == "uid")
            newPath = ResourceUid.GetIdPath(ResourceUid.TextToId(newPath));

        _path = newPath;

        Video = new GoZenVideo();

        if (Debug)
            Video.EnableDebug();
        else
            Video.DisableDebug();

        _videoThread = WorkerThreadPool.AddTask(Callable.From(() => OpenVideo()));
        if (EnableAudio)
            OpenAudio();
    }

    public async void UpdateVideo(GoZenVideo video, AudioStream audioStream = null)
    {
        Close();

        if (!IsNodeReady())
            await ToSignal(this, SignalName.Ready);
        if (!GetTree().Root.IsNodeReady())
            await ToSignal(GetTree().Root, SignalName.Ready);

        _ignorePathSetter = true;
        Path = video.GetVideoPath();
        _ignorePathSetter = false;

        if (EnableAudio)
        {
            if (audioStream != null)
                AudioStream.Stream = audioStream;
            else
                OpenAudio();
        }

        _UpdateVideo(video);
        if (IsOpen() && EnableAutoPlay)
            Play();
    }

    private void _UpdateVideo(GoZenVideo video)
    {
        Video = video;

        if (!IsOpen())
        {
            GD.PrintErr("Video isn't open!");
            Video = null;
            return;
        }

        Image image;
        var rotationRadians = Mathf.DegToRad((float)Video.GetRotation());

        IsPlaying = false;
        CurrentFrame = 0;

        _padding = Video.GetPadding();
        _rotation = Video.GetRotation();
        _frameRate = Video.GetFramerate();
        _resolution = Video.GetResolution();
        _frameCount = Video.GetFrameCount();
        _hasAlpha = Video.GetHasAlpha();

        VideoStreams = Video.GetStreams((int)StreamType.Video);
        AudioStreams = Video.GetStreams((int)StreamType.Audio);
        SubtitleStreams = Video.GetStreams((int)StreamType.Subtitle);

        Chapters.Clear();
        for (int i = 0; i < Video.GetChapterCount(); i++)
        {
            var meta = Video.GetChapterMetadata(i);
            string title = meta.ContainsKey("title") ? meta["title"].AsString() : "";
            Chapters.Add(new Chapter(
                Video.GetChapterStart(i),
                Video.GetChapterEnd(i),
                title
            ));
        }

        if (Mathf.Abs(_rotation) == 90)
            image = Image.CreateEmpty(_resolution.Y, _resolution.X, false, Image.Format.R8);
        else
            image = Image.CreateEmpty(_resolution.X, _resolution.Y, false, Image.Format.R8);

        image.Fill(Colors.White);

        if (Debug)
            PrintVideoDebug();

        ((ImageTexture)VideoTexture.Texture).SetImage(image);

        _shaderMaterial.SetShaderParameter("resolution", Video.GetActualResolution());
        _shaderMaterial.SetShaderParameter("full_color", Video.IsFullColorRange());
        _shaderMaterial.SetShaderParameter("interlaced", Video.GetInterlaced());
        _shaderMaterial.SetShaderParameter("rotation", rotationRadians);
        SetColorProfile();

        _yTexture.SetImage(Video.GetYData());
        _uTexture.SetImage(Video.GetUData());
        _vTexture.SetImage(Video.GetVData());
        _aTexture.SetImage(_hasAlpha ? Video.GetAData() : image);

        _shaderMaterial.SetShaderParameter("y_data", _yTexture);
        _shaderMaterial.SetShaderParameter("u_data", _uTexture);
        _shaderMaterial.SetShaderParameter("v_data", _vTexture);
        _shaderMaterial.SetShaderParameter("a_data", _aTexture);

        SetPlaybackSpeed(PlaybackSpeed);
        EmitSignalVideoLoaded();
    }

    private void SetColorProfile(ColorProfile? colorProfile = null)
    {
        Vector4 colorData;
        var profile = Video.GetColorProfile();

        if (colorProfile.HasValue)
            ColorProfile = colorProfile.Value;

        if (ColorProfile != ColorProfile.Auto)
            profile = ColorProfile.ToString().ToLower();

        switch (profile)
        {
            case "bt2020":
            case "bt2100":
                colorData = new Vector4(1.4746f, 0.16455f, 0.57135f, 1.8814f);
                break;
            case "bt601":
            case "bt470":
                colorData = new Vector4(1.402f, 0.344136f, 0.714136f, 1.772f);
                break;
            default:
                colorData = new Vector4(1.5748f, 0.1873f, 0.4681f, 1.8556f);
                break;
        }

        _shaderMaterial.SetShaderParameter("color_profile", colorData);
    }

    public void SeekFrame(int frame)
    {
        if (!IsOpen() && frame == CurrentFrame)
            return;

        CurrentFrame = int.Clamp(frame, 0, _frameCount);
        if (Video.SeekFrame(CurrentFrame) != (int)Error.Ok)
        {
            GD.PrintErr("Couldn't seek frame!");
        }
        else
            SetFrameImage();

        if (EnableAudio && AudioStream.Stream != null && AudioStream.Stream.GetLength() != 0)
        {
            AudioStream.SetStreamPaused(false);
            AudioStream.Play(CurrentFrame / _frameRate);
            AudioStream.SetStreamPaused(!IsPlaying);
        }
    }

    public bool NextFrame(bool skip = false)
    {
        bool success = Video.NextFrame(skip);
        if (success && !skip)
        {
            SetFrameImage();
            EmitSignalNextFrameCalled(CurrentFrame);
        }
        return success;
    }

    public void Close()
    {
        if (_videoThread != -1)
        {
            var error = WorkerThreadPool.WaitForTaskCompletion(_videoThread);
            if (error != Error.Ok)
                GD.PrintErr($"Something went wrong waiting for task completion! {error}");
            _videoThread = -1;
        }

        if (Video != null)
        {
            if (IsPlaying)
                Pause();
            Video = null;
        }

        if (AudioStream != null)
        {
            AudioStream.Stop();
            AudioStream.Stream = null;
        }
    }
    #endregion

    #region Playback Handling

    public override void _Process(double delta)
    {
        if (IsPlaying)
        {
            _skippedFrames = 1;
            _timeElapsed += (float)delta;

            if (_timeElapsed < _timeFrame)
                return;

            if (_timeElapsed >= _timeFrame)
            {
                int frames = Mathf.RoundToInt(_timeElapsed / _timeFrame);
                _skippedFrames = frames;
            }

            _timeElapsed -= _skippedFrames * _timeFrame;
            CurrentFrame += _skippedFrames;

            bool eofReached = false;

            if (_frameCount > 0 && CurrentFrame >= _frameCount)
            {
                eofReached = true;
            }
            else
            {
                if (EnableAudio)
                    _SyncAudioVideo();

                if (_skippedFrames > _frameRate)
                {
                    SeekFrame(CurrentFrame);
                }
                else
                {
                    while (_skippedFrames != 1)
                    {
                        if (!NextFrame(true))
                        {
                            eofReached = true;
                            break;
                        }
                        _skippedFrames--;
                    }
                    if (!eofReached && !NextFrame())
                        eofReached = true;
                }
            }

            if (eofReached)
            {
                IsPlaying = !IsPlaying;

                if (EnableAudio && AudioStream.Stream != null)
                    AudioStream.SetStreamPaused(true);

                EmitSignalVideoEnded();

                if (Loop)
                {
                    SeekFrame(0);
                    Play();
                }
            }
        }
        else if (_videoThread != -1)
        {
            var error = WorkerThreadPool.WaitForTaskCompletion(_videoThread);
            if (error != Error.Ok)
                GD.PrintErr($"Something went wrong waiting for task completion! {error}");

            _videoThread = -1;
            _UpdateVideo(Video);
            if (EnableAutoPlay)
                Play();
        }
    }

    public void Play()
    {
        if (!IsOpen())
        {
            GD.Print($"The video on '{Path}' isn't open yet!");
            return;
        }

        if (IsPlaying) return;
        IsPlaying = true;

        if (EnableAudio && AudioStream.Stream != null && AudioStream.Stream.GetLength() != 0)
        {
            AudioStream.SetStreamPaused(false);
            AudioStream.Play((CurrentFrame + 1) / _frameRate);
            AudioStream.SetStreamPaused(!IsPlaying);
        }

        EmitSignalPlaybackStarted();
    }

    public void Pause()
    {
        IsPlaying = false;

        if (EnableAudio && AudioStream.Stream != null)
            AudioStream.SetStreamPaused(true);

        EmitSignalPlaybackPaused();
    }

    private void _SyncAudioVideo()
    {
        if (_timeElapsed < 1.20f)
            return;
        else if (EnableAudio && AudioStream.Stream != null && AudioStream.Stream.GetLength() != 0)
        {
            float audioOffset = AudioStream.GetPlaybackPosition() + (float)AudioServer.GetTimeSinceLastMix() - (CurrentFrame + 1) / _frameRate;

            if (Mathf.Abs(audioOffset) > AUDIO_OFFSET_THRESHOLD)
            {
                if (Debug) GD.Print("Audio Sync: time correction: ", audioOffset);
                AudioStream.Seek((CurrentFrame + 1) / _frameRate);
                AudioStream.PitchScale = PlaybackSpeed;
            }
            else if (AudioSpeedToSync)
            {
                if (Mathf.IsZeroApprox(AudioStream.PitchScale - PlaybackSpeed))
                {
                    if (audioOffset > AUDIO_OFFSET_THRESHOLD / 2)
                    {
                        AudioStream.PitchScale = PlaybackSpeed * 0.99f;
                        if (Debug) GD.Print("Audio Sync: slow down");
                    }
                    else if (audioOffset < -AUDIO_OFFSET_THRESHOLD / 2)
                    {
                        AudioStream.PitchScale = PlaybackSpeed * 1.01f;
                        if (Debug) GD.Print("Audio Sync: speed up");
                    }
                }
                else
                {
                    if (!((AudioStream.PitchScale > PlaybackSpeed) != (audioOffset < 0)))
                    {
                        AudioStream.PitchScale = PlaybackSpeed;
                        if (Debug) GD.Print("Audio Sync: back to normal");
                    }
                }
            }
        }
    }
    #endregion

    #region Getters
    public int GetVideoFrameCount() => _frameCount;
    public float GetVideoFramerate() => _frameRate;
    public int GetVideoLength() => (int)(_frameCount / _frameRate);
    public float GetVideoLengthFloat() => _frameCount / _frameRate;
    public int GetCurrentPlaybackPosition() => (int)(CurrentFrame / _frameRate);
    public float GetCurrentPlaybackPositionFloat() => CurrentFrame / _frameRate;
    public int GetVideoRotation() => _rotation;
    public bool IsVideoAlpha() => _hasAlpha;

    public string GetStreamTitle(int stream)
    {
        if (!IsOpen())
        {
            GD.PrintErr("Video is not open!");
            return "";
        }
        var meta = Video.GetStreamMetadata(stream);
        return meta.ContainsKey("title") ? meta["title"].AsString() : "";
    }

    public string GetStreamLanguage(int stream)
    {
        if (!IsOpen())
        {
            GD.PrintErr("Video is not open!");
            return "";
        }
        var meta = Video.GetStreamMetadata(stream);
        return meta.ContainsKey("language") ? meta["language"].AsString() : "";
    }

    public bool IsOpen() => Video != null && Video.IsOpen();

    private ImageTexture GetImgTex(byte[] imageData, int width, int height, bool r8 = true)
    {
        var format = r8 ? Image.Format.R8 : Image.Format.Rg8;
        var image = Image.CreateFromData(width, height, false, format, imageData);
        return ImageTexture.CreateFromImage(image);
    }
    #endregion

    #region Setters

    public void SetCurrentFrame(int frame)
    {
        _currentFrame = frame;
        EmitSignalFrameChanged(CurrentFrame);
    }

    public void SetFrameImage()
    {
        RenderingServer.Texture2DUpdate(_yTexture.GetRid(), Video.GetYData(), 0);
        RenderingServer.Texture2DUpdate(_uTexture.GetRid(), Video.GetUData(), 0);
        RenderingServer.Texture2DUpdate(_vTexture.GetRid(), Video.GetVData(), 0);

        if (_hasAlpha)
            RenderingServer.Texture2DUpdate(_aTexture.GetRid(), Video.GetAData(), 0);
    }

    public void SetPlaybackSpeed(float speed)
    {
        if (PlaybackSpeedOverride == Vector2.Zero)
            _playbackSpeed = Mathf.Clamp(speed, 0.5f, 2f);
        else
            _playbackSpeed = Mathf.Clamp(speed, PlaybackSpeedOverride.X, PlaybackSpeedOverride.Y);

        _timeFrame = (1.0f / _frameRate) / PlaybackSpeed;

        if (EnableAudio && AudioStream.Stream != null)
        {
            AudioStream.PitchScale = PlaybackSpeed;
            _SetPitchAdjust();

            if (IsPlaying)
            {
                AudioStream.Play(CurrentFrame * (1.0f / _frameRate));
            }
        }
    }

    public void SetPitchAdjust(bool newPitchValue)
    {
        _pitchAdjust = newPitchValue;
        _SetPitchAdjust();
    }

    private void _SetPitchAdjust()
    {
        if (PitchAdjust)
            _audioPitchEffect.PitchScale = (float)Mathf.Clamp(1.0 / PlaybackSpeed, 0.5f, 2f);
        else if (_audioPitchEffect.PitchScale != 1.0f)
        {
            _audioPitchEffect.PitchScale = 1.0f;
        }
    }

    public void SetAudioStream(int stream)
    {
        if (!IsOpen())
        {
            GD.PrintErr("Video is not open!");
            return;
        }

        if (!AudioStreams.Contains(stream))
        {
            GD.PrintErr("Invalid audio stream!");
            return;
        }

        if (EnableAudio)
        {
            OpenAudio(stream);
            if (IsPlaying && AudioStream.Stream != null && AudioStream.Stream.GetLength() != 0)
            {
                AudioStream.SetStreamPaused(false);
                AudioStream.Play(CurrentFrame / _frameRate);
                AudioStream.SetStreamPaused(!IsPlaying);
            }
        }
    }
    #endregion

    #region Misc
    public string DurationToFormattedString(float durationInSeconds)
    {
        int hours = Mathf.FloorToInt(durationInSeconds / 3600.0f);
        int minutes = Mathf.FloorToInt(durationInSeconds / 60.0f) % 60;
        int seconds = Mathf.FloorToInt(durationInSeconds) % 60;

        if (hours == 0)
            return $"{minutes:D2}:{seconds:D2}";
        return $"{hours:D2}:{minutes:D2}:{seconds:D2}";
    }

    private void OpenVideo()
    {
        if (Video.Open(Path) != (int)Error.Ok)
            GD.PrintErr("Error opening video!");
    }

    private void OpenAudio(int stream = -1)
    {
        var asff = new AudioStreamFFmpeg();
        if (asff.Open(Path, stream) != (int)Error.Ok)
            GD.PrintErr($"Failed to open AudioStreamFFmpeg for: {Path}");

        AudioStream.Stream = asff;
    }

    private void PrintStreamInfo(int[] streams)
    {
        for (int i = 0; i < streams.Length; i++)
        {
            var metadata = Video.GetStreamMetadata(streams[i]);
            string title = metadata.ContainsKey("title") ? metadata["title"].AsString() : "";
            string language = metadata.ContainsKey("language") ? metadata["language"].AsString() : "";

            if (string.IsNullOrEmpty(title))
                title = "Track " + (i + 1);
            if (!string.IsNullOrEmpty(language))
                title += $" - {language}";

            GD.Print($"- {title}");
        }
    }

    private void PrintSystemDebug()
    {
        GD.PrintRich("[b]System Info");
        GD.Print("OS name: ", OS.GetName());
        GD.Print("Distro name: ", OS.GetDistributionName());
        GD.Print("OS version: ", OS.GetVersion());
        GD.PrintRich("Memory Info:\n\t", OS.GetMemoryInfo());
        GD.Print("CPU name: ", OS.GetProcessorName());
        GD.Print("Threads count: ", OS.GetProcessorCount());
    }

    private void PrintVideoDebug()
    {
        GD.PrintRich("[b]Video debug info");
        GD.Print("Extension: ", Path.GetExtension());
        GD.Print("Resolution: ", _resolution);
        GD.Print("Actual resolution: ", Video.GetActualResolution());
        GD.Print("Pixel format: ", Video.GetPixelFormat());
        GD.Print("Color profile: ", Video.GetColorProfile());
        GD.Print("Framerate: ", _frameRate);
        GD.Print("Duration (in frames): ", _frameCount);
        GD.Print("Padding: ", _padding);
        GD.Print("Rotation: ", _rotation);
        GD.Print("Alpha: ", _hasAlpha);
        GD.Print("Full color range: ", Video.IsFullColorRange());
        GD.Print("Interlaced flag: ", Video.GetInterlaced());
        GD.Print("Using sws: ", Video.IsUsingSws());
        GD.Print("Sar: ", Video.GetSar());

        GD.PrintRich($"Video streams: [i]({VideoStreams.Length})");
        PrintStreamInfo(VideoStreams);

        if (AudioStreams.Length != 0)
        {
            GD.PrintRich($"Audio streams: [i]({AudioStreams.Length})");
            PrintStreamInfo(AudioStreams);
        }
        else if (Debug)
        {
            GD.Print("No audio streams found.");
        }

        if (SubtitleStreams.Length != 0)
        {
            GD.PrintRich($"Subtitle streams: [i]({SubtitleStreams.Length})");
            PrintStreamInfo(SubtitleStreams);
        }
        else if (Debug)
        {
            GD.Print("No subtitle streams found.");
        }

        if (Chapters.Count != 0)
        {
            GD.PrintRich($"Chapters: [i]({Chapters.Count})");
            for (int i = 0; i < Chapters.Count; i++)
            {
                string title = Chapters[i].Title;
                if (string.IsNullOrEmpty(title))
                    title = "Chapter " + (i + 1);

                GD.Print($"- {DurationToFormattedString(Chapters[i].Start)}-{DurationToFormattedString(Chapters[i].End)} - {title}");
            }
        }
        else
        {
            GD.Print("No chapters found.");
        }
    }
    #endregion
}
