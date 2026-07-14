import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import '../../widgets/video_parse_widgets.dart';
import '../home/home_controller.dart';

/// 图集解析结果页，使用单一 Sliver 滚动容器按可视区域懒加载图片。
///
/// 构建设计：标题放入 [SliverToBoxAdapter]，瀑布流使用
/// [SliverMasonryGrid]，避免嵌套 `shrinkWrap` 网格一次创建整个图集。
class GalleryResultView extends GetView<HomeController> {
  const GalleryResultView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonePageShell(
        includeBottomPadding: false,
        child: Obx(() {
          final result = controller.currentResult.value;
          final images = result?.images ?? const [];
          if (result == null || images.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 18),
                ResultTitleBar(title: '图集结果'),
                SizedBox(height: 16),
                EmptyStatePanel(
                  title: '暂无图集资源',
                  description: '解析结果没有返回图片直链，或当前结果已经被清空',
                  icon: Icons.photo_library_outlined,
                ),
              ],
            );
          }

          return CustomScrollView(
            key: const Key('gallery-result-scroll-view'),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    ResultTitleBar(
                      title: '图集结果',
                      trailing: RoundIconButton(
                        icon: Icons.download,
                        semanticLabel: '批量下载',
                        color: AppTheme.accentPrimary,
                        backgroundColor: AppTheme.surfaceInfo,
                        onTap: controller.downloadAllImagesToGallery,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(4),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = _resolveCrossAxisCount(
                      constraints.crossAxisExtent,
                    );
                    return SliverMasonryGrid.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
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
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  static double _cardHeight(int index) {
    const heights = [166.0, 204.0, 214.0, 158.0, 154.0, 194.0];
    return heights[index % heights.length];
  }

  static int _resolveCrossAxisCount(double maxWidth) {
    if (maxWidth >= 520) {
      return 3;
    }
    return 2;
  }
}

/// 单张图集卡片，以固定高度稳定瀑布流布局，并在右下角提供下载操作。
class _GalleryImageCard extends StatelessWidget {
  const _GalleryImageCard({
    required this.imageUrl,
    required this.index,
    required this.height,
    required this.onTap,
    required this.onDownload,
  });

  final String imageUrl;
  final int index;
  final double height;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        color: _fallbackColor(index),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: _GalleryIconButton(
                icon: Icons.download,
                semanticLabel: '下载第 ${index + 1} 张图片',
                onTap: onDownload,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _fallbackColor(int index) {
    const colors = [
      Color(0xFFCFE7F1),
      Color(0xFFDDECCB),
      Color(0xFFE8DCC4),
      Color(0xFFF0D1C9),
      Color(0xFFDCE4E8),
      Color(0xFFD8E0F5),
    ];
    return colors[index % colors.length];
  }
}

/// 图集卡片内的紧凑下载按钮，提供独立的无障碍语义。
class _GalleryIconButton extends StatelessWidget {
  const _GalleryIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppTheme.surfacePrimary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, color: AppTheme.accentPrimary, size: 18),
          ),
        ),
      ),
    );
  }
}
