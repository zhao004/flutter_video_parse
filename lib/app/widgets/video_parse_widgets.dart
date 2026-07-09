import 'package:dart_video_parse/dart_video_parse.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/parse_ui_models.dart';
import '../theme/app_theme.dart';
import '../utils/app_toast.dart';

/// 页面最大宽度容器，兼容手机画板和更宽的调试窗口。
class PhonePageShell extends StatelessWidget {
  const PhonePageShell({
    required this.child,
    super.key,
    this.includeBottomPadding = true,
  });

  final Widget child;
  final bool includeBottomPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.pageWidth),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              bottom: includeBottomPadding
                  ? AppTheme.compactBottomNavHeight
                  : 24,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Pencil 画板中的标题文案样式。
class PageTitleBlock extends StatelessWidget {
  const PageTitleBlock({required this.title, super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.foregroundPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.18,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: const TextStyle(
              color: AppTheme.foregroundSecondary,
              fontSize: 13,
              height: 1.18,
            ),
          ),
        ],
      ],
    );
  }
}

/// 统一圆角面板，承接设计稿中的浅色卡片和边框。
class SoftPanel extends StatelessWidget {
  const SoftPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(14),
    this.color = AppTheme.surfacePanel,
    this.borderColor = AppTheme.borderMuted,
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

/// 圆形图标底座，统一处理点击态和可访问语义。
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.semanticLabel,
    super.key,
    this.onTap,
    this.color = AppTheme.foregroundPrimary,
    this.backgroundColor = AppTheme.surfacePanel,
    this.size = 40,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Color color;
  final Color backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(size / 2),
            border: Border.all(color: AppTheme.borderMuted),
          ),
          child: Icon(icon, color: color, size: size * 0.54),
        ),
      ),
    );
  }
}

/// 设计稿中的主按钮/次按钮，提供加载态与禁用态。
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
    final foreground = primary
        ? AppTheme.foregroundInverse
        : AppTheme.accentPrimary;
    final background = primary
        ? AppTheme.accentPrimary
        : AppTheme.surfacePrimary;
    final borderColor = primary ? AppTheme.accentPrimary : AppTheme.borderMuted;

    return SizedBox(
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: loading ? null : onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: onTap == null
                  ? background.withValues(alpha: 0.62)
                  : background,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else
                  Icon(icon, color: foreground, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
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

/// 首页底部导航，保持 Pencil 中悬浮胶囊形态。
class FloatingBottomTabs extends StatelessWidget {
  const FloatingBottomTabs({
    required this.currentIndex,
    required this.onChanged,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.link, '解析'),
    (Icons.query_stats, '状态'),
    (Icons.settings_outlined, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 18,
      right: 18,
      bottom: 14,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 354),
          child: Container(
            height: 56,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppTheme.surfacePrimary.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.borderSoft),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  offset: Offset(0, 8),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(
              children: [
                for (var index = 0; index < _items.length; index++)
                  Expanded(
                    child: _BottomTabItem(
                      icon: _items[index].$1,
                      label: _items[index].$2,
                      selected: index == currentIndex,
                      onTap: index == currentIndex
                          ? null
                          : () => onChanged(index),
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

class _BottomTabItem extends StatelessWidget {
  const _BottomTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppTheme.accentPrimary
        : AppTheme.foregroundSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? AppTheme.surfaceChip : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Provider 下拉项，过滤非法空列表场景。
class ProviderSelector extends StatelessWidget {
  const ProviderSelector({
    required this.providers,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<ProviderInfo> providers;
  final VideoParseProvider? selected;
  final ValueChanged<VideoParseProvider?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppTheme.borderMuted),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune, color: AppTheme.accentPrimary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<VideoParseProvider?>(
                value: selected,
                isExpanded: true,
                isDense: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppTheme.accentPrimary,
                  size: 20,
                ),
                selectedItemBuilder: (_) => [
                  const _ProviderSelectedText(title: '自动轮询'),
                  for (final provider in providers)
                    _ProviderSelectedText(title: provider.name),
                ],
                items: [
                  const DropdownMenuItem<VideoParseProvider?>(
                    value: null,
                    child: _ProviderOptionText(
                      title: '自动轮询',
                      subtitle: '按优先级自动选择解析源',
                    ),
                  ),
                  for (final provider in providers)
                    DropdownMenuItem<VideoParseProvider?>(
                      value: provider.provider,
                      child: _ProviderOptionText(
                        title: provider.name,
                        subtitle: provider.displayName,
                      ),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderSelectedText extends StatelessWidget {
  const _ProviderSelectedText({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.foregroundPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

class _ProviderOptionText extends StatelessWidget {
  const _ProviderOptionText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.foregroundPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        Text(
          subtitle,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.foregroundMuted,
            fontSize: 10,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

/// 状态概览卡片。
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

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SoftPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: softColor,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 7),
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.foregroundMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Provider 状态列表项。
class ProviderStatusTile extends StatelessWidget {
  const ProviderStatusTile({required this.data, super.key});

  final ProviderStatusViewData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.softColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                data.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.foregroundPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.latencyLabel,
                style: TextStyle(
                  color: data.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                data.statusLabel,
                style: const TextStyle(
                  color: AppTheme.foregroundMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 资源列表项，负责复制直链的基础交互。
class MediaResourceTile extends StatelessWidget {
  const MediaResourceTile({required this.data, super.key});

  final MediaResourceViewData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.highlight
                  ? AppTheme.successSoft
                  : AppTheme.surfacePrimary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              data.icon,
              color: data.highlight
                  ? AppTheme.success
                  : AppTheme.foregroundMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.foregroundPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  data.description,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.foregroundMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: data.url.trim().isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: data.url));
                    AppToast.success('已复制', '${data.title}直链已复制');
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: data.highlight
                    ? AppTheme.successSoft
                    : AppTheme.surfacePrimary,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                data.actionLabel,
                style: TextStyle(
                  color: data.highlight
                      ? AppTheme.success
                      : AppTheme.foregroundMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 解析日志条目。
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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.surfaceInfo : AppTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.accentPrimary : AppTheme.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: entry.softColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(entry.icon, color: entry.color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.foregroundPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    entry.description,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.foregroundMuted,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '解析日期：${entry.utc8DateLabel} UTC+8',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.foregroundMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (selecting) ...[
              const SizedBox(width: 10),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected
                    ? AppTheme.accentPrimary
                    : AppTheme.foregroundMuted,
                size: 22,
              ),
            ] else if (entry.badge.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: entry.softColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  entry.badge,
                  style: TextStyle(
                    color: entry.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 标准结果页标题栏。
class ResultTitleBar extends StatelessWidget {
  const ResultTitleBar({
    required this.title,
    super.key,
    this.trailing,
    this.onBack,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;

    return Row(
      children: [
        RoundIconButton(
          icon: Icons.arrow_back,
          semanticLabel: '返回',
          onTap: onBack ?? Get.back<void>,
        ),
        const SizedBox(width: 10),
        Expanded(child: PageTitleBlock(title: title)),
        ?trailing,
      ],
    );
  }
}

/// 通用空状态，处理无结果和异常边界。
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
    return SoftPanel(
      color: AppTheme.surfaceInfo,
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.accentPrimary, size: 42),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.foregroundPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.foregroundMuted,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
