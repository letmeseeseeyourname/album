import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 视频播放器管理器 - 负责视频播放的初始化、控制和资源释放
class VideoPlayerManager {
  Player? _player;
  VideoController? _controller;
  bool _isPlaying = false;

  Player? get player => _player;
  VideoController? get controller => _controller;
  bool get isPlaying => _isPlaying;

  /// 初始化视频播放器
  Future<void> initialize(String videoPath) async {
    // 先释放之前的播放器
    await dispose();

    _player = Player();
    _controller = VideoController(_player!);

    await _player!.open(Media(videoPath));
    await _player!.play();
    _isPlaying = true;
  }

  /// 播放视频
  Future<void> play() async {
    if (_player != null) {
      await _player!.play();
      _isPlaying = true;
    }
  }

  /// 暂停视频
  Future<void> pause() async {
    if (_player != null) {
      await _player!.pause();
      _isPlaying = false;
    }
  }

  /// 切换播放/暂停状态
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// 停止视频
  Future<void> stop() async {
    if (_player != null) {
      await _player!.stop();
      _isPlaying = false;
    }
  }

  /// 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    if (_player != null) {
      await _player!.seek(position);
    }
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    if (_player != null) {
      await _player!.setVolume(volume * 100);
    }
  }

  /// 释放播放器资源
  Future<void> dispose() async {
    if (_player != null) {
      await _player!.stop();
      await _player!.dispose();
      _player = null;
      _controller = null;
      _isPlaying = false;
    }
  }

  /// 构建视频播放器组件
  Widget buildVideoPlayer({
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    if (_controller == null) {
      return const Center(
        child: Text('视频播放器未初始化'),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Video(
        controller: _controller!,
        fit: fit,
      ),
    );
  }

  /// 构建视频控制栏
  Widget buildVideoControls({
    VoidCallback? onClose,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: togglePlayPause,
          ),
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.white),
            onPressed: stop,
          ),
          const Spacer(),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}