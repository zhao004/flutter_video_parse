import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_parse/app/models/download_task_models.dart';
import 'package:flutter_video_parse/app/services/download_task_manager.dart';

import 'support/fake_background_downloader_gateway.dart';

void main() {
  group('DownloadTaskManager', () {
    late FakeBackgroundDownloaderGateway gateway;
    late DownloadTaskManager manager;

    setUp(() async {
      gateway = FakeBackgroundDownloaderGateway();
      manager = DownloadTaskManager(gateway: gateway);
      await manager.initialize();
    });

    tearDown(() async {
      manager.onClose();
      await gateway.close();
    });

    test('图集批量入队会去重并聚合为一个逻辑任务', () async {
      final result = await manager.enqueueGallery(
        name: '测试图集',
        urls: const [
          'https://cdn.example.com/image.jpg?index=1',
          'https://cdn.example.com/image.jpg?index=1',
          'https://cdn.example.com/image.jpg?index=2',
        ],
      );

      expect(result.created, isTrue);
      expect(result.skippedCount, 1);
      expect(gateway.enqueuedTasks, hasLength(2));
      expect(
        gateway.enqueuedTasks.map((task) => task.filename).toSet(),
        hasLength(2),
      );
      expect(
        gateway.enqueuedTasks.map((task) => task.group).toSet(),
        hasLength(1),
      );
      expect(gateway.enqueuedTasks.every((task) => task.allowPause), isTrue);
      expect(
        gateway.enqueuedTasks.every(
          (task) => task.baseDirectory == BaseDirectory.applicationSupport,
        ),
        isTrue,
      );
      expect(manager.jobs, hasLength(1));
      expect(manager.jobs.single.kind, DownloadJobKind.gallery);
      expect(manager.jobs.single.totalItems, 2);
      expect(manager.jobs.single.status, DownloadJobStatus.queued);
    });

    test('活动 URL 会阻止重复创建下载任务', () async {
      const url = 'https://cdn.example.com/video.mp4';
      final first = await manager.enqueueVideo(name: '视频', url: url);
      final second = await manager.enqueueVideo(name: '视频', url: url);

      expect(first.created, isTrue);
      expect(second.created, isFalse);
      expect(second.skippedCount, 1);
      expect(gateway.enqueuedTasks, hasLength(1));
    });

    test('子任务进度按数量等权聚合并在完成后保存到相册', () async {
      await manager.enqueueGallery(
        name: '进度图集',
        urls: const [
          'https://cdn.example.com/1.jpg',
          'https://cdn.example.com/2.jpg',
        ],
      );
      final first = gateway.enqueuedTasks[0];
      final second = gateway.enqueuedTasks[1];

      gateway.emitRecord(TaskRecord(first, TaskStatus.complete, 1, 100));
      gateway.emitRecord(TaskRecord(second, TaskStatus.running, 0.5, 100));
      await _flushAsyncWork();

      expect(manager.jobs.single.status, DownloadJobStatus.downloading);
      expect(manager.jobs.single.progress, closeTo(0.75, 0.001));
      expect(manager.jobs.single.completedItems, 1);

      gateway.emitRecord(TaskRecord(second, TaskStatus.complete, 1, 100));
      await _flushAsyncWork();

      expect(gateway.movedTasks, hasLength(2));
      expect(manager.jobs.single.status, DownloadJobStatus.completed);
      expect(manager.jobs.single.completedItems, 2);
      expect(manager.jobs.single.progress, 1);
    });

    test('相册迁移失败会将任务收口为可删除的失败状态', () async {
      gateway.moveResult = null;
      gateway.sourceFileExists = true;
      await manager.enqueueImage(
        name: '测试图片',
        url: 'https://cdn.example.com/image.jpg',
      );
      final task = gateway.enqueuedTasks.single;

      gateway.emitRecord(TaskRecord(task, TaskStatus.complete, 1, 100));
      await _flushAsyncWork();

      expect(manager.jobs.single.status, DownloadJobStatus.failed);
      expect(manager.jobs.single.failedItems, 1);
      expect(manager.jobs.single.canDelete, isTrue);
    });

    test('取消图集时只终止活动子任务并保留已保存数量', () async {
      await manager.enqueueGallery(
        name: '部分完成图集',
        urls: const [
          'https://cdn.example.com/1.jpg',
          'https://cdn.example.com/2.jpg',
        ],
      );
      final first = gateway.enqueuedTasks[0];
      final second = gateway.enqueuedTasks[1];
      gateway.emitRecord(TaskRecord(first, TaskStatus.complete, 1, 100));
      gateway.emitRecord(TaskRecord(second, TaskStatus.running, 0.2, 100));
      await _flushAsyncWork();

      final result = await manager.cancelJob(manager.jobs.single.id);

      expect(result.success, isTrue);
      expect(manager.jobs.single.status, DownloadJobStatus.canceled);
      expect(manager.jobs.single.completedItems, 1);
      expect(gateway.records[first.taskId]?.status, TaskStatus.complete);
      expect(gateway.records[second.taskId]?.status, TaskStatus.canceled);
    });

    test('任务支持暂停继续取消，且只有终态允许删除', () async {
      await manager.enqueueVideo(
        name: '测试视频',
        url: 'https://cdn.example.com/video.mp4',
      );
      final task = gateway.enqueuedTasks.single;
      gateway.emitRecord(TaskRecord(task, TaskStatus.running, 0.25, 100));

      expect(
        (await manager.deleteJob(manager.jobs.single.id)).success,
        isFalse,
      );
      expect((await manager.pauseJob(manager.jobs.single.id)).success, isTrue);
      expect(manager.jobs.single.status, DownloadJobStatus.paused);
      expect((await manager.resumeJob(manager.jobs.single.id)).success, isTrue);
      expect(manager.jobs.single.status, DownloadJobStatus.queued);
      expect((await manager.cancelJob(manager.jobs.single.id)).success, isTrue);
      expect(manager.jobs.single.status, DownloadJobStatus.canceled);
      expect((await manager.deleteJob(manager.jobs.single.id)).success, isTrue);
      expect(manager.jobs, isEmpty);
    });

    test('必要存储权限被拒绝时不会创建插件任务', () async {
      gateway.sharedStoragePermission = PermissionStatus.denied;

      final result = await manager.enqueueImage(
        name: '无权限图片',
        url: 'https://cdn.example.com/image.jpg',
      );

      expect(result.created, isFalse);
      expect(result.message, contains('权限'));
      expect(gateway.enqueuedTasks, isEmpty);
    });
  });
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
