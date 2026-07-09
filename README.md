# VideoParse

`VideoParse` 是一个基于 Flutter 的短视频/图集解析应用。应用支持粘贴短视频分享链接、选择解析源、查看解析源状态，并根据解析结果自动进入视频结果页或图集结果页。解析日志和解析缓存通过 Drift + SQLite 本地持久化。

## 功能特性

- 视频/图集解析：接入本地 `dart_video_parse` 解析库，支持自动轮询解析源或手动选择指定解析源。
- 结果自动分流：解析成功后根据 `ParseResult` 媒体类型跳转到视频结果页或图集结果页。
- 视频结果页：使用 `chewie` + `video_player` 预览视频，支持复制视频直链、复制封面直链、下载视频到系统相册。
- 图集结果页：使用 `flutter_staggered_grid_view` 展示瀑布流，使用 `photo_view` 支持图片预览、缩放和左右滑动切换。
- 图集下载：支持单图下载和全部下载；全部下载会显示进度弹窗，并支持终止当前批量下载任务。
- 解析源状态：支持探测解析源可用性、延迟和状态。
- 解析日志：使用 Drift + SQLite 记录解析结果、错误和解析源探测日志，列表展示 UTC+8 解析日期，支持多选删除。
- 解析缓存：相同短视频链接和解析源在 6 小时内复用本地解析结果，降低重复请求消耗。
- 统一提示：使用 `toastification` 统一展示成功、错误、警告和信息提示。

## 技术栈

| 能力 | 依赖/方案 |
| --- | --- |
| 状态管理与路由 | GetX |
| 视频解析 | `dart_video_parse` 本地路径依赖 |
| 本地数据库 | Drift + SQLite |
| 网络请求 | Dio + Retrofit |
| 视频播放 | chewie + video_player |
| 相册保存 | gal |
| 图集瀑布流 | flutter_staggered_grid_view |
| 图片预览 | photo_view |
| Toast 提示 | toastification |
| 代码生成 | build_runner、drift_dev、json_serializable、retrofit_generator |

## 项目结构

```text
lib/
  main.dart                         # 应用入口，配置主题、路由和 ToastificationWrapper
  app/
    database/                       # Drift 数据库、表定义和类型转换器
      tables/
      type/
    http/                           # Retrofit/Dio HTTP 客户端
    models/                         # UI 状态和展示模型
    pages/
      home/                         # 首页、解析页、解析源状态页、设置页控制逻辑
      logs/                         # 解析日志独立页入口
      result/                       # 视频结果页和图集结果页
    routes/                         # GetX 路由表
    services/                       # 解析服务、日志仓储、解析缓存仓储
    theme/                          # Material 3 主题配置
    utils/                          # 通用工具，如 AppToast
    widgets/                        # 页面复用组件
test/
  video_parse_service_test.dart     # 解析服务核心逻辑测试
  widget_test.dart                  # Flutter Widget 测试入口
android/                            # Android 平台配置、权限和 Gradle 配置
```

## 运行前准备

1. 安装 Flutter SDK，并确保本机 Dart SDK 满足 `pubspec.yaml` 中的 `sdk: ^3.11.0`。
2. 确保本项目同级目录存在本地解析库：

   ```text
   E:\IDEProjects\dart_video_parse
   E:\IDEProjects\flutter_video_parse
   ```

   `pubspec.yaml` 中通过以下方式引用解析库：

   ```yaml
   dart_video_parse:
     path: ../dart_video_parse
   ```

3. 连接 Android 设备或启动模拟器。下载到相册功能依赖 Android 相册权限。

## 安装与启动

同步依赖：

```bash
flutter pub get
```

生成 Drift、JSON 和 Retrofit 代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

启动应用：

```bash
flutter run
```

## 常用开发命令

格式化代码：

```bash
dart format lib test
```

静态分析：

```bash
flutter analyze
```

运行测试：

```bash
flutter test
```

重新生成代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

构建 Android APK：

```bash
flutter build apk
```

> 注意：发布 APK 时需要按项目规则完成 V2/V3 签名，并通过 `apksigner verify` 校验后再分发。

## 核心流程

### 解析流程

1. 用户在视频解析页输入或粘贴短视频分享链接。
2. `HomeController` 调用 `VideoParseService.parse()`。
3. `VideoParseService` 先进行输入校验，并提取第一个 HTTP/HTTPS 链接。
4. 服务层按“标准化链接 + 解析源”读取解析缓存。
5. 缓存命中时直接返回缓存结果；未命中时调用 `dart_video_parse`。
6. 解析结果有效后写入缓存，并返回给控制器。
7. 控制器根据结果类型跳转到视频结果页或图集结果页。

### 日志流程

- 每次解析、解析失败或解析源探测都会创建 `ParseLogEntry`。
- `ParseLogRepository` 将日志写入 Drift + SQLite。
- 默认只保留最近 80 条日志，避免本地数据库无限增长。
- 日志列表支持多选、全选、取消选择和批量删除。

### 缓存流程

- 缓存表为 `parse_result_caches`。
- 缓存键格式为：`标准化链接::解析源名称`。
- 自动解析源使用 `auto` 作为解析源名称。
- 默认缓存有效期为 6 小时。
- 读取缓存时会自动删除过期或无法反序列化的数据。

## Android 权限

应用在 Android 端声明以下权限：

- `INTERNET`：访问解析源和下载媒体资源。
- `READ_MEDIA_IMAGES`：Android 13+ 读取/保存图片相关媒体权限。
- `READ_MEDIA_VIDEO`：Android 13+ 读取/保存视频相关媒体权限。
- `WRITE_EXTERNAL_STORAGE`：Android 10 及以下保存媒体资源。

媒体保存通过 `gal` 库写入系统相册。权限不足时，应用会通过 Toast 提示用户授权。

## 测试范围

当前测试重点覆盖 `VideoParseService`：

- 空链接输入校验。
- 视频结果解析成功。
- 图集结果识别。
- 视频结果附带图片时仍识别为视频。
- 重复解析相同链接命中缓存。
- 空媒体结果返回失败状态。

新增解析规则、缓存策略或结果类型判断时，应优先补充 `test/video_parse_service_test.dart`。

## 开发约定

- 文件命名使用 `snake_case.dart`。
- 类和 Widget 使用 `UpperCamelCase`。
- 变量、方法和路由名称使用 `lowerCamelCase`。
- 页面相关文件保持 `*_view.dart`、`*_controller.dart`、`*_binding.dart` 命名模式。
- 业务逻辑优先放在 `services/` 或仓储层，页面只负责渲染和交互。
- Drift、Retrofit、JSON 相关 `*.g.dart` 文件由构建工具生成，不要手工修改。
- 不提交密钥、令牌、账号密码、本机路径和生成目录。

## 故障排查

### `flutter pub get` 找不到 `dart_video_parse`

确认本项目和 `dart_video_parse` 位于同级目录，并且 `../dart_video_parse` 可以从项目根目录访问。

### 代码生成文件缺失或过期

运行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 保存图片或视频失败

检查设备相册权限、网络连接和媒体链接是否仍然有效。部分短视频直链可能会过期，必要时重新解析链接。

### 解析结果一直来自缓存

缓存有效期默认为 6 小时。可以在设置页清空解析缓存和解析日志，或调整 `VideoParseService.cacheTtl`。
