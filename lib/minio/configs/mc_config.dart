import 'dart:io';

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