import 'package:dart_video_parse/dart_video_parse.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_parse/app/models/parse_ui_models.dart';
import 'package:flutter_video_parse/app/services/parse_result_cache_repository.dart';
import 'package:flutter_video_parse/app/services/video_parse_service.dart';

void main() {
  group('VideoParseService', () {
    test('空链接会返回参数错误', () async {
      final service = VideoParseService(
        parser: VideoParser(
          providers: [
            TestVideoProvider(
              provider: VideoParseProvider.spapi,
              displayName: '测试源',
              priority: 1,
              baseUrl: 'https://example.com',
              handler: (_) async => const ParseResult(type: 'video'),
            ),
          ],
        ),
      );

      final outcome = await service.parse(rawInput: '   ');

      expect(outcome.success, isFalse);
      expect(outcome.code, ParseCodes.badRequest);
      expect(outcome.message, '待解析链接不能为空');
    });

    test('可解析视频结果会返回成功状态', () async {
      final service = VideoParseService(
        parser: VideoParser(
          providers: [
            TestVideoProvider(
              provider: VideoParseProvider.spapi,
              displayName: '测试源',
              priority: 1,
              baseUrl: 'https://example.com',
              handler: (url) async => ParseResult(
                type: 'video',
                sourceUrl: url,
                videos: const [VideoItem(url: 'https://cdn.example.com/a.mp4')],
              ),
            ),
          ],
        ),
      );

      final outcome = await service.parse(
        rawInput: '分享 https://example.com/video/1',
      );

      expect(outcome.success, isTrue);
      expect(outcome.hasVideo, isTrue);
      expect(outcome.hasGallery, isFalse);
      expect(outcome.result?.parserUsed, 'spapi');
    });

    test('图集类型结果会优先识别为图集', () async {
      final service = VideoParseService(
        parser: VideoParser(
          providers: [
            TestVideoProvider(
              provider: VideoParseProvider.spapi,
              displayName: '测试源',
              priority: 1,
              baseUrl: 'https://example.com',
              handler: (url) async => ParseResult(
                type: 'gallery',
                sourceUrl: url,
                images: const [ImageItem(url: 'https://cdn.example.com/a.jpg')],
              ),
            ),
          ],
        ),
      );

      final outcome = await service.parse(
        rawInput: '分享 https://example.com/gallery/1',
      );

      expect(outcome.success, isTrue);
      expect(outcome.hasGallery, isTrue);
      expect(outcome.hasVideo, isFalse);
      expect(outcome.result?.parserUsed, 'spapi');
    });

    test('视频结果带图片资源时仍识别为视频', () async {
      final service = VideoParseService(
        parser: VideoParser(
          providers: [
            TestVideoProvider(
              provider: VideoParseProvider.spapi,
              displayName: '测试源',
              priority: 1,
              baseUrl: 'https://example.com',
              handler: (url) async => ParseResult(
                type: 'video',
                sourceUrl: url,
                videos: const [VideoItem(url: 'https://cdn.example.com/a.mp4')],
                images: const [
                  ImageItem(url: 'https://cdn.example.com/cover.jpg'),
                ],
              ),
            ),
          ],
        ),
      );

      final outcome = await service.parse(
        rawInput: '分享 https://example.com/video-with-cover/1',
      );

      expect(outcome.success, isTrue);
      expect(outcome.hasVideo, isTrue);
      expect(outcome.hasGallery, isFalse);
      expect(outcome.result?.isVideo, isTrue);
      expect(buildParseSuccessDescription(outcome.result!), contains('视频资源'));
      expect(
        buildParseSuccessDescription(outcome.result!),
        isNot(contains('图集资源')),
      );
    });

    test('重复解析相同链接会命中缓存避免再次请求', () async {
      var requestCount = 0;
      final cacheStore = _MemoryParseResultCacheStore();
      final service = VideoParseService(
        cacheStore: cacheStore,
        parser: VideoParser(
          providers: [
            TestVideoProvider(
              provider: VideoParseProvider.spapi,
              displayName: '测试源',
              priority: 1,
              baseUrl: 'https://example.com',
              handler: (url) async {
                requestCount++;
                return ParseResult(
                  type: 'video',
                  sourceUrl: url,
                  videos: const [
                    VideoItem(url: 'https://cdn.example.com/cache.mp4'),
                  ],
                );
              },
            ),
          ],
        ),
      );

      final firstOutcome = await service.parse(
        rawInput: '分享 https://example.com/cache/1',
      );
      final secondOutcome = await service.parse(
        rawInput: '分享 https://example.com/cache/1',
      );

      expect(firstOutcome.success, isTrue);
      expect(firstOutcome.fromCache, isFalse);
      expect(secondOutcome.success, isTrue);
      expect(secondOutcome.fromCache, isTrue);
      expect(secondOutcome.message, '命中解析缓存');
      expect(
        secondOutcome.result?.videos.single.url,
        firstOutcome.result?.videos.single.url,
      );
      expect(requestCount, 1);
    });

    test('缓存读取异常时会降级为网络解析', () async {
      var requestCount = 0;
      final service = VideoParseService(
        cacheStore: _ThrowingParseResultCacheStore(throwOnRead: true),
        parser: VideoParser(
          providers: [
            TestVideoProvider(
              provider: VideoParseProvider.spapi,
              displayName: '测试源',
              priority: 1,
              baseUrl: 'https://example.com',
              handler: (url) async {
                requestCount++;
                return ParseResult(
                  type: 'video',
                  sourceUrl: url,
                  videos: const [
                    VideoItem(url: 'https://cdn.example.com/read-fallback.mp4'),
                  ],
                );
              },
            ),
          ],
        ),
      );

      final outcome = await service.parse(
        rawInput: 'https://example.com/cache-read-error/1',
      );

      expect(outcome.success, isTrue);
      expect(outcome.fromCache, isFalse);
      expect(outcome.result?.videos.single.url, contains('read-fallback'));
      expect(requestCount, 1);
    });

    test('缓存写入异常时仍返回已经取得的解析结果', () async {
      final service = VideoParseService(
        cacheStore: _ThrowingParseResultCacheStore(throwOnWrite: true),
        parser: VideoParser(
          providers: [
            TestVideoProvider(
              provider: VideoParseProvider.spapi,
              displayName: '测试源',
              priority: 1,
              baseUrl: 'https://example.com',
              handler: (url) async => ParseResult(
                type: 'video',
                sourceUrl: url,
                videos: const [
                  VideoItem(url: 'https://cdn.example.com/write-fallback.mp4'),
                ],
              ),
            ),
          ],
        ),
      );

      final outcome = await service.parse(
        rawInput: 'https://example.com/cache-write-error/1',
      );

      expect(outcome.success, isTrue);
      expect(outcome.fromCache, isFalse);
      expect(outcome.result?.videos.single.url, contains('write-fallback'));
    });

    test('空媒体结果会返回轮询失败', () async {
      final service = VideoParseService(
        parser: VideoParser(
          providers: [
            TestVideoProvider(
              provider: VideoParseProvider.spapi,
              displayName: '测试源',
              priority: 1,
              baseUrl: 'https://example.com',
              handler: (_) async => const ParseResult(type: 'video'),
            ),
          ],
        ),
      );

      final outcome = await service.parse(
        rawInput: 'https://example.com/video/1',
      );

      expect(outcome.success, isFalse);
      expect(outcome.code, ParseCodes.serverError);
      expect(outcome.message, contains('所有解析接口均无法解析'));
    });
  });
}

class _MemoryParseResultCacheStore implements ParseResultCacheStore {
  final Map<String, ParseResult> _items = <String, ParseResult>{};

  @override
  Future<ParseResult?> read({
    required String inputUrl,
    VideoParseProvider? provider,
  }) async {
    return _items[_cacheKey(inputUrl: inputUrl, provider: provider)];
  }

  @override
  Future<void> write({
    required String inputUrl,
    required ParseResult result,
    required Duration ttl,
    VideoParseProvider? provider,
  }) async {
    _items[_cacheKey(inputUrl: inputUrl, provider: provider)] = result;
  }

  String _cacheKey({required String inputUrl, VideoParseProvider? provider}) {
    final url = ParseUtils.firstHttpUrl(inputUrl).trim();
    final normalizedUrl = url.isEmpty ? inputUrl.trim() : url;
    return '$normalizedUrl::${provider?.name ?? 'auto'}';
  }
}

class _ThrowingParseResultCacheStore implements ParseResultCacheStore {
  const _ThrowingParseResultCacheStore({
    this.throwOnRead = false,
    this.throwOnWrite = false,
  });

  final bool throwOnRead;
  final bool throwOnWrite;

  @override
  Future<ParseResult?> read({
    required String inputUrl,
    VideoParseProvider? provider,
  }) async {
    if (throwOnRead) {
      throw StateError('模拟缓存读取失败');
    }
    return null;
  }

  @override
  Future<void> write({
    required String inputUrl,
    required ParseResult result,
    required Duration ttl,
    VideoParseProvider? provider,
  }) async {
    if (throwOnWrite) {
      throw StateError('模拟缓存写入失败');
    }
  }
}
