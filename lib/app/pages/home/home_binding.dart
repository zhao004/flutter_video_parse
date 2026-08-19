import 'package:get/get.dart';

import '../../database/database.dart';
import '../../services/download_task_manager.dart';
import '../../services/media_cache_service.dart';
import '../../services/parse_log_repository.dart';
import '../../services/parse_result_cache_repository.dart';
import '../../services/video_parse_service.dart';
import 'home_controller.dart';

/// 首页依赖绑定，统一注册页面级控制器。
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AppDatabase>(AppDatabase.new, fenix: true);
    Get.lazyPut<ParseLogRepository>(
      () => ParseLogRepository(Get.find<AppDatabase>()),
      fenix: true,
    );
    Get.lazyPut<ParseResultCacheRepository>(
      () => ParseResultCacheRepository(Get.find<AppDatabase>()),
      fenix: true,
    );
    Get.lazyPut<MediaCacheService>(MediaCacheService.new, fenix: true);
    Get.lazyPut<VideoParseService>(
      () =>
          VideoParseService(cacheStore: Get.find<ParseResultCacheRepository>()),
      fenix: true,
    );
    Get.lazyPut<HomeController>(
      () => HomeController(
        service: Get.find<VideoParseService>(),
        downloadTaskManager: Get.find<DownloadTaskManager>(),
        logRepository: Get.find<ParseLogRepository>(),
        mediaCacheStore: Get.find<MediaCacheService>(),
      ),
    );
  }
}
