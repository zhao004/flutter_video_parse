import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:get/get.dart';

import '../models/download_task_models.dart';
import 'background_downloader_gateway.dart';

/// 后台下载任务管理器，负责插件记录与应用逻辑任务之间的转换。
///
/// 设计意图：插件持久化每个实际文件，应用通过唯一 group 聚合视频、单图或
/// 整组图集；页面不依赖平台任务细节，应用重启后也能从数据库恢复相同视图。
class DownloadTaskManager extends GetxService {
  DownloadTaskManager({required BackgroundDownloaderGateway gateway})
    : _gateway = gateway;

  static const String _groupPrefix = 'video_parse_media_';
  static const String _downloadDirectory = 'media_downloads';
  static const int _metadataVersion = 1;
  static const int _maximumFileNameLength = 120;
  static const int _downloadRetries = 2;

  final BackgroundDownloaderGateway _gateway;
  final Map<String, TaskRecord> _records = <String, TaskRecord>{};
  final Set<String> _savingTaskIds = <String>{};
  final List<TaskRecord> _recordsReceivedDuringLoad = <TaskRecord>[];

  final RxList<DownloadJobViewData> jobs = <DownloadJobViewData>[].obs;
  final RxBool loading = false.obs;
  final RxBool ready = false.obs;
  final RxnString loadError = RxnString();

  StreamSubscription<TaskUpdate>? _taskUpdateSubscription;
  StreamSubscription<TaskRecord>? _recordUpdateSubscription;
  bool _subscriptionsBound = false;
  bool _started = false;
  bool _loadingSnapshot = false;
  bool _notificationPermissionResolved = false;
  Future<void>? _initializationFuture;

  /// 初始化监听和插件数据库。异常只进入可重试状态，不阻止应用启动。
  Future<void> initialize() {
    return _initializationFuture ??= _initializeInternal().whenComplete(() {
      _initializationFuture = null;
    });
  }

  Future<void> _initializeInternal() async {
    _bindSubscriptions();
    loading.value = true;
    loadError.value = null;
    try {
      if (!_started) {
        await _gateway.start();
        _started = true;
      }
      await _reloadRecords();
      ready.value = true;
      await _finalizePendingRecords();
    } catch (_) {
      loadError.value = '下载记录加载失败，请稍后重试';
    } finally {
      loading.value = false;
    }
  }

  /// 页面加载失败后的显式重试入口。
  Future<void> retryLoad() => initialize();

  String get settingsSubtitle {
    if (loading.value && jobs.isEmpty) {
      return '正在加载下载任务';
    }
    if (loadError.value != null && jobs.isEmpty) {
      return '下载记录暂不可用';
    }
    if (jobs.isEmpty) {
      return '暂无下载任务';
    }
    final downloadingCount = jobs.where((job) {
      return job.status == DownloadJobStatus.downloading ||
          job.status == DownloadJobStatus.saving;
    }).length;
    final queuedCount = jobs.where((job) {
      return job.status == DownloadJobStatus.queued ||
          job.status == DownloadJobStatus.retrying;
    }).length;
    if (downloadingCount > 0 || queuedCount > 0) {
      return '下载中 $downloadingCount 个 · 排队 $queuedCount 个';
    }
    return '共 ${jobs.length} 条任务记录';
  }

  /// 返回占用指定 URL 的非终态逻辑任务。
  DownloadJobViewData? activeJobForUrl(String url) {
    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl == null) {
      return null;
    }
    for (final job in jobs) {
      if (!job.isTerminal && job.urls.contains(normalizedUrl)) {
        return job;
      }
    }
    return null;
  }

  /// 返回与给定 URL 集合有交集的活动图集任务。
  DownloadJobViewData? activeGalleryJobForUrls(Iterable<String> urls) {
    final normalizedUrls = urls.map(_normalizeUrl).whereType<String>().toSet();
    for (final job in jobs) {
      if (job.kind == DownloadJobKind.gallery &&
          !job.isTerminal &&
          job.urls.any(normalizedUrls.contains)) {
        return job;
      }
    }
    return null;
  }

  Future<DownloadEnqueueResult> enqueueVideo({
    required String name,
    required String url,
    DownloadPermissionRationale? showPermissionRationale,
  }) {
    return _enqueue(
      name: name,
      kind: DownloadJobKind.video,
      urls: [url],
      showPermissionRationale: showPermissionRationale,
    );
  }

  Future<DownloadEnqueueResult> enqueueImage({
    required String name,
    required String url,
    DownloadPermissionRationale? showPermissionRationale,
  }) {
    return _enqueue(
      name: name,
      kind: DownloadJobKind.image,
      urls: [url],
      showPermissionRationale: showPermissionRationale,
    );
  }

  Future<DownloadEnqueueResult> enqueueGallery({
    required String name,
    required Iterable<String> urls,
    DownloadPermissionRationale? showPermissionRationale,
  }) {
    return _enqueue(
      name: name,
      kind: DownloadJobKind.gallery,
      urls: urls,
      showPermissionRationale: showPermissionRationale,
    );
  }

  Future<DownloadEnqueueResult> _enqueue({
    required String name,
    required DownloadJobKind kind,
    required Iterable<String> urls,
    DownloadPermissionRationale? showPermissionRationale,
  }) async {
    if (!_started) {
      await initialize();
    }
    if (!_started) {
      return const DownloadEnqueueResult(created: false, message: '后台下载服务暂不可用');
    }

    final normalizedName = name.trim().isEmpty
        ? _fallbackJobName(kind)
        : name.trim();
    final uniqueUrls = <String>{};
    var skippedCount = 0;
    for (final url in urls) {
      final normalizedUrl = _normalizeUrl(url);
      if (normalizedUrl == null || !uniqueUrls.add(normalizedUrl)) {
        skippedCount++;
      }
    }
    if (uniqueUrls.isEmpty) {
      return DownloadEnqueueResult(
        created: false,
        message: '没有可下载的有效资源链接',
        skippedCount: skippedCount,
      );
    }

    final activeUrls = _activeUrls();
    final eligibleUrls = uniqueUrls
        .where((url) => !activeUrls.contains(url))
        .toList(growable: false);
    skippedCount += uniqueUrls.length - eligibleUrls.length;
    if (eligibleUrls.isEmpty) {
      return DownloadEnqueueResult(
        created: false,
        message: '所选资源已在下载队列中',
        skippedCount: skippedCount,
      );
    }

    final permissionResult = await _ensurePermissions(showPermissionRationale);
    if (!permissionResult.$1) {
      return DownloadEnqueueResult(
        created: false,
        message: '未获得保存到系统相册所需权限',
        skippedCount: skippedCount,
      );
    }

    final jobId = _newJobId();
    final group = '$_groupPrefix$jobId';
    _gateway.configureJobNotification(group: group, jobName: normalizedName);
    final tasks = <DownloadTask>[];
    for (var index = 0; index < eligibleUrls.length; index++) {
      final metadata = _DownloadTaskMetadata(
        version: _metadataVersion,
        jobId: jobId,
        name: normalizedName,
        kind: kind,
        itemIndex: index,
        totalItems: eligibleUrls.length,
        savedToGallery: false,
      );
      tasks.add(
        DownloadTask(
          url: eligibleUrls[index],
          filename: _safeFileName(
            eligibleUrls[index],
            kind: kind,
            itemIndex: index,
          ),
          directory: '$_downloadDirectory/$jobId',
          baseDirectory: BaseDirectory.applicationSupport,
          group: group,
          updates: Updates.statusAndProgress,
          retries: _downloadRetries,
          allowPause: true,
          displayName: normalizedName,
          metaData: metadata.encode(),
        ),
      );
    }

    try {
      final enqueueResults = await _gateway.enqueueAll(tasks);
      var acceptedCount = 0;
      for (var index = 0; index < tasks.length; index++) {
        final accepted = index < enqueueResults.length && enqueueResults[index];
        final record = accepted
            ? TaskRecord(tasks[index], TaskStatus.enqueued, 0, -1)
            : TaskRecord(
                tasks[index],
                TaskStatus.failed,
                progressFailed,
                -1,
                TaskException('任务未能加入后台下载队列'),
              );
        _records[tasks[index].taskId] = record;
        if (accepted) {
          acceptedCount++;
        } else {
          await _gateway.updateRecord(record);
        }
      }
      _rebuildJobs();
      final notificationsEnabled = permissionResult.$2;
      final message = acceptedCount == 0
          ? '任务未能加入后台下载队列'
          : notificationsEnabled
          ? '任务已加入后台下载队列'
          : '任务已加入队列，系统通知未开启';
      return DownloadEnqueueResult(
        created: acceptedCount > 0,
        message: message,
        jobId: jobId,
        skippedCount: skippedCount,
      );
    } catch (_) {
      return DownloadEnqueueResult(
        created: false,
        message: '创建后台下载任务失败，请稍后重试',
        skippedCount: skippedCount,
      );
    }
  }

  /// 暂停逻辑任务中当前可暂停的插件子任务。
  Future<DownloadOperationResult> pauseJob(String jobId) async {
    final job = _jobById(jobId);
    if (job == null || !job.canPause) {
      return const DownloadOperationResult(false, '当前任务无法暂停');
    }
    try {
      final paused = await _gateway.pauseGroup(job.group);
      return paused.isEmpty
          ? const DownloadOperationResult(false, '资源服务器暂不支持暂停')
          : const DownloadOperationResult(true, '下载已暂停');
    } catch (_) {
      return const DownloadOperationResult(false, '暂停下载失败，请稍后重试');
    }
  }

  /// 继续已暂停的逻辑任务；插件会在无法续传时自动从头重试。
  Future<DownloadOperationResult> resumeJob(String jobId) async {
    final job = _jobById(jobId);
    if (job == null || !job.canResume) {
      return const DownloadOperationResult(false, '当前任务无法继续');
    }
    try {
      final resumed = await _gateway.resumeGroup(job.group);
      return resumed.isEmpty
          ? const DownloadOperationResult(false, '任务暂时无法继续下载')
          : const DownloadOperationResult(true, '下载已继续');
    } catch (_) {
      return const DownloadOperationResult(false, '继续下载失败，请稍后重试');
    }
  }

  /// 取消逻辑任务内尚未进入终态的全部子任务。
  Future<DownloadOperationResult> cancelJob(String jobId) async {
    final job = _jobById(jobId);
    if (job == null || !job.canCancel) {
      return const DownloadOperationResult(false, '当前任务无法取消');
    }
    try {
      final activeTaskIds = _records.values
          .where((record) {
            return _metadataFor(record.task)?.jobId == jobId &&
                !record.status.isFinalState;
          })
          .map((record) => record.taskId)
          .toList(growable: false);
      if (activeTaskIds.isEmpty) {
        return const DownloadOperationResult(false, '当前任务无法取消');
      }
      final canceled = await _gateway.cancelTasks(activeTaskIds);
      return canceled
          ? const DownloadOperationResult(true, '下载已取消')
          : const DownloadOperationResult(false, '部分下载任务未能取消');
    } catch (_) {
      return const DownloadOperationResult(false, '取消下载失败，请稍后重试');
    }
  }

  /// 删除终态记录；未移入相册的私有文件必须先成功清理。
  Future<DownloadOperationResult> deleteJob(String jobId) async {
    final job = _jobById(jobId);
    if (job == null || !job.canDelete) {
      return const DownloadOperationResult(false, '只能删除已结束的任务');
    }
    final records = _records.values
        .where((record) => _metadataFor(record.task)?.jobId == jobId)
        .toList(growable: false);
    try {
      for (final record in records) {
        final metadata = _metadataFor(record.task);
        if (record.task is DownloadTask &&
            metadata != null &&
            !metadata.savedToGallery) {
          final deleted = await _gateway.deleteTaskFile(
            record.task as DownloadTask,
          );
          if (!deleted) {
            return const DownloadOperationResult(false, '残留下载文件清理失败，任务记录未删除');
          }
        }
      }
      await _gateway.deleteRecords(records.map((record) => record.taskId));
      for (final record in records) {
        _records.remove(record.taskId);
      }
      _rebuildJobs();
      return const DownloadOperationResult(true, '任务记录已删除');
    } catch (_) {
      return const DownloadOperationResult(false, '删除任务失败，请稍后重试');
    }
  }

  void _bindSubscriptions() {
    if (_subscriptionsBound) {
      return;
    }
    _subscriptionsBound = true;
    // 必须在 start 前订阅；数据库流负责实际状态，任务流用于接收后台补发事件。
    _taskUpdateSubscription = _gateway.updates.listen((update) {
      if (_metadataFor(update.task) == null) {
        return;
      }
    }, onError: (_) {});
    _recordUpdateSubscription = _gateway.recordUpdates.listen(
      _handleRecordUpdate,
      onError: (_) {
        loadError.value = '下载状态同步失败，请稍后重试';
      },
    );
  }

  Future<void> _reloadRecords() async {
    _loadingSnapshot = true;
    _recordsReceivedDuringLoad.clear();
    try {
      final snapshot = await _gateway.allRecords();
      _records
        ..clear()
        ..addEntries(
          snapshot
              .where((record) => _metadataFor(record.task) != null)
              .map((record) => MapEntry(record.taskId, record)),
        );
      for (final record in _recordsReceivedDuringLoad) {
        _records[record.taskId] = record;
      }
      _restoreNotificationConfigurations();
      _rebuildJobs();
    } finally {
      _recordsReceivedDuringLoad.clear();
      _loadingSnapshot = false;
    }
  }

  void _handleRecordUpdate(TaskRecord record) {
    if (_metadataFor(record.task) == null) {
      return;
    }
    if (_loadingSnapshot) {
      _recordsReceivedDuringLoad.add(record);
      return;
    }
    _records[record.taskId] = record;
    _rebuildJobs();
    if (record.status == TaskStatus.complete) {
      unawaited(_finalizeRecord(record));
    }
  }

  void _restoreNotificationConfigurations() {
    final configuredGroups = <String>{};
    for (final record in _records.values) {
      final metadata = _metadataFor(record.task);
      if (metadata == null || !configuredGroups.add(record.group)) {
        continue;
      }
      _gateway.configureJobNotification(
        group: record.group,
        jobName: metadata.name,
      );
    }
  }

  Future<void> _finalizePendingRecords() async {
    final records = _records.values
        .where((record) {
          final metadata = _metadataFor(record.task);
          return record.status == TaskStatus.complete &&
              metadata != null &&
              !metadata.savedToGallery;
        })
        .toList(growable: false);
    for (final record in records) {
      await _finalizeRecord(record);
    }
  }

  Future<void> _finalizeRecord(TaskRecord record) async {
    final task = record.task;
    final metadata = _metadataFor(task);
    if (task is! DownloadTask ||
        metadata == null ||
        metadata.savedToGallery ||
        !_savingTaskIds.add(task.taskId)) {
      return;
    }
    _rebuildJobs();
    try {
      String? destinationPath;
      Object? moveError;
      try {
        destinationPath = await _gateway.moveToSharedStorage(
          task,
          metadata.kind == DownloadJobKind.video
              ? SharedStorage.video
              : SharedStorage.images,
        );
      } catch (error) {
        moveError = error;
      }

      final sourceExists = await _gateway.taskFileExists(task);
      if (destinationPath != null || sourceExists == false) {
        final updatedTask = task.copyWith(
          metaData: metadata.copyWith(savedToGallery: true).encode(),
        );
        final updatedRecord = TaskRecord(
          updatedTask,
          TaskStatus.complete,
          progressComplete,
          record.expectedFileSize,
        );
        _records[task.taskId] = updatedRecord;
        await _gateway.updateRecord(updatedRecord);
      } else {
        final description = moveError == null
            ? '文件保存到系统相册失败'
            : '文件保存到系统相册失败，请检查存储权限';
        final failedRecord = TaskRecord(
          task,
          TaskStatus.failed,
          progressFailed,
          record.expectedFileSize,
          TaskFileSystemException(description),
        );
        _records[task.taskId] = failedRecord;
        await _gateway.updateRecord(failedRecord);
      }
    } catch (_) {
      final failedRecord = TaskRecord(
        task,
        TaskStatus.failed,
        progressFailed,
        record.expectedFileSize,
        TaskFileSystemException('文件保存到系统相册失败，请稍后重试'),
      );
      _records[task.taskId] = failedRecord;
      try {
        await _gateway.updateRecord(failedRecord);
      } catch (_) {
        loadError.value = '下载结果保存失败，请稍后重试';
      }
    } finally {
      _savingTaskIds.remove(task.taskId);
      _rebuildJobs();
    }
  }

  Future<(bool, bool)> _ensurePermissions(
    DownloadPermissionRationale? showRationale,
  ) async {
    final storageGranted = await _ensurePermission(
      PermissionType.androidSharedStorage,
      DownloadPermissionKind.sharedStorage,
      showRationale,
    );
    if (!storageGranted) {
      return (false, false);
    }

    var notificationGranted = false;
    if (!_notificationPermissionResolved) {
      notificationGranted = await _ensurePermission(
        PermissionType.notifications,
        DownloadPermissionKind.notifications,
        showRationale,
      );
      _notificationPermissionResolved = true;
    } else {
      notificationGranted =
          await _gateway.permissionStatus(PermissionType.notifications) ==
          PermissionStatus.granted;
    }
    return (true, notificationGranted);
  }

  Future<bool> _ensurePermission(
    PermissionType type,
    DownloadPermissionKind kind,
    DownloadPermissionRationale? showRationale,
  ) async {
    final currentStatus = await _gateway.permissionStatus(type);
    if (currentStatus == PermissionStatus.granted) {
      return true;
    }
    final needsRationale = await _gateway.shouldShowPermissionRationale(type);
    if (needsRationale && showRationale != null && !await showRationale(kind)) {
      return false;
    }
    return await _gateway.requestPermission(type) == PermissionStatus.granted;
  }

  Set<String> _activeUrls() {
    return jobs
        .where((job) => !job.isTerminal)
        .expand((job) => job.urls)
        .toSet();
  }

  DownloadJobViewData? _jobById(String jobId) {
    for (final job in jobs) {
      if (job.id == jobId) {
        return job;
      }
    }
    return null;
  }

  void _rebuildJobs() {
    final groupedRecords = <String, List<TaskRecord>>{};
    for (final record in _records.values) {
      final metadata = _metadataFor(record.task);
      if (metadata == null) {
        continue;
      }
      groupedRecords.putIfAbsent(metadata.jobId, () => []).add(record);
    }

    final rebuilt = <DownloadJobViewData>[];
    for (final entry in groupedRecords.entries) {
      final records = entry.value
        ..sort(
          (left, right) =>
              left.task.creationTime.compareTo(right.task.creationTime),
        );
      final metadata = _metadataFor(records.first.task)!;
      final status = _aggregateStatus(records);
      final progress = _aggregateProgress(records, status);
      final completedItems = records.where((record) {
        final itemMetadata = _metadataFor(record.task);
        return record.status == TaskStatus.complete &&
            itemMetadata?.savedToGallery == true;
      }).length;
      final failedItems = records.where((record) {
        return record.status == TaskStatus.failed ||
            record.status == TaskStatus.notFound;
      }).length;
      final canceledItems = records
          .where((record) => record.status == TaskStatus.canceled)
          .length;
      final totalItems = records
          .map((record) => _metadataFor(record.task)?.totalItems ?? 1)
          .fold<int>(records.length, max);
      rebuilt.add(
        DownloadJobViewData(
          id: entry.key,
          group: records.first.group,
          name: metadata.name,
          kind: metadata.kind,
          status: status,
          progress: progress,
          completedItems: completedItems,
          totalItems: totalItems,
          failedItems: failedItems,
          canceledItems: canceledItems,
          createdAt: records.first.task.creationTime,
          taskIds: List.unmodifiable(records.map((record) => record.taskId)),
          urls: Set.unmodifiable(records.map((record) => record.task.url)),
          message: _statusMessage(
            status,
            completedItems: completedItems,
            totalItems: totalItems,
            failedItems: failedItems,
          ),
        ),
      );
    }
    rebuilt.sort((left, right) {
      final priorityDifference =
          _statusPriority(left.status) - _statusPriority(right.status);
      if (priorityDifference != 0) {
        return priorityDifference;
      }
      if (left.isTerminal) {
        return right.createdAt.compareTo(left.createdAt);
      }
      return left.createdAt.compareTo(right.createdAt);
    });
    jobs.assignAll(rebuilt);
  }

  DownloadJobStatus _aggregateStatus(List<TaskRecord> records) {
    if (records.any((record) => _savingTaskIds.contains(record.taskId)) ||
        records.any((record) {
          final metadata = _metadataFor(record.task);
          return record.status == TaskStatus.complete &&
              metadata != null &&
              !metadata.savedToGallery;
        })) {
      return DownloadJobStatus.saving;
    }
    if (records.any((record) => record.status == TaskStatus.running)) {
      return DownloadJobStatus.downloading;
    }
    if (records.any((record) => record.status == TaskStatus.waitingToRetry)) {
      return DownloadJobStatus.retrying;
    }
    if (records.any((record) => record.status == TaskStatus.enqueued)) {
      return DownloadJobStatus.queued;
    }
    if (records.any((record) => record.status == TaskStatus.paused)) {
      return DownloadJobStatus.paused;
    }
    if (records.every((record) {
      return record.status == TaskStatus.complete &&
          _metadataFor(record.task)?.savedToGallery == true;
    })) {
      return DownloadJobStatus.completed;
    }
    if (records.any((record) {
      return record.status == TaskStatus.failed ||
          record.status == TaskStatus.notFound;
    })) {
      return DownloadJobStatus.failed;
    }
    if (records.any((record) => record.status == TaskStatus.canceled)) {
      return DownloadJobStatus.canceled;
    }
    return DownloadJobStatus.failed;
  }

  double? _aggregateProgress(
    List<TaskRecord> records,
    DownloadJobStatus status,
  ) {
    if (records.isEmpty) {
      return null;
    }
    final values = records
        .map((record) {
          if (record.status == TaskStatus.complete) {
            return 1.0;
          }
          return record.progress >= 0 && record.progress <= 1
              ? record.progress
              : 0.0;
        })
        .toList(growable: false);
    final aggregate =
        values.reduce((left, right) => left + right) / values.length;
    final hasKnownProgress = records.any((record) {
      return record.progress > 0 || record.expectedFileSize > 0;
    });
    if (status == DownloadJobStatus.downloading && !hasKnownProgress) {
      return null;
    }
    return aggregate.clamp(0.0, 1.0).toDouble();
  }

  int _statusPriority(DownloadJobStatus status) => switch (status) {
    DownloadJobStatus.downloading || DownloadJobStatus.saving => 0,
    DownloadJobStatus.queued || DownloadJobStatus.retrying => 1,
    DownloadJobStatus.paused => 2,
    _ => 3,
  };

  String _statusMessage(
    DownloadJobStatus status, {
    required int completedItems,
    required int totalItems,
    required int failedItems,
  }) {
    return switch (status) {
      DownloadJobStatus.queued => '等待后台下载',
      DownloadJobStatus.downloading => '正在下载',
      DownloadJobStatus.retrying => '网络异常，等待重试',
      DownloadJobStatus.paused => '下载已暂停',
      DownloadJobStatus.saving => '正在保存到系统相册',
      DownloadJobStatus.completed => '已保存 $completedItems / $totalItems 个文件',
      DownloadJobStatus.failed =>
        failedItems > 0 ? '$failedItems 个文件下载或保存失败' : '下载失败，请稍后重试',
      DownloadJobStatus.canceled =>
        '下载已取消，已保存 $completedItems / $totalItems 个文件',
    };
  }

  _DownloadTaskMetadata? _metadataFor(Task task) {
    if (!task.group.startsWith(_groupPrefix)) {
      return null;
    }
    final parsed = _DownloadTaskMetadata.tryParse(task.metaData);
    if (parsed != null) {
      return parsed;
    }

    // 元数据损坏时仍保留任务管理能力，避免产生无法取消或删除的孤立记录。
    final groupSuffix = task.group.substring(_groupPrefix.length).trim();
    final normalizedFileName = task.filename.toLowerCase();
    final looksLikeVideo = const [
      '.mp4',
      '.mov',
      '.m4v',
      '.webm',
      '.mkv',
    ].any(normalizedFileName.endsWith);
    return _DownloadTaskMetadata(
      version: _metadataVersion,
      jobId: groupSuffix.isEmpty ? task.taskId : groupSuffix,
      name: task.displayName.trim().isEmpty
          ? '未知下载任务'
          : task.displayName.trim(),
      kind: looksLikeVideo ? DownloadJobKind.video : DownloadJobKind.image,
      itemIndex: 0,
      totalItems: 1,
      savedToGallery: false,
    );
  }

  String _newJobId() {
    final randomPart = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return '${DateTime.now().microsecondsSinceEpoch}_$randomPart';
  }

  static String? _normalizeUrl(String value) {
    final normalized = value.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri.replace(fragment: '').toString();
  }

  static String _fallbackJobName(DownloadJobKind kind) => switch (kind) {
    DownloadJobKind.video => '未命名视频',
    DownloadJobKind.image => '未命名图片',
    DownloadJobKind.gallery => '未命名图集',
  };

  static String _safeFileName(
    String url, {
    required DownloadJobKind kind,
    required int itemIndex,
  }) {
    final uri = Uri.parse(url);
    final sourceName = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final sanitizedSource = _sanitizeFileName(sourceName);
    final baseName = switch (kind) {
      DownloadJobKind.video =>
        sanitizedSource.isEmpty ? 'video' : sanitizedSource,
      DownloadJobKind.image || DownloadJobKind.gallery =>
        sanitizedSource.isEmpty
            ? 'image_${itemIndex + 1}'
            : 'image_${itemIndex + 1}_$sanitizedSource',
    };
    final fallbackExtension = kind == DownloadJobKind.video ? '.mp4' : '.jpg';
    final withExtension = _extension(baseName).isEmpty
        ? '$baseName$fallbackExtension'
        : baseName;
    if (withExtension.length <= _maximumFileNameLength) {
      return withExtension;
    }
    final extension = _extension(withExtension);
    final maximumBaseLength = _maximumFileNameLength - extension.length;
    return '${withExtension.substring(0, maximumBaseLength)}$extension';
  }

  static String _sanitizeFileName(String value) {
    return value.trim().replaceAll(RegExp(r'[^\w\-.]+'), '_');
  }

  static String _extension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex);
  }

  @override
  void onClose() {
    _taskUpdateSubscription?.cancel();
    _recordUpdateSubscription?.cancel();
    super.onClose();
  }
}

class _DownloadTaskMetadata {
  const _DownloadTaskMetadata({
    required this.version,
    required this.jobId,
    required this.name,
    required this.kind,
    required this.itemIndex,
    required this.totalItems,
    required this.savedToGallery,
  });

  final int version;
  final String jobId;
  final String name;
  final DownloadJobKind kind;
  final int itemIndex;
  final int totalItems;
  final bool savedToGallery;

  String encode() {
    return jsonEncode({
      'version': version,
      'jobId': jobId,
      'name': name,
      'kind': kind.name,
      'itemIndex': itemIndex,
      'totalItems': totalItems,
      'savedToGallery': savedToGallery,
    });
  }

  _DownloadTaskMetadata copyWith({bool? savedToGallery}) {
    return _DownloadTaskMetadata(
      version: version,
      jobId: jobId,
      name: name,
      kind: kind,
      itemIndex: itemIndex,
      totalItems: totalItems,
      savedToGallery: savedToGallery ?? this.savedToGallery,
    );
  }

  static _DownloadTaskMetadata? tryParse(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final version = decoded['version'];
      final jobId = decoded['jobId'];
      final name = decoded['name'];
      final kindName = decoded['kind'];
      final itemIndex = decoded['itemIndex'];
      final totalItems = decoded['totalItems'];
      final savedToGallery = decoded['savedToGallery'];
      if (version is! int ||
          version != DownloadTaskManager._metadataVersion ||
          jobId is! String ||
          jobId.isEmpty ||
          name is! String ||
          name.trim().isEmpty ||
          kindName is! String ||
          itemIndex is! int ||
          itemIndex < 0 ||
          totalItems is! int ||
          totalItems <= 0 ||
          itemIndex >= totalItems ||
          savedToGallery is! bool) {
        return null;
      }
      final kind = DownloadJobKind.values
          .where((candidate) => candidate.name == kindName)
          .firstOrNull;
      if (kind == null) {
        return null;
      }
      return _DownloadTaskMetadata(
        version: version,
        jobId: jobId,
        name: name.trim(),
        kind: kind,
        itemIndex: itemIndex,
        totalItems: totalItems,
        savedToGallery: savedToGallery,
      );
    } catch (_) {
      return null;
    }
  }
}
