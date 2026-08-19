import 'package:get/get.dart';

import '../../services/download_task_manager.dart';
import 'download_management_controller.dart';

/// 下载管理页依赖绑定，复用应用级常驻下载管理器。
class DownloadManagementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DownloadManagementController>(
      () => DownloadManagementController(Get.find<DownloadTaskManager>()),
    );
  }
}
