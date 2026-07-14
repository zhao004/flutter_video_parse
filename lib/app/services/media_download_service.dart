import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../http/app_http_client.dart';

/// 下载后写入相册的媒体类型。
enum MediaFileType { image, video }

/// 下载失败类型，供界面选择提示级别并避免展示底层异常。
enum MediaDownloadFailure {
  invalidUrl,
  permissionDenied,
  canceled,
  network,
  gallery,
  fileSystem,
  unexpected,
}

/// 媒体下载结果，统一表达成功、取消和可展示的失败原因。
class MediaDownloadOutcome {
  const MediaDownloadOutcome._({
    required this.saved,
    required this.message,
    this.failure,
  });

  const MediaDownloadOutcome.success()
    : this._(saved: true, message: '资源已保存到系统相册');

  const MediaDownloadOutcome.failure(
    MediaDownloadFailure failure,
    String message,
  ) : this._(saved: false, message: message, failure: failure);

  final bool saved;
  final String message;
  final MediaDownloadFailure? failure;

  bool get canceled => failure == MediaDownloadFailure.canceled;
}

/// 相册平台能力抽象，隔离 Gal 静态 API，便于下载流程做单元测试。
abstract interface class MediaGalleryStore {
  Future<bool> hasAccess();

  Future<bool> requestAccess();

  Future<void> saveImage(String filePath);

  Future<void> saveVideo(String filePath);
}

/// Gal 相册能力的生产实现。
class GalMediaGalleryStore implements MediaGalleryStore {
  const GalMediaGalleryStore();

  @override
  Future<bool> hasAccess() => Gal.hasAccess();

  @override
  Future<bool> requestAccess() => Gal.requestAccess();

  @override
  Future<void> saveImage(String filePath) => Gal.putImage(filePath);

  @override
  Future<void> saveVideo(String filePath) => Gal.putVideo(filePath);
}

typedef TemporaryDirectoryProvider = Future<Directory> Function();

/// 媒体下载服务，负责有限超时下载、相册保存和临时文件生命周期。
///
/// 异常策略：所有预期异常均转换为 [MediaDownloadOutcome]；无论下载、取消
/// 还是相册保存在哪一步失败，已经创建的临时文件都会在 `finally` 中清理。
class MediaDownloadService {
  MediaDownloadService({
    Dio? client,
    MediaGalleryStore? galleryStore,
    TemporaryDirectoryProvider? temporaryDirectoryProvider,
  }) : _client = client ?? createMediaDownloadDio(),
       _galleryStore = galleryStore ?? const GalMediaGalleryStore(),
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _ownsClient = client == null;

  static const int _maximumFileNameLength = 120;

  final Dio _client;
  final MediaGalleryStore _galleryStore;
  final TemporaryDirectoryProvider _temporaryDirectoryProvider;
  final bool _ownsClient;

  /// 下载媒体并保存到系统相册。
  Future<MediaDownloadOutcome> download({
    required String url,
    required MediaFileType mediaType,
    required String fallbackName,
    required CancelToken cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final normalizedUrl = url.trim();
    final uri = _validHttpUri(normalizedUrl);
    if (uri == null) {
      return const MediaDownloadOutcome.failure(
        MediaDownloadFailure.invalidUrl,
        '资源链接为空或格式无效',
      );
    }

    String? temporaryFilePath;
    try {
      var hasAccess = await _galleryStore.hasAccess();
      if (!hasAccess) {
        hasAccess = await _galleryStore.requestAccess();
      }
      if (!hasAccess) {
        return const MediaDownloadOutcome.failure(
          MediaDownloadFailure.permissionDenied,
          '请允许访问相册后再保存资源',
        );
      }

      final temporaryDirectory = await _temporaryDirectoryProvider();
      if (!await temporaryDirectory.exists()) {
        await temporaryDirectory.create(recursive: true);
      }
      final fileName = _safeFileName(uri, fallbackName, mediaType);
      final uniquePrefix = DateTime.now().microsecondsSinceEpoch;
      temporaryFilePath = _joinPath(
        temporaryDirectory.path,
        '${uniquePrefix}_$fileName',
      );

      await _client.download(
        normalizedUrl,
        temporaryFilePath,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );

      if (mediaType == MediaFileType.video) {
        await _galleryStore.saveVideo(temporaryFilePath);
      } else {
        await _galleryStore.saveImage(temporaryFilePath);
      }
      return const MediaDownloadOutcome.success();
    } on GalException catch (error) {
      return MediaDownloadOutcome.failure(
        MediaDownloadFailure.gallery,
        error.type.message,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return const MediaDownloadOutcome.failure(
          MediaDownloadFailure.canceled,
          '下载已终止',
        );
      }
      return MediaDownloadOutcome.failure(
        MediaDownloadFailure.network,
        _networkErrorMessage(error),
      );
    } on FileSystemException {
      return const MediaDownloadOutcome.failure(
        MediaDownloadFailure.fileSystem,
        '临时文件创建或写入失败，请检查设备存储空间',
      );
    } catch (_) {
      return const MediaDownloadOutcome.failure(
        MediaDownloadFailure.unexpected,
        '媒体下载失败，请稍后重试',
      );
    } finally {
      await _deleteTemporaryFile(temporaryFilePath);
    }
  }

  /// 仅关闭服务自行创建的客户端，注入的共享客户端由外部管理生命周期。
  void close() {
    if (_ownsClient) {
      _client.close(force: true);
    }
  }

  static Uri? _validHttpUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri;
  }

  static String _safeFileName(
    Uri uri,
    String fallbackName,
    MediaFileType mediaType,
  ) {
    final sourceName = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final sanitizedFallback = _sanitizeName(fallbackName).isEmpty
        ? 'media'
        : _sanitizeName(fallbackName);
    final sanitizedSource = _sanitizeName(sourceName);
    final baseName = sanitizedSource.isEmpty
        ? sanitizedFallback
        : sanitizedSource;
    final fallbackExtension = mediaType == MediaFileType.video
        ? '.mp4'
        : '.jpg';
    final withExtension = _extension(baseName).isEmpty
        ? '$baseName$fallbackExtension'
        : baseName;
    if (withExtension.length <= _maximumFileNameLength) {
      return withExtension;
    }

    final extension = _extension(withExtension);
    final baseLength = _maximumFileNameLength - extension.length;
    return '${withExtension.substring(0, baseLength)}$extension';
  }

  static String _sanitizeName(String value) {
    return value.trim().replaceAll(RegExp(r'[^\w\-.]+'), '_');
  }

  static String _extension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex);
  }

  static String _joinPath(String directory, String fileName) {
    if (directory.endsWith(Platform.pathSeparator)) {
      return '$directory$fileName';
    }
    return '$directory${Platform.pathSeparator}$fileName';
  }

  static String _networkErrorMessage(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => '媒体下载超时，请稍后重试',
      DioExceptionType.connectionError => '无法连接媒体服务器，请检查网络',
      DioExceptionType.badResponse => '媒体服务器返回异常状态',
      _ => '网络下载失败，请稍后重试',
    };
  }

  static Future<void> _deleteTemporaryFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      return;
    }
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // 清理属于尽力操作，不能覆盖原始下载或保存结果。
    }
  }
}
