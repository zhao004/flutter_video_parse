import 'package:dart_video_parse/dart_video_parse.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_parse/app/database/database.dart';
import 'package:flutter_video_parse/app/models/parse_ui_models.dart';
import 'package:flutter_video_parse/app/services/parse_log_repository.dart';
import 'package:flutter_video_parse/app/services/parse_result_cache_repository.dart';

void main() {
  group('SQLite 本地容量统计', () {
    late AppDatabase database;
    late ParseLogRepository logRepository;
    late ParseResultCacheRepository cacheRepository;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      logRepository = ParseLogRepository(database);
      cacheRepository = ParseResultCacheRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('同时统计日志和图集解析 JSON，清空后恢复为零', () async {
      expect(await cacheRepository.getLocalStorageSizeBytes(), 0);

      await logRepository.createLog(
        ParseLogEntry(
          createdAt: DateTime.utc(2026, 7, 14),
          level: ParseLogLevel.success,
          title: '解析成功',
          description: '包含中文的日志内容',
          source: 'spapi',
          badge: 'video',
        ),
      );
      final logSize = await cacheRepository.getLocalStorageSizeBytes();
      expect(logSize, greaterThan(0));

      await cacheRepository.write(
        inputUrl: 'https://example.com/gallery/1',
        result: ParseResult(
          type: 'gallery',
          images: List.generate(
            40,
            (index) => ImageItem(
              url: 'https://cdn.example.com/gallery/image_$index.jpg',
            ),
          ),
        ),
        ttl: const Duration(hours: 1),
      );
      final totalSize = await cacheRepository.getLocalStorageSizeBytes();
      expect(totalSize, greaterThan(logSize));

      await logRepository.clearLogs();
      expect(await cacheRepository.getLocalStorageSizeBytes(), greaterThan(0));

      await cacheRepository.clear();
      expect(await cacheRepository.getLocalStorageSizeBytes(), 0);
    });
  });
}
