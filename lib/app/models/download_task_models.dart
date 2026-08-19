import 'package:flutter/foundation.dart';

/// 下载管理页展示的逻辑任务类型。
enum DownloadJobKind { video, image, gallery }

/// 聚合插件子任务后的稳定业务状态。
enum DownloadJobStatus {
  queued,
  downloading,
  retrying,
  paused,
  saving,
  completed,
  failed,
  canceled,
}

/// 下载前可能需要解释的系统权限。
enum DownloadPermissionKind { notifications, sharedStorage }

/// 下载管理页使用的不可变任务数据。
@immutable
class DownloadJobViewData {
  const DownloadJobViewData({
    required this.id,
    required this.group,
    required this.name,
    required this.kind,
    required this.status,
    required this.completedItems,
    required this.totalItems,
    required this.failedItems,
    required this.canceledItems,
    required this.createdAt,
    required this.taskIds,
    required this.urls,
    this.progress,
    this.message = '',
  });

  final String id;
  final String group;
  final String name;
  final DownloadJobKind kind;
  final DownloadJobStatus status;
  final double? progress;
  final int completedItems;
  final int totalItems;
  final int failedItems;
  final int canceledItems;
  final DateTime createdAt;
  final List<String> taskIds;
  final Set<String> urls;
  final String message;

  bool get isTerminal => switch (status) {
    DownloadJobStatus.completed ||
    DownloadJobStatus.failed ||
    DownloadJobStatus.canceled => true,
    _ => false,
  };

  bool get canPause => status == DownloadJobStatus.downloading;

  bool get canResume => status == DownloadJobStatus.paused;

  bool get canCancel => !isTerminal && status != DownloadJobStatus.saving;

  bool get canDelete => isTerminal;
}

/// 入队结果同时返回被过滤资源数量，供调用侧给出准确反馈。
@immutable
class DownloadEnqueueResult {
  const DownloadEnqueueResult({
    required this.created,
    required this.message,
    this.jobId,
    this.skippedCount = 0,
  });

  final bool created;
  final String message;
  final String? jobId;
  final int skippedCount;
}

/// 暂停、继续、取消和删除操作的统一结果。
@immutable
class DownloadOperationResult {
  const DownloadOperationResult(this.success, this.message);

  final bool success;
  final String message;
}

typedef DownloadPermissionRationale =
    Future<bool> Function(DownloadPermissionKind kind);
