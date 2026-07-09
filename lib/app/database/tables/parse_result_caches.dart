import 'package:drift/drift.dart';

import '../type/utc_date_time_converter.dart';

/// 解析结果缓存表。
///
/// 设计意图：相同短视频链接和解析源在短时间内重复解析时，直接复用本地
/// SQLite 缓存结果，减少上游请求和用户等待；缓存设置过期时间，避免长期
/// 复用可能失效的媒体直链。
class ParseResultCaches extends Table {
  TextColumn get cacheKey => text()();

  TextColumn get inputUrl => text()();

  TextColumn get providerName => text()();

  TextColumn get resultJson => text()();

  DateTimeColumn get createdAt =>
      dateTime().map(const UtcDateTimeConverter())();

  DateTimeColumn get expiresAt =>
      dateTime().map(const UtcDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}
