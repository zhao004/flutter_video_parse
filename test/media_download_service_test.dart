import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_parse/app/http/app_http_client.dart';
import 'package:flutter_video_parse/app/pages/home/home_controller.dart';
import 'package:flutter_video_parse/app/services/media_download_service.dart';

void main() {
  group('MediaDownloadService', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'flutter_video_parse_download_test_',
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('媒体客户端配置了有限连接和接收超时', () {
      final client = createMediaDownloadDio();

      expect(client.options.connectTimeout, mediaDownloadConnectTimeout);
      expect(client.options.receiveTimeout, mediaDownloadReceiveTimeout);
      expect(client.options.connectTimeout, isNot(Duration.zero));
      expect(client.options.receiveTimeout, isNot(Duration.zero));

      client.close(force: true);
    });

    test('非法链接会在访问相册和网络前被拒绝', () async {
      final galleryStore = _FakeMediaGalleryStore();
      final service = MediaDownloadService(
        client: _bytesClient(const [1, 2, 3]),
        galleryStore: galleryStore,
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );

      final outcome = await service.download(
        url: 'file:///private/video.mp4',
        mediaType: MediaFileType.video,
        fallbackName: 'video',
        cancelToken: CancelToken(),
      );

      expect(outcome.saved, isFalse);
      expect(outcome.failure, MediaDownloadFailure.invalidUrl);
      expect(galleryStore.accessCheckCount, 0);
      expect(temporaryDirectory.listSync(), isEmpty);
    });

    test('相册保存失败后仍会删除完整临时文件', () async {
      final galleryStore = _FakeMediaGalleryStore(throwWhenSaving: true);
      final service = MediaDownloadService(
        client: _bytesClient(const [4, 5, 6, 7]),
        galleryStore: galleryStore,
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );

      final outcome = await service.download(
        url: 'https://cdn.example.com/image.jpg',
        mediaType: MediaFileType.image,
        fallbackName: 'image',
        cancelToken: CancelToken(),
      );

      expect(outcome.saved, isFalse);
      expect(outcome.failure, MediaDownloadFailure.unexpected);
      expect(galleryStore.bytesReadWhileSaving, const [4, 5, 6, 7]);
      expect(temporaryDirectory.listSync(), isEmpty);
    });

    test('网络流写入部分内容后失败也会删除临时文件', () async {
      final client = Dio()
        ..httpClientAdapter = const _PartialFailureHttpClientAdapter();
      final service = MediaDownloadService(
        client: client,
        galleryStore: _FakeMediaGalleryStore(),
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );

      final outcome = await service.download(
        url: 'https://cdn.example.com/partial.jpg',
        mediaType: MediaFileType.image,
        fallbackName: 'partial',
        cancelToken: CancelToken(),
      );

      expect(outcome.saved, isFalse);
      expect(temporaryDirectory.listSync(), isEmpty);
    });

    test('保存成功后也会删除临时文件', () async {
      final galleryStore = _FakeMediaGalleryStore();
      final service = MediaDownloadService(
        client: _bytesClient(const [8, 9]),
        galleryStore: galleryStore,
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );

      final outcome = await service.download(
        url: 'https://cdn.example.com/video.mp4',
        mediaType: MediaFileType.video,
        fallbackName: 'video',
        cancelToken: CancelToken(),
      );

      expect(outcome.saved, isTrue);
      expect(galleryStore.bytesReadWhileSaving, const [8, 9]);
      expect(temporaryDirectory.listSync(), isEmpty);
    });

    test('取消令牌会终止正在等待的下载', () async {
      final adapter = _CancelingHttpClientAdapter();
      final client = Dio()..httpClientAdapter = adapter;
      final service = MediaDownloadService(
        client: client,
        galleryStore: _FakeMediaGalleryStore(),
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );
      final cancelToken = CancelToken();

      final download = service.download(
        url: 'https://cdn.example.com/slow.mp4',
        mediaType: MediaFileType.video,
        fallbackName: 'video',
        cancelToken: cancelToken,
      );
      await adapter.requestStarted.future;
      cancelToken.cancel('测试取消');
      final outcome = await download;

      expect(outcome.saved, isFalse);
      expect(outcome.failure, MediaDownloadFailure.canceled);
      expect(temporaryDirectory.listSync(), isEmpty);
    });

    test('首页控制器销毁时会取消单文件下载', () async {
      final downloadService = _CancelAwareMediaDownloadService();
      final controller = HomeController(mediaDownloadService: downloadService);

      final download = controller.downloadImageToGallery(
        'https://cdn.example.com/slow.jpg',
      );
      await downloadService.requestStarted.future;
      controller.onClose();
      await download;

      expect(downloadService.receivedToken?.isCancelled, isTrue);
      expect(controller.downloadingMedia.value, isFalse);
    });
  });
}

Dio _bytesClient(List<int> bytes) {
  return Dio()..httpClientAdapter = _BytesHttpClientAdapter(bytes);
}

class _BytesHttpClientAdapter implements HttpClientAdapter {
  const _BytesHttpClientAdapter(this.bytes);

  final List<int> bytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      bytes,
      HttpStatus.ok,
      headers: {
        Headers.contentLengthHeader: [bytes.length.toString()],
        Headers.contentTypeHeader: ['application/octet-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CancelingHttpClientAdapter implements HttpClientAdapter {
  final Completer<void> requestStarted = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestStarted.complete();
    await cancelFuture;
    throw DioException.requestCancelled(
      requestOptions: options,
      reason: '测试取消',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _PartialFailureHttpClientAdapter implements HttpClientAdapter {
  const _PartialFailureHttpClientAdapter();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final stream = Stream<Uint8List>.multi((controller) {
      controller.add(Uint8List.fromList(const [1, 2]));
      controller.addError(
        DioException.connectionError(requestOptions: options, reason: '模拟传输中断'),
      );
    });
    return ResponseBody(
      stream,
      HttpStatus.ok,
      headers: {
        Headers.contentLengthHeader: ['4'],
        Headers.contentTypeHeader: ['application/octet-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeMediaGalleryStore implements MediaGalleryStore {
  _FakeMediaGalleryStore({this.throwWhenSaving = false});

  final bool throwWhenSaving;
  int accessCheckCount = 0;
  List<int>? bytesReadWhileSaving;

  @override
  Future<bool> hasAccess() async {
    accessCheckCount++;
    return true;
  }

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<void> saveImage(String filePath) => _save(filePath);

  @override
  Future<void> saveVideo(String filePath) => _save(filePath);

  Future<void> _save(String filePath) async {
    bytesReadWhileSaving = await File(filePath).readAsBytes();
    if (throwWhenSaving) {
      throw StateError('模拟相册保存失败');
    }
  }
}

class _CancelAwareMediaDownloadService extends MediaDownloadService {
  _CancelAwareMediaDownloadService()
    : super(client: Dio(), galleryStore: _FakeMediaGalleryStore());

  final Completer<void> requestStarted = Completer<void>();
  CancelToken? receivedToken;

  @override
  Future<MediaDownloadOutcome> download({
    required String url,
    required MediaFileType mediaType,
    required String fallbackName,
    required CancelToken cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    receivedToken = cancelToken;
    requestStarted.complete();
    await cancelToken.whenCancel;
    return const MediaDownloadOutcome.failure(
      MediaDownloadFailure.canceled,
      '下载已终止',
    );
  }
}
