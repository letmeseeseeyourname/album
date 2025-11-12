import 'dart:io';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../manager/video_player_manager.dart';

/// 预览面板组件 - 显示文件的详细预览
class PreviewPanel extends StatefulWidget {
  final FileItem item;
  final VoidCallback onClose;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PreviewPanel({
    super.key,
    required this.item,
    required this.onClose,
    this.onPrevious,
    this.onNext,
  });

  @override
  State<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<PreviewPanel> {
  final VideoPlayerManager _videoManager = VideoPlayerManager();
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  @override
  void didUpdateWidget(PreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _initializePreview();
    }
  }

  @override
  void dispose() {
    _videoManager.dispose();
    super.dispose();
  }

  Future<void> _initializePreview() async {
    if (widget.item.type == FileItemType.video) {
      setState(() => _isVideoInitialized = false);

      try {
        await _videoManager.initialize(widget.item.path);
        if (mounted) {
          setState(() => _isVideoInitialized = true);
        }
      } catch (e) {
        debugPrint('Error initializing video: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('视频加载失败: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      await _videoManager.dispose();
      setState(() => _isVideoInitialized = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 400,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildPreviewContent(),
          ),
          _buildFileInfo(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.item.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.onPrevious != null)
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: widget.onPrevious,
              tooltip: '上一个',
            ),
          if (widget.onNext != null)
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: widget.onNext,
              tooltip: '下一个',
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
            tooltip: '关闭预览',
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent() {
    return Container(
      color: Colors.black12,
      child: Stack(
        children: [
          Center(
            child: _buildMediaPreview(),
          ),
          if (widget.item.type == FileItemType.video && _isVideoInitialized)
            _buildVideoControls(),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    switch (widget.item.type) {
      case FileItemType.image:
        return Image.file(
          File(widget.item.path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  '无法加载图片',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            );
          },
        );

      case FileItemType.video:
        if (_isVideoInitialized) {
          return _videoManager.buildVideoPlayer(
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
          );
        } else {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '正在加载视频...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          );
        }

      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              '不支持预览此类型文件',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        );
    }
  }

  Widget _buildVideoControls() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: _videoManager.buildVideoControls(),
    );
  }

  Widget _buildFileInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoRow('类型', _getFileTypeText()),
          const SizedBox(height: 8),
          if (widget.item.size != null)
            _buildInfoRow('大小', _formatFileSize(widget.item.size!)),
          const SizedBox(height: 8),
          _buildInfoRow('路径', widget.item.path, isPath: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPath = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
            maxLines: isPath ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getFileTypeText() {
    switch (widget.item.type) {
      case FileItemType.image:
        return '图片';
      case FileItemType.video:
        return '视频';
      case FileItemType.folder:
        return '文件夹';
      default:
        return '未知';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}