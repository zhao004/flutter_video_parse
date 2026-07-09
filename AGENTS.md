# Repository Guidelines

## Project Structure & Module Organization

本仓库是 Flutter 应用项目。入口文件位于 `lib/main.dart`；业务代码按功能放在 `lib/app/` 下：`pages/` 存放页面、控制器和绑定，
`routes/` 管理 GetX 路由，`database/` 存放 Drift 数据库、表和类型转换器，`http/` 存放 Retrofit/Dio 客户端，`models/`
存放数据模型。测试文件位于 `test/`，Android 平台代码位于 `android/`。生成文件如 `*.g.dart` 由构建工具维护，不要手工修改。

## Build, Test, and Development Commands

- `flutter pub get`：安装或同步依赖。
- `dart run build_runner build --delete-conflicting-outputs`：重新生成 Drift、JSON 和 Retrofit 相关代码。
- `flutter analyze`：运行静态检查和 `flutter_lints` 规则。
- `flutter test`：运行单元测试和 Widget 测试。
- `flutter run`：在已连接设备或模拟器上启动应用。
- `flutter build apk`：构建 Android APK。

## Coding Style & Naming Conventions

遵循 Dart 官方格式和 `flutter_lints`。提交前运行 `dart format lib test` 和 `flutter analyze`。文件名使用 `snake_case.dart`
，类和 Widget 使用 `UpperCamelCase`，变量、方法和路由名称使用 `lowerCamelCase`。页面相关文件保持同一目录内的 `*_view.dart`、
`*_controller.dart`、`*_binding.dart` 命名模式。公共 Widget、服务和数据访问逻辑应拆分为可复用模块，避免在页面中堆叠网络、数据库和状态逻辑。

## Testing Guidelines

测试基于 `flutter_test`。新增业务逻辑应配套单元测试；新增页面交互应配套 Widget 测试。测试文件命名使用 `*_test.dart`
，并放在与被测模块对应的 `test/` 路径中。涉及网络或数据库时优先使用 mock、fake 或临时数据库，避免测试依赖外部服务和本机固定状态。

## Commit & Pull Request Guidelines

当前目录没有可读取的 Git 历史，因此提交信息采用仓库通用规则：中文、简洁、说明意图，例如 `修复首页数据加载异常`。Pull Request
应包含变更摘要、测试结果、关联 issue；涉及界面变化时附截图或录屏；涉及数据库、路由或生成代码时说明迁移影响和重新生成命令。

## Security & Configuration Tips

不要提交密钥、令牌、账号密码或本机路径。Android 本地配置保留在 `android/local.properties`
。新增环境配置时优先通过平台配置、环境变量或构建参数注入。提交前避免包含 `.dart_tool/`、`build/`、`.git/`、`pubspec.lock`
等受限或生成内容。
