import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import 'app/routes/app_pages.dart';
import 'app/services/background_downloader_gateway.dart';
import 'app/services/download_task_manager.dart';
import 'app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final downloadTaskManager = DownloadTaskManager(
    gateway: BackgroundDownloaderPluginGateway(),
  );
  await downloadTaskManager.initialize();
  Get.put<DownloadTaskManager>(downloadTaskManager, permanent: true);
  runApp(const VideoParseApp());
}

/// 应用入口，统一配置 Material 3 主题和 GetX 路由。
class VideoParseApp extends StatelessWidget {
  const VideoParseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: GetMaterialApp(
        title: 'VideoParse',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      ),
    );
  }
}
