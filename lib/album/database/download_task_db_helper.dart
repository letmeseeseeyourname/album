// download_task_db_helper.dart
// ✅ 修复版：确保 download_tasks 表在任何情况下都会被创建

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 下载任务状态枚举
enum DownloadTaskStatus {
  pending,    // 等待下载
  downloading, // 下载中
  paused,     // 暂停
  completed,  // 完成
  failed,     // 失败
  canceled,   // 取消
}

/// 状态扩展：枚举 ↔ 整数映射
extension DownloadTaskStatusX on DownloadTaskStatus {
  int get code => index;
  static DownloadTaskStatus fromCode(int code) => DownloadTaskStatus.values[code];
}

/// 下载任务记录模型
class DownloadTaskRecord {
  final String taskId;      // 任务ID (使用resId)
  final int userId;          // 用户ID
  final int groupId;         // 群组ID
  final String fileName;     // 文件名
  final String? filePath;    // 文件路径
  final String? thumbnailUrl; // 缩略图URL
  final String downloadUrl;  // 下载URL
  final int fileSize;        // 文件大小
  final int downloadedSize;  // 已下载大小
  final String fileType;     // 文件类型 (P/V)
  final DownloadTaskStatus status; // 状态
  final String? savePath;    // 保存路径
  final String? errorMessage; // 错误信息
  final int createdAt;       // 创建时间
  final int updatedAt;       // 更新时间

  DownloadTaskRecord({
    required this.taskId,
    required this.userId,
    required this.groupId,
    required this.fileName,
    this.filePath,
    this.thumbnailUrl,
    required this.downloadUrl,
    required this.fileSize,
    this.downloadedSize = 0,
    required this.fileType,
    required this.status,
    this.savePath,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  DownloadTaskRecord copyWith({
    String? fileName,
    String? filePath,
    String? thumbnailUrl,
    String? downloadUrl,
    int? fileSize,
    int? downloadedSize,
    String? fileType,
    DownloadTaskStatus? status,
    String? savePath,
    String? errorMessage,
    int? updatedAt,
  }) =>
      DownloadTaskRecord(
        taskId: taskId,
        userId: userId,
        groupId: groupId,
        fileName: fileName ?? this.fileName,
        filePath: filePath ?? this.filePath,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        downloadUrl: downloadUrl ?? this.downloadUrl,
        fileSize: fileSize ?? this.fileSize,
        downloadedSize: downloadedSize ?? this.downloadedSize,
        fileType: fileType ?? this.fileType,
        status: status ?? this.status,
        savePath: savePath ?? this.savePath,
        errorMessage: errorMessage ?? this.errorMessage,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
    'task_id': taskId,
    'user_id': userId,
    'group_id': groupId,
    'file_name': fileName,
    'file_path': filePath,
    'thumbnail_url': thumbnailUrl,
    'download_url': downloadUrl,
    'file_size': fileSize,
    'downloaded_size': downloadedSize,
    'file_type': fileType,
    'status': status.code,
    'save_path': savePath,
    'error_message': errorMessage,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  static DownloadTaskRecord fromMap(Map<String, Object?> map) => DownloadTaskRecord(
    taskId: map['task_id'] as String,
    userId: map['user_id'] as int,
    groupId: map['group_id'] as int,
    fileName: map['file_name'] as String,
    filePath: map['file_path'] as String?,
    thumbnailUrl: map['thumbnail_url'] as String?,
    downloadUrl: map['download_url'] as String,
    fileSize: map['file_size'] as int,
    downloadedSize: map['downloaded_size'] as int? ?? 0,
    fileType: map['file_type'] as String,
    status: DownloadTaskStatusX.fromCode(map['status'] as int),
    savePath: map['save_path'] as String?,
    errorMessage: map['error_message'] as String?,
    createdAt: map['created_at'] as int,
    updatedAt: map['updated_at'] as int,
  );

  /// 计算下载进度（百分比）
  double get progress {
    if (fileSize <= 0) return 0.0;
    return (downloadedSize / fileSize).clamp(0.0, 1.0);
  }

  /// 是否可以恢复下载
  bool get canResume => status == DownloadTaskStatus.paused ||
      status == DownloadTaskStatus.failed ||
      status == DownloadTaskStatus.pending;

  /// 是否正在下载
  bool get isDownloading => status == DownloadTaskStatus.downloading;

  /// 是否已完成
  bool get isCompleted => status == DownloadTaskStatus.completed;
}

/// 下载任务数据库管理器
class DownloadTaskDbHelper {
  static final DownloadTaskDbHelper instance = DownloadTaskDbHelper._init();
  DownloadTaskDbHelper._init();

  static const _dbName = 'upload_tasks.db'; // 复用同一个数据库文件
  static const _table = 'download_tasks';

  Database? _db;
  Future<Database>? _openFuture;
  bool _tableEnsured = false; // ✅ 标记表是否已确认存在

  /// 保证数据库已打开（单例模式）
  Future<Database> _database() async {
    if (_db != null) {
      // ✅ 即使数据库已打开，也要确保表存在
      if (!_tableEnsured) {
        await _ensureTableExists(_db!);
      }
      return _db!;
    }
    _openFuture ??= _openDb();
    _db = await _openFuture!;
    return _db!;
  }

  /// 打开数据库（FFI 版）
  Future<Database> _openDb() async {
    debugPrint('=== 打开下载任务数据库 ===');

    try {
      // 初始化 FFI 支持
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      debugPrint('FFI 初始化成功');

      final dbPath = await databaseFactory.getDatabasesPath();
      final path = p.join(dbPath, _dbName);
      debugPrint("数据库路径: $path");

      // ✅ 简化：不依赖版本号，直接打开数据库
      final db = await databaseFactory.openDatabase(path);

      debugPrint('数据库打开成功');

      // ✅ 确保表存在
      await _ensureTableExists(db);

      return db;
    } catch (e, stack) {
      debugPrint('打开数据库失败: $e');
      debugPrint('堆栈: $stack');
      rethrow;
    }
  }

  /// ✅ 确保下载任务表存在
  Future<void> _ensureTableExists(Database db) async {
    if (_tableEnsured) return;

    try {
      // 检查表是否存在
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$_table'"
      );

      if (tables.isEmpty) {
        debugPrint('download_tasks 表不存在，正在创建...');
        await _createDownloadTable(db);
      } else {
        debugPrint('download_tasks 表已存在');
      }

      _tableEnsured = true;
    } catch (e) {
      debugPrint('检查/创建表失败: $e');
      // 尝试强制创建
      try {
        await _createDownloadTable(db);
        _tableEnsured = true;
      } catch (e2) {
        debugPrint('强制创建表也失败: $e2');
      }
    }
  }

  /// 创建下载任务表
  Future<void> _createDownloadTable(Database db) async {
    debugPrint('开始创建 download_tasks 表...');

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_table (
          task_id TEXT NOT NULL,
          user_id INTEGER NOT NULL,
          group_id INTEGER NOT NULL,
          file_name TEXT NOT NULL,
          file_path TEXT,
          thumbnail_url TEXT,
          download_url TEXT NOT NULL,
          file_size INTEGER NOT NULL,
          downloaded_size INTEGER DEFAULT 0,
          file_type TEXT NOT NULL,
          status INTEGER NOT NULL,
          save_path TEXT,
          error_message TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY (task_id, user_id, group_id)
        );
      ''');
      debugPrint('download_tasks 表创建成功');

      // 创建索引
      await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_user ON $_table(user_id);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_group ON $_table(group_id);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_status ON $_table(status);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_created ON $_table(created_at DESC);');
      debugPrint('索引创建成功');

    } catch (e) {
      debugPrint('创建 download_tasks 表失败: $e');
      rethrow;
    }
  }

  /// 插入新任务（或更新现有任务）
  Future<int> insertTask(DownloadTaskRecord task) async {
    final db = await _database();
    return db.insert(
      _table,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批量插入任务
  Future<void> insertTasks(List<DownloadTaskRecord> tasks) async {
    if (tasks.isEmpty) return;

    final db = await _database();
    final batch = db.batch();

    for (final task in tasks) {
      batch.insert(
        _table,
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 更新任务状态
  Future<int> updateStatus({
    required String taskId,
    required int userId,
    required int groupId,
    required DownloadTaskStatus status,
    String? errorMessage,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;

    final updateData = <String, Object?>{
      'status': status.code,
      'updated_at': now,
    };

    if (errorMessage != null) {
      updateData['error_message'] = errorMessage;
    }

    return db.update(
      _table,
      updateData,
      where: 'task_id = ? AND user_id = ? AND group_id = ?',
      whereArgs: [taskId, userId, groupId],
    );
  }

  /// 更新下载进度
  Future<int> updateProgress({
    required String taskId,
    required int userId,
    required int groupId,
    required int downloadedSize,
    DownloadTaskStatus? status,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;

    final updateData = <String, Object?>{
      'downloaded_size': downloadedSize,
      'updated_at': now,
    };

    if (status != null) {
      updateData['status'] = status.code;
    }

    return db.update(
      _table,
      updateData,
      where: 'task_id = ? AND user_id = ? AND group_id = ?',
      whereArgs: [taskId, userId, groupId],
    );
  }

  /// 更新保存路径
  Future<int> updateSavePath({
    required String taskId,
    required int userId,
    required int groupId,
    required String savePath,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;

    return db.update(
      _table,
      {
        'save_path': savePath,
        'updated_at': now,
      },
      where: 'task_id = ? AND user_id = ? AND group_id = ?',
      whereArgs: [taskId, userId, groupId],
    );
  }

  /// 删除任务
  Future<int> deleteTask({
    required String taskId,
    required int userId,
    required int groupId,
  }) async {
    final db = await _database();
    return db.delete(
      _table,
      where: 'task_id = ? AND user_id = ? AND group_id = ?',
      whereArgs: [taskId, userId, groupId],
    );
  }

  /// 批量删除任务
  Future<int> deleteTasks(List<String> taskIds, int userId, int groupId) async {
    if (taskIds.isEmpty) return 0;

    final db = await _database();
    final placeholders = List.filled(taskIds.length, '?').join(',');

    return db.delete(
      _table,
      where: 'task_id IN ($placeholders) AND user_id = ? AND group_id = ?',
      whereArgs: [...taskIds, userId, groupId],
    );
  }

  /// 删除指定用户+群组的所有任务
  Future<int> deleteByUserGroup(int userId, int groupId) async {
    final db = await _database();
    return db.delete(
      _table,
      where: 'user_id = ? AND group_id = ?',
      whereArgs: [userId, groupId],
    );
  }

  /// 获取单个任务
  Future<DownloadTaskRecord?> getTask({
    required String taskId,
    required int userId,
    required int groupId,
  }) async {
    final db = await _database();
    final rows = await db.query(
      _table,
      where: 'task_id = ? AND user_id = ? AND group_id = ?',
      whereArgs: [taskId, userId, groupId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DownloadTaskRecord.fromMap(rows.first);
  }

  /// 查询任务列表
  Future<List<DownloadTaskRecord>> listTasks({
    required int userId,
    required int groupId,
    DownloadTaskStatus? status,
    int? limit,
    int? offset,
  }) async {
    final db = await _database();
    final where = StringBuffer('user_id = ? AND group_id = ?');
    final whereArgs = <Object?>[userId, groupId];

    if (status != null) {
      where.write(' AND status = ?');
      whereArgs.add(status.code);
    }

    final rows = await db.query(
      _table,
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map(DownloadTaskRecord.fromMap).toList();
  }

  /// 获取未完成的任务（用于恢复下载）
  Future<List<DownloadTaskRecord>> getIncompleteTasks({
    required int userId,
    required int groupId,
  }) async {
    final db = await _database();

    final rows = await db.query(
      _table,
      where: 'user_id = ? AND group_id = ? AND status IN (?,?,?)',
      whereArgs: [
        userId,
        groupId,
        DownloadTaskStatus.pending.code,
        DownloadTaskStatus.downloading.code,
        DownloadTaskStatus.paused.code,
      ],
      orderBy: 'created_at DESC',
    );

    return rows.map(DownloadTaskRecord.fromMap).toList();
  }

  /// 获取正在下载的任务数量
  Future<int> getDownloadingCount({
    required int userId,
    required int groupId,
  }) async {
    final db = await _database();

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_table WHERE user_id = ? AND group_id = ? AND status = ?',
      [userId, groupId, DownloadTaskStatus.downloading.code],
    );

    return result.first['count'] as int? ?? 0;
  }

  /// 清理过期的已完成任务（保留最近N条）
  Future<int> cleanOldCompletedTasks({
    required int userId,
    required int groupId,
    int keepCount = 100,
  }) async {
    final db = await _database();

    // 获取需要保留的任务ID
    final keepRows = await db.query(
      _table,
      columns: ['task_id'],
      where: 'user_id = ? AND group_id = ? AND status = ?',
      whereArgs: [userId, groupId, DownloadTaskStatus.completed.code],
      orderBy: 'created_at DESC',
      limit: keepCount,
    );

    if (keepRows.isEmpty) return 0;

    final keepIds = keepRows.map((r) => r['task_id'] as String).toList();
    final placeholders = List.filled(keepIds.length, '?').join(',');

    // 删除不在保留列表中的已完成任务
    return db.delete(
      _table,
      where: 'user_id = ? AND group_id = ? AND status = ? AND task_id NOT IN ($placeholders)',
      whereArgs: [userId, groupId, DownloadTaskStatus.completed.code, ...keepIds],
    );
  }

  /// 获取统计信息
  Future<Map<String, int>> getStatistics({
    required int userId,
    required int groupId,
  }) async {
    final db = await _database();

    final rows = await db.rawQuery('''
      SELECT 
        status, 
        COUNT(*) as count,
        SUM(file_size) as total_size,
        SUM(downloaded_size) as downloaded_size
      FROM $_table 
      WHERE user_id = ? AND group_id = ?
      GROUP BY status
    ''', [userId, groupId]);

    final stats = <String, int>{
      'total': 0,
      'pending': 0,
      'downloading': 0,
      'paused': 0,
      'completed': 0,
      'failed': 0,
      'canceled': 0,
      'total_size': 0,
      'downloaded_size': 0,
    };

    for (final row in rows) {
      final status = DownloadTaskStatusX.fromCode(row['status'] as int);
      final count = row['count'] as int;
      final totalSize = row['total_size'] as int? ?? 0;
      final downloadedSize = row['downloaded_size'] as int? ?? 0;

      stats[status.name] = count;
      stats['total'] = stats['total']! + count;
      stats['total_size'] = stats['total_size']! + totalSize;
      stats['downloaded_size'] = stats['downloaded_size']! + downloadedSize;
    }

    return stats;
  }

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _openFuture = null;
    _tableEnsured = false;
  }
}