import 'package:get/get.dart';

import '../pages/downloads/download_management_binding.dart';
import '../pages/downloads/download_management_view.dart';
import '../pages/home/home_binding.dart';
import '../pages/home/home_view.dart';
import '../pages/result/gallery_result_view.dart';
import '../pages/result/video_result_view.dart';

part 'app_routes.dart';

/// GetX 路由表，集中管理主页面、结果页和日志页。
class AppPages {
  AppPages._();

  static const initial = Routes.home;

  static final routes = [
    GetPage(
      name: _Paths.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(name: _Paths.videoResult, page: () => const VideoResultView()),
    GetPage(name: _Paths.galleryResult, page: () => const GalleryResultView()),
    GetPage(
      name: _Paths.downloadManagement,
      page: () => const DownloadManagementView(),
      binding: DownloadManagementBinding(),
    ),
  ];
}
