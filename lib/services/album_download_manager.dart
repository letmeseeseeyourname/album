// services/album_download_manager.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import '../network/constant_sign.dart';
import '../user/models/resource_list_model.dart';
import '../user/my_instance.dart';

class AlbumDownloadManager {
  static final AlbumDownloadManager _instance = AlbumDownloadManager._internal();
  factory AlbumDownloadManager() => _instance;
  AlbumDownloadManager._internal();

  static AlbumDownloadManager get instance => _instance;

  // 下载进度回调
  Function(int current, int total, String fileName)? onProgress;
  Function(String message)? onComplete;
  Function(String error)? onError;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  /// 批量下载资源
  Future<void> downloadResources({
    required List<ResList> resources,
    required String savePath,
  }) async {
    if (_isDownloading) {
      onError?.call('下载任务正在进行中');
      return;
    }

    if (resources.isEmpty) {
      onError?.call('没有选择要下载的资源');
      return;
    }

    _isDownloading = true;

    try {
      // 确保保存目录存在
      final saveDir = Directory(savePath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < resources.length; i++) {
        final resource = resources[i];
        final fileName = resource.fileName ?? 'file_${DateTime.now().millisecondsSinceEpoch}';

        onProgress?.call(i + 1, resources.length, fileName);

        try {
          // 使用原始路径下载
          // final downloadUrl = resource.originPath ?? resource.mediumPath;
          final downloadUrl = "${AppConfig.minio()}/${resource.originPath ?? resource.mediumPath}";

          if (downloadUrl.isEmpty) {
            debugPrint('资源 $fileName 没有有效的下载路径');
            failCount++;
            continue;
          }

          // 下载文件
          final success = await _downloadFile(
            url: downloadUrl,
            savePath: path.join(savePath, fileName),
          );

          if (success) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          debugPrint('下载 $fileName 失败: $e');
          failCount++;
        }
      }

      final message = '下载完成！成功: $successCount, 失败: $failCount';
      onComplete?.call(message);
    } catch (e) {
      onError?.call('下载失败: $e');
    } finally {
      _isDownloading = false;
    }
  }

  /// 下载单个文件
  Future<bool> _downloadFile({
    required String url,
    required String savePath,
  }) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return true;
      } else {
        debugPrint('下载失败，HTTP状态码: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('下载文件异常: $e');
      return false;
    }
  }

  /// 取消下载
  void cancelDownload() {
    _isDownloading = false;
  }

  /// 获取默认下载路径
  static Future<String> getDefaultDownloadPath() async {
    // 首先尝试从设置中获取用户配置的下载路径
    String? savedPath = await MyInstance().getDownloadPath();

    String downloadPath;
    if (savedPath != null && savedPath.isNotEmpty) {
      // 使用用户设置的路径
      downloadPath = savedPath;
    } else {
      // 使用默认路径
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          downloadPath = path.join(userProfile, 'Downloads', '亲选相册');
        } else {
          downloadPath = path.join(Directory.current.path, 'downloads', '亲选相册');
        }
      } else {
        // 其他平台
        downloadPath = path.join(Directory.current.path, 'downloads', '亲选相册');
      }

      // 将默认路径保存到设置中
      await MyInstance().setDownloadPath(downloadPath);
    }

    // 确保下载目录存在,如果不存在则创建
    try {
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
        debugPrint('创建下载目录: $downloadPath');
      }
    } catch (e) {
      debugPrint('创建下载目录失败: $e');
    }

    return downloadPath;
  }
}

/// 下载进度对话框
class DownloadProgressDialog extends StatefulWidget {
  final List<ResList> resources;
  final String savePath;

  const DownloadProgressDialog({
    super.key,
    required this.resources,
    required this.savePath,
  });

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  int _current = 0;
  int _total = 0;
  String _currentFileName = '';
  bool _isCompleted = false;
  String _completionMessage = '';

  @override
  void initState() {
    super.initState();
    _total = widget.resources.length;
    _startDownload();
  }

  void _startDownload() {
    final downloadManager = AlbumDownloadManager.instance;

    downloadManager.onProgress = (current, total, fileName) {
      if (mounted) {
        setState(() {
          _current = current;
          _total = total;
          _currentFileName = fileName;
        });
      }
    };

    downloadManager.onComplete = (message) {
      if (mounted) {
        setState(() {
          _isCompleted = true;
          _completionMessage = message;
        });
      }
    };

    downloadManager.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        Navigator.pop(context);
      }
    };

    downloadManager.downloadResources(
      resources: widget.resources,
      savePath: widget.savePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isCompleted ? '下载完成' : '正在下载',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            if (!_isCompleted) ...[
              LinearProgressIndicator(
                value: _total > 0 ? _current / _total : 0,
              ),
              const SizedBox(height: 16),
              Text('$_current / $_total'),
              const SizedBox(height: 8),
              Text(
                _currentFileName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(_completionMessage),
              const SizedBox(height: 16),
              Text(
                '保存位置: ${widget.savePath}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isCompleted)
                  TextButton(
                    onPressed: () {
                      AlbumDownloadManager.instance.cancelDownload();
                      Navigator.pop(context);
                    },
                    child: const Text('取消'),
                  ),
                if (_isCompleted)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('确定'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    final downloadManager = AlbumDownloadManager.instance;
    downloadManager.onProgress = null;
    downloadManager.onComplete = null;
    downloadManager.onError = null;
    super.dispose();
  }
}