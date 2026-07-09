import 'package:drift/drift.dart';

class UtcDateTimeConverter extends TypeConverter<DateTime, DateTime> {
  const UtcDateTimeConverter();

  @override
  DateTime fromSql(DateTime fromDb) => fromDb.toLocal();

  @override
  DateTime toSql(DateTime value) => value.toUtc();
}
