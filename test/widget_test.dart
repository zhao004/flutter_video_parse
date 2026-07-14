import 'dart:async';

import 'package:dart_video_parse/dart_video_parse.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_parse/app/pages/home/home_controller.dart';
import 'package:flutter_video_parse/app/pages/result/gallery_result_view.dart';
import 'package:flutter_video_parse/app/services/media_download_service.dart';
import 'package:flutter_video_parse/app/services/video_parse_service.dart';
import 'package:flutter_video_parse/app/widgets/video_parse_widgets.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('图集首屏仅构建可视区域内的图片', (tester) async {
    final controller = HomeController(
      service: VideoParseService(parser: VideoParser(providers: const [])),
    );
    Get.put<HomeController>(controller);
    controller.currentResult.value = ParseResult(
      type: 'gallery',
      images: List.generate(
        120,
        (index) =>
            ImageItem(url: 'https://cdn.example.com/gallery/image_$index.jpg'),
      ),
    );

    await tester.pumpWidget(const GetMaterialApp(home: GalleryResultView()));
    await tester.pump();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SliverMasonryGrid), findsOneWidget);
    final initialImageCount = find.byType(Image).evaluate().length;
    expect(initialImageCount, greaterThan(0));
    expect(initialImageCount, lessThan(120));
  });

  testWidgets('底部导航定位包含系统安全区', (tester) async {
    const bottomInset = 36.0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            viewPadding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Scaffold(
            body: Stack(
              children: [
                FloatingBottomTabs(currentIndex: 0, onChanged: _ignoreTab),
              ],
            ),
          ),
        ),
      ),
    );

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.bottom, 14 + bottomInset);
  });

  testWidgets('保存当前图片后再终止会计入成功数量', (tester) async {
    final downloadService = _CompletingMediaDownloadService();
    final controller = HomeController(mediaDownloadService: downloadService);
    controller.currentResult.value = const ParseResult(
      type: 'gallery',
      images: [ImageItem(url: 'https://cdn.example.com/gallery/image.jpg')],
    );
    await tester.pumpWidget(
      const ToastificationWrapper(
        child: GetMaterialApp(home: Scaffold(body: SizedBox.expand())),
      ),
    );

    final download = controller.downloadAllImagesToGallery();
    await downloadService.requestStarted.future;
    await tester.pumpAndSettle();
    controller.cancelGalleryDownload();
    downloadService.savedFile.complete();
    await download;
    await tester.pump();

    expect(find.text('已终止下载，成功保存 1 / 1 张图片'), findsOneWidget);
    expect(find.textContaining('成功 1 张'), findsOneWidget);

    Get.back<void>();
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    controller.onClose();
  });
}

void _ignoreTab(int _) {}

class _CompletingMediaDownloadService extends MediaDownloadService {
  _CompletingMediaDownloadService()
    : super(client: Dio(), galleryStore: const _UnusedGalleryStore());

  final Completer<void> requestStarted = Completer<void>();
  final Completer<void> savedFile = Completer<void>();

  @override
  Future<MediaDownloadOutcome> download({
    required String url,
    required MediaFileType mediaType,
    required String fallbackName,
    required CancelToken cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    requestStarted.complete();
    await savedFile.future;
    return const MediaDownloadOutcome.success();
  }
}

class _UnusedGalleryStore implements MediaGalleryStore {
  const _UnusedGalleryStore();

  @override
  Future<bool> hasAccess() async => true;

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<void> saveImage(String filePath) async {}

  @override
  Future<void> saveVideo(String filePath) async {}
}
