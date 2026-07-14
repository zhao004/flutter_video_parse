import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'app_http_client.g.dart';

@RestApi()
abstract class AppHttpClient {
  factory AppHttpClient(Dio dio, {String baseUrl}) = _AppHttpClient;

  @GET('/health')
  Future<HttpResponse<dynamic>> health();
}

Dio createAppHttpClientDio({String baseUrl = 'https://example.com/api'}) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    ),
  )..interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
}

/// 媒体文件连接超时，避免不可达地址长期占用下载状态。
const mediaDownloadConnectTimeout = Duration(seconds: 15);

/// 媒体文件分段接收超时；大文件允许较长传输，但不能无限等待。
const mediaDownloadReceiveTimeout = Duration(minutes: 2);

/// 创建供图片和视频下载复用的 Dio 实例。
Dio createMediaDownloadDio() {
  return Dio(
    BaseOptions(
      connectTimeout: mediaDownloadConnectTimeout,
      receiveTimeout: mediaDownloadReceiveTimeout,
      sendTimeout: mediaDownloadConnectTimeout,
    ),
  );
}
