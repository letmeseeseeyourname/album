// services/mc_service.dart
// MinIO Client (mc.exe) 封装服务
// 使用命令行工具 mc.exe 进行文件上传下载，支持实时进度、取消操作

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 传输进度回调
/// [transferred] 已传输字节数
/// [total] 总字节数
/// [speed] 传输速度（字节/秒）
typedef TransferProgressCallback = void Function(int transferred, int total, int speed);

/// 传输完成回调
typedef TransferCompleteCallback = void Function(bool success, String message);

/// ============================================================
/// MC 配置
/// ============================================================
class McConfig {
  /// mc.exe 路径（会自动设置）
  static String _mcPath = '';

  /// 别名（在 mc 中配置的服务器别名）
  static String alias = 'myminio';

  /// MinIO 服务器地址
  static String endpoint = 'http://localhost:9000';

  /// Access Key
  static String accessKey = 'minioadmin';

  /// Secret Key
  static String secretKey = 'minioadmin';

  /// 获取 mc.exe 路径
  static String get mcPath {
    if (_mcPath.isEmpty) {
      _mcPath = _getDefaultMcPath();
    }
    return _mcPath;
  }

  /// 获取默认 mc.exe 路径（项目目录下）
  static String _getDefaultMcPath() {
    // 获取当前可执行文件所在目录
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;

    // 可能的 mc.exe 位置（按优先级）
    final possiblePaths = [
      // 1. 可执行文件同级目录
      // '$exeDir${Platform.pathSeparator}mc.exe',
      // // 2. 可执行文件同级 tools 目录
      // '$exeDir${Platform.pathSeparator}tools${Platform.pathSeparator}mc.exe',
      // // 3. 可执行文件同级 bin 目录
      // '$exeDir${Platform.pathSeparator}bin${Platform.pathSeparator}mc.exe',
      // // 4. 项目根目录 assets
      '${Directory.current.path}${Platform.pathSeparator}assets${Platform.pathSeparator}mc.exe',
      // // 5. 项目根目录 tools
      // '${Directory.current.path}${Platform.pathSeparator}tools${Platform.pathSeparator}mc.exe',
      // // 6. 项目根目录
      // '${Directory.current.path}${Platform.pathSeparator}mc.exe',
    ];

    for (final path in possiblePaths) {
      if (File(path).existsSync()) {
        print('[McConfig] 找到 mc.exe: $path');
        return path;
      }
    }

    // 如果都找不到，返回默认名称（依赖 PATH 环境变量）
    print('[McConfig] 未在项目目录找到 mc.exe，将使用 PATH 环境变量');
    return 'mc.exe';
  }

  /// 手动设置 mc.exe 路径
  static void setMcPath(String path) {
    _mcPath = path;
  }

  /// 配置服务器信息
  static void configure({
    required String alias,
    required String endpoint,
    required String accessKey,
    required String secretKey,
  }) {
    McConfig.alias = alias;
    McConfig.endpoint = endpoint;
    McConfig.accessKey = accessKey;
    McConfig.secretKey = secretKey;
  }

  /// 获取 mc.exe 所在目录（用于存放配置文件）
  static String get mcConfigDir {
    final mcFile = File(mcPath);
    if (mcFile.existsSync()) {
      return mcFile.parent.path;
    }
    return Directory.current.path;
  }
}

/// ============================================================
/// 传输任务状态
/// ============================================================
enum McTaskStatus {
  pending,    // 等待中
  running,    // 进行中
  completed,  // 已完成
  cancelled,  // 已取消
  failed,     // 失败
}

/// ============================================================
/// 传输任务信息
/// ============================================================
class McTask {
  final String taskId;
  final String localPath;
  final String remotePath;
  final bool isUpload;
  final DateTime startTime;

  Process? process;
  int transferredBytes = 0;
  int totalBytes = 0;
  int speed = 0;
  McTaskStatus status = McTaskStatus.pending;
  String? errorMessage;

  McTask({
    required this.taskId,
    required this.localPath,
    required this.remotePath,
    required this.isUpload,
  }) : startTime = DateTime.now();

  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0;

  String get formattedSpeed => _formatSize(speed) + '/s';

  String get formattedTransferred => _formatSize(transferredBytes);

  String get formattedTotal => _formatSize(totalBytes);

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// ============================================================
/// 传输结果
/// ============================================================
class McResult {
  final bool success;
  final String message;
  final String? taskId;
  final String? localPath;
  final String? remotePath;
  final int? size;
  final Duration? duration;
  final bool isCancelled;

  McResult({
    required this.success,
    required this.message,
    this.taskId,
    this.localPath,
    this.remotePath,
    this.size,
    this.duration,
    this.isCancelled = false,
  });

  @override
  String toString() => 'McResult(success: $success, message: $message, isCancelled: $isCancelled)';
}

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
      print('[McService] mc.exe 路径: $mcPath');
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
        print('[McService] 在 PATH 中找到 mc: $foundPath');
        McConfig.setMcPath(foundPath);
        return true;
      }
    } catch (_) {}

    print('[McService] 错误: mc.exe 未找到');
    print('[McService] 请将 mc.exe 放置在以下位置之一:');
    print('  - 可执行文件同级目录');
    print('  - 可执行文件同级 tools/ 目录');
    print('  - 项目 assets/ 目录');
    print('  - 项目 tools/ 目录');
    print('  - 或添加到系统 PATH 环境变量');

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
        print('[McService] 别名配置成功: ${McConfig.alias} -> ${McConfig.endpoint}');
        return true;
      } else {
        print('[McService] 别名配置失败: ${result.stderr}');
        return false;
      }
    } catch (e) {
      print('[McService] 初始化失败: $e');
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

    print('[McService] ========== 上传开始 ==========');
    print('[McService] 本地文件: $localPath');
    print('[McService] 远程路径: $remotePath');
    print('[McService] 文件大小: ${task.totalBytes} bytes');
    print('[McService] mc 命令: ${McConfig.mcPath} cp --json "$localPath" "$remotePath"');

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
        print('[McService] 验证文件存在: $exists');
        if (!exists) {
          print('[McService] ⚠️ 警告: 上传似乎成功但文件未找到，请检查路径');
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

  /// 上传文件（默认模式，非JSON，输出更直观）
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

    // 确保存储桶存在
    // await createBucket(bucket);

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

    print('[McService] ========== 上传开始（默认模式）==========');
    print('[McService] 本地文件: $localPath');
    print('[McService] 远程路径: $remotePath');
    print('[McService] 文件大小: ${task.totalBytes} bytes');

    final startTime = DateTime.now();
    task.status = McTaskStatus.running;

    try {
      // ✅ 使用默认模式（不带 --json）
      final args = ['cp', localPath, remotePath];
      print('[McService] 执行命令: ${McConfig.mcPath} ${args.join(" ")}');

      task.process = await Process.start(
        McConfig.mcPath,
        args,
        runInShell: true,
        environment: {
          'MC_CONFIG_DIR': McConfig.mcConfigDir,
        },
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutCompleter = Completer<void>();

      // 监听 stdout（默认模式会输出进度条）
      task.process!.stdout.transform(utf8.decoder).listen(
            (data) {
          stdoutBuffer.write(data);
          onOutput?.call(data);
          print('[McService] stdout: $data');
        },
        onDone: () => stdoutCompleter.complete(),
        onError: (e) => stdoutCompleter.completeError(e),
      );

      // 监听 stderr
      task.process!.stderr.transform(utf8.decoder).listen((data) {
        stderrBuffer.write(data);
        onOutput?.call(data);
        print('[McService] stderr: $data');
      });

      // 等待进程结束
      final exitCode = await task.process!.exitCode;
      await stdoutCompleter.future.catchError((_) {});

      final duration = DateTime.now().difference(startTime);

      // print('[McService] exitCode: $exitCode');
      // print('[McService] 完整 stdout: ${stdoutBuffer.toString()}');
      // print('[McService] 完整 stderr: ${stderrBuffer.toString()}');

      if (exitCode == 0) {
        task.status = McTaskStatus.completed;
        task.transferredBytes = task.totalBytes;

        // 验证文件是否存在
        final exists = await _objectExists(bucket, fileName);
        print('[McService] 验证文件存在: $exists');

        print('[McService] ✅ 上传完成');

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
      } else {
        task.status = McTaskStatus.failed;
        task.errorMessage = stderrBuffer.toString();

        print('[McService] ❌ 上传失败');

        return McResult(
          success: false,
          message: '上传失败: ${stderrBuffer.toString()}',
          taskId: effectiveTaskId,
        );
      }
    } catch (e) {
      task.status = McTaskStatus.failed;
      task.errorMessage = e.toString();

      print('[McService] ❌ 上传异常: $e');

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

    print('[McService] 开始上传目录: $localDir -> $remotePath');

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

    print('[McService] 开始下载: $remotePath -> $localPath');

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

  /// 下载文件（默认模式，非JSON，输出更直观）
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

    print('[McService] ========== 下载开始（默认模式）==========');
    print('[McService] 远程路径: $remotePath');
    print('[McService] 本地文件: $localPath');
    print('[McService] 文件大小: ${task.totalBytes} bytes');

    final startTime = DateTime.now();
    task.status = McTaskStatus.running;

    try {
      // ✅ 使用默认模式（不带 --json）
      final args = ['cp', remotePath, localPath];
      print('[McService] 执行命令: ${McConfig.mcPath} ${args.join(" ")}');

      task.process = await Process.start(
        McConfig.mcPath,
        args,
        runInShell: true,
        environment: {
          'MC_CONFIG_DIR': McConfig.mcConfigDir,
        },
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutCompleter = Completer<void>();

      // 监听 stdout
      task.process!.stdout.transform(utf8.decoder).listen(
            (data) {
          stdoutBuffer.write(data);
          onOutput?.call(data);
          print('[McService] stdout: $data');
        },
        onDone: () => stdoutCompleter.complete(),
        onError: (e) => stdoutCompleter.completeError(e),
      );

      // 监听 stderr
      task.process!.stderr.transform(utf8.decoder).listen((data) {
        stderrBuffer.write(data);
        onOutput?.call(data);
        print('[McService] stderr: $data');
      });

      // 等待进程结束
      final exitCode = await task.process!.exitCode;
      await stdoutCompleter.future.catchError((_) {});

      final duration = DateTime.now().difference(startTime);

      print('[McService] exitCode: $exitCode');
      print('[McService] 完整 stdout: ${stdoutBuffer.toString()}');
      print('[McService] 完整 stderr: ${stderrBuffer.toString()}');

      if (exitCode == 0) {
        task.status = McTaskStatus.completed;

        // 验证本地文件是否存在
        final localFile = File(localPath);
        final exists = await localFile.exists();
        print('[McService] 验证本地文件存在: $exists');

        if (exists) {
          task.transferredBytes = await localFile.length();
        }

        print('[McService] ✅ 下载完成');

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
      } else {
        task.status = McTaskStatus.failed;
        task.errorMessage = stderrBuffer.toString();

        print('[McService] ❌ 下载失败');

        return McResult(
          success: false,
          message: '下载失败: ${stderrBuffer.toString()}',
          taskId: effectiveTaskId,
        );
      }
    } catch (e) {
      task.status = McTaskStatus.failed;
      task.errorMessage = e.toString();

      print('[McService] ❌ 下载异常: $e');

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

    print('[McService] 开始下载目录: $remotePath -> $localDir');

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
  Future<bool> cancelTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) {
      print('[McService] 任务不存在: $taskId');
      return false;
    }

    if (task.status != McTaskStatus.running) {
      print('[McService] 任务未在运行: $taskId');
      return false;
    }

    try {
      // 杀死进程
      if (task.process != null) {
        task.process!.kill(ProcessSignal.sigterm);

        // Windows 下可能需要强制杀死
        if (Platform.isWindows) {
          await Process.run('taskkill', ['/F', '/T', '/PID', '${task.process!.pid}'], runInShell: true);
        }
      }

      task.status = McTaskStatus.cancelled;
      print('[McService] 已取消任务: $taskId');
      return true;
    } catch (e) {
      print('[McService] 取消任务失败: $e');
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

    print('[McService] 已取消 $cancelledCount 个任务');
    return cancelledCount;
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
        print('[McService] 列出对象失败: ${result.stderr}');
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
      print('[McService] 列出对象异常: $e');
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
        print('[McService] 删除成功: $objectName');
        return true;
      } else {
        print('[McService] 删除失败: ${result.stderr}');
        return false;
      }
    } catch (e) {
      print('[McService] 删除异常: $e');
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
      print('[McService] 删除目录异常: $e');
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
      print('[McService] 创建存储桶失败: ${result.stderr}');
      return false;
    } catch (e) {
      print('[McService] 创建存储桶异常: $e');
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
      print('[McService] 执行命令: ${McConfig.mcPath} ${args.join(" ")}');

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
      print('[McService] exitCode: $exitCode');
      if (stdoutBuffer.isNotEmpty) {
        print('[McService] stdout: ${stdoutBuffer.toString()}');
      }
      if (stderrBuffer.isNotEmpty) {
        print('[McService] stderr: ${stderrBuffer.toString()}');
      }

      if (exitCode == 0) {
        task.status = McTaskStatus.completed;
        task.transferredBytes = task.totalBytes;
        onProgress?.call(task.totalBytes, task.totalBytes, 0);

        print('[McService] ✅ 传输完成: ${task.localPath}');

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

        print('[McService] ❌ 传输失败');

        return McResult(
          success: false,
          message: '传输失败: ${stderrBuffer.toString()}',
          taskId: task.taskId,
        );
      }
    } catch (e) {
      task.status = McTaskStatus.failed;
      task.errorMessage = e.toString();

      print('[McService] ❌ 传输异常: $e');

      return McResult(
        success: false,
        message: '传输异常: $e',
        taskId: task.taskId,
      );
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

      print('[McService] stat 命令结果: exitCode=${result.exitCode}');
      if (result.exitCode != 0) {
        print('[McService] stat stderr: ${result.stderr}');
      }

      return result.exitCode == 0;
    } catch (e) {
      print('[McService] _objectExists 异常: $e');
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

/// ============================================================
/// 对象信息
/// ============================================================
class McObjectInfo {
  final String key;
  final int size;
  final DateTime? lastModified;
  final bool isDir;

  McObjectInfo({
    required this.key,
    required this.size,
    this.lastModified,
    this.isDir = false,
  });

  String get readableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  String toString() => 'McObjectInfo(key: $key, size: $readableSize, isDir: $isDir)';
}