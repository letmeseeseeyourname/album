import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 上传任务状态枚举
enum UploadTaskStatus {
  pending, // created but not started
  uploading,
  success,
  failed,
  canceled,
}

/// 状态扩展：枚举 ↔ 整数映射
extension UploadTaskStatusX on UploadTaskStatus {
  int get code => index;
  static UploadTaskStatus fromCode(int code) => UploadTaskStatus.values[code];
}

/// 上传任务记录模型（增强版：包含文件统计）
class UploadTaskRecord {
  final int taskId;
  final int userId;
  final int groupId;
  final UploadTaskStatus status;
  final int createdAt;
  final int updatedAt;
  final int fileCount;
  final int totalSize;

  UploadTaskRecord({
    required this.taskId,
    required this.userId,
    required this.groupId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.fileCount = 0,
    this.totalSize = 0,
  });

  UploadTaskRecord copyWith({
    UploadTaskStatus? status,
    int? updatedAt,
    int? fileCount,
    int? totalSize,
  }) =>
      UploadTaskRecord(
        taskId: taskId,
        userId: userId,
        groupId: groupId,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        fileCount: fileCount ?? this.fileCount,
        totalSize: totalSize ?? this.totalSize,
      );

  Map<String, Object?> toMap() => {
    'task_id': taskId,
    'user_id': userId,
    'group_id': groupId,
    'status': status.code,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'file_count': fileCount,
    'total_size': totalSize,
  };

  static UploadTaskRecord fromMap(Map<String, Object?> map) => UploadTaskRecord(
    taskId: map['task_id'] as int,
    userId: map['user_id'] as int,
    groupId: map['group_id'] as int,
    status: UploadTaskStatusX.fromCode(map['status'] as int),
    createdAt: map['created_at'] as int,
    updatedAt: map['updated_at'] as int,
    fileCount: (map['file_count'] as int?) ?? 0,
    totalSize: (map['total_size'] as int?) ?? 0,
  );

  String get formattedSize {
    if (totalSize < 1024) {
      return '${totalSize}B';
    } else if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)}KB';
    } else if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
    }
  }
}

/// 上传任务数据库管理器
class UploadFileTaskManager {
  static final UploadFileTaskManager instance = UploadFileTaskManager._init();
  UploadFileTaskManager._init();

  static const _dbName = 'upload_tasks.db';
  static const _dbVersion = 7;
  static const _table = 'upload_tasks';

  Database? _db;
  Future<Database>? _openFuture;
  bool _schemaFixed = false; // ✅ 标记是否已修复过

  Future<Database> _database() async {
    if (_db != null) return _db!;
    _openFuture ??= _openDb();
    _db = await _openFuture!;
    return _db!;
  }

  Future<Database> _openDb() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    debugPrint("upload_tasks DB path: $path");

    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: (db, version) async {
          debugPrint('Creating new database with version $version');
          await _createTable(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint('Upgrading database from $oldVersion to $newVersion');
        },
      ),
    );

    // ✅ 打开后立即检查并修复表结构
    await _ensureTableStructure(db);

    return db;
  }

  /// ✅ 检查并修复表结构
  Future<void> _ensureTableStructure(Database db) async {
    if (_schemaFixed) return; // 已修复过就跳过

    try {
      final columns = await db.rawQuery("PRAGMA table_info($_table)");
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      debugPrint('Current columns: $columnNames');

      if (!columnNames.contains('file_count') || !columnNames.contains('total_size')) {
        debugPrint('Missing columns detected, rebuilding table...');
        await _rebuildTable(db, columnNames);
      }

      _schemaFixed = true;
    } catch (e) {
      debugPrint('Error checking table structure: $e');
      // 表可能不存在，创建它
      await _createTable(db);
      _schemaFixed = true;
    }
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        task_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        group_id INTEGER NOT NULL,
        status INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        file_count INTEGER NOT NULL DEFAULT 0,
        total_size INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (task_id, user_id, group_id)
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_user ON $_table(user_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_group ON $_table(group_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_status ON $_table(status);');
  }

  Future<void> _rebuildTable(Database db, Set<String> existingColumns) async {
    debugPrint('Rebuilding table...');

    // 1. 创建新表
    await db.execute('DROP TABLE IF EXISTS ${_table}_new;');
    await db.execute('''
      CREATE TABLE ${_table}_new (
        task_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        group_id INTEGER NOT NULL,
        status INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        file_count INTEGER NOT NULL DEFAULT 0,
        total_size INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (task_id, user_id, group_id)
      );
    ''');

    // 2. 迁移数据
    final baseColumns = ['task_id', 'user_id', 'group_id', 'status', 'created_at', 'updated_at'];
    final existingBaseColumns = baseColumns.where((c) => existingColumns.contains(c)).toList();

    if (existingBaseColumns.isNotEmpty) {
      final columnList = existingBaseColumns.join(', ');
      await db.execute('''
        INSERT INTO ${_table}_new ($columnList, file_count, total_size)
        SELECT $columnList, 0, 0 FROM $_table;
      ''');
    }

    // 3. 替换旧表
    await db.execute('DROP TABLE IF EXISTS $_table;');
    await db.execute('ALTER TABLE ${_table}_new RENAME TO $_table;');

    // 4. 重建索引
    await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_user ON $_table(user_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_group ON $_table(group_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_status ON $_table(status);');

    debugPrint('Table rebuild completed');
  }

  /// ✅ 插入任务（带自动修复）
  Future<void> insertTask({
    required int taskId,
    required int userId,
    required int groupId,
    UploadTaskStatus status = UploadTaskStatus.pending,
    int fileCount = 0,
    int totalSize = 0,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.insert(
        _table,
        UploadTaskRecord(
          taskId: taskId,
          userId: userId,
          groupId: groupId,
          status: status,
          createdAt: now,
          updatedAt: now,
          fileCount: fileCount,
          totalSize: totalSize,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // ✅ 捕获列缺失错误，自动修复后重试
      if (e.toString().contains('has no column named')) {
        debugPrint('Column missing error, attempting auto-fix...');
        _schemaFixed = false; // 重置标记
        await _ensureTableStructure(db);

        // 重试插入
        await db.insert(
          _table,
          UploadTaskRecord(
            taskId: taskId,
            userId: userId,
            groupId: groupId,
            status: status,
            createdAt: now,
            updatedAt: now,
            fileCount: fileCount,
            totalSize: totalSize,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        debugPrint('Auto-fix successful, insert completed');
      } else {
        rethrow;
      }
    }
  }

  Future<void> upsertTask({
    required int taskId,
    required int userId,
    required int groupId,
    UploadTaskStatus status = UploadTaskStatus.pending,
    int? fileCount,
    int? totalSize,
  }) async {
    await insertTask(
      taskId: taskId,
      userId: userId,
      groupId: groupId,
      status: status,
      fileCount: fileCount ?? 0,
      totalSize: totalSize ?? 0,
    );
  }

  Future<int> updateStatus(int taskId, UploadTaskStatus status) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.update(
      _table,
      {'status': status.code, 'updated_at': now},
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  Future<int> updateStatusForKey({
    required int taskId,
    required int userId,
    required int groupId,
    required UploadTaskStatus status,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.update(
      _table,
      {'status': status.code, 'updated_at': now},
      where: 'task_id = ? AND user_id = ? AND group_id = ?',
      whereArgs: [taskId, userId, groupId],
    );
  }

  Future<int> updateTaskStats({
    required int taskId,
    required int userId,
    required int groupId,
    required int fileCount,
    required int totalSize,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.update(
      _table,
      {
        'file_count': fileCount,
        'total_size': totalSize,
        'updated_at': now,
      },
      where: 'task_id = ? AND user_id = ? AND group_id = ?',
      whereArgs: [taskId, userId, groupId],
    );
  }

  Future<int> deleteTask(int taskId) async {
    final db = await _database();
    return db.delete(_table, where: 'task_id = ?', whereArgs: [taskId]);
  }

  Future<int> deleteTaskForKey({
    required int taskId,
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

  Future<int> deleteByUserGroup(int userId, int groupId) async {
    final db = await _database();
    return db.delete(_table, where: 'user_id = ? AND group_id = ?', whereArgs: [userId, groupId]);
  }

  Future<UploadTaskRecord?> getTask(int taskId) async {
    final db = await _database();
    final rows = await db.query(_table, where: 'task_id = ?', whereArgs: [taskId], limit: 1);
    if (rows.isEmpty) return null;
    return UploadTaskRecord.fromMap(rows.first);
  }

  Future<UploadTaskRecord?> getTaskForKey({
    required int taskId,
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
    return UploadTaskRecord.fromMap(rows.first);
  }

  Future<List<UploadTaskRecord>> listTasks({
    required int userId,
    required int groupId,
    UploadTaskStatus? status,
    int? limit,
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
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(UploadTaskRecord.fromMap).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _openFuture = null;
    _schemaFixed = false;
  }
}