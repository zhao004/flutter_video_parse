import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import '../../utils/app_toast.dart';
import '../../widgets/video_parse_widgets.dart';
import '../home/home_controller.dart';

/// 解析日志页，对应 Pencil 的“解析日志”画板。
class ParseLogsView extends GetView<HomeController> {
  const ParseLogsView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          controller.returnToHomeTab(2);
        }
      },
      child: Scaffold(
        body: PhonePageShell(
          child: Obx(
            () => ListView(
              children: [
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ResultTitleBar(
                        title: '解析日志',
                        onBack: () => controller.returnToHomeTab(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RoundIconButton(
                      icon: Icons.checklist,
                      semanticLabel: '多选',
                      color: AppTheme.accentPrimary,
                      backgroundColor: AppTheme.surfaceInfo,
                      onTap: () => AppToast.info('暂未启用', 'MVP 暂不支持多选操作'),
                    ),
                    const SizedBox(width: 8),
                    RoundIconButton(
                      icon: Icons.delete_sweep,
                      semanticLabel: '清空',
                      color: AppTheme.danger,
                      backgroundColor: AppTheme.dangerSoft,
                      onTap: controller.showClearCacheDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SoftPanel(
                  padding: const EdgeInsets.all(12),
                  borderColor: AppTheme.surfacePrimary,
                  child: controller.logs.isEmpty
                      ? const EmptyStatePanel(
                          title: '暂无解析日志',
                          description: '执行解析或 Provider 探测后，这里会显示最近记录',
                          icon: Icons.list_alt,
                        )
                      : Column(
                          children: [
                            for (final entry in controller.logs) ...[
                              ParseLogTile(
                                entry: entry,
                                onTap: () => controller.showLogDetail(entry),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
