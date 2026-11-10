# Loong's Diary

简体中文 | [English](README.md)

这是 [Moodiary](https://github.com/ZhuJHua/moodiary) 的个人 fork。原项目由 [ZhuJHua](https://github.com/ZhuJHua) 与贡献者开发；本分支保留 Flutter、Rust、Isar 和 GetX 技术基础，围绕日常记录与数据可靠性继续调整。

Android release 的应用名称为 **Loongs Diary**。Dart 包名和部分平台标识仍使用 `moodiary` / `Moodiary`，尚未完成全平台更名。当前源码版本为 `2.7.3+90`，[.fvmrc](.fvmrc) 固定 Flutter `3.32.0`。

实现状态与验证范围见[当前开发状态](docs/DEVELOPMENT.md)，改动记录见 [CHANGELOG](CHANGELOG.md)。

## 当前能力

- 本地日记存储，提供纯文本、Markdown 和富文本编辑器；支持图片、音频、视频与绘画附件。
- 搜索、分类、心情记录和统计；通过本地 Rust/Jieba 生成日记关键词等元数据。
- 首页展示菜单可选「月袋」：纸感月份包裹展开为每天一个的照片 / 摘句气泡，再进入当天日记阅读和编辑；保留列表、网格与分类筛选。
- 深浅主题、自定义配色和字体导入；支持密码解锁，以及设备支持的生物识别解锁。
- 完整备份导入/导出、单篇日记分享、局域网传输与既有 WebDAV 同步实现。
- 手选天气：**14 种预设、−30 至 50 °C**，无需天气 API Key。
- 通过系统定位服务记录位置。系统地名反查可能需要网络；取得坐标后若地名反查失败，使用坐标作为位置名称。

最近的数据可靠性改动恢复了关键词生成，并增加备份校验、暂存和捕获恢复异常后的回滚。**尚未实现强制终止或崩溃后的自动恢复。** 源码实现和自动检查并不代表所有平台都已验证可用，具体范围见开发状态文档。

## 可选服务与实验代码

| 能力 | 当前状态与配置 |
| --- | --- |
| 天气 | 在编辑器中手动选择，当前流程无需和风天气凭据。 |
| 足迹地图 | 使用在线地图瓦片，需要在“设置 → 实验室”配置[天地图](http://lbs.tianditu.gov.cn/server/MapService.html) Key。 |
| 在线助手与心情分析 | 已有[腾讯混元](https://cloud.tencent.com/document/product/1729/97731) 接入代码；在“设置 → 实验室”配置腾讯云 ID 与 Key，调用时会向服务商发送对话内容或心情统计。 |
| WebDAV | 在备份与同步设置中填写服务器、用户名和密码。应用目前使用 `lib/utils/webdav_util.dart`，新的 `lib/services/sync/` 替代实现尚未完成。 |
| 本地 TensorFlow Lite 问答 | 保留实验源码，但模型初始化和推理已停用，目前不能作为离线助手使用。 |
| Supabase、自建服务与 MinIO | Supabase 尚未接通，`server/` 仅为后端骨架，MinIO 未启用；这些均不是可用的云同步方案。 |

在线服务需要网络和有效的服务商配置。本次修订没有新增这些服务的端到端验证。

## 平台与安装

| 平台 | 仓库状态 |
| --- | --- |
| Android | 有应用工程；当前面向 ARM64（`arm64-v8a`），最低 Android 8.0 / API 26。Release 应用 ID 为 `cn.yooss.moodiary.loongs`。 |
| iOS / macOS | 有应用工程，需要 Apple 工具链，并分别验证构建与设备运行。 |
| Windows | 有应用工程，需要 Windows 桌面工具链，并分别验证构建与运行。 |
| Linux / Web | 当前没有顶层应用工程。Rust 插件中的 Linux 目录不代表已支持 Linux 应用。 |

如需已发布的安装包，请查看本 fork 的 [Releases](https://github.com/mygqdmmss/Loong-s-Diary/releases) 及其中标注的源码版本。最新本地 Android ARM64 包为 `b8c5c78` 的 `2.7.3+93`，修复了 build 91 / 92 缺少原生插件注册的问题；**不要再安装或分发 build 91 / 92**。build 93 沿用原包名与签名，可直接覆盖更新。本次未发布 GitHub Release，用户手机上的启动结果尚待确认。见[开发状态](docs/DEVELOPMENT.md)及[安卓打包检查](docs/ANDROID_RELEASE.md)。

应用内的更新检查目前仍指向 **Moodiary 上游 Release**，尚未跟踪本 fork 的发布。

## 从源码构建

### 工具链

- 使用 [.fvmrc](.fvmrc) 指定的 Flutter **3.32.0**；[pubspec.yaml](pubspec.yaml) 要求 Dart **3.8.0 或更新版本**。可用 FVM 管理版本，以下命令使用 `PATH` 中的 `flutter`。
- 支持 Rust 2024 edition 的 Rust stable，以及目标平台的编译器和链接器。仓库工作流和 Cargokit 默认使用 stable，未固定 nightly 工具链。
- Android：**JDK 21**、Android SDK Platform **36**、Build Tools **36.0.0**、NDK **28.0.13004108**。Android 所需 Clang/LLVM 由 NDK 提供。
- Windows：安装包含“使用 C++ 的桌面开发”工作负载和 CMake 的 Visual Studio。iOS/macOS：使用 macOS、Xcode 和 CocoaPods。

### 获取源码与依赖

```sh
git clone https://github.com/mygqdmmss/Loong-s-Diary.git
cd Loong-s-Diary
flutter --version
flutter doctor -v
flutter pub get
```

依赖解析需要联网，包括 `pubspec.yaml` 和 `rust/Cargo.toml` 中的 Git 依赖。

### Android 配置

构建前检查 [android/app/build.gradle](android/app/build.gradle)。其中 **release、debug、profile** 都引用自定义签名配置。请在 `android/app/key.jks` 提供自己的密钥库，在 `android/local.properties` 中设置 `storePassword`、`keyPassword`，并让配置中的别名（`key0`）与密钥一致；也可以按本地开发需求调整签名配置。保留 `local.properties` 中自动生成的 SDK 路径，不要把密钥库和密码提交到版本控制。

仓库在 `android/app/src/main/jniLibs/arm64-v8a/libmoodiary_rust.so` 中包含预编译原生库，同时通过 `rust_builder/` 和 Cargokit 配置 Rust 构建。Cargokit 依赖 Flutter Gradle 插件识别，识别失败时会跳过集成。修改 Rust 后尤其需要检查构建日志与 APK 中的实际原生库：预编译库的存在并不代表它与修改后的 Rust 源码一致。其他架构需要对应原生库及构建配置。

完成工具链、签名和原生库配置后执行：

```sh
flutter devices
flutter run -d <device-id>
flutter build apk --release --target-platform android-arm64
```

Release APK 通常位于 `build/app/outputs/flutter-apk/app-release.apk`。

### 其他平台构建入口

在对应宿主系统上配置好平台签名、原生库和依赖后，可使用以下命令。这些命令是构建入口，不代表目前所有平台均能直接编译通过。

| 目标 | 命令 |
| --- | --- |
| Windows | `flutter build windows --release` |
| macOS | `flutter build macos --release` |
| iOS | `flutter build ipa --release` |

开发检查可使用 `flutter test` 和 `flutter analyze`；已记录的结果与已知限制见[开发状态](docs/DEVELOPMENT.md)。

## 上游截图参考

以下图片保留自 Moodiary，仅用于展示上游设计；可能与本 fork 当前的界面、品牌和功能状态不同。

### 移动端

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/screenshot/mobile_dark_zh.webp">
  <source media="(prefers-color-scheme: light)" srcset="res/screenshot/mobile_light_zh.webp">
  <img alt="Moodiary 上游移动端截图，仅供参考。" src="res/screenshot/mobile_light_zh.webp">
</picture>

### 桌面端

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/screenshot/desktop_dark_zh.webp">
  <source media="(prefers-color-scheme: light)" srcset="res/screenshot/desktop_light_zh.webp">
  <img alt="Moodiary 上游桌面端截图，仅供参考。" src="res/screenshot/desktop_light_zh.webp">
</picture>

## 贡献与署名

本 fork 的问题与改动请使用本仓库的 [Issues](https://github.com/mygqdmmss/Loong-s-Diary/issues) 和 [Pull Requests](https://github.com/mygqdmmss/Loong-s-Diary/pulls)，附上复现步骤、受影响平台和相关验证结果。

保留 Moodiary 原作者、贡献者及上游项目署名。上游社区和捐助信息请前往 [Moodiary](https://github.com/ZhuJHua/moodiary)，它们并非本 fork 的官方联系或捐助渠道。同时感谢 Flutter 和项目使用的开源组件，以及为保留的 NLP 实验提供基础的 [Chinese MobileBERT](https://github.com/ymcui/Chinese-MobileBERT)、[MobileBERT](https://github.com/google-research/google-research/tree/master/mobilebert) 和 [ChineseSquad](https://github.com/junzeng-pluto/ChineseSquad)。

本项目采用 **AGPL-3.0** 许可证，详见 [LICENSE](LICENSE)；重新分发时请保留适用的上游版权和许可声明。
