import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

import '../models/local_file_item.dart';



class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('album_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, filePath);
    print('数据库路径: $path');

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      ),
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        md5Hash TEXT NOT NULL,
        filePath TEXT NOT NULL,
        fileName TEXT NOT NULL,
        fileType TEXT NOT NULL,
        fileSize INTEGER NOT NULL,
        assetId TEXT NOT NULL,
        status INTEGER NOT NULL,
        userId TEXT NOT NULL,
        deviceCode TEXT NOT NULL,
        duration INTEGER NOT NULL,
        width INTEGER NOT NULL,
        height INTEGER NOT NULL,
        lng REAL NOT NULL,
        lat REAL NOT NULL,
        createDate REAL NOT NULL,
        UNIQUE(assetId, userId, deviceCode)
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE files ADD COLUMN createDate REAL NOT NULL DEFAULT 0');
    }
  }

  // === CRUD 封装 ===

  Future<int> insertFile(FileItem item) async {
    final db = await instance.database;
    return await db.insert('files', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FileItem>> fetchFiles() async {
    final db = await instance.database;
    final maps = await db.query('files');
    return maps.map((map) => FileItem.fromMap(map)).toList();
  }

  Future<List<FileItem>> queryStatusZeroByAssetIdList(String userId, String deviceCode, List<String> assetIdList) async {
    if (assetIdList.isEmpty) return [];
    final db = await instance.database;
    final placeholders = List.filled(assetIdList.length, '?').join(', ');
    final maps = await db.query(
      'files', // <-- Replace with your table name
      where: 'userId = ? AND deviceCode = ? AND status = ? AND assetId IN ($placeholders)',
      whereArgs: [userId, deviceCode, 0, ...assetIdList],
    );
    return maps.map((map) => FileItem.fromMap(map)).toList();
  }

  Future<List<FileItem>> fetchFilesByUserAndDevice(String userId, String deviceCode) async {
    final db = await instance.database;
    final maps = await db.query(
      'files',
      where: 'userId = ? AND deviceCode = ?',
      whereArgs: [userId, deviceCode],
    );
    return maps.map((map) => FileItem.fromMap(map)).toList();
  }

  Future<int> updateFileStatus(String userId, String deviceCode, int status) async {
    final db = await instance.database;
    return await db.update(
      'files',
      {'status': status},
      where: 'userId = ? AND deviceCode = ?',
      whereArgs: [userId, deviceCode],
    );
  }

  Future<int> updateFileStatusBeforeUploadAll(String userId, String deviceCode) async {
    int status = 0;
    final db = await instance.database;
    return await db.update(
      'files',
      {'status': status},
      where: 'userId = ? AND deviceCode = ? AND status == 1 ',
      whereArgs: [userId, deviceCode],
    );
  }

  Future<FileItem?> getFileByAssetId(String assetId) async {
    final db = await instance.database;
    final maps = await db.query(
      'files',
      where: 'assetId = ?',
      whereArgs: [assetId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return FileItem.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateFile(FileItem item) async {
    final db = await instance.database;
    return await db.update(
      'files',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> updateStatusByMd5Hash(String md5Hash, int status) async {
    final db = await instance.database;
    return await db.update(
      'files',
      {'status': status},
      where: 'md5Hash = ?',
      whereArgs: [md5Hash],
    );
  }

  //remove by assetId
  Future<int> deleteFileByAssetId(String assesetId) async {
    final db = await instance.database;
    return await db.delete(
      'files',
      where: 'assetId = ?',
      whereArgs: [assesetId],
    );
  }

  Future<int> deleteFile(int id) async {
    final db = await instance.database;
    return await db.delete('files', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
