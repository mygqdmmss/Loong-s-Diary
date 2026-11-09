import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/utils/backup_restore.dart';
import 'package:path/path.dart' as p;

void main() {
  late _Fixture fixture;

  setUp(() async {
    fixture = await _Fixture.create();
  });

  tearDown(() async {
    await fixture.root.delete(recursive: true);
  });

  test(
    'malformed ZIP leaves database and every media directory intact',
    () async {
      await fixture.archive.writeAsString('not a zip');
      await fixture.expectRejected();
    },
  );

  final unsafeEntries = <String, List<_Entry>>{
    'parent traversal': [_Entry('../escape', 'bad')],
    'nested traversal': [_Entry('image/../escape', 'bad')],
    'absolute path': [_Entry('/image/escape', 'bad')],
    'drive path': [_Entry('C:/image/escape', 'bad')],
    'drive relative path': [_Entry('C:escape', 'bad')],
    'backslash traversal': [_Entry(r'image\..\escape', 'bad')],
    'UNC path': [_Entry(r'\\server\image\escape', 'bad')],
    'empty component': [_Entry('image//escape', 'bad')],
    'dot component': [_Entry('image/./escape', 'bad')],
    'alternate data stream': [_Entry('image/file:stream', 'bad')],
    'Windows reserved name': [_Entry('image/NUL.txt', 'bad')],
    'trailing dot': [_Entry('image/file.', 'bad')],
    'trailing space': [_Entry('image/file ', 'bad')],
    'unknown root directory': [_Entry('database/live.isar', 'bad')],
    'unexpected root file': [_Entry('readme.txt', 'bad')],
    'file at media root': [_Entry('image', 'bad')],
    'symbolic link': [_Entry('image/link', 'target', mode: 0xa1ff)],
    'special file': [_Entry('image/pipe', '', mode: 0x11ff)],
    'file directory mismatch': [_Entry('image/', '', mode: 0x81a4)],
    'directory file mismatch': [_Entry('image/sub', '', mode: 0x41ed)],
    'duplicate file': [_Entry('image/a', 'one'), _Entry('image/a', 'two')],
    'case collision': [_Entry('image/A', 'one'), _Entry('image/a', 'two')],
    'separator collision': [
      _Entry('image/n/a', 'one'),
      _Entry(r'image\n\a', 'two'),
    ],
    'file ancestor collision': [
      _Entry('image/a', 'one'),
      _Entry('image/a/b', 'two'),
    ],
    'directory duplicate': [_Entry('image/', ''), _Entry('image/', '')],
    'local header disagreement': [
      _Entry('image/a', 'one', localName: '../escape'),
    ],
  };
  for (final entry in unsafeEntries.entries) {
    test('rejects ${entry.key} before extraction', () async {
      await fixture.zip([
        _Entry('backup.isar', 'new database'),
        ...entry.value,
      ]);
      await fixture.expectRejected();
    });
  }

  for (final entries in <String, List<_Entry>>{
    'missing database': [_Entry('image/a', 'new image')],
    'empty database': [_Entry('backup.isar', '')],
    'multiple databases': [_Entry('a.isar', 'one'), _Entry('b.isar', 'two')],
    'nested database': [_Entry('image/a.isar', 'one')],
  }.entries) {
    test('rejects ${entries.key}', () async {
      await fixture.zip(entries.value);
      await fixture.expectRejected();
    });
  }

  test(
    'rejects incomplete central directory records before extraction',
    () async {
      final bytes = _zip([_Entry('backup.isar', 'new database')]);
      ByteData.sublistView(
        bytes,
      ).setUint16(bytes.length - 12, 2, Endian.little);
      await fixture.archive.writeAsBytes(bytes);
      await fixture.expectRejected();
    },
  );

  test(
    'CRC corruption leaves live data intact even if extractor succeeds',
    () async {
      await fixture.zip([
        _Entry('backup.isar', 'new database'),
        _Entry('image/new.jpg', 'corrupt content', crc: 1),
      ]);
      await expectLater(fixture.restore(), throwsFormatException);
      await fixture.expectOriginal();
      await fixture.expectNoTemporaryDirectories();
    },
  );

  test(
    'missing extracted files are rejected before database preparation',
    () async {
      await fixture.validZip();
      await expectLater(
        fixture.restore(extract: (archive, destination) async {}),
        throwsFormatException,
      );
      await fixture.expectOriginal();
    },
  );

  test(
    'extra extracted files are rejected before database preparation',
    () async {
      await fixture.validZip();
      await expectLater(
        fixture.restore(
          extract: (archive, destination) async {
            await _extract(archive, destination);
            await File(
              p.join(destination, 'image', 'unexpected'),
            ).writeAsString('x');
          },
        ),
        throwsFormatException,
      );
      await fixture.expectOriginal();
    },
  );

  test(
    'wrong extracted length is rejected before database preparation',
    () async {
      await fixture.validZip();
      await expectLater(
        fixture.restore(
          extract: (archive, destination) async {
            await _extract(archive, destination);
            await File(
              p.join(destination, 'backup.isar'),
            ).writeAsString('short');
          },
        ),
        throwsFormatException,
      );
      await fixture.expectOriginal();
    },
  );

  test(
    'partial extraction failure preserves live files and cleans staging',
    () async {
      await fixture.validZip();
      final failure = StateError('decompression failed');
      await expectLater(
        fixture.restore(
          extract: (archive, destination) async {
            await File(p.join(destination, 'partial')).writeAsString('partial');
            throw failure;
          },
        ),
        throwsA(same(failure)),
      );
      await fixture.expectOriginal();
      await fixture.expectNoTemporaryDirectories();
    },
  );

  test(
    'database preparation failure leaves all live files untouched',
    () async {
      await fixture.validZip();
      final failure = StateError('invalid database');
      await expectLater(
        fixture.restore(
          prepare: (databasePath) async {
            expect(await File(databasePath).readAsString(), 'new database');
            await fixture.expectOriginal();
            throw failure;
          },
        ),
        throwsA(same(failure)),
      );
      await fixture.expectOriginal();
      await fixture.expectNoTemporaryDirectories();
    },
  );

  test('database commit failure rolls every media directory back', () async {
    await fixture.validZip();
    final failure = StateError('transaction failed');
    await expectLater(
      fixture.restore(
        prepare: (databasePath) async {
          await fixture.expectOriginal();
          return () async {
            expect(await fixture.read('image/new.jpg'), 'new image');
            expect(await fixture.file('image/old').exists(), isFalse);
            throw failure;
          };
        },
      ),
      throwsA(same(failure)),
    );
    await fixture.expectOriginal();
    await fixture.expectNoTemporaryDirectories();
  });

  test(
    'failed media move restores earlier directories without committing',
    () async {
      await fixture.validZip();
      final obstructingFile = fixture.file('video');
      await Directory(obstructingFile.path).delete(recursive: true);
      await obstructingFile.writeAsString('keep this file');
      await expectLater(fixture.restore(), throwsA(isA<FileSystemException>()));
      expect(await fixture.read('image/old'), 'old image');
      expect(await fixture.read('audio/old'), 'old audio');
      expect(await fixture.read('font/old'), 'old font');
      expect(await fixture.database.readAsString(), 'old database');
      expect(await obstructingFile.readAsString(), 'keep this file');
      await fixture.expectNoTemporaryDirectories();
    },
  );

  test(
    'valid restore replaces media and commits the prepared database last',
    () async {
      await fixture.validZip();
      await fixture.restore(
        prepare: (databasePath) async {
          await fixture.expectOriginal();
          expect(p.isWithin(fixture.data.path, databasePath), isTrue);
          final database = await File(databasePath).readAsString();
          return () async {
            expect(await fixture.read('image/new.jpg'), 'new image');
            expect(await fixture.read('audio/nested/new.wav'), 'new audio');
            expect(await fixture.read('video/new.mp4'), 'new video');
            expect(await fixture.read('font/new.ttf'), 'new font');
            await fixture.database.writeAsString(database);
          };
        },
      );
      expect(await fixture.database.readAsString(), 'new database');
      for (final name in _media) {
        expect(await fixture.file('$name/old').exists(), isFalse);
      }
      await fixture.expectNoTemporaryDirectories();
    },
  );

  test(
    'missing optional media directories become empty on successful restore',
    () async {
      await fixture.zip([_Entry('backup.isar', 'new database')]);
      await fixture.restore();
      expect(await fixture.database.readAsString(), 'new database');
      for (final name in _media) {
        expect(
          await Directory(p.join(fixture.data.path, name)).list().toList(),
          isEmpty,
        );
      }
      await fixture.expectNoTemporaryDirectories();
    },
  );

  test(
    'normalizes legacy Windows separators while preserving nested files',
    () async {
      await fixture.zip([
        _Entry('backup.isar', 'new database'),
        _Entry('image/', ''),
        _Entry(r'image\nested\new.jpg', 'legacy image'),
      ]);
      await fixture.restore();
      expect(await fixture.read('image/nested/new.jpg'), 'legacy image');
    },
  );

  test('inspects Zstd metadata without decompressing it in Dart', () async {
    await fixture.zip([_Entry('backup.isar', 'new database', method: 93)]);
    await fixture.restore(
      extract: (archive, destination) async {
        // A native extractor supplies the decompressed bytes from this Zstd frame.
        await File(
          p.join(destination, 'backup.isar'),
        ).writeAsString('new database');
      },
    );
    expect(await fixture.database.readAsString(), 'new database');
  });

  test(
    'cleanup failure after commit is reported without undoing successful import',
    () async {
      await fixture.validZip();
      final cleanupErrors = <Object>[];
      await IOOverrides.runZoned(
        () => fixture.restore(
          onCleanupError: (error, stack) {
            cleanupErrors.add(error);
          },
        ),
        createDirectory: (path) => _CleanupFailingDirectory(path),
        fseGetType: (path, followLinks) => Zone.root.run(
          () => FileSystemEntity.type(path, followLinks: followLinks),
        ),
      );
      expect(await fixture.database.readAsString(), 'new database');
      expect(await fixture.read('image/new.jpg'), 'new image');
      expect(cleanupErrors, isNotEmpty);
      expect(
        cleanupErrors.every((error) => error is FileSystemException),
        isTrue,
      );
    },
  );
}

const _media = ['image', 'audio', 'video', 'font'];

class _Fixture {
  _Fixture(this.root, this.data, this.archive, this.database);

  final Directory root;
  final Directory data;
  final File archive;
  final File database;

  static Future<_Fixture> create() async {
    final root = await Directory.systemTemp.createTemp('backup-restore-test-');
    final data = await Directory(p.join(root.path, 'data')).create();
    final database = File(p.join(data.path, 'database', 'live.txt'));
    await database.parent.create();
    await database.writeAsString('old database');
    for (final name in _media) {
      final dir = await Directory(p.join(data.path, name)).create();
      await File(p.join(dir.path, 'old')).writeAsString('old $name');
    }
    return _Fixture(
      root,
      data,
      File(p.join(root.path, 'backup.zip')),
      database,
    );
  }

  File file(String name) => File(p.joinAll([data.path, ...name.split('/')]));
  Future<String> read(String name) => file(name).readAsString();

  Future<void> zip(List<_Entry> entries) => archive.writeAsBytes(_zip(entries));

  Future<void> validZip() => zip([
    _Entry('backup.isar', 'new database'),
    _Entry('image/new.jpg', 'new image'),
    _Entry('audio/nested/new.wav', 'new audio'),
    _Entry('video/new.mp4', 'new video'),
    _Entry('font/new.ttf', 'new font'),
  ]);

  Future<void> restore({
    BackupExtractor? extract,
    BackupDatabasePreparer? prepare,
    void Function(Object, StackTrace)? onCleanupError,
  }) => BackupRestore(
    extract: extract ?? _extract,
    prepareDatabase:
        prepare ??
        (path) async {
          final value = await File(path).readAsString();
          return () async {
            await database.writeAsString(value);
          };
        },
    onCleanupError: onCleanupError,
  ).restore(archivePath: archive.path, dataPath: data.path);

  Future<void> expectOriginal() async {
    expect(await database.readAsString(), 'old database');
    for (final name in _media) {
      expect(await read('$name/old'), 'old $name');
      expect(await Directory(p.join(data.path, name)).list().length, 1);
    }
  }

  Future<void> expectNoTemporaryDirectories() async {
    expect(
      (await data.list().toList())
          .map((entry) => p.basename(entry.path))
          .toSet(),
      {..._media, 'database'},
    );
  }

  Future<void> expectRejected() async {
    var extractionAttempted = false;
    await expectLater(
      restore(
        extract: (archive, destination) async {
          extractionAttempted = true;
        },
      ),
      throwsFormatException,
    );
    expect(extractionAttempted, isFalse);
    await expectOriginal();
    await expectNoTemporaryDirectories();
  }
}

Future<void> _extract(String archivePath, String destination) async {
  final archive = ZipDecoder().decodeBytes(
    await File(archivePath).readAsBytes(),
  );
  for (final entry in archive.files) {
    final path = p.joinAll([
      destination,
      ...entry.name.replaceAll('\\', '/').split('/'),
    ]);
    if (entry.isFile) {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.content);
    } else {
      await Directory(path).create(recursive: true);
    }
  }
}

class _Entry {
  _Entry(
    this.name,
    this.content, {
    this.mode,
    this.crc,
    this.localName,
    this.method = 0,
  });

  final String name;
  final String content;
  final int? mode;
  final int? crc;
  final String? localName;
  final int method;
}

// Handwritten ZIP headers keep duplicates and hostile paths that Archive drops.
Uint8List _zip(List<_Entry> entries) {
  final output = BytesBuilder();
  final directory = BytesBuilder();
  void number(BytesBuilder target, int value, int length) {
    final bytes = ByteData(length);
    if (length == 2) {
      bytes.setUint16(0, value, Endian.little);
    } else {
      bytes.setUint32(0, value, Endian.little);
    }
    target.add(bytes.buffer.asUint8List());
  }

  for (final entry in entries) {
    final name = utf8.encode(entry.name);
    final localName = utf8.encode(entry.localName ?? entry.name);
    final data = utf8.encode(entry.content);
    final compressed = entry.method == 93
        ? [
            0x28,
            0xb5,
            0x2f,
            0xfd,
            0x20,
            data.length,
            (data.length << 3) | 1,
            0,
            0,
            ...data,
          ]
        : data;
    final crc = entry.crc ?? getCrc32(data);
    final offset = output.length;
    number(output, 0x04034b50, 4);
    for (final value in [20, 0x800, entry.method, 0, 0]) {
      number(output, value, 2);
    }
    for (final value in [crc, compressed.length, data.length]) {
      number(output, value, 4);
    }
    number(output, localName.length, 2);
    number(output, 0, 2);
    output.add(localName);
    output.add(compressed);
    number(directory, 0x02014b50, 4);
    for (final value in [0x314, 20, 0x800, entry.method, 0, 0]) {
      number(directory, value, 2);
    }
    for (final value in [crc, compressed.length, data.length]) {
      number(directory, value, 4);
    }
    for (final value in [name.length, 0, 0, 0, 0]) {
      number(directory, value, 2);
    }
    final isDirectory = entry.name.endsWith('/');
    final mode = entry.mode ?? (isDirectory ? 0x41ed : 0x81a4);
    number(directory, (mode << 16) | (isDirectory ? 0x10 : 0), 4);
    number(directory, offset, 4);
    directory.add(name);
  }
  final directoryOffset = output.length;
  final directoryBytes = directory.takeBytes();
  output.add(directoryBytes);
  number(output, 0x06054b50, 4);
  for (final value in [0, 0, entries.length, entries.length]) {
    number(output, value, 2);
  }
  number(output, directoryBytes.length, 4);
  number(output, directoryOffset, 4);
  number(output, 0, 2);
  return output.takeBytes();
}

// Real filesystem operations remain in use; only temporary-directory deletion
// fails, as it can when the OS keeps a file locked after the database commits.
class _CleanupFailingDirectory implements Directory {
  _CleanupFailingDirectory(this.path);

  @override
  final String path;

  T _real<T>(T Function(Directory) action) =>
      Zone.root.run(() => action(Directory(path)));

  @override
  Future<Directory> create({bool recursive = false}) =>
      _real((dir) => dir.create(recursive: recursive));

  @override
  Future<Directory> createTemp([String? prefix]) async =>
      _CleanupFailingDirectory(
        (await _real((dir) => dir.createTemp(prefix))).path,
      );

  @override
  Future<bool> exists() => _real((dir) => dir.exists());

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) =>
      _real((dir) => dir.list(recursive: recursive, followLinks: followLinks));

  @override
  Future<Directory> rename(String newPath) =>
      _real((dir) => dir.rename(newPath));

  @override
  Future<Directory> delete({bool recursive = false}) async {
    throw FileSystemException('cleanup locked', path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
