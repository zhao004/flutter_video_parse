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
