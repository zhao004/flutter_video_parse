import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/parse_logs.dart';
import 'tables/parse_result_caches.dart';
import 'type/utc_date_time_converter.dart';

part 'database.g.dart';

@DriftDatabase(tables: [ParseLogs, ParseResultCaches])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 使用指定执行器创建数据库，仅用于内存数据库等隔离测试场景。
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(parseLogs);
      }
      if (from < 3) {
        await migrator.createTable(parseResultCaches);
      }
    },
  );

  Future<List<ParseLog>> getRecentParseLogs({int limit = 80}) {
    final query = select(parseLogs)
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.get();
  }

  Future<int> createParseLog(ParseLogsCompanion log) {
    return into(parseLogs).insert(log);
  }

  Future<int> deleteParseLogsByIds(Iterable<int> ids) {
    final idList = ids.toList(growable: false);
    if (idList.isEmpty) {
      return Future.value(0);
    }
    return (delete(parseLogs)..where((table) => table.id.isIn(idList))).go();
  }

  Future<int> deleteAllParseLogs() => delete(parseLogs).go();

  Future<int> trimParseLogs({int keepLatest = 80}) async {
    if (keepLatest <= 0) {
      return deleteAllParseLogs();
    }

    final rowsToDelete = await customSelect(
      '''
      SELECT id
      FROM parse_logs
      WHERE id NOT IN (
        SELECT id
        FROM parse_logs
        ORDER BY created_at DESC
        LIMIT ?
      )
      ''',
      variables: [Variable<int>(keepLatest)],
      readsFrom: {parseLogs},
    ).map((row) => row.read<int>('id')).get();

    return deleteParseLogsByIds(rowsToDelete);
  }

  Future<ParseResultCache?> getParseResultCache(String cacheKey) {
    return (select(
      parseResultCaches,
    )..where((table) => table.cacheKey.equals(cacheKey))).getSingleOrNull();
  }

  Future<int> upsertParseResultCache(ParseResultCachesCompanion cache) {
    return into(parseResultCaches).insertOnConflictUpdate(cache);
  }

  Future<int> deleteParseResultCache(String cacheKey) {
    return (delete(
      parseResultCaches,
    )..where((table) => table.cacheKey.equals(cacheKey))).go();
  }

  Future<int> deleteExpiredParseResultCaches(DateTime now) {
    return (delete(
      parseResultCaches,
    )..where((table) => table.expiresAt.isSmallerThanValue(now))).go();
  }

  Future<int> deleteAllParseResultCaches() => delete(parseResultCaches).go();

  /// 查询日志和解析缓存的逻辑载荷大小，单位为字节。
  ///
  /// 设计取舍：按 SQLite 中实际 UTF-8 字节数统计文本，并计入整数时间字段；
  /// 不使用数据库文件大小，因为已释放页和表结构页会让“清空”后仍显示旧容量。
  Future<int> getLocalStorageSizeBytes() async {
    final row = await customSelect(
      '''
      SELECT
        COALESCE((
          SELECT SUM(
            16 +
            LENGTH(CAST(level AS BLOB)) +
            LENGTH(CAST(title AS BLOB)) +
            LENGTH(CAST(description AS BLOB)) +
            LENGTH(CAST(source AS BLOB)) +
            LENGTH(CAST(badge AS BLOB))
          )
          FROM parse_logs
        ), 0) +
        COALESCE((
          SELECT SUM(
            16 +
            LENGTH(CAST(cache_key AS BLOB)) +
            LENGTH(CAST(input_url AS BLOB)) +
            LENGTH(CAST(provider_name AS BLOB)) +
            LENGTH(CAST(result_json AS BLOB))
          )
          FROM parse_result_caches
        ), 0) AS size_bytes
      ''',
      readsFrom: {parseLogs, parseResultCaches},
    ).getSingle();
    return row.read<int>('size_bytes');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/app_database.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
