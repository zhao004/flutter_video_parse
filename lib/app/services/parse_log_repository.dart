import 'package:drift/drift.dart';

import '../database/database.dart';
import '../models/parse_ui_models.dart';

/// 解析日志仓储，封装 Drift + SQLite 的读写细节。
///
/// 设计意图：控制器只处理页面状态和交互，不直接拼装数据库 Companion；
/// 这样后续调整表结构或清理策略时，不会影响日志列表 UI。
class ParseLogRepository {
  const ParseLogRepository(this._database);

  static const int defaultLimit = 80;

  final AppDatabase _database;

  Future<List<ParseLogEntry>> fetchRecentLogs({
    int limit = defaultLimit,
  }) async {
    final rows = await _database.getRecentParseLogs(limit: limit);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<ParseLogEntry?> createLog(ParseLogEntry entry) async {
    final id = await _database.createParseLog(
      ParseLogsCompanion.insert(
        createdAt: entry.createdAt,
        level: entry.level.name,
        title: entry.title,
        description: entry.description,
        source: Value(entry.source),
        badge: Value(entry.badge),
      ),
    );
    await _database.trimParseLogs(keepLatest: defaultLimit);

    return ParseLogEntry(
      id: id,
      createdAt: entry.createdAt,
      level: entry.level,
      title: entry.title,
      description: entry.description,
      source: entry.source,
      badge: entry.badge,
    );
  }

  Future<int> deleteLogsByIds(Iterable<int> ids) {
    return _database.deleteParseLogsByIds(ids);
  }

  Future<int> clearLogs() {
    return _database.deleteAllParseLogs();
  }

  ParseLogEntry _fromRow(ParseLog row) {
    return ParseLogEntry(
      id: row.id,
      createdAt: row.createdAt,
      level: _parseLevel(row.level),
      title: row.title,
      description: row.description,
      source: row.source,
      badge: row.badge,
    );
  }

  /// 将数据库文本安全映射为日志级别。
  ///
  /// 异常策略：遇到旧版本或异常数据时降级为 warning，保证日志列表可渲染。
  ParseLogLevel _parseLevel(String value) {
    return switch (value) {
      'success' => ParseLogLevel.success,
      'error' => ParseLogLevel.error,
      'warning' => ParseLogLevel.warning,
      _ => ParseLogLevel.warning,
    };
  }
}
