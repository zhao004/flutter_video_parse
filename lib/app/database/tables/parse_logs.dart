import 'package:drift/drift.dart';

import '../type/utc_date_time_converter.dart';

/// 解析日志持久化表。
///
/// 设计意图：日志需要跨应用重启保留，因此使用 Drift + SQLite 存储；
/// 只保存界面展示所需字段，避免把解析结果大对象写入日志表导致体积膨胀。
class ParseLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get createdAt =>
      dateTime().map(const UtcDateTimeConverter())();

  TextColumn get level => text()();

  TextColumn get title => text()();

  TextColumn get description => text()();

  TextColumn get source => text().withDefault(const Constant(''))();

  TextColumn get badge => text().withDefault(const Constant(''))();
}
