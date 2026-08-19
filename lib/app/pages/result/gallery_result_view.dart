import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import '../../widgets/video_parse_widgets.dart';
import '../home/home_controller.dart';

/// 图集解析结果页，使用标准 AppBar 和单一 Sliver 容器懒加载图片。
///
/// 构建设计：紧凑、中等、扩展窗口分别使用 2、3、4 列；每张图片作为
/// 独立 Card，下载按钮保持 48dp 触控目标并使用 tonal 强调。
class GalleryResultView extends GetView<HomeController> {
  const GalleryResultView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图集结果'),
        actions: [
          Obx(() {
            final images = controller.currentResult.value?.images ?? const [];
            final downloadJob = controller.galleryDownloadJob;
            final downloading = downloadJob != null;
            return IconButton(
              tooltip: downloading ? downloadJob.message : '下载全部图片',
              onPressed: images.isEmpty || downloading
                  ? null
                  : controller.downloadAllImagesToGallery,
              icon: downloading && downloadJob.progress != null
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      downloading
                          ? Icons.pause_circle_outline
                          : Icons.download_for_offline_outlined,
                    ),
            );
          }),
          const SizedBox(width: AppTheme.space4),
        ],
      ),
      body: AdaptivePageShell(
        topPadding: AppTheme.space8,
        child: Obx(() {
          final result = controller.currentResult.value;
          final images = result?.images ?? const [];
          if (result == null || images.isEmpty) {
            return ListView(
              children: const [
                EmptyStatePanel(
                  title: '暂无图集资源',
                  description: '当前解析结果没有可用图片',
                  icon: Icons.photo_library_outlined,
                ),
              ],
            );
          }

          return CustomScrollView(
            key: const Key('gallery-result-scroll-view'),
            slivers: [
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = _resolveCrossAxisCount(
                    constraints.crossAxisExtent,
                  );
                  return SliverMasonryGrid.count(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: AppTheme.space12,
                    crossAxisSpacing: AppTheme.space12,
                    childCount: images.length,
                    itemBuilder: (context, index) {
                      return _GalleryImageCard(
                        imageUrl: images[index].url,
                        index: index,
                        height: _cardHeight(index),
                        onTap: () => controller.showImagePreviewDialog(index),
                        onDownload: () => controller.downloadImageToGallery(
                          images[index].url,
                          index: index,
                        ),
                        downloading:
                            controller.imageDownloadJob(images[index].url) !=
                            null,
                      );
                    },
                  );
                },
              ),
            ],
          );
        }),
      ),
    );
  }

  static double _cardHeight(int index) {
    const heights = [176.0, 216.0, 224.0, 168.0, 184.0, 208.0];
    return heights[index % heights.length];
  }

  static int _resolveCrossAxisCount(double maxWidth) {
    if (maxWidth >= AppTheme.expandedBreakpoint) {
      return 4;
    }
    if (maxWidth >= AppTheme.compactBreakpoint) {
      return 3;
    }
    return 2;
  }
}

/// 单张图片卡片，网络图片失败时保留主题化占位并维持瀑布流尺寸。
class _GalleryImageCard extends StatelessWidget {
  const _GalleryImageCard({
    required this.imageUrl,
    required this.index,
    required this.height,
    required this.onTap,
    required this.onDownload,
    required this.downloading,
  });

  final String imageUrl;
  final int index;
  final double height;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final bool downloading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalizedImageUrl = imageUrl.trim();
    final fallback = Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: colors.onSurfaceVariant,
        size: 32,
      ),
    );
    return Card(
      color: _fallbackColor(colors, index),
      child: SizedBox(
        height: height,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (normalizedImageUrl.isEmpty)
                fallback
              else
                CachedNetworkImage(
                  imageUrl: normalizedImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  ),
                  errorWidget: (_, _, _) => fallback,
                ),
              Positioned(
                right: AppTheme.space8,
                bottom: AppTheme.space8,
                child: IconButton.filledTonal(
                  tooltip: downloading
                      ? '第 ${index + 1} 张图片正在下载'
                      : '下载第 ${index + 1} 张图片',
                  onPressed: downloading ? null : onDownload,
                  icon: downloading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _fallbackColor(ColorScheme colors, int index) {
    final candidates = [
      colors.primaryContainer,
      colors.secondaryContainer,
      colors.tertiaryContainer,
      colors.surfaceContainerHighest,
    ];
    return candidates[index % candidates.length];
  }
}
