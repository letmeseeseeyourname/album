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

/// 上传任务记录模型
class UploadTaskRecord {
  final int taskId; // unique id for this upload task
  final int userId;
  final int groupId;
  final UploadTaskStatus status;
  final int createdAt; // epoch millis
  final int updatedAt; // epoch millis

  UploadTaskRecord({
    required this.taskId,
    required this.userId,
    required this.groupId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  UploadTaskRecord copyWith({
    UploadTaskStatus? status,
    int? updatedAt,
  }) =>
      UploadTaskRecord(
        taskId: taskId,
        userId: userId,
        groupId: groupId,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
    'task_id': taskId,
    'user_id': userId,
    'group_id': groupId,
    'status': status.code,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  static UploadTaskRecord fromMap(Map<String, Object?> map) => UploadTaskRecord(
    taskId: map['task_id'] as int,
    userId: map['user_id'] as int,
    groupId: map['group_id'] as int,
    status: UploadTaskStatusX.fromCode(map['status'] as int),
    createdAt: map['created_at'] as int,
    updatedAt: map['updated_at'] as int,
  );
}

/// 上传任务数据库管理器（Windows/Linux/macOS/移动端通用）
class UploadFileTaskManager {
  static final UploadFileTaskManager instance = UploadFileTaskManager._init();
  UploadFileTaskManager._init();

  static const _dbName = 'upload_tasks.db';
  static const _dbVersion = 3;
  static const _table = 'upload_tasks';

  Database? _db;
  Future<Database>? _openFuture;

  /// 保证数据库已打开（单例模式）
  Future<Database> _database() async {
    if (_db != null) return _db!;
    _openFuture ??= _openDb();
    _db = await _openFuture!;
    return _db!;
  }

  /// 打开数据库（FFI 版）
  Future<Database> _openDb() async {
    // ✅ 初始化 FFI 支持
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    debugPrint("upload_tasks DB path: $path");

    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_table (
              task_id INTEGER NOT NULL,
              user_id INTEGER NOT NULL,
              group_id INTEGER NOT NULL,
              status INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              PRIMARY KEY (task_id, user_id, group_id)
            );
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_user ON $_table(user_id);');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_group ON $_table(group_id);');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_status ON $_table(status);');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS ${_table}_new (
                task_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                group_id INTEGER NOT NULL,
                status INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (task_id, user_id, group_id)
              );
            ''');
            await db.execute('''
              INSERT OR REPLACE INTO ${_table}_new(task_id,user_id,group_id,status,created_at,updated_at)
              SELECT CAST(task_id AS INTEGER), user_id, group_id, status, created_at, updated_at FROM $_table;
            ''');
            await db.execute('DROP TABLE IF EXISTS $_table;');
            await db.execute('ALTER TABLE ${_table}_new RENAME TO $_table;');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_user ON $_table(user_id);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_group ON $_table(group_id);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_status ON $_table(status);');
          }

          if (oldVersion < 3) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS ${_table}_v3 (
                task_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                group_id INTEGER NOT NULL,
                status INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (task_id, user_id, group_id)
              );
            ''');
            await db.execute('''
              INSERT OR REPLACE INTO ${_table}_v3(task_id,user_id,group_id,status,created_at,updated_at)
              SELECT task_id, user_id, group_id, status, created_at, updated_at FROM $_table;
            ''');
            await db.execute('DROP TABLE IF EXISTS $_table;');
            await db.execute('ALTER TABLE ${_table}_v3 RENAME TO $_table;');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_user ON $_table(user_id);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_group ON $_table(group_id);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_${_table}_status ON $_table(status);');
          }
        },
      ),
    );
  }

  /// 插入新任务（存在相同主键会替换）
  Future<void> insertTask({
    required int taskId,
    required int userId,
    required int groupId,
    UploadTaskStatus status = UploadTaskStatus.pending,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      _table,
      UploadTaskRecord(
        taskId: taskId,
        userId: userId,
        groupId: groupId,
        status: status,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Upsert（插入或替换）任务
  Future<void> upsertTask({
    required int taskId,
    required int userId,
    required int groupId,
    UploadTaskStatus status = UploadTaskStatus.pending,
  }) async {
    await insertTask(taskId: taskId, userId: userId, groupId: groupId, status: status);
  }

  /// 根据 taskId 更新状态（可能匹配多个用户）
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

  /// 更新复合主键对应的任务状态
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

  /// 删除指定 taskId（可能删除多行）
  Future<int> deleteTask(int taskId) async {
    final db = await _database();
    return db.delete(_table, where: 'task_id = ?', whereArgs: [taskId]);
  }

  /// 删除单条（复合主键）
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

  /// 删除指定用户+群组的所有任务
  Future<int> deleteByUserGroup(int userId, int groupId) async {
    final db = await _database();
    return db.delete(_table, where: 'user_id = ? AND group_id = ?', whereArgs: [userId, groupId]);
  }

  /// 获取单个任务（按 taskId）
  Future<UploadTaskRecord?> getTask(int taskId) async {
    final db = await _database();
    final rows = await db.query(_table, where: 'task_id = ?', whereArgs: [taskId], limit: 1);
    if (rows.isEmpty) return null;
    return UploadTaskRecord.fromMap(rows.first);
  }

  /// 获取单个任务（复合主键）
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

  /// 查询用户/群组下的任务列表（可按状态过滤）
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

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _openFuture = null;
  }
}
