import 'package:dart_video_parse/dart_video_parse.dart';

import '../models/parse_ui_models.dart';
import 'parse_result_cache_repository.dart';

/// 解析库门面，负责输入校验、异常收敛和结果形态判断。
///
/// 设计意图：控制器只处理 UI 状态，不感知解析库的错误码和异常类型；
/// 这样后续替换解析库或增加缓存层时，不需要改动页面。
class VideoParseService {
  VideoParseService({
    VideoParser? parser,
    ParseResultCacheStore? cacheStore,
    this.cacheTtl = const Duration(hours: 6),
  }) : _parser = parser ?? VideoParser(),
       _cacheStore = cacheStore;

  final VideoParser _parser;
  final ParseResultCacheStore? _cacheStore;

  /// 解析结果缓存有效期。
  ///
  /// 设计取舍：短视频直链可能会随上游策略失效，缓存时间不宜过长；6 小时
  /// 能覆盖用户短时间重复解析，又能降低复用过期直链的概率。
  final Duration cacheTtl;

  List<ProviderInfo> listProviders() => _parser.listProviders();

  Future<List<ProviderStatus>> listProvidersStatus() {
    return _parser.listProvidersStatus();
  }

  Future<VideoParseOutcome> parse({
    required String rawInput,
    VideoParseProvider? provider,
  }) async {
    final input = rawInput.trim();
    final validationError = validateInput(input);
    if (validationError != null) {
      return VideoParseOutcome(
        success: false,
        message: validationError,
        code: ParseCodes.badRequest,
      );
    }

    ParseResult? cachedResult;
    try {
      cachedResult = await _cacheStore?.read(
        inputUrl: input,
        provider: provider,
      );
    } catch (_) {
      // 缓存是可选优化，SQLite 损坏或磁盘异常时按未命中处理，不能阻断解析。
      cachedResult = null;
    }
    if (cachedResult != null) {
      return VideoParseOutcome(
        success: true,
        message: '命中解析缓存',
        code: ParseCodes.success,
        result: cachedResult,
        fromCache: true,
      );
    }

    try {
      final response = provider == null
          ? await _parser.parse(input)
          : await _parser.parseByProvider(input, provider);
      final result = response.data;
      if (!response.success) {
        return VideoParseOutcome(
          success: false,
          message: response.msg,
          code: response.code,
          result: result,
        );
      }

      if (result == null || !result.isValid) {
        return const VideoParseOutcome(
          success: false,
          message: '解析成功但没有返回可用媒体资源',
          code: ParseCodes.notFound,
        );
      }

      try {
        await _cacheStore?.write(
          inputUrl: input,
          provider: provider,
          result: result,
          ttl: cacheTtl,
        );
      } catch (_) {
        // 网络结果已经有效，缓存落盘失败时仍应把结果交给用户。
      }

      return VideoParseOutcome(
        success: true,
        message: response.msg,
        code: response.code,
        result: result,
      );
    } catch (error) {
      return VideoParseOutcome(
        success: false,
        message: '解析请求失败：$error',
        code: ParseCodes.serverError,
      );
    }
  }

  /// 输入校验前置到服务层，保证按钮、测试和未来深链入口共享同一规则。
  String? validateInput(String input) {
    if (input.isEmpty) {
      return '待解析链接不能为空';
    }
    final uri = Uri.tryParse(ParseUtils.firstHttpUrl(input));
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return '待解析链接格式无效';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return '待解析链接格式无效，必须以 http:// 或 https:// 开头';
    }
    return null;
  }
}
