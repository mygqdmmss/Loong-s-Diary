# 当前开发状态

更新日期：2026-11-10。本文用于说明这个个人维护分支的实际进度；历史设计和实施计划见文末链接。

## 版本与技术栈

| 项目 | 当前情况 |
|---|---|
| 项目 | Loong-s-Diary，基于 Moodiary 的个人分支 |
| 应用版本 | [`pubspec.yaml`](../pubspec.yaml) 仍为 `2.7.3+90`；最新本地 Android APK 为 `6c8e504` 的 `2.7.3+92`（月袋界面），先前 `64313aa` 的 build 91 保留。构建号通过命令行覆盖 |
| Flutter / Dart | [`.fvmrc`](../.fvmrc) 固定 Flutter `3.32.0`；2026-11-09 本机验证使用 Flutter `3.32.8` / Dart `3.8.1`。`pubspec.yaml` 要求 Dart `>=3.8.0` |
| 界面与状态 | Flutter、GetX、Flutter Quill / Markdown，中英文 ARB 本地化 |
| 本地数据 | Isar `4.0.0-dev.14` 保存日记、分类和字体；偏好设置、缓存与媒体文件另行存储 |
| 原生能力 | Rust + `flutter_rust_bridge 2.9.0`，包含 Jieba 文本分析、ZIP/Zstd、加密和媒体处理等接口 |

应用版本、开发分支提交和安装包是三件独立的事。看到 `2.7.3+90` 不能判断设备上是否已经包含本页记录的修复。

## 个人分支的近期改动

| 日期 / 提交 | 已落地内容 |
|---|---|
| 2026-05-16，`d120894` 至 `536f3c8` | 天气改为手选 14 项预设与温度；地点改为系统地名反查，失败时显示坐标。保留旧数据格式和旧和风天气配置 |
| 2026-07-11，`054fcc1` | 修复 Rust FFI，调整搜索、备份导出、日记详情与编辑流程 |
| 2026-11-09，`cca6d84` | 恢复自动分词与关键词，统一等待 Rust 初始化；备份导入增加暂存校验、数据库校验、目录替换和异常回滚 |
| 2026-11-09，文档与界面文案对齐 | 更新 README、当前开发状态入口和历史计划，修正天气 / 定位、旧和风天气配置、关键词重新生成入口的说明 |
| 2026-11-09，Android 本地安装包 | 从 `64313aa` 构建 `2.7.3+91` ARM64 Release APK；签名、包名、ZIP 完整性和对齐检查通过，尚未安装到真机 |
| 2026-11-10，`6c8e504`，月袋与每日光影 | 新增可切换的月份包裹、每日照片 / 摘句气泡及当天日记阅读，支持分类与实时更新；完成 build 92 APK 和包校验 |

## 已实现功能与使用边界

| 功能 | 当前行为 |
|---|---|
| 日记与整理 | 已有文本、富文本和 Markdown 编辑，多媒体、分类、标签、日历、统计和回收站等界面与实现；本轮没有逐项做设备验收 |
| 月袋与每日光影 | 首页右上角展示菜单新增「月袋」。纸质月份包裹 → 每天一个照片 / 摘句气泡 → 当天一篇或多篇日记 → 原有详情和编辑；支持分类、月份切换、纯文字与媒体占位，旧月份不受首页分页限制。按本地日历日期分组，修改日期 / 分类、回收后自动更新；深浅主题、大字号和减少动态效果均有对应处理 |
| 天气 | 用户手选 14 种天气和 `-30～50°C` 温度，默认沿用当前记录，无法识别时回退到晴 / `20°C`；不自动获取实况天气或预报 |
| 地点 | 使用 `geolocator` 取坐标，交给系统地理编码服务反查地名；已有坐标但反查失败时显示经纬度，无法定位时保留原地点。系统服务本身可能依赖网络，不能保证断网时返回地名 |
| 自动关键词 | 保存时通过 Rust/Jieba 分词并提取最多 5 个 TF-IDF 关键词；完整分析成功才更新派生字段，失败保留已有值并继续保存正文，空正文清空派生字段。已有日记可从实验室入口重新生成 |
| 搜索 | 按空白拆分搜索词，每个词都必须在标题或正文中命中子串（AND），忽略大小写，只搜索未进入回收站的日记，按时间倒序。关键词恢复没有改变此规则，也未启用语义搜索或基于分词字段的全文索引 |
| 备份导出 | 使用数据库快照，等待快照完成后再加入压缩包；导出后保持当前数据库可继续编辑 |
| 备份导入 | 全量替换语义：先检查 ZIP 结构、条目路径和重复项，再解压到独立临时目录，核对文件长度 / CRC 和 Isar/MDBX 元数据并读取数据库；校验通过后替换媒体目录，最后用一个 Isar 事务替换数据。缺少的可选媒体目录按空目录处理 |
| 导入失败处理 | 校验失败不会开始替换现有数据；替换期间抛出异常时回滚媒体目录。若系统阻止回滚，保留回滚目录中的原媒体并记录错误。进程被强制终止后的自动恢复尚未实现 |
| WebDAV / 局域网 | 保留现有配置与同步路径，本轮未做联网端到端验收。`lib/services/sync/` 中的新同步抽象仍有未实现方法，不能视为所有同步后端均已完成 |

## 依赖配置或尚未接通的功能

| 功能 | 状态 |
|---|---|
| 在线 AI 助手 / AI 分析 | 已有腾讯混元调用路径，需要用户自己的腾讯云 ID、Key 及可用网络；本轮未验证在线服务 |
| 地图 | 已有天地图展示路径，需要天地图 Key 和网络；不影响手选天气 |
| 旧和风天气设置 | `qweatherKey` / `qweatherApiHost` 仍保留以兼容既有设置，但当前天气和地名流程不再使用它们 |
| 本地 TFLite 问答 | 保留模型运行相关代码，但模型初始化和问答调用未接通，不能作为可用的离线 AI 功能 |
| Supabase 账户 / 云端存储 | 保留原型代码；初始化未接通，服务 URL 和匿名 Key 为空，不能作为可用云同步 |
| MinIO | 同步实现仍被注释，未完成 |

## 验证记录与平台范围

2026-11-09 数据可靠性修复的验证记录见[实施计划](superpowers/plans/2026-11-09-data-reliability.md#verification-results)，对应代码提交 `cca6d84`：

- `flutter --no-version-check test --no-pub --reporter expanded`：**92 项通过，0 项失败**，包括天气 / 地名工具、文本分析与初始化、备份校验 / 回滚等测试。
- 其中 12 项使用本机缓存的真实 Isar 原生库，覆盖损坏 / 截断数据库、元数据事务号不一致、真实数据库的 ZIP 恢复，以及导出后继续编辑。
- 该修复涉及的 Dart 实现和测试文件静态分析无诊断。这是变更文件的结果，不能等同于全工程 `flutter analyze` 已全部通过。
- 测试使用合成数据和临时目录，没有导入、恢复或覆盖用户真实日记。

同日完成文档与界面文案对齐后，重新验证结果如下：

- `flutter --no-version-check gen-l10n` 成功；中英文 ARB 均可解析，311 个翻译键一致。
- 再次运行上述完整 Flutter 测试命令：**92 项通过，0 项失败**。
- 日记设置、实验室两个页面及三个生成的本地化 Dart 文件静态分析无诊断；两个页面通过格式检查。
- 独立审阅未发现问题，检查的 58 处本地链接 / 路径均存在，`git diff --check` 通过。

| 平台 / 路径 | 验证边界 |
|---|---|
| Windows 开发环境 | 上述 Flutter 测试和真实 Isar 测试已记录通过；依赖解析曾提示 Windows 符号链接支持不可用，本轮未修改系统设置或验证桌面应用完整构建 |
| Android | 已构建 build 91 与带月袋界面的 build 92 ARM64 Release APK，并完成包内容与签名校验；未连接 Android 设备，仍缺少逐项真机验收记录 |
| iOS / macOS | 仓库保留平台工程，本轮未构建或真机验证 |
| Rust / Zstd 目标设备往返 | 尚未在目标设备验证真实 Rust 导出、导入、媒体和数据库的一整套往返；Dart 测试与真实 Isar 测试不能替代该验收 |

### Android 安装包记录

- 文件：`build/releases/Loongs-Diary-2.7.3-build91-64313aa-arm64.apk`，74,283,065 字节（约 70.8 MiB）；该目录是本地产物，不进入版本控制。
- 构建命令：`flutter --no-version-check build apk --release --target-platform android-arm64 --build-name=2.7.3 --build-number=91 --no-pub`。
- 包名 `cn.yooss.moodiary.loongs`，最低 API 26，目标 API 36；APK v2 / v3 签名验证通过，签名证书与 2026-07-11 的旧 APK 一致，构建号由 90 增至 91。
- SHA-256：`94fea9ae256423a11e4236b9d7dcb1aff742e440ee89a12ab21ee2b3123fa05e`。
- CargoKit 未识别 Flutter 插件，使用仓库已有的 Android 原生库；APK 中经过符号裁剪的 Rust 库与旧 APK 逐字节相同。此次修复没有修改 Rust 源码或生成的桥接文件。
- APK 包含关键词、备份可靠性和文案修复；月份包裹新界面不包含在 build 91 中，后续实现和 build 92 记录另列。本次未发布 GitHub Release，也未进行设备安装或运行验证。

### 月袋版本 build 92 验证与安装包（2026-11-10）

- 源码：`6c8e50466db64815922c78941a43acb07ee6ce78`，分支 `codex/monthly-memories`。
- 文件：`build/releases/Loongs-Diary-2.7.3-build92-6c8e504-arm64.apk`，74,415,161 字节（约 71.0 MiB）。旁附 SHA-256 与 `BUILD92-INFO.txt`；build 91 未覆盖。
- SHA-256：`4de4fad579ee8e94ae1d9413d1250d6b5b7cace1f16c76d0c231e2a8bd0a76ff`。
- 使用 Flutter 3.32.8 / Dart 3.8.1 与 conda `py313` 工具链，命令为 `flutter --no-version-check build apk --release --target-platform android-arm64 --build-name=2.7.3 --build-number=92 --no-pub`。
- 最终源码完整测试 **128 项通过，0 项失败**；变更 Dart 文件静态分析无诊断。真实 Flutter 组件的 9 项渲染 / 交互检查及 2 项摘句月袋深浅色检查通过，涵盖 320px / 1.8 倍文字与 31 天点击可达性。测试使用合成内容；未读写用户日记，未将示例照片或字体加入应用。
- 独立审阅通过，审阅中发现的纯文字月袋缺少真实摘句已修复并复核。没有待处理的阻断项。
- 包名 `cn.yooss.moodiary.loongs`，构建号 92，ARM64，最低 API 26，目标 API 36；APK v2 / v3 签名、ZIP 完整性与 zipalign 校验通过，签名证书与 build 91 一致。
- CargoKit 仍未识别 Flutter 插件；包中的 Rust 原生库与 build 91 逐字节相同，本轮未修改 Rust 源码、桥接或原生库。
- 应用内入口：**首页右上角展示菜单 → 月袋**。尚未连接真机安装或验证原生运行，也未上传 GitHub Release。

## 开发入口

先进入准备修改的仓库目录，确认当前分支、提交和本地改动：

```bash
git status --short
git branch --show-current
git log -5 --oneline
git worktree list
flutter --version
```

建议用 FVM 对齐 `.fvmrc`；使用其他 SDK 时，在测试结果中记录实际版本。

已检查的 Windows 开发机使用 conda 环境 `py313` 提供 Rust / Cargo 和 JDK 工具链，可先执行 `conda activate py313`。Flutter SDK 独立安装，不在该 conda 环境内；激活后仍需用 `flutter --version` 核对实际使用的版本。其他开发机按 README 配置工具链即可，无需使用相同的 conda 环境名。

常用命令如下，使用 FVM 时在 `flutter` 前加 `fvm`：

```bash
flutter pub get
flutter gen-l10n
flutter test
flutter analyze
flutter devices
flutter run -d <device-id>
```

依赖已经缓存时可用 `flutter pub get --offline`；解析完成后可用 `flutter test --no-pub` 避免重复解析。涉及 Rust 或平台插件时还需要匹配的平台工具链，生成代码和已有原生库不能代替对应平台的构建验证。

| 要修改的部分 | 主要入口 |
|---|---|
| 启动、初始化 | [`lib/main.dart`](../lib/main.dart)、[`lib/utils/rust_util.dart`](../lib/utils/rust_util.dart) |
| 日记编辑、天气、地点 | [`lib/pages/edit/`](../lib/pages/edit/)、[`lib/components/weather_picker_sheet.dart`](../lib/components/weather_picker_sheet.dart)、[`lib/api/api.dart`](../lib/api/api.dart) |
| 文本分析与搜索 | [`lib/utils/diary_text_analysis.dart`](../lib/utils/diary_text_analysis.dart)、[`lib/components/search_sheet/`](../lib/components/search_sheet/)、[`lib/persistence/isar.dart`](../lib/persistence/isar.dart) |
| 备份导入与导出 | [`lib/utils/file_util.dart`](../lib/utils/file_util.dart)、[`lib/utils/backup_restore.dart`](../lib/utils/backup_restore.dart)、[`lib/persistence/isar_backup.dart`](../lib/persistence/isar_backup.dart) |
| 文案与实验入口 | [`lib/l10n/`](../lib/l10n/)、[`lib/pages/laboratory/`](../lib/pages/laboratory/) |
| 月袋与每日光影 | [`lib/components/monthly_diary/`](../lib/components/monthly_diary/)、[`lib/pages/monthly_diary/`](../lib/pages/monthly_diary/)、[`lib/persistence/monthly_diary_repository.dart`](../lib/persistence/monthly_diary_repository.dart) |
| 原生实现与测试 | [`rust/src/api/`](../rust/src/api/)、[`test/`](../test/) |

本轮修复在 `codex/diary-data-reliability` 的独立 Git worktree 中完成。日常使用的原目录（例如 `D:/Code/Loong-s-Diary`）与 worktree 是不同的检出目录：它们共享 Git 提交和分支信息，但工作文件不会自动同步。继续开发或运行应用前，应在实际使用的目录核对提交；需要把修复带回原目录时，通过 Git 合并相应分支或提交，并保留原目录已有的未提交改动。

## 历史记录

- [离线天气与定位设计](superpowers/specs/2026-05-16-offline-weather-location-design.md)：2026-05-16 的已落地历史方案，示例代码保留原设计语境。
- [离线天气与定位实施计划](superpowers/plans/2026-05-16-offline-weather-location.md)：顶部给出任务与提交的对应关系，未勾步骤不代表需要重新实现。
- [关键词与备份可靠性设计](superpowers/specs/2026-11-09-data-reliability-design.md)及[实施与验证记录](superpowers/plans/2026-11-09-data-reliability.md)：记录修复范围、测试结果和剩余平台限制。
- [月袋与每日光影设计](superpowers/specs/2026-11-09-monthly-memories-design.md)及[实施与验证记录](superpowers/plans/2026-11-09-monthly-memories.md)：用户选择的混合界面、按天分组与新 APK 的验证范围。

后续完成设备验收、功能接通或发布安装包时，同步更新本页的日期、验证环境和范围。
