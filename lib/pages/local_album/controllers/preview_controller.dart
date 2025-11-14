// controllers/preview_controller.dart
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../models/file_item.dart';

/// 预览控制器 - 负责媒体预览和视频播放
class PreviewController {
  bool _showPreview = false;
  int _previewIndex = -1;
  List<FileItem> _mediaItems = [];

  // 视频播放器相关
  Player? _videoPlayer;
  VideoController? _videoController;
  bool _isPlaying = false;

  bool get showPreview => _showPreview;
  int get previewIndex => _previewIndex;
  List<FileItem> get mediaItems => List.unmodifiable(_mediaItems);
  VideoController? get videoController => _videoController;
  bool get isPlaying => _isPlaying;

  /// 打开预览
  void openPreview(int index, List<FileItem> allFiles) {
    // 获取所有媒体文件（图片和视频）
    final mediaFiles = allFiles.where((item) =>
    item.type == FileItemType.image || item.type == FileItemType.video
    ).toList();

    // 找到当前项在媒体列表中的位置
    final currentItem = allFiles[index];
    final mediaIndex = mediaFiles.indexOf(currentItem);

    if (mediaIndex >= 0) {
      _showPreview = true;
      _previewIndex = mediaIndex;
      _mediaItems = mediaFiles;
    }
  }

  /// 关闭预览
  void closePreview() {
    disposeVideoPlayer();
    _showPreview = false;
    _previewIndex = -1;
    _mediaItems = [];
  }

  /// 切换到上一个媒体
  void previousMedia() {
    if (_previewIndex > 0) {
      _previewIndex--;
      return;
    }
  }

  /// 切换到下一个媒体
  void nextMedia() {
    if (_previewIndex < _mediaItems.length - 1) {
      _previewIndex++;
      return;
    }
  }

  /// 获取当前预览的文件
  FileItem? getCurrentPreviewItem() {
    if (_previewIndex >= 0 && _previewIndex < _mediaItems.length) {
      return _mediaItems[_previewIndex];
    }
    return null;
  }

  /// 是否是视频
  bool isCurrentItemVideo() {
    final item = getCurrentPreviewItem();
    return item?.type == FileItemType.video;
  }

  /// 初始化视频播放器
  void initVideoPlayer(String path, Function(bool) onPlayingChanged) {
    disposeVideoPlayer();

    _videoPlayer = Player();
    _videoController = VideoController(_videoPlayer!);

    _videoPlayer!.open(Media('file:///$path'));
    _videoPlayer!.stream.playing.listen((playing) {
      _isPlaying = playing;
      onPlayingChanged(playing);
    });
  }

  /// 释放视频播放器
  void disposeVideoPlayer() {
    _videoPlayer?.dispose();
    _videoPlayer = null;
    _videoController = null;
    _isPlaying = false;
  }

  /// 切换播放/暂停
  void togglePlayPause() {
    _videoPlayer?.playOrPause();
  }

  /// 重置状态
  void reset() {
    closePreview();
  }

  /// 清理资源
  void dispose() {
    disposeVideoPlayer();
  }
}