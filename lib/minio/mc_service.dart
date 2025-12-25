// services/mc_service.dart
// MinIO Client (mc.exe) 封装服务
// 使用命令行工具 mc.exe 进行文件上传下载，支持实时进度、取消操作

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ablumwin/minio/tasks/mc_task.dart';
import 'package:flutter/cupertino.dart';
import 'configs/mc_config.dart';
import 'configs/mc_task_status.dart';
import 'mc_output_parser.dart';
import 'models/mc_object_info.dart';
import 'models/mc_result.dart';

/// 传输进度回调
/// [transferred] 已传输字节数
/// [total] 总字节数
/// [speed] 传输速度（字节/秒）
typedef TransferProgressCallback = void Function(int transferred, int total, int speed);

/// 传输完成回调
typedef TransferCompleteCallback = void Function(bool success, String message);

/// ============================================================
/// MC Service 主类
/// ============================================================
class McService {
  static McService? _instance;

  // 任务管理
  final Map<String, McTask> _tasks = {};

  // 是否已初始化别名
  bool _aliasConfigured = false;

  static McService get instance {
    _instance ??= McService._internal();
    return _instance!;
  }

  McService._internal();

  // ============================================================
  // 初始化
  // ============================================================

  /// 检查 mc.exe 是否存在
  Future<bool> checkMcExists() async {
    final mcPath = McConfig.mcPath;
    final mcFile = File(mcPath);

    if (await mcFile.exists()) {
     debugPrint('[McService] mc.exe 路径: $mcPath');
      return true;
    }

    // 尝试在 PATH 中查找
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['mc'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final foundPath = (result.stdout as String).trim().split('\n').first;
       debugPrint('[McService] 在 PATH 中找到 mc: $foundPath');
        McConfig.setMcPath(foundPath);
        return true;
      }
    } catch (_) {}

   debugPrint('[McService] 错误: mc.exe 未找到');
   debugPrint('[McService] 请将 mc.exe 放置在以下位置之一:');
   debugPrint('  - 可执行文件同级目录');
   debugPrint('  - 可执行文件同级 tools/ 目录');
   debugPrint('  - 项目 assets/ 目录');
   debugPrint('  - 项目 tools/ 目录');
   debugPrint('  - 或添加到系统 PATH 环境变量');

    return false;
  }

  /// 初始化 mc 别名配置
  Future<bool> initialize() async {
    if (_aliasConfigured) return true;

    // 检查 mc.exe 是否存在
    final mcExists = await checkMcExists();
    if (!mcExists) {
      return false;
    }

    try {
      // 配置别名
      // 设置 MC_CONFIG_DIR 环境变量，让配置文件存放在 mc.exe 同目录
      final configDir = McConfig.mcConfigDir;

      final result = await Process.run(
        McConfig.mcPath,
        [
          'alias', 'set',
          McConfig.alias,
          McConfig.endpoint,
          McConfig.accessKey,
          McConfig.secretKey,
        ],
        runInShell: true,
        environment: {
          'MC_CONFIG_DIR': configDir,
        },
      );

      if (result.exitCode == 0) {
        _aliasConfigured = true;
        debugPrint('[McService] 别名配置成功: ${McConfig.alias} -> ${McConfig.endpoint}');
        return true;
      } else {
       debugPrint('[McService] 别名配置失败: ${result.stderr}');
        return false;
      }
    } catch (e) {
     debugPrint('[McService] 初始化失败: $e');
      return false;
    }
  }

  /// 重新配置别名
  Future<bool> reconfigure({
    required String endpoint,
    required String accessKey,
    required String secretKey,
    String? alias,
  }) async {
    McConfig.endpoint = endpoint;
    McConfig.accessKey = accessKey;
    McConfig.secretKey = secretKey;
    if (alias != null) McConfig.alias = alias;

    _aliasConfigured = false;
    return await initialize();
  }

  /// 获取 mc.exe 完整路径（供外部使用）
  String get mcExecutablePath => McConfig.mcPath;

  // ============================================================
  // 任务管理
  // ============================================================

  /// 获取所有任务
  List<McTask> get allTasks => _tasks.values.toList();

  /// 获取正在进行的任务
  List<McTask> get activeTasks => _tasks.values
      .where((t) => t.status == McTaskStatus.running)
      .toList();

  /// 获取指定任务
  McTask? getTask(String taskId) => _tasks[taskId];

  /// 生成任务ID
  String _generateTaskId() => 'mc_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length}';

  /// 清理已完成的任务
  void clearCompletedTasks() {
    _tasks.removeWhere((_, task) =>
    task.status == McTaskStatus.completed ||
        task.status == McTaskStatus.cancelled ||
        task.status == McTaskStatus.failed);
  }

  // ============================================================
  // 上传
  // ============================================================

  /// 上传文件
  /// [localPath] 本地文件路径
  /// [bucket] 存储桶名称
  /// [objectName] 对象名称（可选，默认使用文件名）
  /// [onProgress] 进度回调
  /// [taskId] 任务ID（可选）
  Future<McResult> uploadFile(
      String localPath,
      String bucket, {
        String? objectName,
        TransferProgressCallback? onProgress,
        String? taskId,
      }) async {
    // 确保已初始化
    if (!_aliasConfigured) {
      final initialized = await initialize();
      if (!initialized) {
        return McResult(success: false, message: 'mc 未初始化');
      }
    }

    // 检查文件
    final file = File(localPath);
    if (!await file.exists()) {
      return McResult(success: false, message: '文件不存在: $localPath');
    }

    // ✅ 确保存储桶存在
    await createBucket(bucket);

    // 生成远程路径
    // 如果 objectName 包含路径，直接使用；否则只用文件名
    final fileName = objectName ?? localPath.split(Platform.pathSeparator).last;
    final remotePath = '${McConfig.alias}/$bucket/$fileName';

    // 创建任务
    final effectiveTaskId = taskId ?? _generateTaskId();
    final task = McTask(
      taskId: effectiveTaskId,
      localPath: localPath,
      remotePath: remotePath,
      isUpload: true,
    );

    task.totalBytes = await file.length();
    _tasks[effectiveTaskId] = task;

   debugPrint('[McService] ========== 上传开始 ==========');
   debugPrint('[McService] 本地文件: $localPath');
   debugPrint('[McService] 远程路径: $remotePath');
   debugPrint('[McService] 文件大小: ${task.totalBytes} bytes');
   debugPrint('[McService] mc 命令: ${McConfig.mcPath} cp --json "$localPath" "$remotePath"');

    try {
      // 执行 mc cp 命令
      final result = await _executeTransfer(
        task: task,
        args: ['cp', '--json', localPath, remotePath],
        onProgress: onProgress,
      );

      // ✅ 上传完成后验证文件是否存在
      if (result.success) {
        final exists = await _objectExists(bucket, fileName);
       debugPrint('[McService] 验证文件存在: $exists');
        if (!exists) {
         debugPrint('[McService] ⚠️ 警告: 上传似乎成功但文件未找到，请检查路径');
        }
      }

      return result;
    } catch (e) {
      task.status = McTaskStatus.failed;
      task.errorMessage = e.toString();
      return McResult(
        success: false,
        message: '上传失败: $e',
        taskId: effectiveTaskId,
      );
    }
  }

  /// 上传文件（默认模式，使用 McOutputParser 解析进度）
  /// [localPath] 本地文件路径
  /// [bucket] 存储桶名称
  /// [objectName] 对象名称（可选，默认使用文件名）
  /// [onOutput] 原始输出回调（mc 的原始输出文本）
  Future<McResult> uploadFileDefault(
      String localPath,
      String bucket, {
        String? objectName,
        void Function(String output)? onOutput,
        String? taskId,
      }) async {
    // 确保已初始化
    if (!_aliasConfigured) {
      final initialized = await initialize();
      if (!initialized) {
        return McResult(success: false, message: 'mc 未初始化');
      }
    }

    // 检查文件
    final file = File(localPath);
    if (!await file.exists()) {
      return McResult(success: false, message: '文件不存在: $localPath');
    }


    // 生成远程路径
    final fileName = objectName ?? localPath.split(Platform.pathSeparator).last;
    final remotePath = '${McConfig.alias}/$bucket/$fileName';

    // 创建任务
    final effectiveTaskId = taskId ?? _generateTaskId();
    final task = McTask(
      taskId: effectiveTaskId,
      localPath: localPath,
      remotePath: remotePath,
      isUpload: true,
    );

    task.totalBytes = await file.length();
    _tasks[effectiveTaskId] = task;

   debugPrint('[McService] ========== 上传开始（默认模式）==========');
   debugPrint('[McService] 本地文件: $localPath');
   debugPrint('[McService] 远程路径: $remotePath');
   debugPrint('[McService] 文件大小: ${task.totalBytes} bytes');

    final startTime = DateTime.now();
    task.status = McTaskStatus.running;

    try {
      // 使用默认模式
      final args = ['cp', localPath, remotePath];
     debugPrint('[McService] 执行命令: ${McConfig.mcPath} ${args.join(" ")}');

      // 不使用 runInShell，直接启动 mc.exe，这样可以正确获取进程 PID 并终止
      task.process = await Process.start(
        McConfig.mcPath,
        args,
        environment: {
          'MC_CONFIG_DIR': McConfig.mcConfigDir,
        },
      );

     debugPrint('[McService] 进程已启动, PID: ${task.process!.pid}');

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutCompleter = Completer<void>();

      // 监听 stdout，使用 McOutputParser 解析进度
      task.process!.stdout.transform(utf8.decoder).listen(
            (data) {
          stdoutBuffer.write(data);
          onOutput?.call(data);

          // 使用 McOutputParser 解析进度
          final progressInfo = McOutputParser.parse(data);
          if (progressInfo.total > 0 || progressInfo.transferred > 0) {
            task.transferredBytes = progressInfo.transferred;
            if (progressInfo.total > 0) {
              task.totalBytes = progressInfo.total;
            }
            task.speed = progressInfo.speed;
           debugPrint('[McService] 进度: ${progressInfo.formattedTransferred} / ${progressInfo.formattedTotal} @ ${progressInfo.formattedSpeed}');
          }
        },
        onDone: () => stdoutCompleter.complete(),
        onError: (e) => stdoutCompleter.completeError(e),
      );

      // 监听 stderr
      task.process!.stderr.transform(utf8.decoder).listen((data) {
        stderrBuffer.write(data);
        onOutput?.call(data);

        // stderr 也可能包含进度信息
        final progressInfo = McOutputParser.parse(data);
        if (progressInfo.total > 0 || progressInfo.transferred > 0) {
          task.transferredBytes = progressInfo.transferred;
          if (progressInfo.total > 0) {
            task.totalBytes = progressInfo.total;
          }
          task.speed = progressInfo.speed;
        }
      });

      // 等待进程结束
      final exitCode = await task.process!.exitCode;
      await stdoutCompleter.future.catchError((_) {});

      final duration = DateTime.now().difference(startTime);

      if (exitCode == 0) {
        task.status = McTaskStatus.completed;
        task.transferredBytes = task.totalBytes;

        // 验证文件是否存在
        final exists = await _objectExists(bucket, fileName);
       debugPrint('[McService] 验证文件存在: $exists');

       debugPrint('[McService] ✅ 上传完成');

        return McResult(
          success: true,
          message: '上传成功',
          taskId: effectiveTaskId,
          localPath: localPath,
          remotePath: remotePath,
          size: task.totalBytes,
          duration: duration,
        );
      } else if (task.status == McTaskStatus.cancelled) {
        return McResult(
          success: false,
          message: '上传已取消',
          taskId: effectiveTaskId,
          isCancelled: true,
        );
      } else if (task.status == McTaskStatus.paused) {
        // 如果是暂停状态，等待恢复
        return McResult(
          success: false,
          message: '上传已暂停',
          taskId: effectiveTaskId,
        );
      } else {
        task.status = McTaskStatus.failed;
        task.errorMessage = stderrBuffer.toString();

       debugPrint('[McService] ❌ 上传失败');

        return McResult(
          success: false,
          message: '上传失败: ${stderrBuffer.toString()}',
          taskId: effectiveTaskId,
        );
      }
    } catch (e) {
      task.status = McTaskStatus.failed;
      task.errorMessage = e.toString();

     debugPrint('[McService] ❌ 上传异常: $e');

      return McResult(
        success: false,
        message: '上传异常: $e',
        taskId: effectiveTaskId,
      );
    }
  }

  /// 上传目录
  Future<McResult> uploadDirectory(
      String localDir,
      String bucket, {
        String? prefix,
        TransferProgressCallback? onProgress,
        String? taskId,
        bool recursive = true,
      }) async {
    if (!_aliasConfigured) {
      final initialized = await initialize();
      if (!initialized) {
        return McResult(success: false, message: 'mc 未初始化');
      }
    }

    final dir = Directory(localDir);
    if (!await dir.exists()) {
      return McResult(success: false, message: '目录不存在: $localDir');
    }

    final remotePath = prefix != null
        ? '${McConfig.alias}/$bucket/$prefix'
        : '${McConfig.alias}/$bucket';

    final effectiveTaskId = taskId ?? _generateTaskId();
    final task = McTask(
      taskId: effectiveTaskId,
      localPath: localDir,
      remotePath: remotePath,
      isUpload: true,
    );

    // 计算目录总大小
    task.totalBytes = await _calculateDirectorySize(dir);
    _tasks[effectiveTaskId] = task;

   debugPrint('[McService] 开始上传目录: $localDir -> $remotePath');

    try {
      final args = recursive
          ? ['cp', '--json', '--recursive', localDir, remotePath]
          : ['cp', '--json', localDir, remotePath];

      return await _executeTransfer(
        task: task,
        args: args,
        onProgress: onProgress,
      );
    } catch (e) {
      task.status = McTaskStatus.failed;
      return McResult(success: false, message: '上传目录失败: $e', taskId: effectiveTaskId);
    }
  }

  // ============================================================
  // 下载
  // ============================================================

  /// 下载文件
  Future<McResult> downloadFile(
      String bucket,
      String objectName,
      String localPath, {
        TransferProgressCallback? onProgress,
        String? taskId,
      }) async {
    if (!_aliasConfigured) {
      final initialized = await initialize();
      if (!initialized) {
        return McResult(success: false, message: 'mc 未初始化');
      }
    }

    final remotePath = '${McConfig.alias}/$bucket/$objectName';
    final effectiveTaskId = taskId ?? _generateTaskId();

    final task = McTask(
      taskId: effectiveTaskId,
      localPath: localPath,
      remotePath: remotePath,
      isUpload: false,
    );

    _tasks[effectiveTaskId] = task;

   debugPrint('[McService] 开始下载: $remotePath -> $localPath');

    try {
      // 先获取文件大小
      final statResult = await _statObject(bucket, objectName);
      if (statResult != null) {
        task.totalBytes = statResult;
      }

      return await _executeTransfer(
        task: task,
        args: ['cp', '--json', remotePath, localPath],
        onProgress: onProgress,
      );
    } catch (e) {
      task.status = McTaskStatus.failed;
      return McResult(success: false, message: '下载失败: $e', taskId: effectiveTaskId);
    }
  }

  /// 下载文件（默认模式，使用 McOutputParser 解析进度）
  Future<McResult> downloadFileDefault(
      String bucket,
      String objectName,
      String localPath, {
        void Function(String output)? onOutput,
        String? taskId,
      }) async {
    if (!_aliasConfigured) {
      final initialized = await initialize();
      if (!initialized) {
        return McResult(success: false, message: 'mc 未初始化');
      }
    }

    final remotePath = '${McConfig.alias}/$bucket/$objectName';
    final effectiveTaskId = taskId ?? _generateTaskId();

    final task = McTask(
      taskId: effectiveTaskId,
      localPath: localPath,
      remotePath: remotePath,
      isUpload: false,
    );

    _tasks[effectiveTaskId] = task;

    // 获取文件大小
    final statResult = await _statObject(bucket, objectName);
    if (statResult != null) {
      task.totalBytes = statResult;
    }

   debugPrint('[McService] ========== 下载开始（默认模式）==========');
   debugPrint('[McService] 远程路径: $remotePath');
   debugPrint('[McService] 本地文件: $localPath');
   debugPrint('[McService] 文件大小: ${task.totalBytes} bytes');

    final startTime = DateTime.now();
    task.status = McTaskStatus.running;

    try {
      // 使用默认模式
      final args = ['cp', remotePath, localPath];
     debugPrint('[McService] 执行命令: ${McConfig.mcPath} ${args.join(" ")}');

      // 不使用 runInShell，直接启动 mc.exe，这样可以正确获取进程 PID 并终止
      task.process = await Process.start(
        McConfig.mcPath,
        args,
        environment: {
          'MC_CONFIG_DIR': McConfig.mcConfigDir,
        },
      );

     debugPrint('[McService] 进程已启动, PID: ${task.process!.pid}');

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutCompleter = Completer<void>();

      // 监听 stdout，使用 McOutputParser 解析进度
      task.process!.stdout.transform(utf8.decoder).listen(
            (data) {
          stdoutBuffer.write(data);
          onOutput?.call(data);

          // 使用 McOutputParser 解析进度
          final progressInfo = McOutputParser.parse(data);
          if (progressInfo.total > 0 || progressInfo.transferred > 0) {
            task.transferredBytes = progressInfo.transferred;
            if (progressInfo.total > 0) {
              task.totalBytes = progressInfo.total;
            }
            task.speed = progressInfo.speed;
           debugPrint('[McService] 进度: ${progressInfo.formattedTransferred} / ${progressInfo.formattedTotal} @ ${progressInfo.formattedSpeed}');
          }
        },
        onDone: () => stdoutCompleter.complete(),
        onError: (e) => stdoutCompleter.completeError(e),
      );

      // 监听 stderr
      task.process!.stderr.transform(utf8.decoder).listen((data) {
        stderrBuffer.write(data);
        onOutput?.call(data);

        // stderr 也可能包含进度信息
        final progressInfo = McOutputParser.parse(data);
        if (progressInfo.total > 0 || progressInfo.transferred > 0) {
          task.transferredBytes = progressInfo.transferred;
          if (progressInfo.total > 0) {
            task.totalBytes = progressInfo.total;
          }
          task.speed = progressInfo.speed;
        }
      });

      // 等待进程结束
      final exitCode = await task.process!.exitCode;
      await stdoutCompleter.future.catchError((_) {});

      final duration = DateTime.now().difference(startTime);

      if (exitCode == 0) {
        task.status = McTaskStatus.completed;

        // 验证本地文件是否存在
        final localFile = File(localPath);
        final exists = await localFile.exists();
       debugPrint('[McService] 验证本地文件存在: $exists');

        if (exists) {
          task.transferredBytes = await localFile.length();
        }

       debugPrint('[McService] ✅ 下载完成');

        return McResult(
          success: true,
          message: '下载成功',
          taskId: effectiveTaskId,
          localPath: localPath,
          remotePath: remotePath,
          size: task.transferredBytes,
          duration: duration,
        );
      } else if (task.status == McTaskStatus.cancelled) {
        return McResult(
          success: false,
          message: '下载已取消',
          taskId: effectiveTaskId,
          isCancelled: true,
        );
      } else if (task.status == McTaskStatus.paused) {
        return McResult(
          success: false,
          message: '下载已暂停',
          taskId: effectiveTaskId,
        );
      } else {
        task.status = McTaskStatus.failed;
        task.errorMessage = stderrBuffer.toString();

       debugPrint('[McService] ❌ 下载失败');

        return McResult(
          success: false,
          message: '下载失败: ${stderrBuffer.toString()}',
          taskId: effectiveTaskId,
        );
      }
    } catch (e) {
      task.status = McTaskStatus.failed;
      task.errorMessage = e.toString();

     debugPrint('[McService] ❌ 下载异常: $e');

      return McResult(
        success: false,
        message: '下载异常: $e',
        taskId: effectiveTaskId,
      );
    }
  }

  /// 下载目录
  Future<McResult> downloadDirectory(
      String bucket,
      String prefix,
      String localDir, {
        TransferProgressCallback? onProgress,
        String? taskId,
        bool recursive = true,
      }) async {
    if (!_aliasConfigured) {
      final initialized = await initialize();
      if (!initialized) {
        return McResult(success: false, message: 'mc 未初始化');
      }
    }

    final remotePath = '${McConfig.alias}/$bucket/$prefix';
    final effectiveTaskId = taskId ?? _generateTaskId();

    final task = McTask(
      taskId: effectiveTaskId,
      localPath: localDir,
      remotePath: remotePath,
      isUpload: false,
    );

    _tasks[effectiveTaskId] = task;

   debugPrint('[McService] 开始下载目录: $remotePath -> $localDir');

    try {
      final args = recursive
          ? ['cp', '--json', '--recursive', remotePath, localDir]
          : ['cp', '--json', remotePath, localDir];

      return await _executeTransfer(
        task: task,
        args: args,
        onProgress: onProgress,
      );
    } catch (e) {
      task.status = McTaskStatus.failed;
      return McResult(success: false, message: '下载目录失败: $e', taskId: effectiveTaskId);
    }
  }

  // ============================================================
  // 取消操作
  // ============================================================

  /// 取消指定任务
  /// [deleteIncomplete] 是否删除上传中断产生的不完整文件，默认为 false
  Future<bool> cancelTask(String taskId, {bool deleteIncomplete = false}) async {
    final task = _tasks[taskId];
    if (task == null) {
     debugPrint('[McService] 任务不存在: $taskId');
      return false;
    }

    // 支持取消 running 和 paused 状态的任务
    if (task.status != McTaskStatus.running && task.status != McTaskStatus.paused) {
     debugPrint('[McService] 任务未在运行或暂停: $taskId (当前状态: ${task.status})');
      return false;
    }

    // 保存任务信息，用于后续删除不完整文件
    final isUpload = task.isUpload;
    final remotePath = task.remotePath;
    final wasPaused = task.status == McTaskStatus.paused;

    try {
      // 先标记状态为取消中
      task.status = McTaskStatus.cancelled;

      // 杀死进程
      if (task.process != null) {
        final pid = task.process!.pid;
       debugPrint('[McService] 正在终止进程, PID: $pid, 之前是否暂停: $wasPaused');

        if (Platform.isWindows) {
          // 如果进程是暂停状态，需要先恢复再终止
          if (wasPaused) {
           debugPrint('[McService] 进程处于暂停状态，先恢复再终止');

            // 尝试使用 pssuspend -r 恢复
            final pssuspendPath = await _findPssuspend();
            if (pssuspendPath != null) {
              await Process.run(pssuspendPath, ['-nobanner', '-r', '$pid']);
            } else {
              // 使用 PowerShell 恢复
              await _resumeWithPowerShell(pid);
            }

            // 等待恢复生效
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // 方法1: 先尝试直接 kill
          try {
            task.process!.kill(ProcessSignal.sigterm);
          } catch (e) {
           debugPrint('[McService] kill sigterm 失败: $e');
          }

          // 方法2: 使用 taskkill 强制终止进程树
          final result = await Process.run(
            'taskkill',
            ['/F', '/T', '/PID', '$pid'],
            runInShell: true,
          );
         debugPrint('[McService] taskkill /PID 结果: exitCode=${result.exitCode}, stdout=${result.stdout}, stderr=${result.stderr}');

          // 方法3: 如果还是失败，通过进程名强制杀死
          if (result.exitCode != 0) {
            final mcName = McConfig.mcPath.split(Platform.pathSeparator).last;
            final result2 = await Process.run(
              'taskkill',
              ['/F', '/IM', mcName],
              runInShell: true,
            );
           debugPrint('[McService] taskkill /IM 结果: exitCode=${result2.exitCode}');
          }
        } else {
          // Linux/macOS: 如果是暂停状态，先发送 SIGCONT
          if (wasPaused) {
           debugPrint('[McService] 进程处于暂停状态，先恢复再终止');
            await Process.run('kill', ['-CONT', '$pid']);
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // 先尝试 SIGTERM，再 SIGKILL
          task.process!.kill(ProcessSignal.sigterm);

          // 等待一小段时间
          await Future.delayed(const Duration(milliseconds: 300));

          // 如果还在运行，强制杀死
          try {
            task.process!.kill(ProcessSignal.sigkill);
          } catch (_) {}
        }
      }

     debugPrint('[McService] 已取消任务: $taskId');

      // 等待进程完全终止
      await Future.delayed(const Duration(milliseconds: 1500));

      // 如果是上传任务且需要删除不完整文件
      if (isUpload && deleteIncomplete) {
        // 从 remotePath 解析 bucket 和 objectName
        // remotePath 格式: alias/bucket/objectName
        final parts = remotePath.split('/');
        if (parts.length >= 3) {
          final bucket = parts[1];
          final objectName = parts.sublist(2).join('/');

          // 尝试删除不完整的文件
         debugPrint('[McService] 尝试删除不完整文件: $bucket/$objectName');
          final deleted = await deleteObject(bucket, objectName);
          if (deleted) {
           debugPrint('[McService] 已删除不完整的上传文件: $objectName');
          } else {
           debugPrint('[McService] 未找到需要删除的文件（可能上传尚未开始或已完成清理）');
          }
        }
      }

      return true;
    } catch (e) {
     debugPrint('[McService] 取消任务失败: $e');
      return false;
    }
  }

  /// 取消所有任务
  Future<int> cancelAllTasks() async {
    int cancelledCount = 0;
    final runningTasks = _tasks.entries
        .where((e) => e.value.status == McTaskStatus.running)
        .map((e) => e.key)
        .toList();

    for (final taskId in runningTasks) {
      if (await cancelTask(taskId)) {
        cancelledCount++;
      }
    }

   debugPrint('[McService] 已取消 $cancelledCount 个任务');
    return cancelledCount;
  }

  /// 暂停指定任务
  /// Windows: 优先使用 pssuspend.exe，备选 PowerShell
  /// Unix: 使用 SIGSTOP 信号
  Future<bool> pauseTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) {
     debugPrint('[McService] 任务不存在: $taskId');
      return false;
    }

    // 如果已经是暂停状态，直接返回成功
    if (task.status == McTaskStatus.paused) {
     debugPrint('[McService] 任务已经是暂停状态: $taskId');
      return true;
    }

    if (task.status != McTaskStatus.running) {
     debugPrint('[McService] 任务未在运行: $taskId (当前状态: ${task.status})');
      return false;
    }

    try {
      if (task.process != null) {
        final pid = task.process!.pid;
       debugPrint('[McService] 正在暂停进程, PID: $pid');

        // 立即标记状态为暂停，防止重复调用
        task.status = McTaskStatus.paused;

        if (Platform.isWindows) {
          // 查找 pssuspend.exe 路径
          final pssuspendPath = await _findPssuspend();

          if (pssuspendPath != null) {
            // 使用 pssuspend.exe 暂停进程
           debugPrint('[McService] 使用 pssuspend: $pssuspendPath');
            final result = await Process.run(
              pssuspendPath,
              ['-nobanner', '$pid'],
            );

           debugPrint('[McService] pssuspend 暂停结果: exitCode=${result.exitCode}');
            if (result.stdout.toString().isNotEmpty) {
             debugPrint('[McService] pssuspend stdout: ${result.stdout}');
            }
            if (result.stderr.toString().isNotEmpty) {
             debugPrint('[McService] pssuspend stderr: ${result.stderr}');
            }

            if (result.exitCode == 0 || result.stdout.toString().contains('suspended')) {
             debugPrint('[McService] 任务已暂停 (pssuspend): $taskId');
              return true;
            }
          }

          // pssuspend 不可用或失败，尝试 PowerShell 方案
         debugPrint('[McService] pssuspend 不可用，尝试 PowerShell 方案');
          final success = await _suspendWithPowerShell(pid);
          if (success) {
           debugPrint('[McService] 任务已暂停 (PowerShell): $taskId');
            return true;
          }

          // 都失败了，恢复状态
          task.status = McTaskStatus.running;
         debugPrint('[McService] 暂停失败');
          return false;
        } else {
          // Linux/macOS: 使用 SIGSTOP 信号暂停进程
          final result = await Process.run('kill', ['-STOP', '$pid']);
          if (result.exitCode == 0) {
           debugPrint('[McService] 任务已暂停 (SIGSTOP): $taskId');
            return true;
          } else {
           debugPrint('[McService] 暂停失败: ${result.stderr}');
            task.status = McTaskStatus.running;
            return false;
          }
        }
      }
      return false;
    } catch (e) {
     debugPrint('[McService] 暂停任务失败: $e');
      task.status = McTaskStatus.running;
      return false;
    }
  }

  /// 继续执行已暂停的任务
  Future<bool> resumeTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) {
     debugPrint('[McService] 任务不存在: $taskId');
      return false;
    }

    if (task.status != McTaskStatus.paused) {
     debugPrint('[McService] 任务未暂停: $taskId (当前状态: ${task.status})');
      return false;
    }

    try {
      if (task.process != null) {
        final pid = task.process!.pid;
       debugPrint('[McService] 正在恢复进程, PID: $pid');

        if (Platform.isWindows) {
          // 查找 pssuspend.exe 路径
          final pssuspendPath = await _findPssuspend();

          if (pssuspendPath != null) {
            // 使用 pssuspend.exe -r 恢复进程
           debugPrint('[McService] 使用 pssuspend -r: $pssuspendPath');
            final result = await Process.run(
              pssuspendPath,
              ['-nobanner', '-r', '$pid'],
            );

           debugPrint('[McService] pssuspend 恢复结果: exitCode=${result.exitCode}');
            if (result.stdout.toString().isNotEmpty) {
             debugPrint('[McService] pssuspend stdout: ${result.stdout}');
            }
            if (result.stderr.toString().isNotEmpty) {
             debugPrint('[McService] pssuspend stderr: ${result.stderr}');
            }

            if (result.exitCode == 0 || result.stdout.toString().contains('resumed')) {
              task.status = McTaskStatus.running;
             debugPrint('[McService] 任务已恢复 (pssuspend): $taskId');
              return true;
            }
          }

          // pssuspend 不可用或失败，尝试 PowerShell 方案
         debugPrint('[McService] pssuspend 不可用，尝试 PowerShell 方案');
          final success = await _resumeWithPowerShell(pid);
          if (success) {
            task.status = McTaskStatus.running;
           debugPrint('[McService] 任务已恢复 (PowerShell): $taskId');
            return true;
          }

         debugPrint('[McService] 恢复失败');
          return false;
        } else {
          // Linux/macOS: 使用 SIGCONT 信号恢复进程
          final result = await Process.run('kill', ['-CONT', '$pid']);
          if (result.exitCode == 0) {
            task.status = McTaskStatus.running;
           debugPrint('[McService] 任务已恢复 (SIGCONT): $taskId');
            return true;
          } else {
           debugPrint('[McService] 恢复失败: ${result.stderr}');
            return false;
          }
        }
      }
      return false;
    } catch (e) {
     debugPrint('[McService] 恢复任务失败: $e');
      return false;
    }
  }

  /// 查找 pssuspend.exe 路径
  Future<String?> _findPssuspend() async {
    // 可能的路径
    final possiblePaths = [
      // 1. mc.exe 同目录
      '${McConfig.mcConfigDir}${Platform.pathSeparator}pssuspend.exe',
      // 2. mc.exe 同目录的 tools 子目录
      '${McConfig.mcConfigDir}${Platform.pathSeparator}tools${Platform.pathSeparator}pssuspend.exe',
      // 3. 项目 assets 目录
      '${Directory.current.path}${Platform.pathSeparator}assets${Platform.pathSeparator}pssuspend.exe',
      // 4. 项目 tools 目录
      '${Directory.current.path}${Platform.pathSeparator}tools${Platform.pathSeparator}pssuspend.exe',
    ];

    for (final path in possiblePaths) {
      if (await File(path).exists()) {
       debugPrint('[McService] 找到 pssuspend.exe: $path');
        return path;
      }
    }

    // 尝试在 PATH 中查找
    try {
      final result = await Process.run('where', ['pssuspend.exe'], runInShell: true);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim().split('\n').first.trim();
        if (path.isNotEmpty) {
         debugPrint('[McService] 在 PATH 中找到 pssuspend.exe: $path');
          return path;
        }
      }
    } catch (_) {}

   debugPrint('[McService] 未找到 pssuspend.exe');
    return null;
  }

  /// 使用 PowerShell 暂停进程（备选方案）
  Future<bool> _suspendWithPowerShell(int pid) async {
    try {
      final tempDir = Directory.systemTemp;
      final scriptFile = File('${tempDir.path}${Platform.pathSeparator}suspend_$pid.ps1');

      final psScript = '''
Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
public class ProcSuspend {
    [DllImport("kernel32.dll")]
    static extern IntPtr OpenThread(int access, bool inherit, int tid);
    [DllImport("kernel32.dll")]
    static extern uint SuspendThread(IntPtr h);
    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr h);
    public static void Do(int pid) {
        var p = Process.GetProcessById(pid);
        foreach (ProcessThread t in p.Threads) {
            IntPtr h = OpenThread(2, false, t.Id);
            if (h != IntPtr.Zero) { SuspendThread(h); CloseHandle(h); }
        }
    }
}
"@
[ProcSuspend]::Do($pid)
''';

      await scriptFile.writeAsString(psScript);

      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptFile.path],
      );

      try { await scriptFile.delete(); } catch (_) {}

     debugPrint('[McService] PowerShell 暂停结果: exitCode=${result.exitCode}');
      if (result.stderr.toString().isNotEmpty) {
       debugPrint('[McService] PowerShell stderr: ${result.stderr}');
      }

      return result.exitCode == 0;
    } catch (e) {
     debugPrint('[McService] PowerShell 暂停异常: $e');
      return false;
    }
  }

  /// 使用 PowerShell 恢复进程（备选方案）
  Future<bool> _resumeWithPowerShell(int pid) async {
    try {
      final tempDir = Directory.systemTemp;
      final scriptFile = File('${tempDir.path}${Platform.pathSeparator}resume_$pid.ps1');

      final psScript = '''
Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
public class ProcResume {
    [DllImport("kernel32.dll")]
    static extern IntPtr OpenThread(int access, bool inherit, int tid);
    [DllImport("kernel32.dll")]
    static extern uint ResumeThread(IntPtr h);
    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr h);
    public static void Do(int pid) {
        var p = Process.GetProcessById(pid);
        foreach (ProcessThread t in p.Threads) {
            IntPtr h = OpenThread(2, false, t.Id);
            if (h != IntPtr.Zero) { ResumeThread(h); CloseHandle(h); }
        }
    }
}
"@
[ProcResume]::Do($pid)
''';

      await scriptFile.writeAsString(psScript);

      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptFile.path],
      );

      try { await scriptFile.delete(); } catch (_) {}

     debugPrint('[McService] PowerShell 恢复结果: exitCode=${result.exitCode}');
      if (result.stderr.toString().isNotEmpty) {
       debugPrint('[McService] PowerShell stderr: ${result.stderr}');
      }

      return result.exitCode == 0;
    } catch (e) {
     debugPrint('[McService] PowerShell 恢复异常: $e');
      return false;
    }
  }

  /// 检查任务是否已暂停
  bool isTaskPaused(String taskId) {
    final task = _tasks[taskId];
    return task?.status == McTaskStatus.paused;
  }

  // ============================================================
  // 其他操作
  // ============================================================

  /// 列出存储桶中的对象
  Future<List<McObjectInfo>> listObjects(
      String bucket, {
        String prefix = '',
        bool recursive = false,
      }) async {
    if (!_aliasConfigured) await initialize();

    try {
      final remotePath = prefix.isEmpty
          ? '${McConfig.alias}/$bucket'
          : '${McConfig.alias}/$bucket/$prefix';

      final args = recursive
          ? ['ls', '--json', '--recursive', remotePath]
          : ['ls', '--json', remotePath];

      final result = await Process.run(
        McConfig.mcPath,
        args,
        runInShell: true,
        environment: {'MC_CONFIG_DIR': McConfig.mcConfigDir},
      );

      if (result.exitCode != 0) {
       debugPrint('[McService] 列出对象失败: ${result.stderr}');
        return [];
      }

      final objects = <McObjectInfo>[];
      final lines = (result.stdout as String).split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line);
          if (json['status'] == 'success') {
            objects.add(McObjectInfo(
              key: json['key'] ?? '',
              size: json['size'] ?? 0,
              lastModified: json['lastModified'] != null
                  ? DateTime.tryParse(json['lastModified'])
                  : null,
              isDir: json['type'] == 'folder',
            ));
          }
        } catch (_) {}
      }

      return objects;
    } catch (e) {
     debugPrint('[McService] 列出对象异常: $e');
      return [];
    }
  }

  /// 删除对象
  Future<bool> deleteObject(String bucket, String objectName) async {
    if (!_aliasConfigured) await initialize();

    try {
      final remotePath = '${McConfig.alias}/$bucket/$objectName';
      final result = await Process.run(
        McConfig.mcPath,
        ['rm', remotePath],
        runInShell: true,
        environment: {'MC_CONFIG_DIR': McConfig.mcConfigDir},
      );

      if (result.exitCode == 0) {
       debugPrint('[McService] 删除成功: $objectName');
        return true;
      } else {
       debugPrint('[McService] 删除失败: ${result.stderr}');
        return false;
      }
    } catch (e) {
     debugPrint('[McService] 删除异常: $e');
      return false;
    }
  }

  /// 删除目录（递归）
  Future<bool> deleteDirectory(String bucket, String prefix) async {
    if (!_aliasConfigured) await initialize();

    try {
      final remotePath = '${McConfig.alias}/$bucket/$prefix';
      final result = await Process.run(
        McConfig.mcPath,
        ['rm', '--recursive', '--force', remotePath],
        runInShell: true,
        environment: {'MC_CONFIG_DIR': McConfig.mcConfigDir},
      );

      return result.exitCode == 0;
    } catch (e) {
     debugPrint('[McService] 删除目录异常: $e');
      return false;
    }
  }

  /// 创建存储桶
  Future<bool> createBucket(String bucket) async {
    if (!_aliasConfigured) await initialize();

    try {
      final result = await Process.run(
        McConfig.mcPath,
        ['mb', '${McConfig.alias}/$bucket'],
        runInShell: true,
        environment: {'MC_CONFIG_DIR': McConfig.mcConfigDir},
      );

      if (result.exitCode == 0 || (result.stderr as String).contains('already exists')) {
        return true;
      }
     debugPrint('[McService] 创建存储桶失败: ${result.stderr}');
      return false;
    } catch (e) {
     debugPrint('[McService] 创建存储桶异常: $e');
      return false;
    }
  }

  /// 检查存储桶是否存在
  Future<bool> bucketExists(String bucket) async {
    if (!_aliasConfigured) await initialize();

    try {
      final result = await Process.run(
        McConfig.mcPath,
        ['ls', '${McConfig.alias}/$bucket'],
        runInShell: true,
        environment: {'MC_CONFIG_DIR': McConfig.mcConfigDir},
      );
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // 私有方法
  // ============================================================

  /// 执行传输命令
  Future<McResult> _executeTransfer({
    required McTask task,
    required List<String> args,
    TransferProgressCallback? onProgress,
  }) async {
    final startTime = DateTime.now();
    task.status = McTaskStatus.running;

    try {
     debugPrint('[McService] 执行命令: ${McConfig.mcPath} ${args.join(" ")}');

      // 启动进程（设置配置目录环境变量）
      task.process = await Process.start(
        McConfig.mcPath,
        args,
        runInShell: true,
        environment: {
          'MC_CONFIG_DIR': McConfig.mcConfigDir,
        },
      );

      // 监听输出解析进度
      final stdoutCompleter = Completer<void>();
      final stderrBuffer = StringBuffer();
      final stdoutBuffer = StringBuffer(); // ✅ 记录完整 stdout

      task.process!.stdout.transform(utf8.decoder).listen(
            (data) {
          stdoutBuffer.write(data); // ✅ 记录输出
          _parseProgress(data, task, onProgress);
        },
        onDone: () => stdoutCompleter.complete(),
        onError: (e) => stdoutCompleter.completeError(e),
      );

      task.process!.stderr.transform(utf8.decoder).listen((data) {
        stderrBuffer.write(data);
      });

      // 等待进程结束
      final exitCode = await task.process!.exitCode;
      await stdoutCompleter.future.catchError((_) {});

      final duration = DateTime.now().difference(startTime);

      // ✅ 打印完整输出用于调试
     debugPrint('[McService] exitCode: $exitCode');
      if (stdoutBuffer.isNotEmpty) {
       debugPrint('[McService] stdout: ${stdoutBuffer.toString()}');
      }
      if (stderrBuffer.isNotEmpty) {
       debugPrint('[McService] stderr: ${stderrBuffer.toString()}');
      }

      if (exitCode == 0) {
        task.status = McTaskStatus.completed;
        task.transferredBytes = task.totalBytes;
        onProgress?.call(task.totalBytes, task.totalBytes, 0);

       debugPrint('[McService] ✅ 传输完成: ${task.localPath}');

        return McResult(
          success: true,
          message: '传输成功',
          taskId: task.taskId,
          localPath: task.localPath,
          remotePath: task.remotePath,
          size: task.totalBytes,
          duration: duration,
        );
      } else if (task.status == McTaskStatus.cancelled) {
        return McResult(
          success: false,
          message: '传输已取消',
          taskId: task.taskId,
          isCancelled: true,
        );
      } else {
        task.status = McTaskStatus.failed;
        task.errorMessage = stderrBuffer.toString();

       debugPrint('[McService] ❌ 传输失败');

        return McResult(
          success: false,
          message: '传输失败: ${stderrBuffer.toString()}',
          taskId: task.taskId,
        );
      }
    } catch (e) {
      task.status = McTaskStatus.failed;
      task.errorMessage = e.toString();

     debugPrint('[McService] ❌ 传输异常: $e');

      return McResult(
        success: false,
        message: '传输异常: $e',
        taskId: task.taskId,
      );
    }
  }

  /// 解析 mc JSON 输出的进度信息（简化版，不带回调）
  void _parseJsonProgress(String data, McTask task) {
    for (final line in data.split('\n')) {
      if (line.trim().isEmpty) continue;

      try {
        final json = jsonDecode(line);

        // 解析总大小
        if (json['size'] != null) {
          task.totalBytes = json['size'] is int
              ? json['size']
              : int.tryParse(json['size'].toString()) ?? task.totalBytes;
        }

        // 解析传输字节数（transferred 或 transferredSize）
        final transferred = json['transferred'] ?? json['transferredSize'];
        if (transferred != null) {
          if (transferred is int) {
            task.transferredBytes = transferred;
          } else {
            task.transferredBytes = _parseSize(transferred.toString());
          }
        }

        // 解析速度
        final speed = json['speed'];
        if (speed != null) {
          task.speed = _parseSize(speed.toString().replaceAll('/s', ''));
        }

        // 处理完成状态
        if (json['status'] == 'success') {
          task.transferredBytes = task.totalBytes;
        }

       debugPrint('[McService] 进度解析: transferred=${task.transferredBytes}, total=${task.totalBytes}, speed=${task.speed}');

      } catch (e) {
        // JSON 解析失败，尝试正则匹配
        _parseProgressFromTextSimple(line, task);
      }
    }
  }

  /// 从文本解析进度（简化版，不带回调）
  void _parseProgressFromTextSimple(String text, McTask task) {
    // 匹配类似 "1.5 MiB / 10 MiB" 的进度
    final progressRegex = RegExp(r'([\d.]+)\s*(B|KiB|MiB|GiB)\s*/\s*([\d.]+)\s*(B|KiB|MiB|GiB)');
    final match = progressRegex.firstMatch(text);

    if (match != null) {
      task.transferredBytes = _parseSize('${match.group(1)} ${match.group(2)}');
      task.totalBytes = _parseSize('${match.group(3)} ${match.group(4)}');
    }

    // 匹配速度
    final speedRegex = RegExp(r'([\d.]+)\s*(B|KiB|MiB|GiB)/s');
    final speedMatch = speedRegex.firstMatch(text);
    if (speedMatch != null) {
      task.speed = _parseSize('${speedMatch.group(1)} ${speedMatch.group(2)}');
    }
  }

  /// 解析 mc 输出的进度信息
  void _parseProgress(String data, McTask task, TransferProgressCallback? onProgress) {
    // mc --json 输出格式示例:
    // {"status":"success","source":"...","target":"...","size":1234,"speed":"1.2 MiB/s","transferred":"500 KiB"}

    for (final line in data.split('\n')) {
      if (line.trim().isEmpty) continue;

      try {
        final json = jsonDecode(line);

        // 解析已传输大小
        if (json['size'] != null) {
          task.totalBytes = json['size'] is int ? json['size'] : int.tryParse(json['size'].toString()) ?? task.totalBytes;
        }

        // 解析传输进度
        final transferred = json['transferred'];
        if (transferred != null) {
          task.transferredBytes = _parseSize(transferred.toString());
        }

        // 解析速度
        final speed = json['speed'];
        if (speed != null) {
          task.speed = _parseSize(speed.toString().replaceAll('/s', ''));
        }

        // 回调进度
        onProgress?.call(task.transferredBytes, task.totalBytes, task.speed);

      } catch (_) {
        // JSON 解析失败，尝试正则匹配
        _parseProgressFromText(line, task, onProgress);
      }
    }
  }

  /// 从文本解析进度（备用方案）
  void _parseProgressFromText(String text, McTask task, TransferProgressCallback? onProgress) {
    // 匹配类似 "1.5 MiB / 10 MiB" 的进度
    final progressRegex = RegExp(r'([\d.]+)\s*(B|KiB|MiB|GiB)\s*/\s*([\d.]+)\s*(B|KiB|MiB|GiB)');
    final match = progressRegex.firstMatch(text);

    if (match != null) {
      final transferred = _parseSize('${match.group(1)} ${match.group(2)}');
      final total = _parseSize('${match.group(3)} ${match.group(4)}');

      task.transferredBytes = transferred;
      task.totalBytes = total;

      onProgress?.call(transferred, total, task.speed);
    }

    // 匹配速度
    final speedRegex = RegExp(r'([\d.]+)\s*(B|KiB|MiB|GiB)/s');
    final speedMatch = speedRegex.firstMatch(text);
    if (speedMatch != null) {
      task.speed = _parseSize('${speedMatch.group(1)} ${speedMatch.group(2)}');
    }
  }

  /// 解析大小字符串为字节数
  int _parseSize(String sizeStr) {
    final regex = RegExp(r'([\d.]+)\s*(B|KB|KiB|MB|MiB|GB|GiB|TB|TiB)?', caseSensitive: false);
    final match = regex.firstMatch(sizeStr.trim());

    if (match == null) return 0;

    final value = double.tryParse(match.group(1) ?? '0') ?? 0;
    final unit = (match.group(2) ?? 'B').toUpperCase();

    switch (unit) {
      case 'B':
        return value.round();
      case 'KB':
      case 'KIB':
        return (value * 1024).round();
      case 'MB':
      case 'MIB':
        return (value * 1024 * 1024).round();
      case 'GB':
      case 'GIB':
        return (value * 1024 * 1024 * 1024).round();
      case 'TB':
      case 'TIB':
        return (value * 1024 * 1024 * 1024 * 1024).round();
      default:
        return value.round();
    }
  }

  /// 获取对象大小
  Future<int?> _statObject(String bucket, String objectName) async {
    try {
      final result = await Process.run(
        McConfig.mcPath,
        ['stat', '--json', '${McConfig.alias}/$bucket/$objectName'],
        runInShell: true,
        environment: {'MC_CONFIG_DIR': McConfig.mcConfigDir},
      );

      if (result.exitCode == 0) {
        final json = jsonDecode(result.stdout);
        return json['size'];
      }
    } catch (_) {}
    return null;
  }

  /// 检查对象是否存在
  Future<bool> _objectExists(String bucket, String objectName) async {
    try {
      final result = await Process.run(
        McConfig.mcPath,
        ['stat', '${McConfig.alias}/$bucket/$objectName'],
        runInShell: true,
        environment: {'MC_CONFIG_DIR': McConfig.mcConfigDir},
      );

     debugPrint('[McService] stat 命令结果: exitCode=${result.exitCode}');
      if (result.exitCode != 0) {
       debugPrint('[McService] stat stderr: ${result.stderr}');
      }

      return result.exitCode == 0;
    } catch (e) {
     debugPrint('[McService] _objectExists 异常: $e');
      return false;
    }
  }

  /// 公开方法：检查对象是否存在
  Future<bool> objectExists(String bucket, String objectName) async {
    if (!_aliasConfigured) await initialize();
    return await _objectExists(bucket, objectName);
  }

  /// 计算目录大小
  Future<int> _calculateDirectorySize(Directory dir) async {
    int totalSize = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    } catch (_) {}
    return totalSize;
  }
}


