using Godot;
using System;
using System.Linq;
using Godot.Collections;

public partial class Main : Control
{
    private static readonly string[] VideoExtensions =
    [
        "webm", "mkv", "flv", "vob", "ogv", "ogg", "mng", "avi", "mts", "m2ts", "ts", "mov",
        "qt", "wmv", "yuv", "rm", "rmvb", "viv", "asf", "amv", "mp4", "m4p", "mp2", "mpe",
        "mpv", "mpg", "mpeg", "m2v", "m4v", "svi", "3gp", "3g2", "mxf", "roq", "nsv", "flv",
        "f4v", "f4p", "f4a", "f4b", "gif"
    ];

    private VideoPlayback _videoPlayback;
    private HSlider _timeline;
    private TextureButton _playPauseButton;
    private Label _currentFrameValue;
    private Label _editorFpsValue;
    private Label _maxFrameValue;
    private Label _fpsValue;
    private SpinBox _speedSpinBox;
    private OptionButton _audioTrackOption;
    private Panel _loadingScreen;

    private Array<Texture2D> _icons = new Array<Texture2D>();

    private bool _isDragging = false;
    private bool _wasPlaying = false;

    public override void _Ready()
    {
        _videoPlayback = GetNode<VideoPlayback>("%VideoPlayback");
        _timeline = GetNode<HSlider>("%Timeline");
        _playPauseButton = GetNode<TextureButton>("%PlayPauseButton");
        _currentFrameValue = GetNode<Label>("%CurrentFrameValue");
        _editorFpsValue = GetNode<Label>("%EditorFPSValue");
        _maxFrameValue = GetNode<Label>("%MaxFrameValue");
        _fpsValue = GetNode<Label>("%FPSValue");
        _speedSpinBox = GetNode<SpinBox>("%SpeedSpinBox");
        _audioTrackOption = GetNode<OptionButton>("%AudioTrackOption");
        _loadingScreen = GetNode<Panel>("LoadingPanel");
        
        _icons.Add(GD.Load<Texture2D>("res://icons/play_arrow_48dp_FILL1_wght400_GRAD0_opsz48.png"));
        _icons.Add(GD.Load<Texture2D>("res://icons/pause_48dp_FILL1_wght400_GRAD0_opsz48.png"));

        if (OS.GetCmdlineArgs().Length > 1)
            OpenVideo(OS.GetCmdlineArgs()[1]);
        if (OS.GetName().ToLower() == "android" && OS.RequestPermissions())
            GD.Print("Permissions already granted!");

        GetWindow().FilesDropped += OnVideoDrop;
        _videoPlayback.VideoLoaded += OnAfterVideoOpen;
        _videoPlayback.FrameChanged += OnFrameChanged;

        _audioTrackOption.ItemSelected += OnAudioTrackItemSelected;

        _loadingScreen.Visible = false;
        _speedSpinBox.Value = _videoPlayback.PlaybackSpeed;
    }

    public override void _Input(InputEvent @event)
    {
        if (@event.IsActionReleased("play_pause"))
            OnPlayPauseButtonPressed();
    }

    public void OnVideoDrop(string[] filePaths)
    {
        if (!VideoExtensions.Contains(filePaths[0].GetExtension().ToLower()))
        {
            GD.Print("Not a valid video file!");
            return;
        }

        foreach (var path in filePaths)
        {
            if (!path.EndsWith(".tscn"))
            {
                OpenVideo(path);
                return;
            }
        }
    }

    public void OnUrlLineEditTextSubmitted(string path)
    {
        OpenVideo(path);
    }

    public void OnFrameChanged(int value)
    {
        _timeline.Value = value;
        _currentFrameValue.Text = $"{value}";
        _editorFpsValue.Text = $"{Engine.GetFramesPerSecond()}";
    }

    public void OpenVideo(string path)
    {
        _timeline.Value = 0;
        _loadingScreen.Visible = true;
        _videoPlayback.SetVideoPath(path);
    }

    public void OnAfterVideoOpen()
    {
        if (_videoPlayback.IsOpen())
        {
            _timeline.MaxValue = _videoPlayback.GetVideoFrameCount() - 1;
            _playPauseButton.TextureNormal = _icons[0];
            _maxFrameValue.Text = $"{_videoPlayback.GetVideoFrameCount()}";
            _fpsValue.Text = $"{_videoPlayback.GetVideoFramerate()}".Left(5);
            _loadingScreen.Visible = false;

            _audioTrackOption.Clear();

            for (int i = 0; i < _videoPlayback.AudioStreams.Length; i++)
            {
                string title = _videoPlayback.GetStreamTitle(_videoPlayback.AudioStreams[i]);
                string lang = _videoPlayback.GetStreamLanguage(_videoPlayback.AudioStreams[i]);

                if (string.IsNullOrEmpty(title))
                    title = "Track " + (i + 1);
                if (string.IsNullOrEmpty(lang))
                    _audioTrackOption.AddItem(title);
                else
                    _audioTrackOption.AddItem(title + " - " + lang);
            }
        }
    }

    public void OnPlayPauseButtonPressed()
    {
        if (_videoPlayback.IsOpen())
        {
            if (_videoPlayback.IsPlaying)
            {
                _videoPlayback.Pause();
                _playPauseButton.TextureNormal = _icons[0];
            }
            else
            {
                _videoPlayback.Play();
                _playPauseButton.TextureNormal = _icons[1];
            }
        }
        
        _playPauseButton.ReleaseFocus();
    }

    public void OnTimelineValueChanged(float value)
    {
        if (_isDragging)
            _videoPlayback.SeekFrame((int)_timeline.Value);
    }

    public void OnTimelineDragStarted()
    {
        _isDragging = true;
        _wasPlaying = _videoPlayback.IsPlaying;
        _videoPlayback.Pause();
    }

    public void OnTimelineDragEnded(bool _value)
    {
        _isDragging = false;
        if (_wasPlaying)
            _videoPlayback.Play();
    }

    public void OnSpeedSpinBoxValueChanged(float value)
    {
        _videoPlayback.PlaybackSpeed = value;
    }

    public void OnLoadVideoButtonPressed()
    {
        var dialog = new FileDialog();
        
        dialog.Title = "Open Video";
        dialog.ForceNative = true;
        dialog.UseNativeDialog = true;
        dialog.Access = FileDialog.AccessEnum.Filesystem;
        dialog.FileMode = FileDialog.FileModeEnum.OpenFile;
        dialog.FileSelected += OpenVideo;

        AddChild(dialog);
        dialog.PopupCentered();
    }

    public void OnAudioTrackItemSelected(long index)
    {
        _videoPlayback.SetAudioStream(_videoPlayback.AudioStreams[index]);
    }
}
