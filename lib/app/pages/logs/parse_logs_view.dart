import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import '../../widgets/video_parse_widgets.dart';
import '../home/home_controller.dart';

/// 独立解析日志页，使用标准 AppBar 和 Material 3 日志列表。
class ParseLogsView extends GetView<HomeController> {
  const ParseLogsView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Obx(() {
        final selecting = controller.selectingLogs.value;
        return Scaffold(
          appBar: AppBar(
            leading: selecting
                ? IconButton(
                    tooltip: '退出多选',
                    onPressed: controller.cancelLogSelection,
                    icon: const Icon(Icons.close),
                  )
                : BackButton(onPressed: _handleBack),
            title: Text(
              selecting ? '已选 ${controller.selectedLogs.length} 条' : '解析日志',
            ),
            actions: _buildActions(),
          ),
          body: AdaptivePageShell(child: _buildLogList(selecting)),
        );
      }),
    );
  }

  /// 构建日志内容，选择态下点击条目只切换勾选，不打开详情弹窗。
  Widget _buildLogList(bool selecting) {
    if (controller.logs.isEmpty) {
      return ListView(
        children: const [
          EmptyStatePanel(
            title: '暂无解析日志',
            description: '当前没有可展示的记录',
            icon: Icons.receipt_long_outlined,
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: controller.logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.space8),
      itemBuilder: (context, index) {
        final entry = controller.logs[index];
        return ParseLogTile(
          entry: entry,
          selecting: selecting,
          selected: controller.isLogSelected(entry),
          onTap: () {
            if (selecting) {
              controller.toggleLogSelection(entry);
              return;
            }
            controller.showLogDetail(entry);
          },
          onLongPress: () => controller.selectLogEntry(entry),
        );
      },
    );
  }

  /// 根据选择态提供标准上下文操作，空列表边界由控制器统一反馈。
  List<Widget> _buildActions() {
    if (controller.selectingLogs.value) {
      final allSelected =
          controller.logs.isNotEmpty &&
          controller.selectedLogs.length == controller.logs.length;
      return [
        IconButton(
          tooltip: allSelected ? '取消全选' : '全选',
          onPressed: controller.toggleAllLogSelection,
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
        ),
        IconButton(
          tooltip: '删除所选',
          onPressed: controller.confirmDeleteSelectedLogs,
          icon: const Icon(Icons.delete_outline),
        ),
        const SizedBox(width: AppTheme.space4),
      ];
    }

    return [
      IconButton(
        key: const Key('log-multi-select-button'),
        tooltip: '多选',
        onPressed: controller.enterLogSelectionMode,
        icon: const Icon(Icons.checklist),
      ),
      const SizedBox(width: AppTheme.space4),
    ];
  }

  /// 返回时优先退出上下文选择，避免误丢失当前日志页位置。
  void _handleBack() {
    if (controller.selectingLogs.value) {
      controller.cancelLogSelection();
      return;
    }
    controller.returnToHomeTab(2);
  }
}
