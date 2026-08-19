import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

/// 媒体缓存查询与清理接口，供控制器注入并在测试中替换。
abstract interface class MediaCacheStore {
  Future<int> getSizeInBytes();

  Future<void> clear();
}

/// 磁盘缓存清理接口，隔离第三方缓存管理器并便于异常测试。
abstract interface class MediaDiskCache {
  Future<int> getSizeInBytes();

  Future<void> clear();
}

/// `cached_network_image` 默认磁盘缓存的适配器。
class DefaultMediaDiskCache implements MediaDiskCache {
  DefaultMediaDiskCache({
    BaseCacheManager? cacheManager,
    Future<Directory> Function()? temporaryDirectoryProvider,
  }) : _cacheManagerOverride = cacheManager,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory;

  static const String cacheDirectoryName = DefaultCacheManager.key;

  final BaseCacheManager? _cacheManagerOverride;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  late final BaseCacheManager _cacheManager =
      _cacheManagerOverride ?? DefaultCacheManager();

  @override
  Future<int> getSizeInBytes() async {
    final temporaryDirectory = await _temporaryDirectoryProvider();
    final cacheDirectory = Directory(
      _joinPath(temporaryDirectory.path, cacheDirectoryName),
    );
    return _directorySizeInBytes(cacheDirectory);
  }

  @override
  Future<void> clear() => _cacheManager.emptyCache();
}

/// 图片和视频缓存清理服务。
///
/// 设计意图：默认磁盘缓存负责清除 `cached_network_image` 文件，Flutter
/// [ImageCache] 负责清除解码后的内存图片；临时目录扫描只删除常见媒体扩展名，
/// 避免误删数据库、配置或其他插件的非媒体文件。
class MediaCacheService implements MediaCacheStore {
  MediaCacheService({
    MediaDiskCache? diskCache,
    ImageCache? imageCache,
    Future<Directory> Function()? temporaryDirectoryProvider,
  }) : _diskCacheOverride = diskCache,
       _imageCacheOverride = imageCache,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory;

  static const Set<String> _mediaExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.heic',
    '.avif',
    '.mp4',
    '.mov',
    '.m4v',
    '.webm',
    '.mkv',
    '.avi',
    '.3gp',
  };

  final MediaDiskCache? _diskCacheOverride;
  final ImageCache? _imageCacheOverride;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  late final MediaDiskCache _diskCache =
      _diskCacheOverride ??
      DefaultMediaDiskCache(
        temporaryDirectoryProvider: _temporaryDirectoryProvider,
      );
  late final ImageCache _imageCache =
      _imageCacheOverride ?? PaintingBinding.instance.imageCache;

  @override
  Future<int> getSizeInBytes() async {
    final diskCacheSize = await _diskCache.getSizeInBytes();
    final temporaryDirectory = await _temporaryDirectoryProvider();
    final temporaryMediaSize = await _temporaryMediaSizeInBytes(
      temporaryDirectory,
    );
    return diskCacheSize + temporaryMediaSize;
  }

  @override
  Future<void> clear() async {
    final failures = <Object>[];

    try {
      _imageCache.clear();
      _imageCache.clearLiveImages();
    } catch (error) {
      failures.add(error);
    }

    try {
      await _diskCache.clear();
    } catch (error) {
      failures.add(error);
    }

    try {
      final temporaryDirectory = await _temporaryDirectoryProvider();
      failures.addAll(await _deleteTemporaryMediaFiles(temporaryDirectory));
    } catch (error) {
      failures.add(error);
    }

    if (failures.isNotEmpty) {
      throw MediaCacheClearException(List<Object>.unmodifiable(failures));
    }
  }

  Future<List<Object>> _deleteTemporaryMediaFiles(Directory directory) async {
    if (!await directory.exists()) {
      return const [];
    }

    final failures = <Object>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !_isMediaFile(entity.path)) {
        continue;
      }
      try {
        await entity.delete();
      } catch (error) {
        failures.add(error);
      }
    }
    return failures;
  }

  Future<int> _temporaryMediaSizeInBytes(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }

    final diskCachePath = _normalizedDirectoryPrefix(
      _joinPath(directory.path, DefaultMediaDiskCache.cacheDirectoryName),
    );
    var totalBytes = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File ||
          _isWithinDirectory(entity.path, diskCachePath) ||
          !_isMediaFile(entity.path)) {
        continue;
      }
      totalBytes += await _fileSizeInBytes(entity);
    }
    return totalBytes;
  }

  bool _isMediaFile(String filePath) {
    final normalizedPath = filePath.toLowerCase();
    final slashIndex = normalizedPath.lastIndexOf('/');
    final backslashIndex = normalizedPath.lastIndexOf('\\');
    final separatorIndex = slashIndex > backslashIndex
        ? slashIndex
        : backslashIndex;
    final dotIndex = normalizedPath.lastIndexOf('.');
    if (dotIndex <= separatorIndex) {
      return false;
    }
    return _mediaExtensions.contains(normalizedPath.substring(dotIndex));
  }
}

/// 将媒体缓存字节数格式化为设置页展示文本。
///
/// 使用二进制换算（1 KB = 1024 字节），但沿用用户熟悉的 KB、MB、GB 单位。
String formatMediaCacheSize(int byteCount) {
  final normalizedBytes = byteCount < 0 ? 0 : byteCount;
  if (normalizedBytes == 0) {
    return '0 KB';
  }
  if (normalizedBytes < _bytesPerKilobyte) {
    return '< 1 KB';
  }
  if (normalizedBytes >= _bytesPerGigabyte) {
    return '${_formatSizeValue(normalizedBytes / _bytesPerGigabyte)} GB';
  }
  if (normalizedBytes >= _bytesPerMegabyte) {
    return '${_formatSizeValue(normalizedBytes / _bytesPerMegabyte)} MB';
  }
  return '${_formatSizeValue(normalizedBytes / _bytesPerKilobyte)} KB';
}

const int _bytesPerKilobyte = 1024;
const int _bytesPerMegabyte = _bytesPerKilobyte * 1024;
const int _bytesPerGigabyte = _bytesPerMegabyte * 1024;

String _formatSizeValue(double value) {
  final fractionDigits = value >= 100
      ? 0
      : value >= 10
      ? 1
      : 2;
  return value
      .toStringAsFixed(fractionDigits)
      .replaceFirst(RegExp(r'\.?0+$'), '');
}

Future<int> _directorySizeInBytes(Directory directory) async {
  if (!await directory.exists()) {
    return 0;
  }

  var totalBytes = 0;
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File) {
      totalBytes += await _fileSizeInBytes(entity);
    }
  }
  return totalBytes;
}

Future<int> _fileSizeInBytes(File file) async {
  try {
    return await file.length();
  } on FileSystemException {
    // 缓存管理器可能在统计期间淘汰文件，消失的文件按零字节处理。
    return 0;
  }
}

String _joinPath(String directoryPath, String childName) {
  if (directoryPath.endsWith(Platform.pathSeparator)) {
    return '$directoryPath$childName';
  }
  return '$directoryPath${Platform.pathSeparator}$childName';
}

String _normalizedDirectoryPrefix(String directoryPath) {
  final normalizedPath = Platform.isWindows
      ? directoryPath.toLowerCase()
      : directoryPath;
  return normalizedPath.endsWith(Platform.pathSeparator)
      ? normalizedPath
      : '$normalizedPath${Platform.pathSeparator}';
}

bool _isWithinDirectory(String filePath, String directoryPrefix) {
  final normalizedPath = Platform.isWindows ? filePath.toLowerCase() : filePath;
  return normalizedPath.startsWith(directoryPrefix);
}

/// 媒体缓存未能完整清理时抛出的聚合异常。
///
/// 异常策略：各缓存区域独立尝试，最后统一上抛，保证单一区域失败不会阻止
/// 其他图片或视频缓存继续清理。
class MediaCacheClearException implements Exception {
  const MediaCacheClearException(this.failures);

  final List<Object> failures;

  @override
  String toString() => '媒体缓存清理失败，共 ${failures.length} 项';
}
