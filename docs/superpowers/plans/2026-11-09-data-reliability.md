# Diary Data Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** Restore automatic keyword extraction and make backup import preserve existing data on failure.

**Architecture:** Share one complete Rust initialization future. Prepare and validate backup data in an isolated staging directory, swap media with rollback, and commit the database transaction last.

**Tech Stack:** Existing Flutter/Dart, Isar 4, archive 4.0.7, flutter_rust_bridge 2.9.0; py313 toolchain.

**Spec:** ../specs/2026-11-09-data-reliability-design.md

## Global Constraints

- No new dependencies, database schema changes, or backup format changes.
- Preserve substring search and manual tags.
- Test only synthetic data in temporary directories.
- Do not edit generated Rust bindings or checked-in native binaries.

## Review Focus

- Rust initialization may still be running when analysis starts.
- Analysis failure must not clear old fields or block saving text.
- Corrupt, duplicate, escaping, or unsupported ZIP entries must not change live data.
- Database or directory replacement failure must roll back the media directories.
- Cleanup failures after database commit must not report a failed import or remove the new data.

## Task 1: Keyword analysis

**Files:** lib/utils/rust_util.dart; lib/utils/diary_text_analysis.dart; lib/main.dart; lib/pages/edit/edit_logic.dart; related test files.

**Interfaces:** Produce RustUtil.ensureInitialized() -> Future<void>, shared by startup, analysis and backup. Analyzer returns tokens and sorted keywords only after both Rust calls succeed. Root owns lib/persistence/isar.dart integration to avoid concurrent edits.

- [x] Write failing tests for successful analysis, empty content, failure preservation, and initialization readiness.
- [x] Run targeted tests and record the expected failure.
- [x] Restore analysis with topK=5 and allowedPos=[], preserve existing derived data on failure, and wire initialization through the shared future.
- [x] Run targeted tests and review save-path integration.

## Task 2: Safe backup restore

**Files:** lib/utils/backup_restore.dart; lib/utils/file_util.dart; lib/persistence/isar.dart; test/backup_restore_test.dart and database tests.

**Interfaces:** BackupRestore coordinates staging and filesystem rollback with injected external extraction and database preparation boundaries. IsarUtil prepares a validated database replacement and commits it in one transaction.

- [x] Write failing tests proving live files survive malformed backups and failed database commits, and that valid restore replaces all intended data.
- [x] Run targeted tests and record failures.
- [x] Validate ZIP paths, entry types, duplicates, size/CRC, and exactly one database; extract with existing Rust support for Zstd.
- [x] Prepare database contents before live changes, swap media on the same filesystem, commit DB last, roll back failures and close resources.
- [x] Serialize backup operations and ensure database export completes before adding its file to the archive.
- [x] Run targeted tests and real Isar tests where the cached native library is available.

## Integration and completion

- [x] Run all Flutter tests and changed-file analysis with py313 and the existing Flutter SDK.
- [x] Obtain independent review of both fixes and address actionable findings.
- [x] Record actual verification and remaining platform limits; retain the local reviewable branch.

## Progress

- Worktree created at C:/Users/21272/.codex/worktrees/diary-data-reliability/Loong-s-Diary; base 054fcc1.
- Root cause confirmed: empty keyword assignments; live-directory deletion before validation; incompatible Dart/Zstd import; exporting closed the active database. Snapshot/add-to-ZIP ordering is now explicitly awaited instead of depending on the snapshot method's currently synchronous body.
- Offline dependency resolution completed. Flutter's plugin setup reports Windows symlink support unavailable; no system settings changed. Unit tests will be attempted using the resolved packages.

## Verification results

- Final full suite: `flutter --no-version-check test --no-pub --reporter expanded` under py313: **92 passed, 0 failed** (22 original + 70 new).
- Static analysis of all changed Dart implementation and test files: exit 0, no diagnostics.
- Keyword baseline: 9 behavioral failures before restoration; final 13 keyword/initialization/bridge tests pass.
- Backup engine baseline: 45 behavioral failures before implementation; final 45 filesystem/archive tests pass.
- Real Isar tests: 12 pass, including missing/corrupt/truncated DBs, metadata transaction mismatch, ZIP restore with a real DB, and continued editing after export.
- Independent review found an important missing metadata transaction-number check. The failing native test reproduced acceptance of a damaged latest metadata page; checking both transaction numbers on all three pages fixed it. Final review passed with no open findings.

## Scope and remaining platform limits

- The original checkout remains at 054fcc1; changes are retained in the attached codex/diary-data-reliability worktree.
- No new dependencies, generated bindings, database schemas, or prebuilt native libraries changed.
- No new APK was built or installed; real target-device Zstd round-trip and UI testing remain unverified.
- Rollback covers exceptions during an active import. Automatic recovery after process termination is not implemented. If the OS blocks rollback, original media is retained in the rollback directory and the failure is logged.
