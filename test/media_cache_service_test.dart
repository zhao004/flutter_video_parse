import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_parse/app/services/media_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaCacheService', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'media_cache_service_test_',
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('清理磁盘和内存媒体缓存，但保留非媒体临时文件', () async {
      final nestedDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}nested',
      );
      await nestedDirectory.create();
      final imageFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}cover.JPG',
      );
      final videoFile = File(
        '${nestedDirectory.path}${Platform.pathSeparator}preview.mp4',
      );
      final otherFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}request.txt',
      );
      await imageFile.writeAsBytes([1]);
      await videoFile.writeAsBytes([2]);
      await otherFile.writeAsString('保留');

      final diskCache = _RecordingMediaDiskCache();
      final imageCache = _RecordingImageCache();
      final service = MediaCacheService(
        diskCache: diskCache,
        imageCache: imageCache,
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );

      await service.clear();

      expect(diskCache.clearCount, 1);
      expect(imageCache.clearCalled, isTrue);
      expect(imageCache.clearLiveImagesCalled, isTrue);
      expect(await imageFile.exists(), isFalse);
      expect(await videoFile.exists(), isFalse);
      expect(await otherFile.exists(), isTrue);
    });

    test('统计图片缓存和临时媒体文件且不会重复计算图片缓存目录', () async {
      final nestedDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}nested',
      );
      final cachedImageDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}'
        '${DefaultMediaDiskCache.cacheDirectoryName}',
      );
      await nestedDirectory.create();
      await cachedImageDirectory.create();
      await File(
        '${temporaryDirectory.path}${Platform.pathSeparator}cover.jpg',
      ).writeAsBytes(List.filled(1024, 1));
      await File(
        '${nestedDirectory.path}${Platform.pathSeparator}preview.mp4',
      ).writeAsBytes(List.filled(2048, 2));
      await File(
        '${temporaryDirectory.path}${Platform.pathSeparator}request.txt',
      ).writeAsBytes(List.filled(4096, 3));
      await File(
        '${cachedImageDirectory.path}${Platform.pathSeparator}cached.file',
      ).writeAsBytes(List.filled(8192, 4));

      final service = MediaCacheService(
        diskCache: _RecordingMediaDiskCache(sizeInBytes: 8192),
        imageCache: _RecordingImageCache(),
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );

      expect(await service.getSizeInBytes(), 11264);
    });

    test('默认图片缓存按专用目录中的实际文件大小统计', () async {
      final cacheDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}'
        '${DefaultMediaDiskCache.cacheDirectoryName}',
      );
      final nestedDirectory = Directory(
        '${cacheDirectory.path}${Platform.pathSeparator}nested',
      );
      await nestedDirectory.create(recursive: true);
      await File(
        '${cacheDirectory.path}${Platform.pathSeparator}image.file',
      ).writeAsBytes(List.filled(1024, 1));
      await File(
        '${nestedDirectory.path}${Platform.pathSeparator}cover.webp',
      ).writeAsBytes(List.filled(2048, 2));
      await File(
        '${temporaryDirectory.path}${Platform.pathSeparator}outside.jpg',
      ).writeAsBytes(List.filled(4096, 3));

      final diskCache = DefaultMediaDiskCache(
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );

      expect(await diskCache.getSizeInBytes(), 3072);
    });

    test('磁盘缓存清理失败时仍清除临时媒体并返回异常', () async {
      final videoFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}preview.webm',
      );
      await videoFile.writeAsBytes([1, 2, 3]);
      final service = MediaCacheService(
        diskCache: _RecordingMediaDiskCache(throwsWhenClearing: true),
        imageCache: _RecordingImageCache(),
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );

      await expectLater(
        service.clear(),
        throwsA(isA<MediaCacheClearException>()),
      );

      expect(await videoFile.exists(), isFalse);
    });
  });

  group('formatMediaCacheSize', () {
    test('使用 KB 展示零值和不足 1 KB 的缓存', () {
      expect(formatMediaCacheSize(0), '0 KB');
      expect(formatMediaCacheSize(512), '< 1 KB');
      expect(formatMediaCacheSize(1536), '1.5 KB');
    });

    test('按容量自动切换 MB 和 GB', () {
      expect(formatMediaCacheSize(5 * 1024 * 1024), '5 MB');
      expect(formatMediaCacheSize(1536 * 1024), '1.5 MB');
      expect(formatMediaCacheSize(2 * 1024 * 1024 * 1024), '2 GB');
      expect(formatMediaCacheSize(-1), '0 KB');
    });
  });
}

class _RecordingMediaDiskCache implements MediaDiskCache {
  _RecordingMediaDiskCache({
    this.throwsWhenClearing = false,
    this.sizeInBytes = 0,
  });

  final bool throwsWhenClearing;
  final int sizeInBytes;
  int clearCount = 0;

  @override
  Future<int> getSizeInBytes() async => sizeInBytes;

  @override
  Future<void> clear() async {
    clearCount++;
    if (throwsWhenClearing) {
      throw StateError('模拟磁盘缓存清理失败');
    }
  }
}

class _RecordingImageCache extends ImageCache {
  bool clearCalled = false;
  bool clearLiveImagesCalled = false;

  @override
  void clear() {
    clearCalled = true;
    super.clear();
  }

  @override
  void clearLiveImages() {
    clearLiveImagesCalled = true;
    super.clearLiveImages();
  }
}
