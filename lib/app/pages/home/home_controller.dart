import 'package:dart_video_parse/dart_video_parse.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../models/parse_ui_models.dart';
import '../../routes/app_pages.dart';
import '../../services/media_download_service.dart';
import '../../services/parse_log_repository.dart';
import '../../services/parse_result_cache_repository.dart';
import '../../services/video_parse_service.dart';
import '../../utils/app_toast.dart';

/// 首页控制器，负责解析输入、Provider 探测、结果路由和内存日志。
///
/// 设计意图：UI 只订阅响应式状态，解析库调用和异常压缩都放在控制器/服务层；
/// 这样页面可以保持轻量，也方便单元测试注入假的 [VideoParseService]。
class HomeController extends GetxController {
  HomeController({
    VideoParseService? service,
    MediaDownloadService? mediaDownloadService,
    ParseLogRepository? logRepository,
    ParseResultCacheRepository? cacheRepository,
  }) : _service = service ?? VideoParseService(),
       _mediaDownloadService = mediaDownloadService ?? MediaDownloadService(),
       _ownsMediaDownloadService = mediaDownloadService == null,
       _logRepository = logRepository,
       _cacheRepository = cacheRepository;

  final VideoParseService _service;
  final MediaDownloadService _mediaDownloadService;
  final bool _ownsMediaDownloadService;
  final ParseLogRepository? _logRepository;
  final ParseResultCacheRepository? _cacheRepository;
  final TextEditingController linkController = TextEditingController();

  final RxString version = ''.obs;
  final RxInt currentTabIndex = 0.obs;
  final Rxn<VideoParseProvider> selectedProvider = Rxn<VideoParseProvider>();
  final Rx<ParseUiState> parseState = ParseUiState.idle.obs;
  final RxList<ProviderInfo> providers = <ProviderInfo>[].obs;
  final RxList<ProviderStatusViewData> providerStatuses =
      <ProviderStatusViewData>[].obs;
  final RxList<ParseLogEntry> logs = <ParseLogEntry>[].obs;
  final RxList<ParseLogEntry> selectedLogs = <ParseLogEntry>[].obs;
  final Rxn<ParseResult> currentResult = Rxn<ParseResult>();
  final RxBool probingProviders = false.obs;
  final RxBool showingLogsPanel = false.obs;
  final RxBool selectingLogs = false.obs;
  final RxBool downloadingMedia = false.obs;
  final RxBool cancelingGalleryDownload = false.obs;
  final RxBool hasLinkInput = false.obs;
  final RxInt localStorageSizeBytes = 0.obs;
  final RxDouble downloadProgress = 0.0.obs;
  CancelToken? _activeDownloadCancelToken;

  @override
  void onInit() {
    super.onInit();
    linkController.addListener(_syncLinkInputState);
    _syncLinkInputState();
    final initialTab = Get.arguments;
    if (initialTab is int) {
      currentTabIndex.value = _normalizeTabIndex(initialTab);
    }
    _loadLogs();
    _loadProviders();
    refreshProviderStatuses();
    fetchAppVersion();
  }

  @override
  void onClose() {
    _activeDownloadCancelToken?.cancel('页面已关闭');
    _activeDownloadCancelToken = null;
    if (_ownsMediaDownloadService) {
      _mediaDownloadService.close();
    }
    linkController.removeListener(_syncLinkInputState);
    linkController.dispose();
    super.onClose();
  }

  ///获取软件版本
  Future<void> fetchAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;
      version.value = appVersion;
    } catch (_) {
      version.value = '未知版本';
    }
  }

  /// 同步链接输入框状态，供页面切换“粘贴内容 / 清空编辑框”按钮。
  ///
  /// 设计取舍：以去除首尾空白后的内容作为有效输入，避免只输入空格时按钮误判。
  void _syncLinkInputState() {
    final hasContent = linkController.text.trim().isNotEmpty;
    if (hasLinkInput.value == hasContent) {
      return;
    }
    hasLinkInput.value = hasContent;
  }

  void switchTab(int index) {
    final targetIndex = _normalizeTabIndex(index);
    if (!showingLogsPanel.value && currentTabIndex.value == targetIndex) {
      return;
    }
    showingLogsPanel.value = false;
    currentTabIndex.value = targetIndex;
  }

  /// 打开解析日志面板，并保持底层 Tab 在“设置关于”。
  ///
  /// 设计意图：ADB 系统返回键在部分 Android/Flutter 组合下不会稳定触发
  /// 独立 GetX 路由的 PopScope。把日志作为首页内状态可减少平台返回栈差异。
  void openLogsPanel() {
    cancelLogSelection();
    currentTabIndex.value = 2;
    showingLogsPanel.value = true;
  }

  /// 关闭解析日志面板，回到设置页。
  bool closeLogsPanel() {
    if (!showingLogsPanel.value) {
      return false;
    }
    cancelLogSelection();
    showingLogsPanel.value = false;
    currentTabIndex.value = 2;
    return true;
  }

  /// 处理日志面板返回：选择态先退出选择，否则关闭面板。
  bool handleLogsBack() {
    if (selectingLogs.value) {
      cancelLogSelection();
      return true;
    }
    return closeLogsPanel();
  }

  /// 根据输入状态执行粘贴或清空。
  ///
  /// 异常策略：读取剪贴板失败时只提示用户，不中断当前页面状态；剪贴板为空
  /// 时保留现有空输入，避免写入无意义内容。
  Future<void> pasteOrClearLinkInput() async {
    if (hasLinkInput.value) {
      linkController.clear();
      parseState.value = ParseUiState.idle;
      return;
    }

    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final pastedText = clipboardData?.text?.trim();
      if (pastedText == null || pastedText.isEmpty) {
        AppToast.info('剪贴板为空', '没有可粘贴的链接内容');
        return;
      }

      linkController.text = pastedText;
      linkController.selection = TextSelection.collapsed(
        offset: pastedText.length,
      );
      parseState.value = ParseUiState.idle;
    } catch (_) {
      AppToast.error('粘贴失败', '无法读取剪贴板内容，请手动输入链接');
    }
  }

  /// 进入日志多选模式，空列表时直接给出用户反馈。
  void enterLogSelectionMode() {
    if (logs.isEmpty) {
      AppToast.info('暂无日志', '当前没有可选择的解析日志');
      return;
    }
    selectedLogs.clear();
    selectingLogs.value = true;
  }

  /// 退出多选模式并清空已选项，避免后续删除误伤旧选择。
  void cancelLogSelection() {
    selectedLogs.clear();
    selectingLogs.value = false;
  }

  bool isLogSelected(ParseLogEntry entry) {
    return selectedLogs.contains(entry);
  }

  /// 选择单条日志；若当前不在多选模式，则先进入多选。
  void selectLogEntry(ParseLogEntry entry) {
    if (!logs.contains(entry)) {
      return;
    }
    selectingLogs.value = true;
    if (!selectedLogs.contains(entry)) {
      selectedLogs.add(entry);
    }
  }

  /// 切换单条日志选择状态，并忽略已经不在列表中的过期对象。
  void toggleLogSelection(ParseLogEntry entry) {
    if (!logs.contains(entry)) {
      selectedLogs.remove(entry);
      return;
    }
    selectingLogs.value = true;
    if (selectedLogs.contains(entry)) {
      selectedLogs.remove(entry);
      return;
    }
    selectedLogs.add(entry);
  }

  /// 全选或取消全选当前日志，边界情况下保持选择态可恢复。
  void toggleAllLogSelection() {
    if (logs.isEmpty) {
      cancelLogSelection();
      AppToast.info('暂无日志', '当前没有可选择的解析日志');
      return;
    }
    selectingLogs.value = true;
    if (selectedLogs.length == logs.length) {
      selectedLogs.clear();
      return;
    }
    selectedLogs.assignAll(logs);
  }

  /// 删除已选日志；删除前会过滤过期选择，避免列表变化导致误删。
  Future<void> deleteSelectedLogs() async {
    final targets = selectedLogs.where(logs.contains).toSet();
    if (targets.isEmpty) {
      AppToast.warning('未选择日志', '请先选择需要删除的解析日志');
      return;
    }

    final targetIds = targets
        .map((entry) => entry.id)
        .whereType<int>()
        .toList(growable: false);
    final deletedCount = targets.length;
    try {
      if (_logRepository != null && targetIds.isNotEmpty) {
        await _logRepository.deleteLogsByIds(targetIds);
      }
      logs.removeWhere(targets.contains);
      await _refreshLocalStorageSize();
    } catch (_) {
      AppToast.error('删除失败', '解析日志删除失败，请稍后重试');
      return;
    }
    cancelLogSelection();
    AppToast.success('已删除', '已删除 $deletedCount 条解析日志');
  }

  /// 删除确认弹窗，防止批量操作被误触。
  void confirmDeleteSelectedLogs() {
    final count = selectedLogs.where(logs.contains).length;
    if (count == 0) {
      AppToast.warning('未选择日志', '请先选择需要删除的解析日志');
      return;
    }

    Get.dialog<void>(
      AlertDialog(
        title: const Text('删除所选日志？'),
        content: Text('确认删除已选的 $count 条解析日志？此操作不会影响解析结果。'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Get.back<void>();
              await deleteSelectedLogs();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 二级页返回兜底，优先关闭首页内面板，再处理历史独立路由。
  ///
  /// 异常策略：直接回到主页面并选中指定 Tab，避免不同系统返回栈行为
  /// 把用户带回桌面。
  void returnToHomeTab(int tabIndex) {
    final targetTab = _normalizeTabIndex(tabIndex);
    cancelLogSelection();
    showingLogsPanel.value = false;
    currentTabIndex.value = targetTab;

    if (Get.currentRoute == Routes.home) {
      return;
    }

    Get.offAllNamed(Routes.home, arguments: targetTab);
  }

  Future<void> parseCurrentInput() async {
    if (parseState.value.isLoading) {
      return;
    }

    parseState.value = ParseUiState.loading;
    final provider = selectedProvider.value;
    final outcome = await _service.parse(
      rawInput: linkController.text,
      provider: provider,
    );

    if (!outcome.success || outcome.result == null) {
      parseState.value = ParseUiState.error(outcome.message);
      _addLog(
        ParseLogEntry(
          createdAt: DateTime.now(),
          level: outcome.code == ParseCodes.badRequest
              ? ParseLogLevel.warning
              : ParseLogLevel.error,
          title: outcome.code == ParseCodes.badRequest ? '链接校验失败' : '解析失败',
          description: outcome.message,
          source: provider?.name ?? 'auto',
          badge: outcome.code.toString(),
        ),
      );
      AppToast.error('解析失败', outcome.message);
      return;
    }

    currentResult.value = outcome.result;
    parseState.value = ParseUiState.success;
    _addLog(
      ParseLogEntry(
        createdAt: DateTime.now(),
        level: ParseLogLevel.success,
        title: outcome.fromCache ? '命中解析缓存' : '解析成功',
        description: buildParseSuccessDescription(outcome.result!),
        source: outcome.result!.parserUsed,
        badge: outcome.fromCache
            ? 'cache'
            : outcome.result!.parserUsed.isEmpty
            ? provider?.name ?? 'auto'
            : outcome.result!.parserUsed,
      ),
    );

    if (outcome.hasGallery) {
      await Get.toNamed(Routes.galleryResult);
      return;
    }

    await Get.toNamed(Routes.videoResult);
  }

  Future<void> refreshProviderStatuses() async {
    if (probingProviders.value) {
      return;
    }

    probingProviders.value = true;
    try {
      final statuses = await _service.listProvidersStatus();
      providerStatuses.assignAll(
        statuses.map(ProviderStatusViewData.fromStatus),
      );
      final availableCount = providerStatuses
          .where((item) => item.available)
          .length;
      _addLog(
        ParseLogEntry(
          createdAt: DateTime.now(),
          level: ParseLogLevel.success,
          title: 'Provider 探测完成',
          description: '当前可用 $availableCount / ${statuses.length} 个解析源',
          badge: '$availableCount 个',
        ),
      );
    } catch (error) {
      _addLog(
        ParseLogEntry(
          createdAt: DateTime.now(),
          level: ParseLogLevel.error,
          title: 'Provider 探测失败',
          description: error.toString(),
          badge: 'probe',
        ),
      );
    } finally {
      probingProviders.value = false;
    }
  }

  Future<void> copyPrimaryUrl() async {
    final url = primaryVideoUrl;
    if (url.isEmpty) {
      AppToast.info('暂无直链', '当前结果没有可复制的视频直链');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    AppToast.success('已复制', '视频直链已复制');
  }

  Future<void> copyCoverUrl() async {
    final url = coverUrl;
    if (url.isEmpty) {
      AppToast.info('暂无封面', '当前结果没有可复制的封面直链');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    AppToast.success('已复制', '封面直链已复制');
  }

  void showLogDetail(ParseLogEntry entry) {
    Get.dialog<void>(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text('解析日期：${entry.utc8DateLabel} UTC+8'),
              const SizedBox(height: 10),
              Text(entry.description),
              if (entry.source.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('来源：${entry.source}'),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: Get.back, child: const Text('关闭')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showClearCacheDialog() {
    Get.dialog<void>(
      AlertDialog(
        title: const Text('清空缓存？'),
        content: const Text('确认后将清空 SQLite 中的解析日志和解析结果缓存，不会删除已保存的图片或视频文件。'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              try {
                await _logRepository?.clearLogs();
                await _cacheRepository?.clear();
                logs.clear();
                localStorageSizeBytes.value = 0;
                cancelLogSelection();
                Get.back<void>();
                AppToast.success('已清空', '解析日志和解析缓存已清空');
              } catch (_) {
                Get.back<void>();
                AppToast.error('清空失败', '解析日志或解析缓存清空失败，请稍后重试');
              }
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  Future<void> downloadPrimaryVideoToGallery() async {
    await _downloadNetworkMediaToGallery(
      url: primaryVideoUrl,
      mediaType: MediaFileType.video,
    );
  }

  Future<void> downloadImageToGallery(String url, {int? index}) async {
    await _downloadNetworkMediaToGallery(
      url: url,
      mediaType: MediaFileType.image,
      fallbackName: index == null ? 'image' : 'image_${index + 1}',
    );
  }

  Future<void> downloadAllImagesToGallery() async {
    final result = currentResult.value;
    final images = result?.images ?? const <ImageItem>[];
    final urls = images
        .map((item) => item.url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);

    if (urls.isEmpty) {
      AppToast.info('暂无图片', '当前结果没有可下载的图集图片');
      return;
    }
    if (downloadingMedia.value) {
      AppToast.warning('正在下载', '请等待当前下载任务完成');
      return;
    }

    final totalCount = urls.length;
    final completedCount = 0.obs;
    final successCountState = 0.obs;
    final statusMessage = '准备下载图集图片'.obs;
    var canceled = false;
    downloadingMedia.value = true;
    cancelingGalleryDownload.value = false;
    downloadProgress.value = 0;
    _showGalleryDownloadProgressDialog(
      totalCount: totalCount,
      completedCount: completedCount,
      successCount: successCountState,
      statusMessage: statusMessage,
      onCancel: cancelGalleryDownload,
    );

    var successCount = 0;
    try {
      for (var index = 0; index < urls.length; index++) {
        if (cancelingGalleryDownload.value) {
          canceled = true;
          break;
        }

        downloadProgress.value = 0;
        statusMessage.value = '正在下载第 ${index + 1} / $totalCount 张图片';
        final cancelToken = CancelToken();
        _activeDownloadCancelToken = cancelToken;
        final saved = await _downloadNetworkMediaToGallery(
          url: urls[index],
          mediaType: MediaFileType.image,
          fallbackName: 'image_${index + 1}',
          showSuccessToast: false,
          showErrorToast: false,
          manageDownloadState: false,
          cancelToken: cancelToken,
        );
        if (saved) {
          successCount++;
        }
        successCountState.value = successCount;
        completedCount.value = index + 1;
        if (cancelingGalleryDownload.value || cancelToken.isCancelled) {
          canceled = true;
          break;
        }
      }
    } finally {
      _activeDownloadCancelToken = null;
      downloadingMedia.value = false;
      downloadProgress.value = 0;
    }

    if (canceled) {
      statusMessage.value = '已终止下载，成功保存 $successCount / $totalCount 张图片';
      AppToast.warning('下载已终止', '已保存 $successCount / $totalCount 张图片到相册');
      return;
    }

    statusMessage.value = successCount == totalCount
        ? '全部图片已保存到系统相册'
        : '部分图片保存失败，请稍后重试';
    if (successCount > 0) {
      AppToast.success('保存完成', '已保存 $successCount / $totalCount 张图片到相册');
      return;
    }
    AppToast.error('保存失败', '图集图片保存失败，请检查网络或相册权限');
  }

  /// 终止当前图集批量下载。
  ///
  /// 边界处理：如果当前文件正在网络下载，优先取消 Dio 请求；如果处于文件保存
  /// 阶段，则通过状态位阻止下一张图片继续下载。
  void cancelGalleryDownload() {
    if (!downloadingMedia.value || cancelingGalleryDownload.value) {
      return;
    }
    cancelingGalleryDownload.value = true;
    _activeDownloadCancelToken?.cancel('用户终止图集下载');
  }

  /// 展示批量下载进度弹窗。
  ///
  /// 边界处理：下载中允许用户主动终止，但禁止误触返回关闭；任务完成或终止后
  /// 显示完成按钮，避免用户看不到最终成功数量。
  void _showGalleryDownloadProgressDialog({
    required int totalCount,
    required RxInt completedCount,
    required RxInt successCount,
    required RxString statusMessage,
    required VoidCallback onCancel,
  }) {
    Get.dialog<void>(
      Obx(() {
        final completed = completedCount.value;
        final isCanceled = cancelingGalleryDownload.value;
        final isDone = completed >= totalCount || !downloadingMedia.value;
        final currentFileProgress = isDone || isCanceled
            ? 0.0
            : downloadProgress.value;
        final overallProgress = totalCount <= 0
            ? 0.0
            : ((completed + currentFileProgress) / totalCount).clamp(0.0, 1.0);

        return PopScope(
          canPop: isDone,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '下载图集',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(statusMessage.value),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(value: overallProgress),
                  const SizedBox(height: 10),
                  Text(
                    '进度 ${(overallProgress * 100).toStringAsFixed(0)}% · '
                    '已完成 $completed / $totalCount · '
                    '成功 ${successCount.value} 张',
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: isDone
                        ? FilledButton(
                            onPressed: Get.back<void>,
                            child: const Text('完成'),
                          )
                        : TextButton(
                            onPressed: onCancel,
                            child: const Text('终止下载'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
      barrierDismissible: false,
    );
  }

  void showImagePreviewDialog(int index) {
    final result = currentResult.value;
    final images = result?.images ?? const <ImageItem>[];
    if (images.isEmpty || index < 0 || index >= images.length) {
      AppToast.info('暂无图片', '当前没有可预览的图集图片');
      return;
    }

    final pageController = PageController(initialPage: index);
    final currentIndex = index.obs;
    Get.dialog<void>(
      Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              PhotoViewGallery.builder(
                itemCount: images.length,
                pageController: pageController,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                onPageChanged: (pageIndex) => currentIndex.value = pageIndex,
                loadingBuilder: (context, event) {
                  final expectedBytes = event?.expectedTotalBytes;
                  final loadedBytes = event?.cumulativeBytesLoaded ?? 0;
                  return Center(
                    child: CircularProgressIndicator(
                      value: expectedBytes == null || expectedBytes <= 0
                          ? null
                          : loadedBytes / expectedBytes,
                    ),
                  );
                },
                builder: (context, pageIndex) {
                  final imageUrl = images[pageIndex].url.trim();
                  return PhotoViewGalleryPageOptions(
                    imageProvider: NetworkImage(imageUrl),
                    minScale: PhotoViewComputedScale.contained,
                    initialScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white70,
                          size: 52,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Obx(
                        () => Text(
                          '${currentIndex.value + 1} / ${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: Get.back,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get primaryVideoUrl {
    final videos = currentResult.value?.videos ?? const <VideoItem>[];
    for (final video in videos) {
      if (video.url.trim().isNotEmpty) {
        return video.url.trim();
      }
    }
    return '';
  }

  String get coverUrl {
    return currentResult.value?.cover.trim() ?? '';
  }

  String get cacheSizeLabel {
    const bytesPerKilobyte = 1024;
    const bytesPerMegabyte = bytesPerKilobyte * 1024;
    final sizeBytes = localStorageSizeBytes.value;
    if (sizeBytes <= 0) {
      return '0 KB';
    }
    if (sizeBytes < bytesPerKilobyte) {
      return '<1 KB';
    }
    if (sizeBytes < bytesPerMegabyte) {
      return '${(sizeBytes / bytesPerKilobyte).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / bytesPerMegabyte).toStringAsFixed(1)} MB';
  }

  List<MediaResourceViewData> get videoResources {
    final result = currentResult.value;
    if (result == null) {
      return const <MediaResourceViewData>[];
    }

    final resources = <MediaResourceViewData>[];
    final videoUrl = primaryVideoUrl;
    if (videoUrl.isNotEmpty) {
      resources.add(
        MediaResourceViewData(
          title: '视频链接',
          description: '解析源返回的视频直链',
          url: videoUrl,
          icon: Icons.movie_outlined,
          actionLabel: '复制',
          highlight: true,
        ),
      );
    }

    if (result.cover.trim().isNotEmpty) {
      resources.add(
        MediaResourceViewData(
          title: '封面图片',
          description: '解析源返回的封面图片',
          url: result.cover,
          icon: Icons.image_outlined,
          actionLabel: '复制',
          highlight: true,
        ),
      );
    }

    return resources;
  }

  Future<bool> _downloadNetworkMediaToGallery({
    required String url,
    required MediaFileType mediaType,
    String fallbackName = 'video',
    bool showSuccessToast = true,
    bool showErrorToast = true,
    bool manageDownloadState = true,
    CancelToken? cancelToken,
  }) async {
    if (manageDownloadState && downloadingMedia.value) {
      if (showErrorToast) {
        AppToast.warning('正在下载', '请等待当前下载任务完成');
      }
      return false;
    }

    if (manageDownloadState) {
      downloadingMedia.value = true;
    }
    final effectiveCancelToken = cancelToken ?? CancelToken();
    _activeDownloadCancelToken = effectiveCancelToken;
    downloadProgress.value = 0;
    try {
      final outcome = await _mediaDownloadService.download(
        url: url,
        mediaType: mediaType,
        fallbackName: fallbackName,
        cancelToken: effectiveCancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            downloadProgress.value = (received / total)
                .clamp(0.0, 1.0)
                .toDouble();
          }
        },
      );

      if (outcome.saved && showSuccessToast) {
        AppToast.success('保存成功', '资源已保存到系统相册');
      }
      if (!outcome.saved && showErrorToast && !outcome.canceled) {
        if (outcome.failure == MediaDownloadFailure.permissionDenied) {
          AppToast.warning('权限不足', outcome.message);
        } else {
          final title = outcome.failure == MediaDownloadFailure.gallery
              ? '保存失败'
              : '下载失败';
          AppToast.error(title, outcome.message);
        }
      }
      return outcome.saved;
    } finally {
      downloadProgress.value = 0;
      if (identical(_activeDownloadCancelToken, effectiveCancelToken)) {
        _activeDownloadCancelToken = null;
      }
      if (manageDownloadState) {
        downloadingMedia.value = false;
      }
    }
  }

  void _loadProviders() {
    final items = _service.listProviders();
    providers.assignAll(items);
    if (items.isEmpty) {
      _addLog(
        ParseLogEntry(
          createdAt: DateTime.now(),
          level: ParseLogLevel.warning,
          title: '解析源为空',
          description: '当前没有可用 Provider，解析按钮将只显示错误状态',
          badge: 'empty',
        ),
      );
    }
  }

  Future<void> _loadLogs() async {
    final repository = _logRepository;
    if (repository == null) {
      await _refreshLocalStorageSize();
      return;
    }

    try {
      final persistedLogs = await repository.fetchRecentLogs();
      logs.assignAll(persistedLogs);
      selectedLogs.removeWhere((item) => !logs.contains(item));
    } catch (_) {
      AppToast.error('日志加载失败', '无法读取本地解析日志');
    } finally {
      await _refreshLocalStorageSize();
    }
  }

  Future<void> _addLog(ParseLogEntry entry) async {
    final repository = _logRepository;
    if (repository == null) {
      _insertLog(entry);
      await _refreshLocalStorageSize();
      return;
    }

    try {
      final persistedEntry = await repository.createLog(entry);
      _insertLog(persistedEntry ?? entry);
    } catch (_) {
      _insertLog(entry);
      AppToast.error('日志保存失败', '本条解析日志仅暂存在内存中');
    } finally {
      await _refreshLocalStorageSize();
    }
  }

  /// 刷新设置页展示的 SQLite 逻辑载荷大小。
  ///
  /// 异常策略：容量仅用于提示，数据库暂时不可用时保留上次成功值，不影响解析。
  Future<void> _refreshLocalStorageSize() async {
    final repository = _cacheRepository;
    if (repository == null) {
      return;
    }
    try {
      final sizeBytes = await repository.getLocalStorageSizeBytes();
      localStorageSizeBytes.value = sizeBytes < 0 ? 0 : sizeBytes;
    } catch (_) {
      // 容量展示属于辅助信息，读取失败时不覆盖已有值。
    }
  }

  void _insertLog(ParseLogEntry entry) {
    logs.insert(0, entry);
    if (logs.length > 80) {
      logs.removeRange(80, logs.length);
    }
    selectedLogs.removeWhere((item) => !logs.contains(item));
  }

  int _normalizeTabIndex(int index) {
    if (index < 0) {
      return 0;
    }
    if (index > 2) {
      return 2;
    }
    return index;
  }
}
