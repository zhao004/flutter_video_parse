import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_video_parse/app/services/background_downloader_gateway.dart';

/// 后台下载插件 Fake，测试可直接推送数据库记录而不触发平台通道。
class FakeBackgroundDownloaderGateway implements BackgroundDownloaderGateway {
  final StreamController<TaskUpdate> _taskUpdates =
      StreamController<TaskUpdate>.broadcast(sync: true);
  final StreamController<TaskRecord> _recordUpdates =
      StreamController<TaskRecord>.broadcast(sync: true);

  final Map<String, TaskRecord> records = <String, TaskRecord>{};
  final List<DownloadTask> enqueuedTasks = <DownloadTask>[];
  final List<DownloadTask> movedTasks = <DownloadTask>[];
  final List<String> configuredGroups = <String>[];

  List<bool>? enqueueResults;
  PermissionStatus sharedStoragePermission = PermissionStatus.granted;
  PermissionStatus notificationPermission = PermissionStatus.granted;
  bool showSharedStorageRationale = false;
  bool showNotificationRationale = false;
  String? moveResult = 'content://saved/media';
  Object? moveError;
  bool? sourceFileExists = true;
  bool deleteFileResult = true;
  Object? startError;
  int startCount = 0;

  @override
  Stream<TaskUpdate> get updates => _taskUpdates.stream;

  @override
  Stream<TaskRecord> get recordUpdates => _recordUpdates.stream;

  @override
  Future<void> start() async {
    startCount++;
    if (startError != null) {
      throw startError!;
    }
  }

  @override
  Future<List<TaskRecord>> allRecords() async => records.values.toList();

  @override
  Future<List<bool>> enqueueAll(List<DownloadTask> tasks) async {
    enqueuedTasks.addAll(tasks);
    final results = enqueueResults ?? List<bool>.filled(tasks.length, true);
    for (var index = 0; index < tasks.length; index++) {
      if (index < results.length && results[index]) {
        emitRecord(TaskRecord(tasks[index], TaskStatus.enqueued, 0, -1));
      }
    }
    return results;
  }

  @override
  Future<bool> cancelTasks(Iterable<String> taskIds) async {
    final requestedIds = taskIds.toSet();
    final matching = records.values
        .where(
          (record) =>
              requestedIds.contains(record.taskId) &&
              !record.status.isFinalState,
        )
        .toList(growable: false);
    for (final record in matching) {
      emitRecord(
        TaskRecord(
          record.task,
          TaskStatus.canceled,
          progressCanceled,
          record.expectedFileSize,
        ),
      );
    }
    return matching.isNotEmpty;
  }

  @override
  Future<List<DownloadTask>> pauseGroup(String group) async {
    final paused = <DownloadTask>[];
    for (final record in records.values.toList()) {
      if (record.group == group &&
          record.status == TaskStatus.running &&
          record.task is DownloadTask) {
        final task = record.task as DownloadTask;
        paused.add(task);
        emitRecord(
          TaskRecord(
            task,
            TaskStatus.paused,
            record.progress,
            record.expectedFileSize,
          ),
        );
      }
    }
    return paused;
  }

  @override
  Future<List<Task>> resumeGroup(String group) async {
    final resumed = <Task>[];
    for (final record in records.values.toList()) {
      if (record.group == group && record.status == TaskStatus.paused) {
        resumed.add(record.task);
        emitRecord(
          TaskRecord(
            record.task,
            TaskStatus.enqueued,
            record.progress,
            record.expectedFileSize,
          ),
        );
      }
    }
    return resumed;
  }

  @override
  Future<void> deleteRecords(Iterable<String> taskIds) async {
    for (final taskId in taskIds) {
      records.remove(taskId);
    }
  }

  @override
  Future<void> updateRecord(TaskRecord record) async {
    emitRecord(record);
  }

  @override
  Future<String?> moveToSharedStorage(
    DownloadTask task,
    SharedStorage destination,
  ) async {
    movedTasks.add(task);
    if (moveError != null) {
      throw moveError!;
    }
    if (moveResult != null) {
      sourceFileExists = false;
    }
    return moveResult;
  }

  @override
  Future<bool?> taskFileExists(DownloadTask task) async => sourceFileExists;

  @override
  Future<bool> deleteTaskFile(DownloadTask task) async => deleteFileResult;

  @override
  Future<PermissionStatus> permissionStatus(PermissionType type) async {
    return type == PermissionType.notifications
        ? notificationPermission
        : sharedStoragePermission;
  }

  @override
  Future<PermissionStatus> requestPermission(PermissionType type) async {
    return permissionStatus(type);
  }

  @override
  Future<bool> shouldShowPermissionRationale(PermissionType type) async {
    return type == PermissionType.notifications
        ? showNotificationRationale
        : showSharedStorageRationale;
  }

  @override
  void configureJobNotification({
    required String group,
    required String jobName,
  }) {
    configuredGroups.add(group);
  }

  void emitRecord(TaskRecord record) {
    records[record.taskId] = record;
    _recordUpdates.add(record);
  }

  Future<void> close() async {
    await _taskUpdates.close();
    await _recordUpdates.close();
  }
}
