import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../theme/app_theme.dart';
import '../../widgets/video_parse_widgets.dart';
import '../home/home_controller.dart';

/// 视频解析结果页，对应 Pencil 的“视频结果”画板。
class VideoResultView extends GetView<HomeController> {
  const VideoResultView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonePageShell(
        includeBottomPadding: false,
        child: Obx(() {
          final result = controller.currentResult.value;
          if (result == null) {
            return const _MissingResultView(title: '视频结果');
          }

          final resources = controller.videoResources;
          final videoUrl = controller.primaryVideoUrl;
          final downloading = controller.downloadingMedia.value;
          final progress = controller.downloadProgress.value;
          return ListView(
            children: [
              const SizedBox(height: 18),
              const ResultTitleBar(title: '视频结果'),
              const SizedBox(height: 12),
              SoftPanel(
                color: AppTheme.surfaceInfo,
                radius: 24,
                padding: const EdgeInsets.all(12),
                child: AspectRatio(
                  aspectRatio: 1.72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _ChewieVideoPlayer(
                      key: ValueKey(videoUrl),
                      videoUrl: videoUrl,
                      coverUrl: result.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SoftPanel(
                radius: 20,
                padding: const EdgeInsets.all(14),
                child: Text(
                  result.title.trim().isEmpty ? '未命名视频' : result.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.foregroundPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SoftPanel(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '资源列表',
                          style: TextStyle(
                            color: AppTheme.foregroundPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '复制链接',
                          style: TextStyle(
                            color: AppTheme.accentPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (resources.isEmpty)
                      const EmptyStatePanel(
                        title: '没有可用资源',
                        description: '解析结果缺少可复制的视频或封面直链',
                      )
                    else
                      for (final resource in resources) ...[
                        MediaResourceTile(data: resource),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ParseActionButton(
                label: downloading
                    ? progress > 0
                          ? '下载中 ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%'
                          : '下载中'
                    : '下载视频',
                icon: Icons.download,
                loading: downloading,
                onTap: downloading
                    ? null
                    : controller.downloadPrimaryVideoToGallery,
              ),
            ],
          );
        }),
      ),
    );
  }
}

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
    if (url.isEmpty || uri == null || !uri.hasScheme) {
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
      materialProgressColors: ChewieProgressColors(
        playedColor: AppTheme.accentPrimary,
        handleColor: AppTheme.accentPrimary,
        backgroundColor: AppTheme.borderMuted,
        bufferedColor: AppTheme.surfaceInfo,
      ),
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

class _VideoPlayerPlaceholder extends StatelessWidget {
  const _VideoPlayerPlaceholder({required this.coverUrl});

  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    if (coverUrl.trim().isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            coverUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFFDDEBF3)),
          ),
          const ColoredBox(color: Color(0x55000000)),
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: AppTheme.foregroundInverse,
              size: 56,
            ),
          ),
        ],
      );
    }

    return const ColoredBox(
      color: Color(0xFFDDEBF3),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              color: AppTheme.accentPrimary,
              size: 52,
            ),
            SizedBox(height: 8),
            Text(
              '暂无可播放视频',
              style: TextStyle(
                color: AppTheme.foregroundPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlayerError extends StatelessWidget {
  const _VideoPlayerError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFDDEBF3),
      child: Center(
        child: Text(
          '视频加载失败',
          style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _MissingResultView extends StatelessWidget {
  const _MissingResultView({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 18),
        ResultTitleBar(title: title),
        const SizedBox(height: 16),
        const EmptyStatePanel(
          title: '暂无解析结果',
          description: '请返回首页粘贴链接并完成解析后再查看结果页',
        ),
      ],
    );
  }
}
