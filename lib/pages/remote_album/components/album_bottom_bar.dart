// album/components/album_bottom_bar.dart (优化版 - 仿照上传进度条样式)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../user/my_instance.dart';
import '../../../album/database/download_task_db_helper.dart';
import '../../../album/manager/download_queue_manager.dart';
import '../../../services/transfer_speed_service.dart';
import '../../../eventbus/event_bus.dart';
import '../../../eventbus/download_events.dart';
import '../managers/selection_manager.dart';
import '../managers/album_data_manager.dart';

/// 相册底部栏组件
class AlbumBottomBar extends StatefulWidget {
  final SelectionManager selectionManager;
  final AlbumDataManager dataManager;
  final int? userId;
  final int? groupId;

  const AlbumBottomBar({
    super.key,
    required this.selectionManager,
    required this.dataManager,
    this.userId,
    this.groupId,
  });

  @override
  State<AlbumBottomBar> createState() => _AlbumBottomBarState();
}

class _AlbumBottomBarState extends State<AlbumBottomBar> {
  final DownloadQueueManager _downloadManager = DownloadQueueManager.instance;
  final TransferSpeedService _speedService = TransferSpeedService.instance;

  bool _isInitialized = false;
  String _downloadPath = '';
  String _freeSpace = '计算中...';

  StreamSubscription? _downloadPathSubscription;
  Timer? _speedUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeDownloadManager();
    _loadDownloadPath();
    _subscribeToEvents();
    _startSpeedUpdateTimer();
  }

  void _startSpeedUpdateTimer() {
    _speedUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _hasActiveDownloads) {
        setState(() {});
      }
    });
  }

  bool get _hasActiveDownloads {
    return _downloadManager.downloadTasks.any(
          (t) => t.status == DownloadTaskStatus.downloading ||
          t.status == DownloadTaskStatus.pending,
    );
  }

  void _subscribeToEvents() {
    _downloadPathSubscription = MCEventBus.on<DownloadPathChangedEvent>().listen((event) {
      if (mounted) {
        _loadDownloadPath();
      }
    });
  }

  @override
  void dispose() {
    _downloadPathSubscription?.cancel();
    _speedUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeDownloadManager() async {
    final userId = widget.userId ?? 1;
    final groupId = widget.groupId ?? 1;

    try {
      final downloadPath = await MyInstance().getDownloadPath();
      await _downloadManager.initialize(
        userId: userId,
        groupId: groupId,
        downloadPath: downloadPath,
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('下载管理器初始化失败: $e');
    }
  }

  Future<void> _loadDownloadPath() async {
    try {
      final path = await MyInstance().getDownloadPath();
      final freeSpace = await _getDiskFreeSpace(path);

      if (mounted) {
        setState(() {
          _downloadPath = path;
          _freeSpace = freeSpace;
        });
      }
    } catch (e) {
      debugPrint('加载下载路径失败: $e');
    }
  }

// 使用 PowerShell 获取 Windows 11 磁盘剩余空间
  Future<String> _getDiskFreeSpace(String path) async {
    try {
      if (Platform.isWindows) {
        // 1. 自动提取盘符 (例如 "D:" 或 "C:")
        final driveMatch = RegExp(r'^[a-zA-Z]:').firstMatch(path);
        final driveLetter = driveMatch?.group(0) ?? "C:"; // 默认 C 盘

        // 2. 执行 PowerShell 命令 (比 wmic 更快且兼容 Win11)
        final result = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-Command',
            "(Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='$driveLetter'\").FreeSpace"
          ],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          final output = result.stdout.toString().trim();
          // 过滤非数字字符，确保转换安全
          final numericOutput = output.replaceAll(RegExp(r'[^0-9]'), '');
          final freeBytes = int.tryParse(numericOutput);

          if (freeBytes != null) {
            return _formatBytes(freeBytes);
          }
        }
      }
      return '0.0';
    } catch (e) {
      debugPrint('获取磁盘空间出错: $e');
      return '0.0';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(0)}GB';
  }

  Future<void> _changeDownloadPath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      await MyInstance().setDownloadPath(selectedDirectory);
      await _loadDownloadPath();

      if (_isInitialized) {
        final userId = widget.userId ?? 1;
        final groupId = widget.groupId ?? 1;

        await _downloadManager.initialize(
          userId: userId,
          groupId: groupId,
          downloadPath: selectedDirectory,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载路径已更改为: $selectedDirectory'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ✅ 计算下载进度信息
  Map<String, dynamic> _calculateDownloadProgress() {
    final tasks = _downloadManager.downloadTasks;

    int totalBytes = 0;
    int downloadedBytes = 0;
    int completedCount = 0;
    int totalCount = tasks.length;
    int downloadingCount = 0;
    int pendingCount = 0;
    int failedCount = 0;

    for (final task in tasks) {
      totalBytes += task.fileSize;
      downloadedBytes += task.downloadedSize;

      switch (task.status) {
        case DownloadTaskStatus.completed:
          completedCount++;
          break;
        case DownloadTaskStatus.downloading:
          downloadingCount++;
          break;
        case DownloadTaskStatus.pending:
          pendingCount++;
          break;
        case DownloadTaskStatus.failed:
          failedCount++;
          break;
        default:
          break;
      }
    }

    final progress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

    return {
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'progress': progress,
      'completedCount': completedCount,
      'totalCount': totalCount,
      'downloadingCount': downloadingCount,
      'pendingCount': pendingCount,
      'failedCount': failedCount,
      'isActive': downloadingCount > 0 || pendingCount > 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.selectionManager,
        widget.dataManager,
        _downloadManager,
      ]),
      builder: (context, child) {
        final hasSelection = widget.selectionManager.hasSelection;
        final progressInfo = _calculateDownloadProgress();
        final isDownloading = progressInfo['isActive'] as bool;
        final hasDownloads = progressInfo['totalCount'] > 0 && isDownloading;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              // ✅ 左侧：选中信息（非下载时）或 下载进度（下载时）
              if (hasSelection && !hasDownloads)
                _buildSelectionInfo(),

              // ✅ 下载中时显示进度信息
              if (hasDownloads)
                _buildDownloadProgressSection(progressInfo),

              // ✅ 中间：速度显示（下载中时居中显示）
              if (hasDownloads)
                Expanded(child: _buildSpeedIndicator()),

              // 非下载时的 Spacer
              if (!hasDownloads)
                const Spacer(),

              // ✅ 右侧：设备空间 + 下载按钮
              _buildRightSection(context, hasSelection),
            ],
          ),
        );
      },
    );
  }

  // ✅ 构建选中信息区域
  Widget _buildSelectionInfo() {
    final selectedIds = widget.selectionManager.selectedResIds;

    int totalSize = 0;
    int imageCount = 0;
    int videoCount = 0;

    for (var id in selectedIds) {
      final resources = widget.dataManager.getResourcesByIds({id});
      if (resources.isNotEmpty) {
        final resource = resources.first;
        totalSize += resource.fileSize ?? 0;
        if (resource.fileType == 'V') {
          videoCount++;
        } else {
          imageCount++;
        }
      }
    }

    final sizeStr = _formatFileSize(totalSize);

    return Text(
      '已选：$sizeStr · ${imageCount}张照片/${videoCount}条视频',
      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
    );
  }

  // ✅ 构建下载进度区域（仿照上传进度条样式）
  Widget _buildDownloadProgressSection(Map<String, dynamic> progressInfo) {
    final progress = (progressInfo['progress'] as double).clamp(0.0, 1.0);
    final downloadedBytes = progressInfo['downloadedBytes'] as int;
    final totalBytes = progressInfo['totalBytes'] as int;
    final completedCount = progressInfo['completedCount'] as int;
    final totalCount = progressInfo['totalCount'] as int;
    final failedCount = progressInfo['failedCount'] as int;

    return SizedBox(
      width: 280, // 固定宽度，与上传进度条一致
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：进度条 + 百分比
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    failedCount > 0 ? Colors.blue.shade700 : Colors.blue,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 第二行：已下载大小/总大小 · 文件进度
          Row(
            children: [
              // 大小进度
              Text(
                '${_formatFileSize(downloadedBytes)} / ${_formatFileSize(totalBytes)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 12),
              // 文件进度（带图标的圆角标签）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 12,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$completedCount/$totalCount',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // 失败数量徽章
              if (failedCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$failedCount失败',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ✅ 构建速度指示器（居中显示，与上传样式一致）
  Widget _buildSpeedIndicator() {
    final speed = _speedService.downloadSpeed;
    final formattedSpeed = _formatSpeed(speed.toInt());

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 下载图标
            Icon(
              Icons.download,
              size: 18,
              color: Colors.blue.shade600,
            ),
            const SizedBox(width: 8),
            // 速度文字
            Text(
              formattedSpeed,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 构建右侧区域（设备空间 + 按钮）
  Widget _buildRightSection(BuildContext context, bool hasSelection) {
    final progressInfo = _calculateDownloadProgress();
    final isDownloading = progressInfo['isActive'] as bool;

    final buttonText = isDownloading ? '继续下载' : '下载';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 只在有选中时显示硬盘空间和下载位置
        if (hasSelection) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '硬盘剩余空间：$_freeSpace',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '下载位置：',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      _downloadPath,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _changeDownloadPath,
                      child: Text(
                        '修改',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 30),
        ],
        // 下载按钮
        ElevatedButton(
          onPressed: hasSelection ? () => _handleDownload(context) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C2C2C),
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade500,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            buttonText,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond}B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)}KB/s';
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)}MB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB/s';
    }
  }

  Future<void> _handleDownload(BuildContext context) async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('下载服务正在初始化，请稍候...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedIds = widget.selectionManager.selectedResIds;

    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择要下载的文件'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedResources = widget.dataManager.getResourcesByIds(selectedIds);

    if (selectedResources.isEmpty) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有找到要下载的资源'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _downloadManager.addDownloadTasks(selectedResources);
      widget.selectionManager.clearSelection();

      if (!context.mounted) return;

      final addedCount = selectedResources.length;

      if (addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加 $addedCount 个文件到下载队列'),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}