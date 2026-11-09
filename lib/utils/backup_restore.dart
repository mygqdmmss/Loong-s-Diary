import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

typedef BackupExtractor =
    Future<void> Function(String archivePath, String destination);
typedef PreparedDatabaseCommit = Future<void> Function();
typedef BackupDatabasePreparer =
    Future<PreparedDatabaseCommit> Function(String databasePath);

class BackupRestore {
  BackupRestore({
    required BackupExtractor extract,
    required BackupDatabasePreparer prepareDatabase,
    void Function(Object, StackTrace)? onCleanupError,
  }) : _extract = extract,
       _prepareDatabase = prepareDatabase,
       _onCleanupError = onCleanupError;

  static const _media = ['image', 'audio', 'video', 'font'];

  final BackupExtractor _extract;
  final BackupDatabasePreparer _prepareDatabase;
  final void Function(Object, StackTrace)? _onCleanupError;

  /// The preparer must finish reading and validating the staged database before
  /// returning. Its commit must be atomic: throwing must leave the live database
  /// unchanged. Callers must serialize restores and other backup operations.
  Future<void> restore({
    required String archivePath,
    required String dataPath,
  }) async {
    Directory? stage;
    Directory? rollback;
    final movedOld = <String>[];
    final installed = <String>[];
    var rollbackComplete = true;

    try {
      final contents = _inspectArchive(archivePath);
      stage = await Directory(dataPath).createTemp('.restore-stage-');
      await _extract(archivePath, stage.path);
      await _validateExtraction(stage, contents.paths);
      final commit = await _prepareDatabase(
        p.join(stage.path, contents.databaseName),
      );

      // Missing optional directories intentionally replace old media with empty
      // directories, matching the full-backup import semantics.
      for (final name in _media) {
        await Directory(p.join(stage.path, name)).create(recursive: true);
      }
      rollback = await Directory(dataPath).createTemp('.restore-rollback-');
      for (final name in _media) {
        final livePath = p.join(dataPath, name);
        final type = await FileSystemEntity.type(livePath, followLinks: false);
        if (type == FileSystemEntityType.notFound) continue;
        if (type != FileSystemEntityType.directory) {
          throw FileSystemException('Expected a media directory', livePath);
        }
        await Directory(livePath).rename(p.join(rollback.path, name));
        movedOld.add(name);
      }
      for (final name in _media) {
        await Directory(
          p.join(stage.path, name),
        ).rename(p.join(dataPath, name));
        installed.add(name);
      }

      // Nothing that can fail the restore follows this atomic database commit.
      await commit();
    } catch (_) {
      if (stage != null && rollback != null) {
        for (final name in installed.reversed) {
          try {
            await Directory(
              p.join(dataPath, name),
            ).rename(p.join(stage.path, name));
          } catch (error, stack) {
            rollbackComplete = false;
            _reportCleanupError(error, stack);
          }
        }
        for (final name in movedOld.reversed) {
          try {
            await Directory(
              p.join(rollback.path, name),
            ).rename(p.join(dataPath, name));
          } catch (error, stack) {
            // Keep the rollback directory if the OS prevents recovery. Deleting
            // it in finally would destroy the only remaining original media.
            rollbackComplete = false;
            _reportCleanupError(error, stack);
          }
        }
      }
      rethrow;
    } finally {
      if (stage != null) await _cleanup(stage);
      if (rollback != null && rollbackComplete) await _cleanup(rollback);
    }
  }

  _BackupContents _inspectArchive(String archivePath) {
    final input = InputFileStream(archivePath);
    try {
      final length = input.length;
      final directory = ZipDirectory()..read(input);
      if (directory.filePosition < 0 ||
          directory.filePosition + 22 > length ||
          directory.numberOfThisDisk != 0 ||
          directory.diskWithTheStartOfTheCentralDirectory != 0 ||
          directory.totalCentralDirectoryEntries !=
              directory.fileHeaders.length ||
          directory.totalCentralDirectoryEntriesOnThisDisk !=
              directory.fileHeaders.length ||
          directory.centralDirectoryOffset < 0 ||
          directory.centralDirectorySize <= 0 ||
          directory.centralDirectoryOffset + directory.centralDirectorySize >
              directory.filePosition) {
        throw const FormatException('Invalid ZIP central directory');
      }
      input.setPosition(directory.filePosition + 20);
      if (directory.filePosition + 22 + input.readUint16() != length) {
        throw const FormatException(
          'Truncated ZIP or unexpected trailing bytes',
        );
      }

      final paths = <String, _BackupPath>{};
      final explicitPaths = <String>{};
      final databases = <String>[];
      final localRanges = <(int, int)>[];
      var centralPosition = directory.centralDirectoryOffset;
      final centralEnd = centralPosition + directory.centralDirectorySize;

      for (final header in directory.fileHeaders) {
        if (centralPosition + 46 > centralEnd) {
          throw const FormatException('Truncated ZIP entry');
        }
        input.setPosition(centralPosition + 28);
        final nameLength = input.readUint16();
        final extraLength = input.readUint16();
        final commentLength = input.readUint16();
        centralPosition += 46 + nameLength + extraLength + commentLength;
        if (centralPosition > centralEnd || header.diskNumberStart != 0) {
          throw const FormatException('Invalid ZIP entry bounds');
        }

        final normalized = header.filename.replaceAll('\\', '/');
        final isDirectory = normalized.endsWith('/');
        final name = isDirectory
            ? normalized.substring(0, normalized.length - 1)
            : normalized;
        final parts = _validateName(name);
        final fileType = (header.externalFileAttributes >> 16) & 0xf000;
        final dosDirectory = (header.externalFileAttributes & 0x10) != 0;
        if ((fileType != 0 && fileType != 0x4000 && fileType != 0x8000) ||
            (fileType == 0x4000 && !isDirectory) ||
            (fileType == 0x8000 && isDirectory) ||
            (dosDirectory && !isDirectory) ||
            (isDirectory &&
                (header.uncompressedSize != 0 || header.crc32 != 0)) ||
            (header.generalPurposeBitFlag & 1) != 0) {
          throw FormatException(
            'Unsupported ZIP entry type: ${header.filename}',
          );
        }
        if (parts.length == 1 && !isDirectory && name.endsWith('.isar')) {
          if (header.uncompressedSize <= 0) {
            throw const FormatException('Backup database is empty');
          }
          databases.add(name);
        } else if (!_media.contains(parts.first) ||
            (!isDirectory && parts.length == 1)) {
          throw FormatException('Unexpected backup entry: $name');
        }

        if (!explicitPaths.add(name.toLowerCase())) {
          throw FormatException('Duplicate ZIP entry: $name');
        }
        for (var i = 1; i < parts.length; i++) {
          _addPath(paths, _BackupPath(parts.take(i).join('/'), true));
        }
        _addPath(
          paths,
          _BackupPath(name, isDirectory, header.uncompressedSize, header.crc32),
        );
        localRanges.add(
          _validateLocalHeader(input, header, directory.centralDirectoryOffset),
        );
      }
      if (centralPosition != centralEnd || databases.length != 1) {
        throw const FormatException(
          'Backup must contain exactly one root database',
        );
      }
      localRanges.sort((a, b) => a.$1.compareTo(b.$1));
      for (var i = 1; i < localRanges.length; i++) {
        if (localRanges[i - 1].$2 > localRanges[i].$1) {
          throw const FormatException('Overlapping ZIP entries');
        }
      }
      return _BackupContents(databases.single, paths);
    } on FileSystemException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid ZIP archive: $error');
    } finally {
      input.closeSync();
    }
  }

  List<String> _validateName(String name) {
    final parts = name.split('/');
    final invalidCharacters = RegExp(r'[\x00-\x1f\x7f:*?"<>|]');
    final reservedName = RegExp(
      r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
      caseSensitive: false,
    );
    if (parts.any(
      (part) =>
          part.isEmpty ||
          part == '.' ||
          part == '..' ||
          part.endsWith('.') ||
          part.endsWith(' ') ||
          invalidCharacters.hasMatch(part) ||
          reservedName.hasMatch(part),
    )) {
      throw FormatException('Unsafe ZIP path: $name');
    }
    return parts;
  }

  void _addPath(Map<String, _BackupPath> paths, _BackupPath entry) {
    final key = entry.name.toLowerCase();
    final previous = paths[key];
    if (previous != null &&
        (previous.name != entry.name ||
            previous.isDirectory != entry.isDirectory)) {
      throw FormatException('Conflicting ZIP paths: ${entry.name}');
    }
    paths[key] = entry;
  }

  (int, int) _validateLocalHeader(
    InputStream input,
    ZipFileHeader header,
    int centralOffset,
  ) {
    final offset = header.localHeaderOffset;
    if (offset < 0 || offset + 30 > centralOffset) {
      throw const FormatException('Invalid local ZIP header offset');
    }
    input.setPosition(offset);
    if (input.readUint32() != ZipFile.zipSignature) {
      throw const FormatException('Missing local ZIP header');
    }
    input.skip(2);
    final flags = input.readUint16();
    final method = input.readUint16();
    input.skip(4);
    final crc = input.readUint32();
    final compressedSize = input.readUint32();
    final uncompressedSize = input.readUint32();
    final nameLength = input.readUint16();
    final extraLength = input.readUint16();
    final end = offset + 30 + nameLength + extraLength + header.compressedSize;
    if (end > centralOffset ||
        flags != header.generalPurposeBitFlag ||
        method != header.compressionMethod ||
        header.file?.filename != header.filename ||
        ((flags & 8) == 0 &&
            (crc != header.crc32 ||
                (compressedSize != 0xffffffff &&
                    compressedSize != header.compressedSize) ||
                (uncompressedSize != 0xffffffff &&
                    uncompressedSize != header.uncompressedSize)))) {
      throw const FormatException('Inconsistent ZIP headers');
    }
    return (offset, end);
  }

  Future<void> _validateExtraction(
    Directory stage,
    Map<String, _BackupPath> paths,
  ) async {
    final seen = <String>{};
    await for (final entity in stage.list(
      recursive: true,
      followLinks: false,
    )) {
      final name = p.split(p.relative(entity.path, from: stage.path)).join('/');
      final expected = paths[name.toLowerCase()];
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (expected == null ||
          expected.name != name ||
          (expected.isDirectory
              ? type != FileSystemEntityType.directory
              : type != FileSystemEntityType.file)) {
        throw FormatException(
          'Unexpected extracted path or type: $name ($type)',
        );
      }
      seen.add(name.toLowerCase());
      if (!expected.isDirectory) {
        var length = 0;
        var crc = 0;
        await for (final bytes in File(entity.path).openRead()) {
          length += bytes.length;
          crc = getCrc32(bytes, crc);
        }
        if (length != expected.size || crc != expected.crc) {
          throw FormatException('Backup file is corrupt: $name');
        }
      }
    }
    if (seen.length != paths.length) {
      throw const FormatException('Backup extraction is incomplete');
    }
  }

  Future<void> _cleanup(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (error, stack) {
      _reportCleanupError(error, stack);
    }
  }

  void _reportCleanupError(Object error, StackTrace stack) {
    try {
      _onCleanupError?.call(error, stack);
    } catch (_) {
      // A logging failure must never turn a committed import into a failure.
    }
  }
}

class _BackupPath {
  const _BackupPath(this.name, this.isDirectory, [this.size = 0, this.crc = 0]);

  final String name;
  final bool isDirectory;
  final int size;
  final int crc;
}

class _BackupContents {
  const _BackupContents(this.databaseName, this.paths);

  final String databaseName;
  final Map<String, _BackupPath> paths;
}
