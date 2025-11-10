// controllers/preview_controller.dart
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/file_item.dart';

/// 预览控制器 - 管理媒体预览和视频播放
class PreviewController extends ChangeNotifier {
  // 预览状态
  bool _showPreview = false;

  bool get showPreview => _showPreview;

  int _previewIndex = -1;

  int get previewIndex => _previewIndex;

  List<FileItem> _mediaItems = [];

  List<FileItem> get mediaItems => _mediaItems;

  // 视频播放器
  Player? _videoPlayer;

  Player? get videoPlayer => _videoPlayer;

  VideoController? _videoController;

  VideoController? get videoController => _videoController;

  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// 获取当前预览的文件
  FileItem? get currentItem {
    if (_previewIndex >= 0 && _previewIndex < _mediaItems.length) {
      return _mediaItems[_previewIndex];
    }
    return null;
  }

  /// 是否为视频
  bool get isVideo => currentItem?.type == FileItemType.video;

  /// 是否可以切换到上一个
  bool get canGoPrevious => _previewIndex > 0;

  /// 是否可以切换到下一个
  bool get canGoNext => _previewIndex < _mediaItems.length - 1;

  /// 打开预览
  void openPreview(List<FileItem> allItems, int itemIndex) {
    // 获取所有媒体文件
    _mediaItems = allItems
        .where(
          (item) =>
              item.type == FileItemType.image ||
              item.type == FileItemType.video,
        )
        .toList();

    // 找到当前项在媒体列表中的位置
    if (itemIndex >= 0 && itemIndex < allItems.length) {
      final currentItem = allItems[itemIndex];
      final mediaIndex = _mediaItems.indexOf(currentItem);

      if (mediaIndex >= 0) {
        _showPreview = true;
        _previewIndex = mediaIndex;
        notifyListeners();

        _loadPreviewMedia();
      }
    }
  }

  /// 关闭预览
  void closePreview() {
    _disposeVideoPlayer();
    _showPreview = false;
    _previewIndex = -1;
    _mediaItems = [];
    notifyListeners();
  }

  /// 切换到上一个媒体
  void previousMedia() {
    if (canGoPrevious) {
      _previewIndex--;
      notifyListeners();
      _loadPreviewMedia();
    }
  }

  /// 切换到下一个媒体
  void nextMedia() {
    if (canGoNext) {
      _previewIndex++;
      notifyListeners();
      _loadPreviewMedia();
    }
  }

  /// 加载预览媒体
  void _loadPreviewMedia() {
    if (currentItem == null) return;

    if (isVideo) {
      _initVideoPlayer(currentItem!.path);
    } else {
      _disposeVideoPlayer();
    }
  }

  /// 初始化视频播放器
  void _initVideoPlayer(String path) {
    _disposeVideoPlayer();

    _videoPlayer = Player();
    _videoController = VideoController(_videoPlayer!);

    _videoPlayer!.open(Media('file:///$path'));
    _videoPlayer!.stream.playing.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });
  }

  /// 释放视频播放器
  void _disposeVideoPlayer() {
    _videoPlayer?.dispose();
    _videoPlayer = null;
    _videoController = null;
    _isPlaying = false;
  }

  /// 切换播放/暂停
  void togglePlayPause() {
    _videoPlayer?.playOrPause();
  }

  /// 播放
  void play() {
    _videoPlayer?.play();
  }

  /// 暂停
  void pause() {
    _videoPlayer?.pause();
  }

  /// 设置音量
  void setVolume(double volume) {
    _videoPlayer?.setVolume(volume.clamp(0.0, 1.0));
  }

  /// 设置播放速度
  void setPlaybackSpeed(double speed) {
    _videoPlayer?.setRate(speed);
  }

  @override
  void dispose() {
    _disposeVideoPlayer();
    super.dispose();
  }
}
