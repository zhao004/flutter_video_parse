import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/parse_ui_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/video_parse_widgets.dart';
import 'home_controller.dart';

/// 应用主页面，按窗口宽度在 NavigationBar 与 NavigationRail 之间切换。
///
/// 构建设计：紧凑窗口保留底部三目的地导航；600dp 以上改为侧边 Rail，
/// 840dp 以上展开标签。日志属于设置下的二级视图，因此进入后隐藏主导航。
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  static const _navigationItems = [
    _NavigationItem(
      label: '解析',
      icon: Icons.link_outlined,
      selectedIcon: Icons.link,
    ),
    _NavigationItem(
      label: '状态',
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
    ),
    _NavigationItem(
      label: '设置',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppTheme.compactBreakpoint;
        final extendedRail =
            constraints.maxWidth >= AppTheme.expandedBreakpoint;
        return Obx(() {
          final showingLogs = controller.showingLogsPanel.value;
          final selectedIndex = controller.currentTabIndex.value;
          final selectingLogs = controller.selectingLogs.value;
          final content = showingLogs
              ? _ParseLogsPanel(selecting: selectingLogs)
              : IndexedStack(
                  index: selectedIndex,
                  children: const [
                    _ParseHomeTab(),
                    _ProviderStatusTab(),
                    _SettingsAboutTab(),
                  ],
                );

          return PopScope(
            canPop: !showingLogs,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                controller.handleLogsBack();
              }
            },
            child: Scaffold(
              appBar: AppBar(
                leading: showingLogs
                    ? BackButton(onPressed: controller.handleLogsBack)
                    : null,
                title: Text(_pageTitle(showingLogs, selectedIndex)),
                actions: _appBarActions(showingLogs, selectedIndex),
              ),
              body: Row(
                children: [
                  if (!compact && !showingLogs) ...[
                    NavigationRail(
                      selectedIndex: selectedIndex,
                      extended: extendedRail,
                      labelType: extendedRail
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      onDestinationSelected: controller.switchTab,
                      destinations: [
                        for (final item in _navigationItems)
                          NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(item.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                  ],
                  Expanded(child: content),
                ],
              ),
              bottomNavigationBar: compact && !showingLogs
                  ? NavigationBar(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: controller.switchTab,
                      destinations: [
                        for (final item in _navigationItems)
                          NavigationDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: item.label,
                          ),
                      ],
                    )
                  : null,
            ),
          );
        });
      },
    );
  }

  String _pageTitle(bool showingLogs, int selectedIndex) {
    if (showingLogs) {
      return controller.selectingLogs.value
          ? '已选 ${controller.selectedLogs.length} 条'
          : '解析日志';
    }
    return switch (selectedIndex) {
      1 => '解析源状态',
      2 => '设置',
      _ => '视频解析',
    };
  }

  List<Widget> _appBarActions(bool showingLogs, int selectedIndex) {
    if (showingLogs) {
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

    if (selectedIndex == 1) {
      final probing = controller.probingProviders.value;
      return [
        IconButton(
          tooltip: probing ? '正在探测' : '重新探测',
          onPressed: probing ? null : controller.refreshProviderStatuses,
          icon: probing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
        const SizedBox(width: AppTheme.space4),
      ];
    }
    return const [SizedBox(width: AppTheme.space8)];
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// 首页解析表单，使用单一 Card 聚合相关输入和操作。
class _ParseHomeTab extends GetView<HomeController> {
  const _ParseHomeTab();

  @override
  Widget build(BuildContext context) {
    return AdaptivePageShell(
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          SectionCard(
            child: Column(
              children: [
                Obx(
                  () => ProviderSelector(
                    providers: controller.providers,
                    selected: controller.selectedProvider.value,
                    onChanged: (value) =>
                        controller.selectedProvider.value = value,
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                TextField(
                  key: const Key('parse_link_input'),
                  controller: controller.linkController,
                  minLines: 3,
                  maxLines: 5,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.url],
                  decoration: const InputDecoration(
                    hintText: '请输入短视频链接',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackActions = constraints.maxWidth < 480;
                    final pasteButton = Obx(() {
                      final hasInput = controller.hasLinkInput.value;
                      return ParseActionButton(
                        label: hasInput ? '清空' : '粘贴',
                        icon: hasInput
                            ? Icons.clear
                            : Icons.content_paste_outlined,
                        primary: false,
                        onTap: controller.pasteOrClearLinkInput,
                      );
                    });
                    final parseButton = Obx(() {
                      final loading = controller.parseState.value.isLoading;
                      return ParseActionButton(
                        label: loading ? '解析中' : '开始解析',
                        icon: Icons.auto_awesome,
                        loading: loading,
                        onTap: controller.parseCurrentInput,
                      );
                    });

                    if (stackActions) {
                      return Column(
                        children: [
                          pasteButton,
                          const SizedBox(height: AppTheme.space8),
                          parseButton,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: pasteButton),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(child: parseButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Provider 状态页，概览卡片和列表均按可用宽度自适应。
class _ProviderStatusTab extends GetView<HomeController> {
  const _ProviderStatusTab();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statuses = AppTheme.statusColorsOf(context);
    return AdaptivePageShell(
      child: ListView(
        children: [
          const PageTitleBlock(title: '服务概览'),
          const SizedBox(height: AppTheme.space12),
          Obx(() {
            final providerStatuses = controller.providerStatuses;
            final available = providerStatuses
                .where((item) => item.health == ProviderHealth.available)
                .length;
            final restricted = providerStatuses
                .where((item) => item.health == ProviderHealth.restricted)
                .length;
            final unavailable =
                providerStatuses.length - available - restricted;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatusOverviewCard(
                    value: available,
                    label: '可用',
                    color: statuses.success,
                    softColor: statuses.successContainer,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: StatusOverviewCard(
                    value: restricted,
                    label: '受限',
                    color: statuses.warning,
                    softColor: statuses.warningContainer,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: StatusOverviewCard(
                    value: unavailable,
                    label: '异常',
                    color: colors.error,
                    softColor: colors.errorContainer,
                    icon: Icons.error_outline,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: AppTheme.space24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Provider',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Obx(() => Chip(label: Text('${controller.providers.length} 个源'))),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Obx(() {
            if (controller.providerStatuses.isEmpty) {
              return const EmptyStatePanel(
                title: '暂无探测数据',
                description: '当前没有可展示的 Provider 状态',
                icon: Icons.monitor_heart_outlined,
              );
            }
            return Column(
              children: [
                for (
                  var index = 0;
                  index < controller.providerStatuses.length;
                  index++
                ) ...[
                  ProviderStatusTile(data: controller.providerStatuses[index]),
                  if (index < controller.providerStatuses.length - 1)
                    const SizedBox(height: AppTheme.space8),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// 设置页使用标准列表分组呈现应用信息和数据操作。
class _SettingsAboutTab extends GetView<HomeController> {
  const _SettingsAboutTab();

  static const double _maximumSettingsContentWidth = 720;

  @override
  Widget build(BuildContext context) {
    return AdaptivePageShell(
      child: ListView(
        key: const Key('settings-page'),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _maximumSettingsContentWidth,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PageTitleBlock(title: '数据与记录'),
                      const SizedBox(height: AppTheme.space12),
                      Obx(
                        () => _SettingsTile(
                          key: const Key('settings-logs-action'),
                          icon: Icons.receipt_long_outlined,
                          title: '解析日志',
                          subtitle: '${controller.logs.length} 条记录',
                          onTap: controller.openLogsPanel,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space8),
                      Obx(
                        () => _SettingsTile(
                          key: const Key('settings-downloads-action'),
                          icon: Icons.download_for_offline_outlined,
                          title: '下载管理',
                          subtitle: controller.downloadTaskSubtitle,
                          onTap: controller.openDownloadManagement,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space8),
                      Obx(
                        () => _SettingsTile(
                          key: const Key('settings-clear-action'),
                          icon: Icons.cleaning_services_outlined,
                          title: '清空缓存',
                          subtitle: controller.mediaCacheSubtitle,
                          onTap: controller.showClearMediaCacheDialog,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space24),
                      const PageTitleBlock(title: '关于'),
                      const SizedBox(height: AppTheme.space12),
                      Obx(
                        () => _SettingsTile(
                          key: const Key('settings-version-item'),
                          icon: Icons.info_outline,
                          title: '应用版本',
                          subtitle: _versionSubtitle(controller.version.value),
                          showChevron: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _versionSubtitle(String version) {
    final normalizedVersion = version.trim();
    return normalizedVersion.isEmpty ? '正在读取版本信息' : '当前版本 $normalizedVersion';
  }
}

/// 首页内日志二级视图，列表项支持点击详情和长按进入多选。
class _ParseLogsPanel extends GetView<HomeController> {
  const _ParseLogsPanel({required this.selecting});

  final bool selecting;

  @override
  Widget build(BuildContext context) {
    return AdaptivePageShell(
      child: Obx(() {
        if (controller.logs.isEmpty) {
          return ListView(
            children: const [
              EmptyStatePanel(
                title: '暂无解析日志',
                description: '完成解析或 Provider 探测后会生成记录',
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
      }),
    );
  }
}

/// 参考系统设置页的独立双行设置项，使用 tonal surface 和大圆角分隔操作。
///
/// 构建设计：交互项显示末端箭头，纯信息项隐藏箭头；副标题始终保持
/// 低强调层级，避免与可执行操作名称竞争。
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
    this.onTap,
    this.showChevron = true,
  });

  static const double _cornerRadius = 20;

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cornerRadius),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space8,
        ),
        leading: Icon(icon, color: colors.onSurface),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(color: colors.onSurface),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        trailing: showChevron
            ? Icon(Icons.chevron_right, color: colors.onSurfaceVariant)
            : null,
      ),
    );
  }
}
