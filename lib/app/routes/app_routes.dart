part of 'app_pages.dart';

/// 应用路由名称，保持 GetX 调用侧不直接硬编码路径字符串。
abstract class Routes {
  Routes._();

  static const home = _Paths.home;
  static const videoResult = _Paths.videoResult;
  static const galleryResult = _Paths.galleryResult;
}

abstract class _Paths {
  _Paths._();

  static const home = '/home';
  static const videoResult = '/video-result';
  static const galleryResult = '/gallery-result';
}
