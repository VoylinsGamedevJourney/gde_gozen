using System;
using Godot;
using Godot.Collections;

[GlobalClass, Icon("res://addons/gde_gozen/icon.webp")]
public partial class VideoPlayback : Control
{

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

    public const float PLAYBACK_SPEED_MIN = 0.25f;
    public const float PLAYBACK_SPEED_MAX = 4.0f;

    private string _path = "";

    [Export(PropertyHint.File)]
    public string Path
    {
        get => _path;
        set => SetVideoPath(value);
    }
    [Export] public bool EnableAudio = true;
    [Export] public bool EnableAutoPlay = false;

    private float _playbackSpeed = 1.0f;

    [Export(PropertyHint.Range, $"0.25,4.0,0.05")]
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

    public GoZenVideo? Video;

    public TextureRect VideoTexture = new TextureRect();
    public AudioStreamPlayer AudioStream = new AudioStreamPlayer();

    public bool IsPlaying = false;
    private int _currentFrame = 0;

    public int CurrentFrame
    {
        get => _currentFrame;
        set => SetCurrentFrame(value);
    }

    private float _timeElapsed = 0.0f;
    private float _timeFrame = 0.0f;
    private int _skippedFrames = 0;

    private int _rotation = 0;
    private int _padding = 0;
    private float _frameRate = 0.0f;
    private int _frameCount = 0;

    private Vector2I _resolution = Vector2I.Zero;
    private ShaderMaterial _shaderMaterial;

    private Array<long> _threads = [];
    private AudioEffectPitchShift _audioPitchEffect = new AudioEffectPitchShift();

    private ImageTexture _yTexture;
    private ImageTexture _uTexture;
    private ImageTexture _vTexture;

    private AudioStreamWav _currentStream;

    #region Tree Functions
    public override void _EnterTree()
    {
        _shaderMaterial = new ShaderMaterial();
        
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
        AudioServer.SetBusMute(AudioServer.BusCount - 1, false);
        
        if (Debug && OS.GetName().ToLower() != "web")
            PrintSystemDebug();
    }

    public override void _ExitTree()
    {
        if (Video != null)
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
        if (Video != null)
            Close();

        if (!IsNodeReady())
            await ToSignal(this, SignalName.Ready);
        if (!GetTree().Root.IsNodeReady())
            await ToSignal(GetTree().Root, SignalName.Ready);
        
        _currentStream = new AudioStreamWav();
        _currentStream.MixRate = 44100;
        _currentStream.Stereo = true;
        _currentStream.Format = AudioStreamWav.FormatEnum.Format16Bits;

        AudioStream.Stream = _currentStream;

        if (newPath == "" || newPath.EndsWith(".tscn"))
            return;
        if (newPath.Split(":")[0] == "uid")
            newPath = ResourceUid.GetIdPath(ResourceUid.TextToId(newPath));

        _path = newPath;
        
        Video = new GoZenVideo();
        
        if (Debug)
            Video.EnableDebug();
        else
            Video.DisableDebug();
        
        _threads.Add(WorkerThreadPool.AddTask(Callable.From(() => OpenVideo())));
        if (EnableAudio)
            _threads.Add(WorkerThreadPool.AddTask(Callable.From(() => OpenAudio())));
    }

    public void UpdateVideo(GoZenVideo video, AudioStreamWav audioStream = null)
    {
        if (Video != null)
            Close();
        
        AudioStream.Stream = audioStream;
        _UpdateVideo(video);
    }

    private void _UpdateVideo(GoZenVideo video)
    {
        Video = video;

        if (!IsOpen())
        {
            GD.PrintErr("Video isn't open!");
            return;
        }

        Image image;
        var rotation_radians = Mathf.DegToRad((float)Video.GetRotation());
        
        _padding = Video.GetPadding();
        _rotation = Video.GetRotation();
        _frameRate = Video.GetFramerate();
        _resolution = Video.GetResolution();
        _frameCount = Video.GetFrameCount();

        if (Mathf.Abs(_rotation) == 90)
            image = Image.CreateEmpty(_resolution.Y, _resolution.X, false, Image.Format.R8);
        else
            image = Image.CreateEmpty(_resolution.X, _resolution.Y, false, Image.Format.R8);

        image.Fill(Colors.Black);

        if (Debug)
            PrintVideoDebug();

        ((ImageTexture)VideoTexture.Texture).SetImage(image);
        if (Video.IsFullColorRange())
        {
            if (Video.GetInterlaced() == 0)
                _shaderMaterial.Shader = GD.Load<Shader>("res://addons/gde_gozen/shaders/yuv420p_full.gdshader");
            else
                _shaderMaterial.Shader = GD.Load<Shader>("res://addons/gde_gozen/shaders/deinterlace_yuv420p_full.gdshader");
        }
        else if (Video.GetInterlaced() == 0)
        {
            _shaderMaterial.Shader = GD.Load<Shader>("res://addons/gde_gozen/shaders/yuv420p_standard.gdshader");
            _shaderMaterial.Shader = GD.Load<VisualShader>("res://addons/gde_gozen/shaders/yuv420p_standard.tres");
            _shaderMaterial.SetShaderParameter("interlaced", Video.GetInterlaced());
        }
        else
        {
            _shaderMaterial.Shader = GD.Load<Shader>("res://addons/gde_gozen/shaders/deinterlace_yuv420p_full.gdshader");
            _shaderMaterial.SetShaderParameter("interlaced", Video.GetInterlaced());
        }

        SetColorProfile();
        
        _shaderMaterial.SetShaderParameter("resolution", Video.GetActualResolution());
        _shaderMaterial.SetShaderParameter("rotation", rotation_radians);

        IsPlaying = false;
        SetPlaybackSpeed(PlaybackSpeed);
        CurrentFrame = 0;

        if (_yTexture == null)
        {
            _yTexture = ImageTexture.CreateFromImage(Video.GetYData());
            _uTexture = ImageTexture.CreateFromImage(Video.GetUData());
            _vTexture = ImageTexture.CreateFromImage(Video.GetVData());
        }
        
        _shaderMaterial.SetShaderParameter("y_data", _yTexture);
        _shaderMaterial.SetShaderParameter("u_data", _uTexture);
        _shaderMaterial.SetShaderParameter("v_data", _vTexture);

        SeekFrame(CurrentFrame);

        EmitSignalVideoLoaded();
    }

    private void SetColorProfile(ColorProfile? colorProfile = null)
    {
        var profile = "";
        if (colorProfile != null)
            _colorProfile = colorProfile.Value;

        profile = ColorProfile switch
        {
            ColorProfile.Auto => Video.GetColorProfile(),
            ColorProfile.Bt470 => "bt470",
            ColorProfile.Bt601 => "bt601",
            ColorProfile.Bt709 => "bt709",
            ColorProfile.Bt2020 => "bt2020",
            ColorProfile.Bt2100 => "bt2100",
            _ => Video.GetColorProfile(),
        };

        switch (profile)
        {
            case "bt601":
            case "bt470":
                _shaderMaterial.SetShaderParameter("color_profile", new Vector4(1.402f, 0.344136f, 0.714136f, 1.772f));
                break;
            case "bt2020":
            case "bt2100":
                _shaderMaterial.SetShaderParameter("color_profile", new Vector4(1.4746f, 0.16455f, 0.57135f, 1.8814f));
                break;
            default:
                _shaderMaterial.SetShaderParameter("color_profile", new Vector4(1.5748f, 0.1873f, 0.4681f, 1.8556f));
                break;
        }
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

        if (EnableAudio)
        {
            AudioStream.SetStreamPaused(false);
            AudioStream.Play(CurrentFrame / _frameRate);
            AudioStream.SetStreamPaused(!IsPlaying);
        }
    }
    
    private void NextFrame(bool skip = false)
    {
        if (Video.NextFrame(skip) && !skip)
        {
            SetFrameImage();
            EmitSignalNextFrameCalled(CurrentFrame);
        }
        else if (!skip)
        {
            GD.Print("Something went wrong getting next frame!");
        }
    }

    public void Close()
    {
        if (Video != null)
        {
            if (IsPlaying)
                Pause();

            Video = null;
            _yTexture = null;
            _uTexture = null;
            _vTexture = null;
        }
    }
    #endregion
    
    #region Playback Handling

    public override void _Process(double delta)
    {
        if (IsPlaying)
        {
            _timeElapsed += (float)delta;

            if (_timeElapsed < _timeFrame)
                return;

            var skipped = 0;
            while (_timeElapsed >= _timeFrame)
            {
                _timeElapsed -= _timeFrame;
                CurrentFrame++;
                skipped++;
            }

            if (CurrentFrame >= _frameCount)
            {
                IsPlaying = !IsPlaying;

                if (EnableAudio)
                    AudioStream.SetStreamPaused(true);

                EmitSignalVideoEnded();

                if (Loop)
                {
                    SeekFrame(0);
                    Play();
                }
            }
            else
            {
                while (skipped != 1)
                {
                    NextFrame(true);
                    skipped--;
                }

                NextFrame();
            }
        }
        else if (_threads.Count != 0)
        {
            var remove = new Array<long>();
            foreach (var i in _threads)
            {
                if (WorkerThreadPool.IsTaskCompleted(i))
                {
                    WorkerThreadPool.WaitForTaskCompletion(i);
                    remove.Add(i);
                }
            }
            foreach (var i in remove)
                _threads.Remove(i);

            if (_threads.Count == 0)
            {
                _UpdateVideo(Video);
                if (EnableAutoPlay)
                    Play();
            }
        }
    }

    public void Play()
    {
        if (Video != null && IsOpen() && IsPlaying)
            return;
        IsPlaying = true;

        if (EnableAudio)
        {
            AudioStream.SetStreamPaused(false);
            AudioStream.Play((CurrentFrame + 1) / _frameRate);
            AudioStream.SetStreamPaused(!IsPlaying);
        }
        EmitSignalPlaybackStarted();
    }

    public void Pause()
    {
        if (Video != null && !IsOpen())
            return;
        IsPlaying = false;
        
        if (EnableAudio)
            AudioStream.SetStreamPaused(true);
        
        EmitSignalPlaybackPaused();
    }
    #endregion
    
    #region Getters
    public int GetVideoFrameCount() => _frameCount;
    public float GetVideoFramerate() => _frameRate;
    public int GetVideoRotation() => _rotation;

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
        _yTexture.Update(Video.GetYData());
        _uTexture.Update(Video.GetUData());
        _vTexture.Update(Video.GetVData());
    }

    public void SetPlaybackSpeed(float speed)
    {
        _playbackSpeed = Mathf.Clamp(speed, 0.5f, 2f);
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
        else if (Math.Abs(_audioPitchEffect.PitchScale - 1.0f) > 0.001)
        {
            _audioPitchEffect.PitchScale = 1.0f;
        }
    }
    #endregion
    
    #region Misc

    private void OpenVideo()
    {
        if (Video.Open(Path) != (int)Error.Ok)
            GD.PrintErr("Error opening video!");
    }

    private void OpenAudio()
    {
        var data = GoZenAudio.GetAudioData(Path);
        if (data.Length != 0)
            _currentStream.Data = data;
        else
            GD.PrintErr($"Audio data for video '{Path}' was 0!");
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
        GD.Print("Full color range: ", Video.IsFullColorRange());
        GD.Print("Using sws: ", Video.IsUsingSws());
        GD.Print("Sar: ", Video.GetSar());
    }
    #endregion
}