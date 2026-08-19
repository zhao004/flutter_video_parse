import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// 应用级 Toast 工具，统一替代页面中的临时提示。
///
/// 设计意图：控制器和 Widget 只表达提示语义，展示位置、时长和样式集中维护；
/// 边界策略：允许空描述，避免调用方为了短提示拼接无意义文本。
class AppToast {
  const AppToast._();

  static const Duration _duration = Duration(seconds: 3);

  /// 展示成功提示，适用于复制、保存、删除完成等正向反馈。
  static void success(String title, [String? message]) {
    _show(ToastificationType.success, title, message);
  }

  /// 展示错误提示，适用于解析、下载、权限、持久化等失败场景。
  static void error(String title, [String? message]) {
    _show(ToastificationType.error, title, message);
  }

  /// 展示信息提示，适用于空状态、不可操作说明等中性反馈。
  static void info(String title, [String? message]) {
    _show(ToastificationType.info, title, message);
  }

  /// 展示警告提示，适用于用户需要等待或先选择内容的场景。
  static void warning(String title, [String? message]) {
    _show(ToastificationType.warning, title, message);
  }

  static void _show(ToastificationType type, String title, String? message) {
    final normalizedTitle = title.trim();
    final normalizedMessage = message?.trim();

    toastification.show(
      title: Text(normalizedTitle.isEmpty ? '提示' : normalizedTitle),
      description: normalizedMessage == null || normalizedMessage.isEmpty
          ? null
          : Text(normalizedMessage),
      type: type,
      style: ToastificationStyle.flatColored,
      alignment: Alignment.topCenter,
      autoCloseDuration: _duration,
      showProgressBar: false,
      closeOnClick: true,
      dragToClose: true,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: BorderRadius.circular(4),
    );
  }
}
