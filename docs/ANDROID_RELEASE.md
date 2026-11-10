# Android 安装包检查

2026-11-10：本地 build 91 / 92 缺少 `GeneratedPluginRegistrant`，已确认不适合继续分发。签名、ZIP 校验和 Dart 测试通过不能证明平台插件已注册。缺失注册会使启动最早的 SharedPreferences 平台调用失败，应用可能停在启动图标。此次修复不改变日记、数据库结构、备份格式或 Rust 库。

## 构建前

在实际构建的 checkout / worktree 内完成 Flutter 平台文件生成：

```text
flutter pub get --offline
```

只有命令完整成功后才可依赖 `--no-pub`。`GeneratedPluginRegistrant.java` 是 Git 忽略的生成物，新 worktree 不会继承它；`.flutter-plugins-dependencies` 存在也不能代替注册文件。

若 Windows 已完成依赖解析、依赖全部在缓存内，但仅因桌面插件符号链接权限导致最后的平台生成失败，可以只生成 Android 注册代码：

```powershell
.\tool\generate_android_plugins.ps1 -FlutterSdk 'D:\Flutter\flutter'
```

该工具调用指定 SDK 自带的 Android 生成器，不修改 Windows 开发者模式、全局 Flutter 配置或应用依赖。要求 app 与 SDK 的 package_config 均已存在；它不处理依赖解析失败，也不能替代新依赖所需的正常 `pub get`。已在 Flutter 3.32.8 验证。

Android `preBuild` 现在会检查生成文件和 SharedPreferences 注册；缺失时直接使构建失败，避免再次产出缺少启动插件的包。

## 构建与包检查

```text
flutter --no-version-check build apk --release --target-platform android-arm64 --build-name=2.7.3 --build-number=93 --no-pub
python tool/verify_android_plugins.py --apk build/app/outputs/flutter-apk/app-release.apk
```

Python 工具只使用标准库，检查 DEX 中实际定义的注册类及有实现的 public static `registerWith` 方法。只存在反射字符串不能通过。它支持 multidex，不替代签名校验或真机启动测试。

还应核对包名、构建号、ABI、签名证书、ZIP 完整性及对齐。版本号应递增；保持包名与签名可供覆盖更新。不要通过卸载或清空用户数据解决打包问题。

本次回归证据：原 build 90 通过注册检查，build 91 / 92 均失败；验证工具的 9 项接受检查通过。修复前 Gradle 检查按预期失败，使用当前 SDK 生成 34 个 Java 插件注册项后通过；另两个 Android 插件为 FFI 插件，无 Java 注册项。最终修复包的验证记录见 [DEVELOPMENT.md](DEVELOPMENT.md)。
