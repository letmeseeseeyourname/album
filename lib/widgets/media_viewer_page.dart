// widgets/media_viewer_page.dart
// 使用 media_kit 替代 video_player，完美支持 Windows 桌面
// 修复版本：解决信息弹窗动画和播放速率选择崩溃问题
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
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

  // 修复后的播放速率更改方法
  void _changePlaybackSpeed(double speed) {
    // 立即更新播放器速率
    if (_player != null && _isVideoInitialized) {
      _player!.setRate(speed);
    }

    // 延迟更新 UI 状态，避免在 PopupMenu 关闭时调用 setState 导致崩溃
    // 使用较长的延迟确保 PopupMenu 完全关闭
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _playbackSpeed = speed;
        });
      }
    });
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

  void _toggleFullScreen() async {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      // 进入全屏
      await windowManager.setFullScreen(true);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      // 退出全屏
      await windowManager.setFullScreen(false);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // 修复后的信息弹窗方法 - 带动画效果
  void _showMediaInfo() {
    final currentItem = widget.mediaItems[currentIndex];
    final file = File(currentItem.path);
    final fileStats = file.statSync();

    showGeneralDialog(
      context: context,
      barrierDismissible: true, // ✅ 点击外部区域关闭
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.01), // 半透明遮罩
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _MediaInfoDialog(
          item: currentItem,
          fileSize: fileStats.size,
          animation: animation,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // 组合动画：滑动 + 淡入淡出
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, -1), // 从顶部滑入
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
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
            // 可拖动的标题区域
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) async {
                  // 开始拖动窗口
                  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
                    await windowManager.startDragging();
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.move, // 显示移动光标
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white, size: 24),
              onPressed: _showMediaInfo,
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
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.3),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: _position.inMilliseconds.toDouble(),
                          max: _duration.inMilliseconds.toDouble() > 0
                              ? _duration.inMilliseconds.toDouble()
                              : 1.0,
                          onChanged: (value) {
                            _seekTo(Duration(milliseconds: value.toInt()));
                          },
                          activeColor: Colors.white,
                          inactiveColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 控制按钮行
                Row(
                  children: [
                    // 左侧：播放/暂停按钮
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _togglePlayPause,
                    ),

                    const SizedBox(width: 8),

                    // 音量控制
                    IconButton(
                      icon: Icon(
                        _volume == 0 ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () {
                        _changeVolume(_volume == 0 ? 100.0 : 0.0);
                      },
                    ),
                    SizedBox(
                      width: 80,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10,
                          ),
                        ),
                        child: Slider(
                          value: _volume,
                          max: 100,
                          onChanged: _changeVolume,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // 右侧：倍速和全屏
                    _buildSpeedSelector(),

                    const SizedBox(width: 8),

                    // 全屏按钮
                    IconButton(
                      icon: Icon(
                        _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: _toggleFullScreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 修复后的播放速率选择器
  Widget _buildSpeedSelector() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    return PopupMenuButton<double>(
      key: ValueKey(_playbackSpeed), // 添加 key 防止重建问题
      tooltip: '播放速度',
      icon: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_playbackSpeed}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
      color: Colors.grey[900],
      elevation: 8,
      offset: const Offset(0, -10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      // ✅ 关键修复：延迟执行 setState
      onSelected: (speed) {
        // 立即更新播放器速率（不触发 UI 重建）
        if (_player != null && _isVideoInitialized) {
          _player!.setRate(speed);
        }

        // 延迟更新 UI 状态，确保 PopupMenu 完全关闭后再 setState
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            setState(() {
              _playbackSpeed = speed;
            });
          }
        });
      },
      itemBuilder: (BuildContext context) {
        return speeds.map((speed) {
          final isSelected = (_playbackSpeed - speed).abs() < 0.01;
          return PopupMenuItem<double>(
            value: speed,
            height: 42,
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    '${speed}x',
                    style: TextStyle(
                      color: isSelected ? Colors.blue[300] : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(
                    Icons.check,
                    color: Colors.blue[300],
                    size: 18,
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

// 媒体信息弹框 - 带动画效果
class _MediaInfoDialog extends StatelessWidget {
  final FileItem item;
  final int fileSize;
  final Animation<double> animation;

  const _MediaInfoDialog({
    required this.item,
    required this.fileSize,
    required this.animation,
  });

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  String _getFileExtension() {
    final name = item.name;
    final lastDot = name.lastIndexOf('.');
    if (lastDot != -1 && lastDot < name.length - 1) {
      return name.substring(lastDot + 1).toUpperCase();
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: const EdgeInsets.only(top: 80, right: 20),
        width: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('名称', item.name),
            _buildInfoRow('大小', _formatFileSize(fileSize)),
            _buildInfoRow('类型', _getFileExtension()),
            // 如果有分辨率信息
            // if (item.metadata != null && item.metadata!['resolution'] != null)
            //   _buildInfoRow('分辨率', item.metadata!['resolution']!),
            // // 如果有拍摄时间
            // if (item.metadata != null && item.metadata!['captureTime'] != null)
            //   _buildInfoRow('拍摄时间', item.metadata!['captureTime']!),
            // // 如果有拍摄设备
            // if (item.metadata != null && item.metadata!['device'] != null)
            //   _buildInfoRow('拍摄设备', item.metadata!['device']!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}