import 'dart:convert';

import 'package:dart_video_parse/dart_video_parse.dart';

import '../database/database.dart';

/// 解析结果缓存接口。
///
/// 设计意图：服务层依赖抽象接口，便于测试中注入内存实现，同时生产环境
/// 使用 Drift + SQLite 持久化缓存。
abstract interface class ParseResultCacheStore {
  Future<ParseResult?> read({
    required String inputUrl,
    VideoParseProvider? provider,
  });

  Future<void> write({
    required String inputUrl,
    required ParseResult result,
    required Duration ttl,
    VideoParseProvider? provider,
  });
}

/// 解析结果缓存仓储。
///
/// 设计意图：缓存键由标准化短视频链接和解析源组成，避免相同链接重复请求
/// 上游接口；只缓存有效解析结果，并通过过期时间规避媒体直链失效问题。
class ParseResultCacheRepository implements ParseResultCacheStore {
  const ParseResultCacheRepository(this._database);

  final AppDatabase _database;

  String buildCacheKey({
    required String inputUrl,
    VideoParseProvider? provider,
  }) {
    final providerName = provider?.name ?? _autoProviderName;
    return '${_normalizeUrl(inputUrl)}::$providerName';
  }

  @override
  Future<ParseResult?> read({
    required String inputUrl,
    VideoParseProvider? provider,
  }) async {
    final cacheKey = buildCacheKey(inputUrl: inputUrl, provider: provider);
    final row = await _database.getParseResultCache(cacheKey);
    if (row == null) {
      return null;
    }

    final now = DateTime.now();
    if (!row.expiresAt.isAfter(now)) {
      await _database.deleteParseResultCache(cacheKey);
      return null;
    }

    try {
      final json = jsonDecode(row.resultJson);
      if (json is! Map<String, Object?>) {
        await _database.deleteParseResultCache(cacheKey);
        return null;
      }
      final result = _parseResultFromJson(json);
      return result.isValid ? result : null;
    } catch (_) {
      await _database.deleteParseResultCache(cacheKey);
      return null;
    }
  }

  @override
  Future<void> write({
    required String inputUrl,
    required ParseResult result,
    required Duration ttl,
    VideoParseProvider? provider,
  }) async {
    if (!result.isValid || ttl <= Duration.zero) {
      return;
    }

    final now = DateTime.now();
    final normalizedUrl = _normalizeUrl(inputUrl);
    final providerName = provider?.name ?? _autoProviderName;
    final cacheKey = buildCacheKey(inputUrl: normalizedUrl, provider: provider);
    await _database.upsertParseResultCache(
      ParseResultCachesCompanion.insert(
        cacheKey: cacheKey,
        inputUrl: normalizedUrl,
        providerName: providerName,
        resultJson: jsonEncode(result.toJson()),
        createdAt: now,
        expiresAt: now.add(ttl),
      ),
    );
    await _database.deleteExpiredParseResultCaches(now);
  }

  Future<int> clear() {
    return _database.deleteAllParseResultCaches();
  }

  ParseResult _parseResultFromJson(Map<String, Object?> json) {
    final videos = _listValue(json['videos'])
        .map(_mapValue)
        .whereType<Map<String, Object?>>()
        .map(
          (item) => VideoItem(
            url: _stringValue(item['url']),
            quality: _stringValue(item['quality']),
          ),
        )
        .where((item) => item.url.trim().isNotEmpty)
        .toList(growable: false);

    final images = _listValue(json['images'])
        .map(_mapValue)
        .whereType<Map<String, Object?>>()
        .map((item) => ImageItem(url: _stringValue(item['url'])))
        .where((item) => item.url.trim().isNotEmpty)
        .toList(growable: false);

    final musicMap = _mapValue(json['music']);
    final music = musicMap == null
        ? null
        : MusicInfo(
            title: _stringValue(musicMap['title']),
            url: _stringValue(musicMap['url']),
          );

    return ParseResult(
      type: _stringValue(
        json['media_type'],
        defaultValue: _stringValue(json['type']),
      ),
      title: _stringValue(json['title']),
      author: _stringValue(json['author']),
      cover: _stringValue(json['cover']),
      duration: _stringValue(json['duration']),
      videos: videos,
      images: images,
      music: music,
      platform: _stringValue(json['platform']),
      sourceUrl: _stringValue(json['source_url']),
      parserUsed: _stringValue(json['parser_used']),
    );
  }

  static const String _autoProviderName = 'auto';

  static String _normalizeUrl(String value) {
    final url = ParseUtils.firstHttpUrl(value).trim();
    return url.isEmpty ? value.trim() : url;
  }

  static List<Object?> _listValue(Object? value) {
    return value is List ? value.cast<Object?>() : const <Object?>[];
  }

  static Map<String, Object?>? _mapValue(Object? value) {
    return value is Map ? value.cast<String, Object?>() : null;
  }

  static String _stringValue(Object? value, {String defaultValue = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? defaultValue : text;
  }
}
