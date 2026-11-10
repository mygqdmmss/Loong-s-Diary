# Monthly Memories Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development with independent file ownership and root integration. The user approved the hybrid visual direction and day-level grouping in the interactive preview.

**Goal:** Ship an optional monthly paper-package home view, floating daily photo bubbles, and editable daily reading navigation.

**Architecture:** A tested Isar adapter supplies month summaries and local-date groups. Reusable artwork widgets are independent of persistence. Stateful sliver/pages subscribe to data changes and use the existing diary detail route without its paginated-card assumptions.

**Tech Stack:** Existing Flutter 3.32 / Dart 3.8, GetX, Isar 4, intl and image cache; no new packages.

**Spec:** ../specs/2026-11-09-monthly-memories-design.md

## Global Constraints

- Keep list=0 and grid=1; monthly=2. Preserve category filtering and existing APK build 91.
- Month package → one bubble per local calendar day → that day's entries → existing editable diary detail.
- Exclude recycled entries; use local half-open date ranges, not persisted yM/yMd strings.
- No database schema, backup-format, Rust, native-library or dependency changes; never read/change/stage user `.vscode/`.
- Root owns integration, localization, commits and full-suite verification. Independent implementers own only their assigned new files.
- Responsive from 320px, support large text, light/dark themes and reduced motion; decorative pictures must not capture taps.

## Review Focus

- An older month absent from the first 30 home entries remains visible and editable.
- UTC-imported records and local midnight boundaries appear in exactly one day/month.
- Moving/deleting the last diary updates day and month counts without stale indexes or disposed-state updates.
- Missing photos, empty titles, 31 populated days and larger text leave every day tappable and identifiable.
- Switching categories/view modes during asynchronous work does not leak old data or continue normal diary pagination in monthly mode.

## Task 1: Month/day data source

**Files:** New `lib/components/monthly_diary/monthly_diary_models.dart`, `lib/persistence/monthly_diary_repository.dart`, `test/monthly_diary_repository_test.dart`.

**Interfaces:** Immutable `DiaryMonth(month, dayCount, entryCount)`; `DiaryDay(day, entries)` with `List<Diary> entries` sorted newest first, first photo-bearing entry cover and useful excerpt. Abstract `MonthlyDiarySource`: `loadMonths({String? categoryId})`, `loadDays(DateTime month, {String? categoryId})`, `loadDay(DateTime day, {String? categoryId})`, `watchChanges() -> Stream<void>`. `MonthlyDiaryRepository(Isar)` implements it. Return types are respectively `Future<List<DiaryMonth>>`, `Future<List<DiaryDay>>`, `Future<List<Diary>>`.

- [x] Write and run failing behavior tests for grouping, visibility/category, cross-year order, local date boundaries and queries beyond home pagination.
- [x] Implement the immutable data models and Isar adapter; month summaries use time projection, days use local ranges; no schema changes.
- [x] Run targeted tests, record red/green evidence and obtain scoped data review.

## Task 2: Crafted package and bubble widgets

**Files:** New `lib/components/monthly_diary/memory_artwork.dart`, `lib/components/monthly_diary/month_package_card.dart`, `lib/components/monthly_diary/memory_bubble_field.dart`, `test/monthly_memory_widgets_test.dart`.

**Interfaces:** `MonthPackageCard` takes `DateTime month`, `String title/subtitle/openLabel/semanticsLabel`, `List<Widget> photos`, `VoidCallback onTap`. `MemoryDayBubble` takes `DateTime day`, `String dateLabel/excerpt/semanticsLabel`, `int entryCount`, optional `Widget photo`, optional `Color accent`, `VoidCallback onTap`. `MemoryBubbleField` takes `List<Widget> children` and lays them out in a stable asymmetric field with scrolling delegated to its parent. Components use no GetX/persistence/localization globals.

- [x] Write and run failing interaction/layout tests: package tap, bubble tap, text-only day, 31 nodes reachable, narrow width / large text, reduced motion.
- [x] Implement paper material and folds, peeking pictures, organic photo masks, soft short text shapes, restrained animation and stable varied positions. Images are supplied widgets; clipping must not steal the outer tap.
- [x] Run focused tests, save actual Flutter render examples with synthetic content, obtain scoped artwork review.

## Task 3: Home, navigation and localization integration

**Files:** New `lib/components/monthly_diary/monthly_diary_sliver.dart`, `lib/pages/monthly_diary/monthly_diary_page.dart`, `lib/pages/monthly_diary/monthly_day_page.dart`, `lib/pages/monthly_diary/monthly_diary_navigation.dart`, `test/monthly_diary_navigation_test.dart`; modify view-mode enum, home view/logic, diary-tab view, IsarUtil adapter getter and l10n ARBs/generated files.

- [x] Add tests for persisted mode values, monthly/day navigation and live changes using an injectable fake source; verify failures before integration.
- [x] Add the source getter and monthly view menu; monthly sliver owns its complete summaries independently of existing pagination. Skip ordinary pagination in this mode.
- [x] Add lazy month covers, month switching, daily bubble page and daily entry page. Subscribe/unsubscribe collection changes, surface retry/empty states, and use mounted checks across awaits.
- [x] Route into existing editable details; refresh registered home lists safely after return without assuming the diary exists in a paginated list.
- [x] Add bilingual user copy, regenerate localization, run navigation and full tests and changed-file analysis.
- [x] Review actual Flutter screenshots, complete independent whole-change review, fix findings, build and verify signed ARM64 APK build 92, update development status.

## Progress and rulings

- Base: `39cfd6a`. Reuse attached worktree; branch `codex/monthly-memories`.
- User explicitly selected hybrid outer paper bags / inner light bubbles and one bubble per day. No additional visual-direction approval is needed.
- Tasks 1 and 2 have disjoint files and interfaces; run them concurrently under the session's proactive delegation instruction. Root implements Task 3 and owns Git mutations, avoiding parallel commits.
- Task 3 consumes Task 1 DTO/source and Task 2 widgets exactly as defined. Neither worker edits integration or localization.
- Baseline, targeted verification, reviews, artifacts and remaining device limits will be recorded here as they complete.

## Verification through 2026-11-10

- Baseline: 92 existing tests passed. Final implementation including real text notes: 128 tests passed, 0 failures (`flutter --no-version-check test --no-pub --reporter expanded`).
- Real Isar tests cover calendar boundaries, category/visibility, older months beyond pagination, representative photos and lazy changes. Navigation tests cover multiple entries, deleting/moving the last entry, category/source races, retries and month switching.
- Artwork tests cover 31 reachable/disjoint targets, 320px and large text, light/dark themes, stable date/hit regions during bounded ambient motion, reduced motion and disabled-first-mount disposal.
- Changed implementation/test files analyzed without diagnostics. The final text-note patch's two files were analyzed again with no issues.
- Nine scratch Flutter rendering/interaction checks passed using synthetic entries and photos, including integrated month/day pages at 320px with 1.8x text and dark420. Screenshots inspected directly; sample content/fonts were not added to app assets.
- Independent component review passed. Whole-change review found one gap: actual text notes in all-text month bags. A focused red/green test verifies the correction at320px/1.8x text; final scoped review is recorded with the artifact results below.
- All work remains in the existing managed worktree on codex/monthly-memories. The original D:/Code/Loong-s-Diary checkout and user .vscode files are untouched.

## Completed artifact

- Code commit 6c8e504; final scoped re-review: spec PASS, quality PASS, no remaining actionable findings. Two additional 320px/1.8x light/dark real-note visual checks passed and were inspected.
- Final build 92 succeeded in 166.2s after final source patch. APK size 74415161 bytes, SHA-256 `4de4fad579ee8e94ae1d9413d1250d6b5b7cace1f16c76d0c231e2a8bd0a76ff`.
- Package/version, ARM64 ABI, v2/v3 signing, zipalign and ZIP CRC checks passed. Signature matches build 91; stripped Rust library byte-identical. Build 91 preserved, no device installation or GitHub Release performed.
- Artifact: `build/releases/Loongs-Diary-2.7.3-build92-6c8e504-arm64.apk`; details in `docs/DEVELOPMENT.md` and local `build/releases/BUILD92-INFO.txt`.
