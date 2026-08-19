import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_video_parse/dart_video_parse.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../models/download_task_models.dart';
import '../../models/parse_ui_models.dart';
import '../../routes/app_pages.dart';
import '../../services/download_task_manager.dart';
import '../../services/media_cache_service.dart';
import '../../services/parse_log_repository.dart';
import '../../services/video_parse_service.dart';
import '../../utils/app_toast.dart';

/// 首页控制器，负责解析输入、Provider 探测、结果路由和内存日志。
///
/// 设计意图：UI 只订阅响应式状态，解析库调用和异常压缩都放在控制器/服务层；
/// 这样页面可以保持轻量，也方便单元测试注入假的 [VideoParseService]。
class HomeController extends GetxController {
  HomeController({
    required DownloadTaskManager downloadTaskManager,
    VideoParseService? service,
    MediaCacheStore? mediaCacheStore,
    ParseLogRepository? logRepository,
  }) : _service = service ?? VideoParseService(),
       _downloadTaskManager = downloadTaskManager,
       _mediaCacheStore = mediaCacheStore ?? MediaCacheService(),
       _logRepository = logRepository;

  final VideoParseService _service;
  final DownloadTaskManager _downloadTaskManager;
  final MediaCacheStore _mediaCacheStore;
  final ParseLogRepository? _logRepository;
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
  final RxBool clearingMediaCache = false.obs;
  final RxBool loadingMediaCacheSize = false.obs;
  final Rxn<int> mediaCacheSizeBytes = Rxn<int>();
  final RxBool hasLinkInput = false.obs;
  int _mediaCacheSizeRequestId = 0;

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
    refreshMediaCacheSize();
  }

  @override
  void onClose() {
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
      if (targetIndex == 2) {
        refreshMediaCacheSize();
      }
      return;
    }
    showingLogsPanel.value = false;
    currentTabIndex.value = targetIndex;
    if (targetIndex == 2) {
      refreshMediaCacheSize();
    }
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
    refreshMediaCacheSize();
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
      AlertDialog(
        title: Text(entry.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('解析日期：${entry.utc8DateLabel} UTC+8'),
              const SizedBox(height: 12),
              Text(entry.description),
              if (entry.source.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('来源：${entry.source}'),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: Get.back, child: const Text('关闭'))],
      ),
    );
  }

  /// 返回设置页可直接展示的缓存状态和容量。
  String get mediaCacheSubtitle {
    if (clearingMediaCache.value) {
      return '正在清空缓存';
    }
    final sizeInBytes = mediaCacheSizeBytes.value;
    if (loadingMediaCacheSize.value && sizeInBytes == null) {
      return '正在计算缓存';
    }
    if (sizeInBytes == null) {
      return '缓存大小暂不可用';
    }
    return '当前缓存 ${formatMediaCacheSize(sizeInBytes)}';
  }

  /// 重新统计图片磁盘缓存和残留视频临时文件的总大小。
  Future<void> refreshMediaCacheSize() async {
    final requestId = ++_mediaCacheSizeRequestId;
    loadingMediaCacheSize.value = true;
    try {
      final sizeInBytes = await _mediaCacheStore.getSizeInBytes();
      if (requestId == _mediaCacheSizeRequestId) {
        mediaCacheSizeBytes.value = sizeInBytes;
      }
    } catch (_) {
      if (requestId == _mediaCacheSizeRequestId) {
        mediaCacheSizeBytes.value = null;
      }
    } finally {
      if (requestId == _mediaCacheSizeRequestId) {
        loadingMediaCacheSize.value = false;
      }
    }
  }

  /// 显示媒体缓存清理确认，不影响解析日志、解析结果缓存和相册文件。
  void showClearMediaCacheDialog() {
    if (clearingMediaCache.value) {
      AppToast.info('正在清理', '图片和视频缓存正在清理中');
      return;
    }
    Get.dialog<void>(
      AlertDialog(
        title: const Text('清空缓存？'),
        content: const Text(
          '确认后将清理已缓存的网络图片和视频临时文件。解析日志、解析结果缓存以及已保存到相册的文件不会被删除。',
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          FilledButton(onPressed: _clearMediaCache, child: const Text('清空')),
        ],
      ),
    );
  }

  Future<void> _clearMediaCache() async {
    if (clearingMediaCache.value) {
      return;
    }

    clearingMediaCache.value = true;
    try {
      await _mediaCacheStore.clear();
      _closeDialogIfOpen();
      AppToast.success('已清空', '图片和视频缓存已清空');
    } catch (_) {
      _closeDialogIfOpen();
      AppToast.error('清空失败', '部分图片或视频缓存未能清理，请稍后重试');
    } finally {
      await refreshMediaCacheSize();
      clearingMediaCache.value = false;
    }
  }

  void _closeDialogIfOpen() {
    if (Get.isDialogOpen == true) {
      Get.back<void>();
    }
  }

  /// 将主视频提交给后台下载器，调用立即返回，不阻塞结果页导航。
  Future<void> downloadPrimaryVideoToGallery() async {
    final url = primaryVideoUrl;
    if (url.isEmpty) {
      AppToast.info('暂无视频', '当前结果没有可下载的视频资源');
      return;
    }
    final result = currentResult.value;
    final name = result == null || result.title.trim().isEmpty
        ? '未命名视频'
        : result.title.trim();
    final enqueueResult = await _downloadTaskManager.enqueueVideo(
      name: name,
      url: url,
      showPermissionRationale: _showDownloadPermissionRationale,
    );
    _showDownloadEnqueueResult(enqueueResult);
  }

  /// 提交单张图片，已在活动任务中的相同 URL 会由管理器去重。
  Future<void> downloadImageToGallery(String url, {int? index}) async {
    final result = currentResult.value;
    final baseName = result == null || result.title.trim().isEmpty
        ? '图集'
        : result.title.trim();
    final imageNumber = index == null ? '' : ' - 图片 ${index + 1}';
    final enqueueResult = await _downloadTaskManager.enqueueImage(
      name: '$baseName$imageNumber',
      url: url,
      showPermissionRationale: _showDownloadPermissionRationale,
    );
    _showDownloadEnqueueResult(enqueueResult);
  }

  /// 将整组图片作为一个逻辑任务批量提交，管理页只展示聚合进度。
  Future<void> downloadAllImagesToGallery() async {
    final result = currentResult.value;
    final urls = (result?.images ?? const <ImageItem>[])
        .map((item) => item.url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) {
      AppToast.info('暂无图片', '当前结果没有可下载的图集图片');
      return;
    }
    final baseName = result == null || result.title.trim().isEmpty
        ? '未命名图集'
        : result.title.trim();
    final enqueueResult = await _downloadTaskManager.enqueueGallery(
      name: '$baseName - 全部图片（${urls.length} 张）',
      urls: urls,
      showPermissionRationale: _showDownloadPermissionRationale,
    );
    _showDownloadEnqueueResult(enqueueResult);
  }

  DownloadJobViewData? get primaryVideoDownloadJob =>
      _downloadTaskManager.activeJobForUrl(primaryVideoUrl);

  DownloadJobViewData? imageDownloadJob(String url) =>
      _downloadTaskManager.activeJobForUrl(url);

  DownloadJobViewData? get galleryDownloadJob {
    final urls =
        currentResult.value?.images.map((item) => item.url) ?? const <String>[];
    return _downloadTaskManager.activeGalleryJobForUrls(urls);
  }

  String get downloadTaskSubtitle => _downloadTaskManager.settingsSubtitle;

  Future<void> openDownloadManagement() async {
    await Get.toNamed<void>(Routes.downloadManagement);
  }

  Future<bool> _showDownloadPermissionRationale(
    DownloadPermissionKind kind,
  ) async {
    final isNotification = kind == DownloadPermissionKind.notifications;
    return await Get.dialog<bool>(
          AlertDialog(
            title: Text(isNotification ? '允许下载通知？' : '允许保存到相册？'),
            content: Text(
              isNotification
                  ? '开启通知后可在后台查看进度，并暂停、继续或取消下载。'
                  : '需要存储权限才能把下载完成的图片或视频保存到系统相册。',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('暂不'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('继续'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showDownloadEnqueueResult(DownloadEnqueueResult result) {
    final skippedMessage = result.skippedCount > 0
        ? '，已跳过 ${result.skippedCount} 个无效或重复资源'
        : '';
    if (result.created) {
      AppToast.success('已加入下载', '${result.message}$skippedMessage');
      return;
    }
    AppToast.warning('未创建下载', '${result.message}$skippedMessage');
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
                    imageProvider: CachedNetworkImageProvider(imageUrl),
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
      return;
    }

    try {
      final persistedLogs = await repository.fetchRecentLogs();
      logs.assignAll(persistedLogs);
      selectedLogs.removeWhere((item) => !logs.contains(item));
    } catch (_) {
      AppToast.error('日志加载失败', '无法读取本地解析日志');
    }
  }

  Future<void> _addLog(ParseLogEntry entry) async {
    final repository = _logRepository;
    if (repository == null) {
      _insertLog(entry);
      return;
    }

    try {
      final persistedEntry = await repository.createLog(entry);
      _insertLog(persistedEntry ?? entry);
    } catch (_) {
      _insertLog(entry);
      AppToast.error('日志保存失败', '本条解析日志仅暂存在内存中');
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
