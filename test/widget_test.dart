import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_video_parse/dart_video_parse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_parse/app/models/parse_ui_models.dart';
import 'package:flutter_video_parse/app/pages/downloads/download_management_binding.dart';
import 'package:flutter_video_parse/app/pages/downloads/download_management_view.dart';
import 'package:flutter_video_parse/app/pages/home/home_controller.dart';
import 'package:flutter_video_parse/app/pages/home/home_view.dart';
import 'package:flutter_video_parse/app/pages/logs/parse_logs_view.dart';
import 'package:flutter_video_parse/app/pages/result/gallery_result_view.dart';
import 'package:flutter_video_parse/app/pages/result/video_result_view.dart';
import 'package:flutter_video_parse/app/routes/app_pages.dart';
import 'package:flutter_video_parse/app/services/download_task_manager.dart';
import 'package:flutter_video_parse/app/services/media_cache_service.dart';
import 'package:flutter_video_parse/app/services/video_parse_service.dart';
import 'package:flutter_video_parse/app/theme/app_theme.dart';
import 'package:flutter_video_parse/app/widgets/video_parse_widgets.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import 'support/fake_background_downloader_gateway.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  test('主题提供 Material 3 深浅色板和业务状态色', () {
    final lightTheme = AppTheme.light();
    final darkTheme = AppTheme.dark();

    expect(AppTheme.seedColor, const Color(0xFF6CAFFC));
    expect(lightTheme.useMaterial3, isTrue);
    expect(darkTheme.useMaterial3, isTrue);
    expect(lightTheme.brightness, Brightness.light);
    expect(darkTheme.brightness, Brightness.dark);
    expect(lightTheme.extension<AppStatusColors>(), isNotNull);
    expect(darkTheme.extension<AppStatusColors>(), isNotNull);
    expect(lightTheme.appBarTheme.titleTextStyle, isNull);
    expect(darkTheme.appBarTheme.titleTextStyle, isNull);
  });

  testWidgets('图集首屏仅构建可视区域内的图片', (tester) async {
    final controller = _createTestController();
    Get.put<HomeController>(controller);
    controller.currentResult.value = ParseResult(
      type: 'gallery',
      images: List.generate(
        120,
        (index) =>
            ImageItem(url: 'https://cdn.example.com/gallery/image_$index.jpg'),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const GalleryResultView(),
      ),
    );
    await tester.pump();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SliverMasonryGrid), findsOneWidget);
    final initialImageCount = find.byType(CachedNetworkImage).evaluate().length;
    expect(initialImageCount, greaterThan(0));
    expect(initialImageCount, lessThan(120));
  });

  testWidgets('主导航按 Material 3 窗口尺寸自适应', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Get.put<HomeController>(_createTestController());

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const HomeView(),
      ),
    );
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(700, 900);
    await tester.pump();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(900, 900);
    await tester.pump();

    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('服务概览在紧凑窗口保持三张卡片并排', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = _createTestController();
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light(), home: const HomeView()),
    );
    controller.switchTab(1);
    await tester.pump();

    final cards = find.byType(StatusOverviewCard);
    expect(cards, findsNWidgets(3));
    final cardRects = List.generate(
      3,
      (index) => tester.getRect(cards.at(index)),
    );
    expect(cardRects[1].top, closeTo(cardRects[0].top, 0.01));
    expect(cardRects[2].top, closeTo(cardRects[0].top, 0.01));
    expect(cardRects[1].left, greaterThan(cardRects[0].right));
    expect(cardRects[2].left, greaterThan(cardRects[1].right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Provider 状态列表不显示探测网址', (tester) async {
    const probeUrl = 'https://status.example.com/private-probe';
    const data = ProviderStatusViewData(
      name: '测试解析源',
      probeUrl: probeUrl,
      statusLabel: '可用',
      latencyLabel: '28ms',
      icon: Icons.check_circle_outline,
      available: true,
      health: ProviderHealth.available,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ProviderStatusTile(data: data)),
      ),
    );

    expect(find.text('测试解析源'), findsOneWidget);
    expect(find.text('28ms'), findsOneWidget);
    expect(find.text('可用'), findsOneWidget);
    expect(find.text(probeUrl), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置页使用分组独立设置行并保留日志入口', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = _createTestController();
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light(), home: const HomeView()),
    );
    await tester.pump();
    controller.version.value = '1.0.0';
    controller.switchTab(2);
    await tester.pump();

    expect(find.text('数据与记录'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.byKey(const Key('settings-logs-action')), findsOneWidget);
    expect(find.byKey(const Key('settings-downloads-action')), findsOneWidget);
    expect(find.byKey(const Key('settings-clear-action')), findsOneWidget);
    expect(find.byKey(const Key('settings-version-item')), findsOneWidget);
    expect(find.text('${controller.logs.length} 条记录'), findsOneWidget);
    expect(find.text('清空缓存'), findsOneWidget);
    expect(find.text('暂无下载任务'), findsOneWidget);
    expect(find.text('当前缓存 0 KB'), findsOneWidget);
    expect(find.text('当前版本 1.0.0'), findsOneWidget);

    final logsRect = tester.getRect(
      find.byKey(const Key('settings-logs-action')),
    );
    final clearRect = tester.getRect(
      find.byKey(const Key('settings-clear-action')),
    );
    expect(clearRect.left, closeTo(logsRect.left, 0.01));
    expect(clearRect.right, closeTo(logsRect.right, 0.01));
    expect(clearRect.top, greaterThan(logsRect.bottom));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const Key('settings-logs-action'))).width,
      lessThanOrEqualTo(720),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('settings-logs-action')));
    await tester.pump();

    expect(controller.showingLogsPanel.value, isTrue);
    expect(find.text('解析日志'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('清空缓存只清理媒体缓存并保留解析日志', (tester) async {
    final mediaCacheStore = _RecordingMediaCacheStore(
      sizeInBytes: 5 * 1024 * 1024,
    );
    final controller = _createTestController(mediaCacheStore: mediaCacheStore);
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      ToastificationWrapper(
        child: GetMaterialApp(theme: AppTheme.light(), home: const HomeView()),
      ),
    );
    await tester.pump();
    final logEntry = _testLogEntry();
    controller.logs.assignAll([logEntry]);
    controller.switchTab(2);
    await tester.pump();

    expect(find.text('当前缓存 5 MB'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-clear-action')));
    await tester.pumpAndSettle();
    expect(find.text('清空缓存？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '清空'));
    await tester.pumpAndSettle();

    expect(mediaCacheStore.clearCount, 1);
    expect(controller.logs, contains(logEntry));
    expect(find.text('图片和视频缓存已清空'), findsOneWidget);
    expect(find.text('当前缓存 0 KB'), findsOneWidget);

    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('设置页下载管理入口跳转独立列表页', (tester) async {
    final gateway = FakeBackgroundDownloaderGateway();
    addTearDown(gateway.close);
    final downloadTaskManager = DownloadTaskManager(gateway: gateway);
    final controller = _createTestController(
      downloadTaskManager: downloadTaskManager,
    );
    Get.put<DownloadTaskManager>(downloadTaskManager);
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        home: const HomeView(),
        getPages: [
          GetPage(
            name: Routes.downloadManagement,
            page: () => const DownloadManagementView(),
            binding: DownloadManagementBinding(),
          ),
        ],
      ),
    );
    controller.switchTab(2);
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings-downloads-action')));
    await tester.pumpAndSettle();

    expect(find.byType(DownloadManagementView), findsOneWidget);
    expect(find.text('下载管理'), findsWidgets);
    expect(find.text('暂无下载任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页解析日志多选按钮可进入选择态并勾选条目', (tester) async {
    final controller = _createTestController();
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light(), home: const HomeView()),
    );
    final logEntry = _testLogEntry();
    controller.logs.assignAll([logEntry]);
    controller.openLogsPanel();
    await tester.pump();

    await tester.tap(find.byKey(const Key('log-multi-select-button')));
    await tester.pump();

    expect(controller.selectingLogs.value, isTrue);
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.text('已选 0 条'), findsOneWidget);

    await tester.tap(find.text(logEntry.title));
    await tester.pump();

    expect(controller.selectedLogs, contains(logEntry));
    expect(find.text('已选 1 条'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('独立解析日志页同步响应多选状态', (tester) async {
    final controller = _createTestController();
    Get.put<HomeController>(controller);
    final logEntry = _testLogEntry();
    controller.logs.assignAll([logEntry]);

    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light(), home: const ParseLogsView()),
    );
    await tester.tap(find.byKey(const Key('log-multi-select-button')));
    await tester.pump();

    expect(controller.selectingLogs.value, isTrue);
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.text('已选 0 条'), findsOneWidget);

    await tester.tap(find.text(logEntry.title));
    await tester.pump();

    expect(controller.selectedLogs, contains(logEntry));
    expect(find.text('已选 1 条'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('视频结果在扩展窗口切换为支持面板布局', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = _createTestController();
    Get.put<HomeController>(controller);
    controller.currentResult.value = const ParseResult(
      type: 'video',
      title: '测试视频',
    );

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const VideoResultView(),
      ),
    );
    await tester.pump();

    var previewRect = tester.getRect(
      find.byKey(const Key('video-preview-card')),
    );
    var resourcesRect = tester.getRect(
      find.byKey(const Key('video-resources-panel')),
    );
    expect(resourcesRect.top, greaterThan(previewRect.bottom));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(900, 900);
    await tester.pump();

    previewRect = tester.getRect(find.byKey(const Key('video-preview-card')));
    resourcesRect = tester.getRect(
      find.byKey(const Key('video-resources-panel')),
    );
    expect(resourcesRect.left, greaterThan(previewRect.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('紧凑布局在系统字体放大后无溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = _createTestController();
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        home: const HomeView(),
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          );
        },
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    for (final tabIndex in [1, 2]) {
      controller.switchTab(tabIndex);
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}

HomeController _createTestController({
  MediaCacheStore? mediaCacheStore,
  DownloadTaskManager? downloadTaskManager,
}) {
  return HomeController(
    downloadTaskManager:
        downloadTaskManager ??
        DownloadTaskManager(gateway: FakeBackgroundDownloaderGateway()),
    service: VideoParseService(parser: VideoParser(providers: const [])),
    mediaCacheStore: mediaCacheStore ?? _RecordingMediaCacheStore(),
  );
}

ParseLogEntry _testLogEntry() {
  return ParseLogEntry(
    id: 1,
    createdAt: DateTime.utc(2026, 7, 14),
    level: ParseLogLevel.success,
    title: '测试解析日志',
    description: '用于验证多选交互',
    source: 'test',
  );
}

class _RecordingMediaCacheStore implements MediaCacheStore {
  _RecordingMediaCacheStore({this.sizeInBytes = 0});

  int sizeInBytes;
  int clearCount = 0;

  @override
  Future<int> getSizeInBytes() async => sizeInBytes;

  @override
  Future<void> clear() async {
    clearCount++;
    sizeInBytes = 0;
  }
}
