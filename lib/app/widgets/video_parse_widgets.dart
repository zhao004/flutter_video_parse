import 'package:dart_video_parse/dart_video_parse.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/parse_ui_models.dart';
import '../theme/app_theme.dart';
import '../utils/app_toast.dart';

/// Material 3 自适应页面内容壳。
///
/// 构建设计：紧凑窗口使用 16dp 边距，中等及以上使用 24dp；超宽窗口把
/// 内容约束在 1040dp 内，避免文本和操作区域被无意义拉伸。
class AdaptivePageShell extends StatelessWidget {
  const AdaptivePageShell({
    required this.child,
    super.key,
    this.topPadding = AppTheme.space16,
    this.bottomPadding = AppTheme.space16,
  });

  final Widget child;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding =
            constraints.maxWidth < AppTheme.compactBreakpoint
            ? AppTheme.space16
            : AppTheme.space24;
        return SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppTheme.maximumContentWidth,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 页面内分区标题，使用 Material 3 标题与正文排版层级。
class PageTitleBlock extends StatelessWidget {
  const PageTitleBlock({required this.title, super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleLarge),
        if (subtitle case final subtitle?) ...[
          const SizedBox(height: AppTheme.space4),
          Text(
            subtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// 标准分区卡片，使用 tonal surface 表达层级而不依赖阴影。
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    super.key,
    this.title,
    this.padding = const EdgeInsets.all(AppTheme.space16),
    this.color,
    this.outlined = false,
  });

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color ?? theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: outlined
            ? BorderSide(color: theme.colorScheme.outlineVariant)
            : BorderSide.none,
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title case final title?) ...[
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppTheme.space12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// 解析流程主操作，按强调级别使用 Filled 或 Filled Tonal 按钮。
class ParseActionButton extends StatelessWidget {
  const ParseActionButton({
    required this.label,
    required this.icon,
    super.key,
    this.onTap,
    this.primary = true,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabledOnTap = loading ? null : onTap;
    final iconWidget = loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon);
    final button = primary
        ? FilledButton.icon(
            onPressed: enabledOnTap,
            icon: iconWidget,
            label: Text(label),
          )
        : FilledButton.tonalIcon(
            onPressed: enabledOnTap,
            icon: iconWidget,
            label: Text(label),
          );

    return SizedBox(width: double.infinity, height: 48, child: button);
  }
}

/// Provider 选择器，使用带标签的 Material 3 表单下拉控件。
class ProviderSelector extends StatelessWidget {
  const ProviderSelector({
    required this.providers,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  static const String _automaticProviderKey = 'automatic';

  final List<ProviderInfo> providers;
  final VideoParseProvider? selected;
  final ValueChanged<VideoParseProvider?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedKey = selected?.name ?? _automaticProviderKey;
    return DropdownButtonFormField<String>(
      key: ValueKey('provider-$selectedKey'),
      initialValue: selectedKey,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '解析源',
        prefixIcon: Icon(Icons.tune),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: _automaticProviderKey,
          child: Text('自动轮询'),
        ),
        for (final provider in providers)
          DropdownMenuItem<String>(
            value: provider.provider.name,
            child: Text(
              '${provider.name} · ${provider.displayName}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value == null || value == _automaticProviderKey) {
          onChanged(null);
          return;
        }
        for (final provider in providers) {
          if (provider.provider.name == value) {
            onChanged(provider.provider);
            return;
          }
        }
        onChanged(null);
      },
    );
  }
}

/// 状态概览卡片，根据单卡可用宽度切换横向或纵向信息层级。
///
/// 构建设计：手机端三卡并排时使用紧凑纵向布局，避免数值和标签挤压；
/// 宽屏保留横向布局以提高信息密度。卡片不固定高度，以兼容系统字体缩放。
class StatusOverviewCard extends StatelessWidget {
  const StatusOverviewCard({
    required this.value,
    required this.label,
    required this.color,
    required this.softColor,
    required this.icon,
    super.key,
  });

  final int value;
  final String label;
  final Color color;
  final Color softColor;
  final IconData icon;

  static const double _horizontalLayoutBreakpoint = 180;
  static const double _compactIconRadius = 18;
  static const double _regularIconRadius = 22;
  static const double _compactIconSize = 20;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final usesHorizontalLayout =
              constraints.maxWidth >= _horizontalLayoutBreakpoint;
          final iconWidget = CircleAvatar(
            radius: usesHorizontalLayout
                ? _regularIconRadius
                : _compactIconRadius,
            backgroundColor: softColor,
            foregroundColor: color,
            child: Icon(
              icon,
              size: usesHorizontalLayout ? null : _compactIconSize,
            ),
          );
          final metrics = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: usesHorizontalLayout
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Text(
                '$value',
                textAlign: TextAlign.center,
                style: usesHorizontalLayout
                    ? textTheme.headlineSmall
                    : textTheme.titleLarge,
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          );

          return Padding(
            padding: EdgeInsets.all(
              usesHorizontalLayout ? AppTheme.space16 : AppTheme.space12,
            ),
            child: usesHorizontalLayout
                ? Row(
                    children: [
                      iconWidget,
                      const SizedBox(width: AppTheme.space12),
                      Expanded(child: metrics),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      iconWidget,
                      const SizedBox(height: AppTheme.space8),
                      metrics,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// Provider 状态列表项，仅展示名称、延迟和状态，不暴露探测网址。
class ProviderStatusTile extends StatelessWidget {
  const ProviderStatusTile({required this.data, super.key});

  final ProviderStatusViewData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _providerTone(context, data.health);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: tone.container,
          foregroundColor: tone.foreground,
          child: Icon(data.icon),
        ),
        title: Text(data.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              data.latencyLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: tone.foreground,
              ),
            ),
            Text(data.statusLabel, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// 媒体资源列表项，复制操作使用标准图标按钮并提供 Tooltip。
class MediaResourceTile extends StatelessWidget {
  const MediaResourceTile({required this.data, super.key});

  final MediaResourceViewData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        data.icon,
        color: data.highlight ? colors.primary : colors.onSurfaceVariant,
      ),
      title: Text(data.title),
      subtitle: Text(
        data.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: data.actionLabel,
        onPressed: data.url.trim().isEmpty
            ? null
            : () async {
                await Clipboard.setData(ClipboardData(text: data.url));
                AppToast.success('已复制', '${data.title}直链已复制');
              },
        icon: const Icon(Icons.content_copy_outlined),
      ),
    );
  }
}

/// 解析日志条目，选择态使用 secondary container 表达。
class ParseLogTile extends StatelessWidget {
  const ParseLogTile({
    required this.entry,
    super.key,
    this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  final ParseLogEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tone = _logTone(context, entry.level);
    return Card(
      color: selected ? colors.secondaryContainer : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? colors.secondary : colors.outlineVariant,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: tone.container,
          foregroundColor: tone.foreground,
          child: Icon(entry.icon),
        ),
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${entry.utc8DateLabel} UTC+8',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: selecting
            ? Checkbox(
                value: selected,
                onChanged: onTap == null ? null : (_) => onTap!(),
              )
            : entry.badge.isEmpty
            ? null
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Chip(
                  label: Text(entry.badge, overflow: TextOverflow.ellipsis),
                  backgroundColor: tone.container,
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color: tone.foreground,
                  ),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ),
      ),
    );
  }
}

/// 通用空状态，使用低层级 tonal surface 承接说明内容。
class EmptyStatePanel extends StatelessWidget {
  const EmptyStatePanel({
    required this.title,
    required this.description,
    super.key,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Icon(icon, size: 28),
              ),
              const SizedBox(height: AppTheme.space16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.space8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({Color foreground, Color container}) _providerTone(
  BuildContext context,
  ProviderHealth health,
) {
  final colors = Theme.of(context).colorScheme;
  final statuses = AppTheme.statusColorsOf(context);
  return switch (health) {
    ProviderHealth.available => (
      foreground: statuses.success,
      container: statuses.successContainer,
    ),
    ProviderHealth.restricted => (
      foreground: statuses.warning,
      container: statuses.warningContainer,
    ),
    ProviderHealth.unavailable => (
      foreground: colors.error,
      container: colors.errorContainer,
    ),
  };
}

({Color foreground, Color container}) _logTone(
  BuildContext context,
  ParseLogLevel level,
) {
  final colors = Theme.of(context).colorScheme;
  final statuses = AppTheme.statusColorsOf(context);
  return switch (level) {
    ParseLogLevel.success => (
      foreground: statuses.success,
      container: statuses.successContainer,
    ),
    ParseLogLevel.warning => (
      foreground: statuses.warning,
      container: statuses.warningContainer,
    ),
    ParseLogLevel.error => (
      foreground: colors.error,
      container: colors.errorContainer,
    ),
  };
}
