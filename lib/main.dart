import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';

void main() {
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
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      ),
    );
  }
}
