import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import '../../widgets/video_parse_widgets.dart';
import 'home_controller.dart';

/// 应用主页面，对应 Pencil 的“解析首页 / 解析源状态 / 设置关于”三张画板。
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: !controller.showingLogsPanel.value,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            controller.handleLogsBack();
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              IndexedStack(
                index: controller.currentTabIndex.value,
                children: const [
                  _ParseHomeTab(),
                  _ProviderStatusTab(),
                  _SettingsAboutTab(),
                ],
              ),
              if (controller.showingLogsPanel.value) const _ParseLogsPanel(),
              if (!controller.showingLogsPanel.value)
                FloatingBottomTabs(
                  currentIndex: controller.currentTabIndex.value,
                  onChanged: controller.switchTab,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParseLogsPanel extends GetView<HomeController> {
  const _ParseLogsPanel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonePageShell(
        child: Obx(
          () => ListView(
            children: [
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ResultTitleBar(
                      title: controller.selectingLogs.value
                          ? '已选 ${controller.selectedLogs.length} 条'
                          : '解析日志',
                      onBack: controller.handleLogsBack,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (controller.selectingLogs.value)
                    RoundIconButton(
                      icon:
                          controller.logs.isNotEmpty &&
                              controller.selectedLogs.length ==
                                  controller.logs.length
                          ? Icons.deselect
                          : Icons.select_all,
                      semanticLabel: '全选',
                      color: AppTheme.accentPrimary,
                      backgroundColor: AppTheme.surfaceInfo,
                      onTap: controller.toggleAllLogSelection,
                    )
                  else
                    RoundIconButton(
                      icon: Icons.checklist,
                      semanticLabel: '多选',
                      color: AppTheme.accentPrimary,
                      backgroundColor: AppTheme.surfaceInfo,
                      onTap: controller.enterLogSelectionMode,
                    ),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: controller.selectingLogs.value
                        ? Icons.delete_outline
                        : Icons.delete_sweep,
                    semanticLabel: controller.selectingLogs.value
                        ? '删除所选'
                        : '清空',
                    color: AppTheme.danger,
                    backgroundColor: AppTheme.dangerSoft,
                    onTap: controller.selectingLogs.value
                        ? controller.confirmDeleteSelectedLogs
                        : controller.showClearCacheDialog,
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
                              selecting: controller.selectingLogs.value,
                              selected: controller.isLogSelected(entry),
                              onTap: () {
                                if (controller.selectingLogs.value) {
                                  controller.toggleLogSelection(entry);
                                  return;
                                }
                                controller.showLogDetail(entry);
                              },
                              onLongPress: () =>
                                  controller.selectLogEntry(entry),
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
    );
  }
}

class _ParseHomeTab extends GetView<HomeController> {
  const _ParseHomeTab();

  @override
  Widget build(BuildContext context) {
    return PhonePageShell(
      child: ListView(
        children: [
          const SizedBox(height: 18),
          const PageTitleBlock(title: '视频解析', subtitle: '粘贴分享链接，自动识别视频或图集结果'),
          const SizedBox(height: 18),
          SoftPanel(
            color: AppTheme.surfaceInfo,
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const Row(
                  children: [
                    _FlowIcon(),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '解析流程',
                            style: TextStyle(
                              color: AppTheme.foregroundPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '选择解析源后粘贴链接，成功后进入对应结果页',
                            style: TextStyle(
                              color: AppTheme.foregroundMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Obx(
                  () => ProviderSelector(
                    providers: controller.providers,
                    selected: controller.selectedProvider.value,
                    onChanged: (value) =>
                        controller.selectedProvider.value = value,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('parse_link_input'),
                  controller: controller.linkController,
                  minLines: 3,
                  maxLines: 5,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(hintText: '请输入短视频链接'),
                ),
                const SizedBox(height: 16),
                Obx(() {
                  final hasLinkInput = controller.hasLinkInput.value;
                  return ParseActionButton(
                    label: hasLinkInput ? '清空编辑框' : '粘贴内容',
                    icon: hasLinkInput
                        ? Icons.cleaning_services_outlined
                        : Icons.content_paste,
                    primary: false,
                    onTap: controller.pasteOrClearLinkInput,
                  );
                }),
                const SizedBox(height: 10),
                Obx(
                  () => ParseActionButton(
                    label: controller.parseState.value.isLoading
                        ? '解析中'
                        : '立即解析',
                    icon: Icons.bolt,
                    loading: controller.parseState.value.isLoading,
                    onTap: controller.parseCurrentInput,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowIcon extends StatelessWidget {
  const _FlowIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderMuted),
      ),
      child: const Icon(Icons.bolt, color: AppTheme.accentPrimary, size: 18),
    );
  }
}

class _ProviderStatusTab extends GetView<HomeController> {
  const _ProviderStatusTab();

  @override
  Widget build(BuildContext context) {
    return PhonePageShell(
      child: ListView(
        children: [
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: PageTitleBlock(title: '解析源状态')),
              Obx(
                () => RoundIconButton(
                  icon: controller.probingProviders.value
                      ? Icons.hourglass_top
                      : Icons.sync,
                  semanticLabel: '重新探测',
                  color: AppTheme.accentPrimary,
                  backgroundColor: AppTheme.surfaceChip,
                  onTap: controller.refreshProviderStatuses,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() {
            final statuses = controller.providerStatuses;
            final available = statuses.where((item) => item.available).length;
            final blocked = statuses.where((item) {
              return !item.available && item.statusLabel == '受限';
            }).length;
            final failed = statuses.length - available - blocked;
            return Row(
              children: [
                StatusOverviewCard(
                  value: available,
                  label: '可用解析源',
                  color: AppTheme.success,
                  softColor: AppTheme.successSoft,
                  icon: Icons.check,
                ),
                const SizedBox(width: 8),
                StatusOverviewCard(
                  value: failed,
                  label: '异常需关注',
                  color: AppTheme.danger,
                  softColor: AppTheme.dangerSoft,
                  icon: Icons.close,
                ),
                const SizedBox(width: 8),
                StatusOverviewCard(
                  value: blocked,
                  label: '受限或限流',
                  color: AppTheme.warning,
                  softColor: AppTheme.warningSoft,
                  icon: Icons.priority_high,
                ),
              ],
            );
          }),
          const SizedBox(height: 10),
          SoftPanel(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Provider 状态',
                            style: TextStyle(
                              color: AppTheme.foregroundPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '按最近一次探测结果排序',
                            style: TextStyle(
                              color: AppTheme.foregroundMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(
                      () => Chip(
                        label: Text('${controller.providers.length} 个源'),
                        backgroundColor: AppTheme.surfaceInfo,
                        side: const BorderSide(color: AppTheme.borderMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Obx(() {
                  if (controller.providerStatuses.isEmpty) {
                    return const EmptyStatePanel(
                      title: '暂无探测数据',
                      description: '点击右上角按钮重新探测解析源状态',
                      icon: Icons.query_stats,
                    );
                  }
                  return Column(
                    children: [
                      for (final item in controller.providerStatuses) ...[
                        ProviderStatusTile(data: item),
                        const SizedBox(height: 6),
                      ],
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsAboutTab extends GetView<HomeController> {
  const _SettingsAboutTab();

  @override
  Widget build(BuildContext context) {
    return PhonePageShell(
      child: ListView(
        children: [
          const SizedBox(height: 18),
          const PageTitleBlock(title: '设置关于', subtitle: '解析日志和本地缓存管理'),
          const SizedBox(height: 14),
          SoftPanel(
            color: AppTheme.surfaceInfo,
            radius: 28,
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 14,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 34,
                    height: 34,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video Parse',
                        style: TextStyle(
                          color: AppTheme.foregroundPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Obx(() {
                        return _VersionCircleBadge(
                          version: controller.version.value,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftPanel(
            padding: const EdgeInsets.all(12),
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '功能导航',
                  style: TextStyle(
                    color: AppTheme.foregroundPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsTile(
                  icon: Icons.list_alt,
                  title: '解析日志',
                  subtitle: '查看最近解析、校验和上游错误',
                  onTap: controller.openLogsPanel,
                ),
                const SizedBox(height: 10),
                Obx(
                  () => _SettingsTile(
                    icon: Icons.delete_sweep_outlined,
                    title: '清空缓存',
                    subtitle: '清理 SQLite 解析日志和临时状态',
                    trailingText: controller.cacheSizeLabel,
                    danger: true,
                    onTap: controller.showClearCacheDialog,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionCircleBadge extends StatelessWidget {
  const _VersionCircleBadge({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '版本 $version',
      child: Chip(
        label: Text("$version v"),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppTheme.borderMuted),
          borderRadius: BorderRadius.circular(23),
        ),
        visualDensity: VisualDensity.compact,
        backgroundColor: AppTheme.surfaceChip,
        side: const BorderSide(color: AppTheme.borderMuted),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.trailingText = '',
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  final String trailingText;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.danger : AppTheme.accentPrimary;
    final softColor = danger ? AppTheme.dangerSoft : AppTheme.surfaceChip;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: softColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.foregroundPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.foregroundMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingText.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                trailingText,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_right,
              color: AppTheme.foregroundMuted,
            ),
          ],
        ),
      ),
    );
  }
}
