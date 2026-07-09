import 'package:dart_video_parse/dart_video_parse.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 页面解析状态，避免界面直接依赖网络请求细节。
enum ParseUiStatus { idle, loading, success, error }

/// 统一的解析状态容器。
///
/// 异常策略：错误信息被压缩为可展示文案，底层异常只记录到日志，避免界面
/// 直接暴露堆栈或网络实现细节。
class ParseUiState {
  const ParseUiState({required this.status, this.message = ''});

  final ParseUiStatus status;
  final String message;

  bool get isLoading => status == ParseUiStatus.loading;

  static const idle = ParseUiState(status: ParseUiStatus.idle);
  static const loading = ParseUiState(status: ParseUiStatus.loading);
  static const success = ParseUiState(status: ParseUiStatus.success);

  factory ParseUiState.error(String message) {
    return ParseUiState(status: ParseUiStatus.error, message: message);
  }
}

/// 日志级别，决定图标、颜色和展示优先级。
enum ParseLogLevel { success, warning, error }

/// 解析日志项。
///
/// 设计取舍：界面层只依赖该模型，不直接暴露 Drift 生成类，避免数据库
/// 字段调整影响页面组件和选择逻辑。
class ParseLogEntry {
  const ParseLogEntry({
    required this.createdAt,
    required this.level,
    required this.title,
    required this.description,
    this.id,
    this.source = '',
    this.badge = '',
  });

  final int? id;
  final DateTime createdAt;
  final ParseLogLevel level;
  final String title;
  final String description;
  final String source;
  final String badge;

  /// UTC+8 解析日期，用于日志列表直接展示。
  ///
  /// 边界处理：数据库统一保存 UTC 时间，展示时固定转为东八区，避免设备
  /// 本地时区变化导致同一条日志显示日期漂移。
  String get utc8DateLabel {
    final utcTime = createdAt.toUtc();
    final utc8Time = utcTime.add(const Duration(hours: 8));
    return '${utc8Time.year.toString().padLeft(4, '0')}-'
        '${utc8Time.month.toString().padLeft(2, '0')}-'
        '${utc8Time.day.toString().padLeft(2, '0')} '
        '${utc8Time.hour.toString().padLeft(2, '0')}:'
        '${utc8Time.minute.toString().padLeft(2, '0')}';
  }

  Color get color => switch (level) {
    ParseLogLevel.success => AppTheme.success,
    ParseLogLevel.warning => AppTheme.warning,
    ParseLogLevel.error => AppTheme.danger,
  };

  Color get softColor => switch (level) {
    ParseLogLevel.success => AppTheme.successSoft,
    ParseLogLevel.warning => AppTheme.warningSoft,
    ParseLogLevel.error => AppTheme.dangerSoft,
  };

  IconData get icon => switch (level) {
    ParseLogLevel.success => Icons.check_circle_outline,
    ParseLogLevel.warning => Icons.rule,
    ParseLogLevel.error => Icons.error_outline,
  };
}

/// 结果页中的可操作媒体资源。
class MediaResourceViewData {
  const MediaResourceViewData({
    required this.title,
    required this.description,
    required this.url,
    required this.icon,
    required this.actionLabel,
    this.highlight = false,
  });

  final String title;
  final String description;
  final String url;
  final IconData icon;
  final String actionLabel;
  final bool highlight;
}

/// Provider 状态的界面映射结果。
class ProviderStatusViewData {
  const ProviderStatusViewData({
    required this.name,
    required this.probeUrl,
    required this.statusLabel,
    required this.latencyLabel,
    required this.color,
    required this.softColor,
    required this.icon,
    required this.available,
  });

  final String name;
  final String probeUrl;
  final String statusLabel;
  final String latencyLabel;
  final Color color;
  final Color softColor;
  final IconData icon;
  final bool available;

  factory ProviderStatusViewData.fromStatus(ProviderStatus status) {
    if (status.available) {
      return ProviderStatusViewData(
        name: status.name,
        probeUrl: status.probeUrl,
        statusLabel: '可用',
        latencyLabel: '${status.latencyMs ?? 0}ms',
        color: AppTheme.success,
        softColor: AppTheme.successSoft,
        icon: Icons.check_circle_outline,
        available: true,
      );
    }

    if (status.reachable) {
      return ProviderStatusViewData(
        name: status.name,
        probeUrl: status.probeUrl,
        statusLabel: '受限',
        latencyLabel: status.httpStatusCode == null
            ? 'unknown'
            : 'HTTP ${status.httpStatusCode}',
        color: AppTheme.warning,
        softColor: AppTheme.warningSoft,
        icon: Icons.warning_amber_rounded,
        available: false,
      );
    }

    return ProviderStatusViewData(
      name: status.name,
      probeUrl: status.probeUrl,
      statusLabel: '异常',
      latencyLabel: 'timeout',
      color: AppTheme.danger,
      softColor: AppTheme.dangerSoft,
      icon: Icons.error_outline,
      available: false,
    );
  }
}

/// 解析服务结果，向控制器屏蔽 ParseResponse 的状态码细节。
class VideoParseOutcome {
  const VideoParseOutcome({
    required this.success,
    required this.message,
    required this.code,
    this.result,
    this.fromCache = false,
  });

  final bool success;
  final String message;
  final int code;
  final ParseResult? result;
  final bool fromCache;

  /// 是否应跳转视频结果页。
  ///
  /// 设计意图：媒体类型由 `dart_video_parse` 统一收敛，前端不再维护重复
  /// 推断规则；视频结果即使携带封面或缩略图，也仍按视频页展示。
  bool get hasVideo {
    final result = this.result;
    if (result == null || !result.isVideo) {
      return false;
    }
    return result.videos.any((item) => item.url.trim().isNotEmpty);
  }

  /// 是否应跳转图集结果页。
  ///
  /// 边界处理：仅使用解析库统一后的 [ParseResult.isGallery]，避免因视频
  /// 结果附带图片资源而误跳图集页。
  bool get hasGallery {
    final result = this.result;
    if (result == null) {
      return false;
    }
    return result.isGallery;
  }
}
