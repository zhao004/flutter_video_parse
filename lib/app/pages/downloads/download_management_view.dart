import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/download_task_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/video_parse_widgets.dart';
import 'download_management_controller.dart';

/// 下载管理列表页，集中展示后台任务进度和可用操作。
///
/// 构建设计：页面宽度限制为 720dp；操作按钮置于独立底部行，确保紧凑窗口
/// 和系统字体放大时标题、状态及按钮不会相互遮挡。
class DownloadManagementView extends GetView<DownloadManagementController> {
  const DownloadManagementView({super.key});

  static const double _maximumListWidth = 720;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('下载管理')),
      body: AdaptivePageShell(
        topPadding: AppTheme.space8,
        child: Obx(() {
          final manager = controller.manager;
          final jobs = controller.jobs;
          if (manager.loading.value && jobs.isEmpty) {
            return ListView(
              children: const [
                SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          if (manager.loadError.value != null && jobs.isEmpty) {
            return ListView(
              children: [
                EmptyStatePanel(
                  title: '下载记录加载失败',
                  description: manager.loadError.value!,
                  icon: Icons.cloud_off_outlined,
                ),
                const SizedBox(height: AppTheme.space16),
                Center(
                  child: FilledButton.icon(
                    onPressed: controller.retryLoad,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ),
              ],
            );
          }
          if (jobs.isEmpty) {
            return ListView(
              key: const Key('download-management-empty'),
              children: const [
                EmptyStatePanel(
                  title: '暂无下载任务',
                  description: '从视频或图集结果页发起下载后，任务会显示在这里',
                  icon: Icons.download_for_offline_outlined,
                ),
              ],
            );
          }
          return ListView.separated(
            key: const Key('download-management-list'),
            itemCount: jobs.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTheme.space8),
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _maximumListWidth,
                  ),
                  child: _DownloadJobTile(
                    job: job,
                    onPause: () => controller.pauseJob(job),
                    onResume: () => controller.resumeJob(job),
                    onCancel: () => controller.confirmCancel(job),
                    onDelete: () => controller.confirmDelete(job),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// 单个逻辑下载任务，使用主题色角色表达状态而不硬编码颜色。
class _DownloadJobTile extends StatelessWidget {
  const _DownloadJobTile({
    required this.job,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onDelete,
  });

  final DownloadJobViewData job;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColor = _statusColor(context, job.status);
    return Material(
      key: Key('download-job-${job.id}'),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 40,
                  child: Icon(_kindIcon(job.kind), color: statusColor),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        _statusLabel(job.status),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space12),
            LinearProgressIndicator(value: job.progress),
            const SizedBox(height: AppTheme.space8),
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space4,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  job.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  _progressLabel(job),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (job.canPause)
                  IconButton(
                    key: Key('download-pause-${job.id}'),
                    tooltip: '暂停下载',
                    onPressed: onPause,
                    icon: const Icon(Icons.pause),
                  ),
                if (job.canResume)
                  IconButton(
                    key: Key('download-resume-${job.id}'),
                    tooltip: '继续下载',
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow),
                  ),
                if (job.canCancel)
                  IconButton(
                    key: Key('download-cancel-${job.id}'),
                    tooltip: '取消下载',
                    onPressed: onCancel,
                    color: colors.error,
                    icon: const Icon(Icons.close),
                  ),
                if (job.canDelete)
                  IconButton(
                    key: Key('download-delete-${job.id}'),
                    tooltip: '删除任务',
                    onPressed: onDelete,
                    color: colors.error,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _kindIcon(DownloadJobKind kind) => switch (kind) {
    DownloadJobKind.video => Icons.movie_outlined,
    DownloadJobKind.image => Icons.image_outlined,
    DownloadJobKind.gallery => Icons.photo_library_outlined,
  };

  String _statusLabel(DownloadJobStatus status) => switch (status) {
    DownloadJobStatus.queued => '排队中',
    DownloadJobStatus.downloading => '下载中',
    DownloadJobStatus.retrying => '等待重试',
    DownloadJobStatus.paused => '已暂停',
    DownloadJobStatus.saving => '保存中',
    DownloadJobStatus.completed => '已完成',
    DownloadJobStatus.failed => '失败',
    DownloadJobStatus.canceled => '已取消',
  };

  String _progressLabel(DownloadJobViewData job) {
    final itemLabel = '${job.completedItems} / ${job.totalItems}';
    final progress = job.progress;
    if (progress == null) {
      return itemLabel;
    }
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return '$percent% · $itemLabel';
  }

  Color _statusColor(BuildContext context, DownloadJobStatus status) {
    final colors = Theme.of(context).colorScheme;
    final statusColors = AppTheme.statusColorsOf(context);
    return switch (status) {
      DownloadJobStatus.completed => statusColors.success,
      DownloadJobStatus.failed => colors.error,
      DownloadJobStatus.canceled ||
      DownloadJobStatus.paused => colors.onSurfaceVariant,
      DownloadJobStatus.retrying => statusColors.warning,
      _ => colors.primary,
    };
  }
}
