import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/download_task_models.dart';
import '../../services/download_task_manager.dart';
import '../../utils/app_toast.dart';

/// 下载管理页控制器，负责危险操作确认和用户反馈。
class DownloadManagementController extends GetxController {
  DownloadManagementController(this.manager);

  final DownloadTaskManager manager;

  List<DownloadJobViewData> get jobs => manager.jobs;

  Future<void> retryLoad() => manager.retryLoad();

  Future<void> pauseJob(DownloadJobViewData job) async {
    _showOperationResult(await manager.pauseJob(job.id));
  }

  Future<void> resumeJob(DownloadJobViewData job) async {
    _showOperationResult(await manager.resumeJob(job.id));
  }

  /// 取消会终止未完成的网络传输，必须二次确认以防误触。
  Future<void> confirmCancel(DownloadJobViewData job) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('取消下载？'),
        content: Text('确认取消“${job.name}”？已保存到相册的文件会保留。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('取消下载'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _showOperationResult(await manager.cancelJob(job.id));
    }
  }

  /// 删除只作用于终态记录，不会删除系统相册中的媒体文件。
  Future<void> confirmDelete(DownloadJobViewData job) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除任务记录？'),
        content: Text('确认删除“${job.name}”的下载记录？相册文件不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _showOperationResult(await manager.deleteJob(job.id));
    }
  }

  void _showOperationResult(DownloadOperationResult result) {
    if (result.success) {
      AppToast.success('操作完成', result.message);
      return;
    }
    AppToast.warning('操作未完成', result.message);
  }
}
