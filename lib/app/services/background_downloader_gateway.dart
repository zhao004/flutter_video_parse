import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

/// 后台下载插件边界，隔离单例与平台通道以便业务逻辑使用 fake 测试。
abstract interface class BackgroundDownloaderGateway {
  Stream<TaskUpdate> get updates;

  Stream<TaskRecord> get recordUpdates;

  Future<void> start();

  Future<List<TaskRecord>> allRecords();

  Future<List<bool>> enqueueAll(List<DownloadTask> tasks);

  Future<bool> cancelTasks(Iterable<String> taskIds);

  Future<List<DownloadTask>> pauseGroup(String group);

  Future<List<Task>> resumeGroup(String group);

  Future<void> deleteRecords(Iterable<String> taskIds);

  Future<void> updateRecord(TaskRecord record);

  Future<String?> moveToSharedStorage(
    DownloadTask task,
    SharedStorage destination,
  );

  Future<bool?> taskFileExists(DownloadTask task);

  Future<bool> deleteTaskFile(DownloadTask task);

  Future<PermissionStatus> permissionStatus(PermissionType type);

  Future<PermissionStatus> requestPermission(PermissionType type);

  Future<bool> shouldShowPermissionRationale(PermissionType type);

  void configureJobNotification({
    required String group,
    required String jobName,
  });
}

/// `background_downloader` 的生产适配器。
class BackgroundDownloaderPluginGateway implements BackgroundDownloaderGateway {
  BackgroundDownloaderPluginGateway({FileDownloader? downloader})
    : _downloader = downloader ?? FileDownloader();

  static const int _maximumConcurrentTasks = 3;
  static const int _maximumConcurrentTasksPerGroup = 1;

  final FileDownloader _downloader;

  @override
  Stream<TaskUpdate> get updates => _downloader.updates;

  @override
  Stream<TaskRecord> get recordUpdates => _downloader.database.updates;

  @override
  Future<void> start() async {
    final responses = await _downloader.configure(
      globalConfig: (
        Config.holdingQueue,
        (_maximumConcurrentTasks, null, _maximumConcurrentTasksPerGroup),
      ),
    );
    final failures = responses.where((response) => response.$2.isNotEmpty);
    if (failures.isNotEmpty) {
      throw StateError('后台下载并发队列配置失败：${failures.first.$2}');
    }
    await _downloader.start(autoCleanDatabase: false);
  }

  @override
  Future<List<TaskRecord>> allRecords() => _downloader.database.allRecords();

  @override
  Future<List<bool>> enqueueAll(List<DownloadTask> tasks) =>
      _downloader.enqueueAll(tasks);

  @override
  Future<bool> cancelTasks(Iterable<String> taskIds) =>
      _downloader.cancelTasksWithIds(taskIds);

  @override
  Future<List<DownloadTask>> pauseGroup(String group) =>
      _downloader.pauseAll(group: group);

  @override
  Future<List<Task>> resumeGroup(String group) =>
      _downloader.resumeAll(group: group);

  @override
  Future<void> deleteRecords(Iterable<String> taskIds) =>
      _downloader.database.deleteRecordsWithIds(taskIds);

  @override
  Future<void> updateRecord(TaskRecord record) =>
      _downloader.database.updateRecord(record);

  @override
  Future<String?> moveToSharedStorage(
    DownloadTask task,
    SharedStorage destination,
  ) => _downloader.moveToSharedStorage(task, destination);

  @override
  Future<bool?> taskFileExists(DownloadTask task) async {
    try {
      return File(await task.filePath()).exists();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<bool> deleteTaskFile(DownloadTask task) async {
    try {
      final file = File(await task.filePath());
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<PermissionStatus> permissionStatus(PermissionType type) =>
      _downloader.permissions.status(type);

  @override
  Future<PermissionStatus> requestPermission(PermissionType type) =>
      _downloader.permissions.request(type);

  @override
  Future<bool> shouldShowPermissionRationale(PermissionType type) =>
      _downloader.permissions.shouldShowRationale(type);

  @override
  void configureJobNotification({
    required String group,
    required String jobName,
  }) {
    _downloader.configureNotificationForGroup(
      group,
      running: TaskNotification(
        '正在下载 $jobName',
        '已完成 {numFinished} / {numTotal}，进度 {progress}',
      ),
      complete: TaskNotification('文件传输完成', jobName),
      error: TaskNotification('下载失败', jobName),
      paused: TaskNotification('下载已暂停', jobName),
      canceled: TaskNotification('下载已取消', jobName),
      progressBar: true,
      groupNotificationId: group,
    );
  }
}
