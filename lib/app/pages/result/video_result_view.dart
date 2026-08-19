import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../models/download_task_models.dart';
import '../../models/parse_ui_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/video_parse_widgets.dart';
import '../home/home_controller.dart';

/// 视频解析结果页，紧凑窗口纵向排列，扩展窗口采用支持面板布局。
class VideoResultView extends GetView<HomeController> {
  const VideoResultView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频结果')),
      body: AdaptivePageShell(
        topPadding: AppTheme.space8,
        child: Obx(() {
          final result = controller.currentResult.value;
          if (result == null) {
            return const _MissingResultView();
          }

          final resources = controller.videoResources;
          final videoUrl = controller.primaryVideoUrl;
          final downloadJob = controller.primaryVideoDownloadJob;
          final downloading = downloadJob != null;
          final preview = _VideoPreviewCard(
            videoUrl: videoUrl,
            coverUrl: result.cover,
          );
          final title = Text(
            result.title.trim().isEmpty ? '未命名视频' : result.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          );
          final resourcesPanel = _VideoResourcesPanel(resources: resources);
          final downloadButton = ParseActionButton(
            label: _downloadLabel(downloadJob),
            icon: Icons.download_outlined,
            loading:
                downloading && downloadJob.status != DownloadJobStatus.paused,
            onTap: downloading
                ? null
                : controller.downloadPrimaryVideoToGallery,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= AppTheme.expandedBreakpoint) {
                return SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            preview,
                            const SizedBox(height: AppTheme.space16),
                            title,
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.space24),
                      SizedBox(
                        width: 360,
                        child: Column(
                          children: [
                            resourcesPanel,
                            const SizedBox(height: AppTheme.space16),
                            downloadButton,
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                children: [
                  preview,
                  const SizedBox(height: AppTheme.space16),
                  title,
                  const SizedBox(height: AppTheme.space24),
                  resourcesPanel,
                  const SizedBox(height: AppTheme.space16),
                  downloadButton,
                ],
              );
            },
          );
        }),
      ),
    );
  }

  String _downloadLabel(DownloadJobViewData? job) {
    if (job == null) {
      return '下载视频';
    }
    if (job.status == DownloadJobStatus.paused) {
      return '下载已暂停';
    }
    if (job.status == DownloadJobStatus.saving) {
      return '正在保存';
    }
    final progress = job.progress;
    if (progress == null || progress <= 0) {
      return job.status == DownloadJobStatus.queued ? '排队中' : '下载中';
    }
    return '下载中 ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%';
  }
}

/// 播放器卡片，为视频内容提供稳定的 16:9 展示区域。
class _VideoPreviewCard extends StatelessWidget {
  const _VideoPreviewCard({required this.videoUrl, required this.coverUrl});

  final String videoUrl;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('video-preview-card'),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _ChewieVideoPlayer(
              key: ValueKey(videoUrl),
              videoUrl: videoUrl,
              coverUrl: coverUrl,
            ),
          ),
        ),
      ),
    );
  }
}

/// 资源支持面板，资源项使用 ListTile，避免卡片嵌套。
class _VideoResourcesPanel extends StatelessWidget {
  const _VideoResourcesPanel({required this.resources});

  final List<MediaResourceViewData> resources;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      key: const Key('video-resources-panel'),
      title: '资源',
      child: resources.isEmpty
          ? Row(
              children: [
                Icon(
                  Icons.link_off_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.space12),
                const Expanded(child: Text('当前结果缺少视频或封面直链')),
              ],
            )
          : Column(
              children: [
                for (var index = 0; index < resources.length; index++) ...[
                  MediaResourceTile(data: resources[index]),
                  if (index < resources.length - 1) const Divider(),
                ],
              ],
            ),
    );
  }
}

/// Chewie 播放器生命周期封装，媒体 URL 变化时重建底层控制器。
class _ChewieVideoPlayer extends StatefulWidget {
  const _ChewieVideoPlayer({
    required this.videoUrl,
    required this.coverUrl,
    super.key,
  });

  final String videoUrl;
  final String coverUrl;

  @override
  State<_ChewieVideoPlayer> createState() => _ChewieVideoPlayerState();
}

class _ChewieVideoPlayerState extends State<_ChewieVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  Future<void>? _initializeFuture;

  @override
  void initState() {
    super.initState();
    _initializeFuture = _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant _ChewieVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeControllers();
      _initializeFuture = _initializePlayer();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    final url = widget.videoUrl.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }

    final videoController = VideoPlayerController.networkUrl(uri);
    _videoPlayerController = videoController;
    await videoController.initialize();
    if (!mounted) {
      await videoController.dispose();
      return;
    }

    final aspectRatio = videoController.value.aspectRatio == 0
        ? 16 / 9
        : videoController.value.aspectRatio;
    _chewieController = ChewieController(
      videoPlayerController: videoController,
      aspectRatio: aspectRatio,
      autoPlay: false,
      looping: false,
      showOptions: false,
      allowPlaybackSpeedChanging: false,
      placeholder: _VideoPlayerPlaceholder(coverUrl: widget.coverUrl),
      errorBuilder: (_, _) => const _VideoPlayerError(),
    );
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoUrl.trim().isEmpty) {
      return _VideoPlayerPlaceholder(coverUrl: widget.coverUrl);
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _VideoPlayerPlaceholder(coverUrl: widget.coverUrl),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
        if (snapshot.hasError || _chewieController == null) {
          return const _VideoPlayerError();
        }
        return Chewie(controller: _chewieController!);
      },
    );
  }
}

/// 播放器封面与无视频占位，颜色来自当前 Material 3 主题。
class _VideoPlayerPlaceholder extends StatelessWidget {
  const _VideoPlayerPlaceholder({required this.coverUrl});

  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (coverUrl.trim().isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: coverUrl.trim(),
            fit: BoxFit.cover,
            placeholder: (_, _) =>
                ColoredBox(color: colors.surfaceContainerHighest),
            errorWidget: (_, _, _) =>
                ColoredBox(color: colors.surfaceContainerHighest),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
          const Center(
            child: Icon(Icons.play_circle, color: Colors.white, size: 56),
          ),
        ],
      );
    }

    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, color: colors.primary, size: 52),
            const SizedBox(height: AppTheme.space8),
            Text('暂无可播放视频', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

/// 播放器错误状态，使用标准 error 语义色。
class _VideoPlayerError extends StatelessWidget {
  const _VideoPlayerError();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ColoredBox(
      color: colors.errorContainer,
      child: Center(
        child: Text(
          '视频加载失败',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

/// 缺失结果时的边界视图。
class _MissingResultView extends StatelessWidget {
  const _MissingResultView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        EmptyStatePanel(title: '暂无解析结果', description: '当前没有可展示的视频结果'),
      ],
    );
  }
}
