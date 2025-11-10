// widgets/preview_panel.dart - 修复按键失效问题
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:io';
import '../controllers/preview_controller.dart';
import '../models/file_item.dart';

/// 预览面板 - 修复版本
class PreviewPanel extends StatefulWidget {
  final PreviewController controller;

  const PreviewPanel({
    super.key,
    required this.controller,
  });

  @override
  State<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<PreviewPanel> {
  PreviewController get ctrl => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // 顶部工具栏 - 使用 Material 确保按钮可点击
          _buildTopBar(),

          // 预览内容区域
          Expanded(
            child: _buildPreviewContent(),
          ),

          // 底部信息栏（视频时显示播放控制）
          if (ctrl.isVideo) _buildVideoControls(),
        ],
      ),
    );
  }

  /// 构建顶部工具栏
  Widget _buildTopBar() {
    return Material(
      color: const Color(0xFF2C2C2C),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 文件名
            Expanded(
              child: Text(
                ctrl.currentItem?.name ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 16),

            // 计数器
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${ctrl.previewIndex + 1} / ${ctrl.mediaItems.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // 关闭按钮 - 使用 Material 包裹确保可点击
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  debugPrint('关闭预览按钮被点击');
                  ctrl.closePreview();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建预览内容
  Widget _buildPreviewContent() {
    final item = ctrl.currentItem;
    if (item == null) {
      return const Center(
        child: Text(
          '无法加载预览',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Stack(
      children: [
        // 主内容区域
        Center(
          child: ctrl.isVideo ? _buildVideoPlayer() : _buildImageViewer(item),
        ),

        // 左侧切换按钮
        if (ctrl.canGoPrevious)
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavigationButton(
                icon: Icons.chevron_left,
                onPressed: () {
                  debugPrint('上一个按钮被点击');
                  ctrl.previousMedia();
                },
              ),
            ),
          ),

        // 右侧切换按钮
        if (ctrl.canGoNext)
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavigationButton(
                icon: Icons.chevron_right,
                onPressed: () {
                  debugPrint('下一个按钮被点击');
                  ctrl.nextMedia();
                },
              ),
            ),
          ),
      ],
    );
  }

  /// 构建导航按钮
  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  /// 构建图片查看器
  Widget _buildImageViewer(FileItem item) {
    final file = File(item.path);
    if (!file.existsSync()) {
      return const Center(
        child: Text(
          '图片文件不存在',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text(
                  '图片加载失败',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建视频播放器
  Widget _buildVideoPlayer() {
    if (ctrl.videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Video(
      controller: ctrl.videoController!,
      controls: NoVideoControls,
    );
  }

  /// 构建视频控制栏
  Widget _buildVideoControls() {
    return Material(
      color: const Color(0xFF2C2C2C),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // 播放/暂停按钮
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  debugPrint('播放/暂停按钮被点击');
                  ctrl.togglePlayPause();
                },
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    ctrl.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // 音量控制（示例）
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.volume_up,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
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
                        value: 0.8, // 这里应该从控制器获取实际音量
                        onChanged: (value) {
                          ctrl.setVolume(value);
                        },
                        activeColor: Colors.white,
                        inactiveColor: Colors.white30,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // 播放速度（可选）
            Material(
              color: Colors.transparent,
              child: PopupMenuButton<double>(
                icon: const Icon(
                  Icons.speed,
                  color: Colors.white70,
                ),
                onSelected: (speed) {
                  ctrl.setPlaybackSpeed(speed);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                  const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                  const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                  const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                  const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                  const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}