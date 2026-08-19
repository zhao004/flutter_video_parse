import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_parse/app/pages/downloads/download_management_controller.dart';
import 'package:flutter_video_parse/app/pages/downloads/download_management_view.dart';
import 'package:flutter_video_parse/app/services/download_task_manager.dart';
import 'package:flutter_video_parse/app/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import 'support/fake_background_downloader_gateway.dart';

void main() {
  late FakeBackgroundDownloaderGateway gateway;
  late DownloadTaskManager manager;

  setUp(() async {
    Get.testMode = true;
    gateway = FakeBackgroundDownloaderGateway();
    manager = DownloadTaskManager(gateway: gateway);
    await manager.initialize();
    Get.put<DownloadTaskManager>(manager);
    Get.put<DownloadManagementController>(
      DownloadManagementController(manager),
    );
  });

  tearDown(() async {
    manager.onClose();
    await gateway.close();
    Get.reset();
  });

  testWidgets('空下载列表显示标准空状态', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pump();

    expect(find.byKey(const Key('download-management-empty')), findsOneWidget);
    expect(find.text('暂无下载任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('下载任务支持暂停继续取消和终态删除', (tester) async {
    await manager.enqueueVideo(
      name: '测试视频任务',
      url: 'https://cdn.example.com/video.mp4',
    );
    final task = gateway.enqueuedTasks.single;
    gateway.emitRecord(TaskRecord(task, TaskStatus.running, 0.35, 100));

    await tester.pumpWidget(_testApp());
    await tester.pump();

    expect(find.text('测试视频任务'), findsOneWidget);
    expect(find.text('35% · 0 / 1'), findsOneWidget);
    expect(
      find.byKey(Key('download-pause-${manager.jobs.single.id}')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(Key('download-pause-${manager.jobs.single.id}')),
    );
    await tester.pump();
    expect(find.text('已暂停'), findsOneWidget);
    expect(
      find.byKey(Key('download-resume-${manager.jobs.single.id}')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(Key('download-resume-${manager.jobs.single.id}')),
    );
    await tester.pump();
    expect(find.text('排队中'), findsOneWidget);

    await tester.tap(
      find.byKey(Key('download-cancel-${manager.jobs.single.id}')),
    );
    await tester.pump();
    expect(find.text('取消下载？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '取消下载'));
    await tester.pump();

    expect(find.text('已取消'), findsOneWidget);
    expect(
      find.byKey(Key('download-delete-${manager.jobs.single.id}')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(Key('download-delete-${manager.jobs.single.id}')),
    );
    await tester.pump();
    expect(find.text('删除任务记录？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pump();

    expect(find.text('暂无下载任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('紧凑窗口和两倍字体下任务项无布局溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await manager.enqueueGallery(
      name: '用于验证长标题布局的图集下载任务名称',
      urls: const [
        'https://cdn.example.com/1.jpg',
        'https://cdn.example.com/2.jpg',
      ],
    );

    await tester.pumpWidget(
      _testApp(
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

    expect(find.byKey(const Key('download-management-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp({TransitionBuilder? builder}) {
  return ToastificationWrapper(
    child: GetMaterialApp(
      theme: AppTheme.light(),
      builder: builder,
      home: const DownloadManagementView(),
    ),
  );
}
