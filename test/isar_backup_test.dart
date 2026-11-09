import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/models/isar/font.dart';
import 'package:moodiary/persistence/isar_backup.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/backup_restore.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Isar live;
  var instance = 0;

  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final package = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((package) => package['name'] == 'isar_flutter_libs');
    final packageRoot = Directory.fromUri(
      configFile.uri.resolve(package['rootUri'] as String),
    ).uri;
    final library = Platform.isWindows
        ? 'windows/isar.dll'
        : Platform.isMacOS
        ? 'macos/libisar.dylib'
        : 'linux/libisar.so';
    await Isar.initialize(packageRoot.resolve(library).toFilePath());
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('diary-isar-backup-test-');
    final liveDirectory = await Directory(p.join(root.path, 'live')).create();
    live = Isar.open(
      schemas: IsarBackup.schemas,
      directory: liveDirectory.path,
      name: 'live-${instance++}',
      inspector: false,
    );
    live.write((db) {
      db.diarys.put(
        Diary()
          ..id = 'original'
          ..title = '原有日记'
          ..type = 'markdown',
      );
      db.categorys.put(
        Category()
          ..id = 'old'
          ..categoryName = '旧分类',
      );
      db.fonts.put(Font(fontFileName: 'old.ttf', fontWghtAxisMap: {}));
    });
  });

  tearDown(() async {
    if (live.isOpen) live.close();
    await root.delete(recursive: true);
  });

  Future<String> makeBackup() async {
    final directory = await Directory(p.join(root.path, 'source')).create();
    final source = Isar.open(
      schemas: IsarBackup.schemas,
      directory: directory.path,
      name: 'source-${instance++}',
      inspector: false,
    );
    try {
      source.write((db) {
        db.diarys.put(
          Diary()
            ..id = 'restored'
            ..title = '恢复的日记'
            ..contentText = '北京的旅行'
            ..keywords = ['旅行']
            ..tokenizer = ['北京', '旅行']
            ..tags = ['个人标签']
            ..type = 'markdown',
        );
        db.categorys.put(
          Category()
            ..id = 'new'
            ..categoryName = '旅行',
        );
        db.fonts.put(Font(fontFileName: 'new.ttf', fontWghtAxisMap: {}));
      });
      final backup = p.join(root.path, 'backup-${instance++}.isar');
      source.copyToFile(backup);
      return backup;
    } finally {
      source.close();
    }
  }

  test(
    'preparation leaves live data intact and closes the source database',
    () async {
      final path = await makeBackup();
      final backup = await IsarBackup.read(path);
      expect(live.diarys.where().findAll().single.title, '原有日记');
      // On Windows this also verifies the source file is no longer held open.
      await File(path).delete();
      await backup.restoreInto(live);
      final diary = live.diarys.where().findAll().single;
      expect(diary.id, 'restored');
      expect(diary.title, '恢复的日记');
      expect(diary.keywords, ['旅行']);
      expect(diary.tags, ['个人标签']);
      expect(live.categorys.where().findAll().single.categoryName, '旅行');
      expect(live.fonts.where().findAll().single.fontFileName, 'new.ttf');
    },
  );

  test(
    'a missing backup is rejected instead of creating an empty database',
    () async {
      final path = p.join(root.path, 'missing.isar');
      await expectLater(
        IsarBackup.read(path),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(path).exists(), false);
      expect(live.diarys.where().findAll().single.title, '原有日记');
    },
  );

  test('a corrupt database is rejected before live data changes', () async {
    final path = p.join(root.path, 'corrupt.isar');
    await File(path).writeAsString('this is not an Isar database');
    await expectLater(IsarBackup.read(path), throwsA(anything));
    expect(live.diarys.where().findAll().single.title, '原有日记');
    expect(live.categorys.where().findAll().single.categoryName, '旧分类');
  });

  test('export keeps the active application database open', () async {
    final app = await Directory(p.join(root.path, 'app')).create();
    final databaseDirectory = await Directory(
      p.join(app.path, 'database'),
    ).create();
    final active = Isar.open(
      schemas: IsarBackup.schemas,
      directory: databaseDirectory.path,
      inspector: false,
    );
    try {
      active.write(
        (db) => db.diarys.put(
          Diary()
            ..id = 'exported'
            ..title = '导出后继续编辑'
            ..type = 'markdown',
        ),
      );
      await IsarUtil.exportIsar(app.path, root.path, 'export.isar');
      expect(active.isOpen, true);
      expect(active.diarys.where().findAll().single.title, '导出后继续编辑');
      active.write(
        (db) => db.diarys.put(
          Diary()
            ..id = 'after-export'
            ..type = 'markdown',
        ),
      );
      expect(active.diarys.count(), 2);
      expect(await File(p.join(root.path, 'export.isar')).exists(), true);
    } finally {
      if (active.isOpen) active.close();
    }
  });

  test(
    'incomplete latest metadata cannot silently restore an older empty database',
    () async {
      final path = await makeBackup();
      final bytes = await File(path).readAsBytes();
      final data = ByteData.sublistView(bytes);
      final pageSize = data.getUint32(64, Endian.little);
      var latestPage = 0;
      for (var page = 1; page < 3; page++) {
        if (data.getUint64(page * pageSize + 28, Endian.little) >
            data.getUint64(latestPage * pageSize + 28, Endian.little)) {
          latestPage = page;
        }
      }
      final offset = latestPage * pageSize;
      data.setUint64(
        196 + offset,
        data.getUint64(28 + offset, Endian.little) + 1,
        Endian.little,
      );
      await File(path).writeAsBytes(bytes);
      await expectLater(IsarBackup.read(path), throwsA(anything));
      expect(live.diarys.where().findAll().single.title, '原有日记');
    },
  );

  for (final length in [64, 4096, 8192, 12288, 32768]) {
    test(
      'a valid header with a database truncated to $length bytes is rejected',
      () async {
        final path = await makeBackup();
        final handle = await File(path).open(mode: FileMode.append);
        await handle.truncate(length);
        await handle.close();
        await expectLater(IsarBackup.read(path), throwsA(anything));
        expect(live.diarys.where().findAll().single.title, '原有日记');
      },
    );
  }

  for (final validDatabase in [true, false]) {
    test(
      'ZIP restore with a real ${validDatabase ? 'valid' : 'invalid'} database',
      () async {
        final data = await Directory(p.join(root.path, 'data')).create();
        final image = await Directory(p.join(data.path, 'image')).create();
        final oldImage = File(p.join(image.path, 'old.txt'));
        await oldImage.writeAsString('original media');
        final databaseBytes = validDatabase
            ? await File(await makeBackup()).readAsBytes()
            : utf8.encode('invalid database');
        final archive = Archive()
          ..addFile(
            ArchiveFile('diary.isar', databaseBytes.length, databaseBytes),
          )
          ..addFile(ArchiveFile.string('image/new.txt', 'restored media'));
        final zipPath = p.join(root.path, 'restore.zip');
        await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));
        final restorer = BackupRestore(
          // Replace only the native decoder boundary; validation, filesystem
          // operations, Isar preparation and database commit are all real.
          extract: (path, destination) async {
            final decoded = ZipDecoder().decodeBytes(
              await File(path).readAsBytes(),
            );
            for (final entry in decoded.files.where((file) => file.isFile)) {
              final output = File(p.join(destination, entry.name));
              await output.parent.create(recursive: true);
              await output.writeAsBytes(entry.content);
            }
          },
          prepareDatabase: (path) async {
            final backup = await IsarBackup.read(path);
            return () => backup.restoreInto(live);
          },
        );
        final restore = restorer.restore(
          archivePath: zipPath,
          dataPath: data.path,
        );
        if (validDatabase) {
          await restore;
          expect(live.diarys.where().findAll().single.title, '恢复的日记');
          expect(await oldImage.exists(), false);
          expect(
            await File(p.join(image.path, 'new.txt')).readAsString(),
            'restored media',
          );
        } else {
          await expectLater(restore, throwsA(anything));
          expect(live.diarys.where().findAll().single.title, '原有日记');
          expect(await oldImage.readAsString(), 'original media');
          expect(await File(p.join(image.path, 'new.txt')).exists(), false);
        }
      },
    );
  }
}
