// widgets/media_viewer_page.dart
// 使用 media_kit 替代 video_player，完美支持 Windows 桌面
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/file_item.dart';

class MediaViewerPage extends StatefulWidget {
  final List<FileItem> mediaItems; // 所有媒体文件
  final int initialIndex; // 初始显示的索引

  const MediaViewerPage({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
  });

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late int currentIndex;
  Player? _player;
  VideoController? _videoController;
  bool _isVideoInitialized = false;
  bool _isControlsVisible = true;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  double _volume = 100.0;
  bool _isFullScreen = false;

  // 鼠标悬停状态
  bool _isLeftHovered = false;
  bool _isRightHovered = false;
  bool _isTopHovered = false;

  // 拖动相关
  Offset _dragOffset = Offset.zero;
  Offset _imagePosition = Offset.zero;
  double _scale = 1.0;
  double _baseScale = 1.0;

  // 视频状态
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _loadCurrentMedia();

    // 自动隐藏控制栏
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  void _loadCurrentMedia() {
    final currentItem = widget.mediaItems[currentIndex];

    if (currentItem.type == FileItemType.video) {
      _initializeVideo(currentItem.path);
    } else {
      _disposeVideo();
      _resetImageTransform();
    }
  }

  void _initializeVideo(String path) async {
    await _disposeVideo();

    try {
      // 创建播放器
      _player = Player();
      _videoController = VideoController(_player!);

      // 监听播放状态
      _player!.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying = playing;
          });
        }
      });

      // 监听播放位置
      _player!.stream.position.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      // 监听时长
      _player!.stream.duration.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      });

      // 打开视频文件
      await _player!.open(Media(path));

      setState(() {
        _isVideoInitialized = true;
      });

      // 自动播放
      await _player!.play();
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法加载视频：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disposeVideo() async {
    if (_player != null) {
      await _player!.dispose();
      _player = null;
      _videoController = null;
      _isVideoInitialized = false;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    }
  }

  void _resetImageTransform() {
    setState(() {
      _imagePosition = Offset.zero;
      _dragOffset = Offset.zero;
      _scale = 1.0;
      _baseScale = 1.0;
    });
  }

  void _navigateToPrevious() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        _loadCurrentMedia();
      });
    }
  }

  void _navigateToNext() {
    if (currentIndex < widget.mediaItems.length - 1) {
      setState(() {
        currentIndex++;
        _loadCurrentMedia();
      });
    }
  }

  void _togglePlayPause() {
    if (_player != null && _isVideoInitialized) {
      if (_isPlaying) {
        _player!.pause();
      } else {
        _player!.play();
      }
    }
  }

  void _changePlaybackSpeed(double speed) {
    if (_player != null && _isVideoInitialized) {
      _player!.setRate(speed);
      setState(() {
        _playbackSpeed = speed;
      });
    }
  }

  void _changeVolume(double volume) {
    if (_player != null && _isVideoInitialized) {
      _player!.setVolume(volume);
      setState(() {
        _volume = volume;
      });
    }
  }

  void _seekTo(Duration position) {
    if (_player != null && _isVideoInitialized) {
      _player!.seek(position);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.mediaItems[currentIndex];
    final isVideo = currentItem.type == FileItemType.video;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (isVideo) {
            setState(() {
              _isControlsVisible = !_isControlsVisible;
            });
          }
        },
        child: MouseRegion(
          onHover: (event) {
            final width = MediaQuery.of(context).size.width;
            final height = MediaQuery.of(context).size.height;

            setState(() {
              _isLeftHovered = event.position.dx < 100;
              _isRightHovered = event.position.dx > width - 100;
              _isTopHovered = event.position.dy < 80;
            });
          },
          onExit: (_) {
            setState(() {
              _isLeftHovered = false;
              _isRightHovered = false;
              _isTopHovered = false;
            });
          },
          child: Stack(
            children: [
              // 主内容区域
              Center(
                child: isVideo
                    ? _buildVideoPlayer()
                    : _buildImageViewer(currentItem),
              ),

              // 顶部控制栏 (返回按钮)
              if (_isTopHovered || !isVideo)
                _buildTopBar(),

              // 左侧导航按钮
              if (_isLeftHovered && currentIndex > 0)
                _buildLeftButton(),

              // 右侧导航按钮
              if (_isRightHovered && currentIndex < widget.mediaItems.length - 1)
                _buildRightButton(),

              // 视频控制栏
              if (isVideo && _isControlsVisible && _isVideoInitialized)
                _buildVideoControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageViewer(FileItem item) {
    return GestureDetector(
      onScaleStart: (details) {
        _baseScale = _scale;
        _dragOffset = _imagePosition;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_baseScale * details.scale).clamp(0.5, 3.0);
          _imagePosition = _dragOffset + details.focalPointDelta;
        });
      },
      child: Transform.translate(
        offset: _imagePosition,
        child: Transform.scale(
          scale: _scale,
          child: Image.file(
            File(item.path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(
                  Icons.broken_image,
                  size: 100,
                  color: Colors.white54,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isVideoInitialized || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Video(
      controller: _videoController!,
      controls: NoVideoControls, // 使用自定义控制栏
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.mediaItems[currentIndex].name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white, size: 24),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftButton() {
    return Positioned(
      left: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 40),
            onPressed: _navigateToPrevious,
          ),
        ),
      ),
    );
  }

  Widget _buildRightButton() {
    return Positioned(
      right: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 40),
            onPressed: _navigateToNext,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: _position.inMilliseconds.toDouble(),
                    max: _duration.inMilliseconds.toDouble() > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                    onChanged: (value) {
                      _seekTo(Duration(milliseconds: value.toInt()));
                    },
                    activeColor: Colors.white,
                    inactiveColor: Colors.white30,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),

            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 播放/暂停
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: _togglePlayPause,
                ),

                const SizedBox(width: 32),

                // 倍速选择
                PopupMenuButton<double>(
                  icon: Row(
                    children: [
                      Text(
                        '${_playbackSpeed}x',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                  onSelected: _changePlaybackSpeed,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                    const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                    const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                    const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                    const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                    const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                  ],
                ),

                const SizedBox(width: 16),

                // 音量控制
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _volume == 0 ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        _changeVolume(_volume == 0 ? 100.0 : 0.0);
                      },
                    ),
                    SizedBox(
                      width: 100,
                      child: Slider(
                        value: _volume,
                        max: 100,
                        onChanged: _changeVolume,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white30,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // 全屏按钮
                IconButton(
                  icon: Icon(
                    _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _isFullScreen = !_isFullScreen;
                    });
                    if (_isFullScreen) {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
                    } else {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}