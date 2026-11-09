# Loong's Diary

[简体中文](README.zh.md) | English

A personal fork of [Moodiary](https://github.com/ZhuJHua/moodiary), the open-source diary app created by [ZhuJHua](https://github.com/ZhuJHua) and its contributors. This fork retains the Flutter, Rust, Isar and GetX foundation and focuses on daily journaling and data reliability.

The Android release is named **Loongs Diary**. Dart packages and several other platform identifiers still use `moodiary` / `Moodiary`; renaming is not complete across platforms. The source version is `2.7.3+90`, with Flutter `3.32.0` pinned in [.fvmrc](.fvmrc).

See [current development status](docs/DEVELOPMENT.md) for implementation and verification details, and [CHANGELOG](CHANGELOG.md) for recorded changes.

## Current capabilities

- Local diary storage with plain text, Markdown and rich-text editors; photos, audio, video and drawing attachments.
- Search, categories, mood records and statistics; local Rust/Jieba keyword extraction for diary metadata.
- Light/dark themes, custom colors and font imports; password and biometric app unlocking where supported by the device.
- Full-backup import/export, individual diary sharing, LAN transfer and the existing WebDAV sync implementation.
- Manual weather selection: **14 presets and −30 to 50 °C**, with no weather API key required.
- Location recording through system location services. System place-name lookup can require connectivity; when it fails after coordinates are obtained, the diary uses coordinates as the display name.

Recent reliability work restores keyword generation and adds backup validation, staging and rollback on caught restore errors. **Automatic recovery after force termination or a crash is not implemented.** Code and automated checks do not establish that every feature works on every platform; see the development status for the scope of verification.

## Optional services and experimental code

| Capability | Current state and setup |
| --- | --- |
| Weather | Selected manually in the editor. QWeather credentials are not needed for the current flow. |
| Trail map | Uses online map tiles; configure a [Tianditu](http://lbs.tianditu.gov.cn/server/MapService.html) key in Settings → Lab. |
| Online assistant and mood analysis | [Tencent Hunyuan](https://cloud.tencent.com/document/product/1729/97731) integration exists. Configure Tencent Cloud ID and Key in Settings → Lab; requests send conversation content or mood statistics to the service. |
| WebDAV | Configure your server, username and password under backup/sync settings. The app currently uses `lib/utils/webdav_util.dart`; the newer `lib/services/sync/` replacement is unfinished. |
| Local TensorFlow Lite Q&A | Experimental source remains, but model initialization/inference is disabled. It is not an available offline assistant. |
| Supabase, self-hosted server and MinIO | Supabase is not connected, `server/` is a backend skeleton, and MinIO is not enabled. These are not working cloud-sync options. |

Online services require network access and valid provider configuration. Their end-to-end operation has not been newly verified for this revision.

## Platforms and installation

| Platform | Repository status |
| --- | --- |
| Android | App project present; currently targets ARM64 (`arm64-v8a`), Android 8.0 / API 26 or later. Release application ID: `cn.yooss.moodiary.loongs`. |
| iOS / macOS | App projects present; require the Apple toolchain and separate build/device verification. |
| Windows | App project present; requires the Windows desktop toolchain and separate build/runtime verification. |
| Linux / Web | No top-level app project in this checkout. A Rust plugin's Linux directory does not establish Linux app support. |

Check this fork's [Releases](https://github.com/mygqdmmss/Loong-s-Diary/releases) for any published packages and their stated revision. Local build records and APKs do not imply that a GitHub release exists. The current data-reliability changes have not been packaged into a new APK or verified on a physical device.

The in-app update checker still points to **upstream Moodiary releases**. It does not currently track releases of this fork.

## Build from source

### Toolchain

- Flutter **3.32.0** from [.fvmrc](.fvmrc), with Dart **3.8.0 or later** as required by [pubspec.yaml](pubspec.yaml). FVM is optional; the commands below use `flutter` from `PATH`.
- Rust stable with support for Rust edition 2024, plus the target platform's compiler/linker. The checked-in workflows and Cargokit default to stable; no nightly toolchain is pinned.
- For Android: **JDK 21**, Android SDK Platform **36**, Build Tools **36.0.0**, and NDK **28.0.13004108**. The NDK provides the Android Clang/LLVM toolchain.
- For Windows: Visual Studio with the Desktop development with C++ workload and CMake. For iOS/macOS: macOS with Xcode and CocoaPods.

### Get the source and dependencies

```sh
git clone https://github.com/mygqdmmss/Loong-s-Diary.git
cd Loong-s-Diary
flutter --version
flutter doctor -v
flutter pub get
```

Dependency resolution needs network access, including the Git dependencies declared in `pubspec.yaml` and `rust/Cargo.toml`.

### Android configuration

Review [android/app/build.gradle](android/app/build.gradle) before building. Its **release, debug and profile** variants all reference a custom signing configuration. Supply your own keystore at `android/app/key.jks`, set `storePassword` and `keyPassword` in `android/local.properties`, and match the configured alias (`key0`) to your key. Alternatively, change the local signing configuration to suit your development setup. Preserve the SDK paths generated in `local.properties`; keep keystores and passwords out of version control.

The repository contains a prebuilt native library at `android/app/src/main/jniLibs/arm64-v8a/libmoodiary_rust.so` and also configures Rust builds through `rust_builder/` and Cargokit. Cargokit depends on detecting the Flutter Gradle plugin and skips its integration when detection fails. Check the build log and the library included in the APK, especially after Rust changes: the presence of a prebuilt library does not confirm that it matches edited Rust source. Other architectures require corresponding native libraries and build configuration.

After resolving the toolchain, signing and native-library configuration:

```sh
flutter devices
flutter run -d <device-id>
flutter build apk --release --target-platform android-arm64
```

The release APK is normally written to `build/app/outputs/flutter-apk/app-release.apk`.

### Other platform build entry points

Use these commands on the corresponding host after configuring that platform's signing, native libraries and dependencies. They are build entry points, not a claim that all platforms currently build without changes.

| Target | Command |
| --- | --- |
| Windows | `flutter build windows --release` |
| macOS | `flutter build macos --release` |
| iOS | `flutter build ipa --release` |

For development checks, use `flutter test` and `flutter analyze`; recorded results and known limitations belong in [development status](docs/DEVELOPMENT.md).

## Upstream screenshots for reference

These images are retained from Moodiary. They illustrate the upstream design and may differ from this fork's current UI, branding and available features.

### Mobile

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/screenshot/mobile_dark_en.webp">
  <source media="(prefers-color-scheme: light)" srcset="res/screenshot/mobile_light_en.webp">
  <img alt="Upstream Moodiary mobile screenshot, for reference." src="res/screenshot/mobile_light_en.webp">
</picture>

### Desktop

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/screenshot/desktop_dark_en.webp">
  <source media="(prefers-color-scheme: light)" srcset="res/screenshot/desktop_light_en.webp">
  <img alt="Upstream Moodiary desktop screenshot, for reference." src="res/screenshot/desktop_light_en.webp">
</picture>

## Contributing and attribution

Use this fork's [Issues](https://github.com/mygqdmmss/Loong-s-Diary/issues) and [Pull Requests](https://github.com/mygqdmmss/Loong-s-Diary/pulls) for its changes. Include reproduction steps, the affected platform and relevant verification results.

Moodiary's original author, contributors and upstream project remain credited. Upstream community and donation information belongs to [Moodiary](https://github.com/ZhuJHua/moodiary), rather than serving as this fork's official contact or donation channel. Thanks also to Flutter and the open-source projects used by the app, including [Chinese MobileBERT](https://github.com/ymcui/Chinese-MobileBERT), [MobileBERT](https://github.com/google-research/google-research/tree/master/mobilebert) and [ChineseSquad](https://github.com/junzeng-pluto/ChineseSquad) for the retained NLP experiments.

This project is licensed under **AGPL-3.0**. See [LICENSE](LICENSE); retain applicable upstream copyright and license notices when redistributing.
