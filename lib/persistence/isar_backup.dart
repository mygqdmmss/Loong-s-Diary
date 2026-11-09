import 'dart:io';
import 'dart:typed_data';

import 'package:isar/isar.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/models/isar/font.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// A fully read backup, ready to replace the live database in one transaction.
class IsarBackup {
  static const schemas = [DiarySchema, CategorySchema, FontSchema];

  final List<Diary> _diaries;
  final List<Category> _categories;
  final List<Font> _fonts;

  IsarBackup._(this._diaries, this._categories, this._fonts);

  static Future<IsarBackup> read(String databasePath) async {
    final file = File(databasePath);
    if (!await file.exists() || await file.length() == 0) {
      throw FileSystemException(
        'Backup database is missing or empty',
        databasePath,
      );
    }
    await _validateFile(file);

    // Isar identifies open instances by name. Never let an imported filename
    // such as default.isar alias the application's already-open database.
    final directory = await file.parent.createTemp('.database-check-');
    final name = 'restore-${const Uuid().v4()}';
    Isar? source;
    try {
      await file.copy(p.join(directory.path, '$name.isar'));
      source = await Isar.openAsync(
        schemas: schemas,
        directory: directory.path,
        name: name,
        inspector: false,
      );
      final diaries = await source.diarys.where().findAllAsync();
      final categories = await source.categorys.where().findAllAsync();
      final fonts = await source.fonts.where().findAllAsync();
      return IsarBackup._(diaries, categories, fonts);
    } finally {
      source?.close();
      await directory.delete(recursive: true);
    }
  }

  Future<void> restoreInto(Isar target) async {
    await target.writeAsync((isar) {
      isar.clear();
      isar.diarys.putAll(_diaries);
      isar.categorys.putAll(_categories);
      isar.fonts.putAll(_fonts);
    });
  }

  static Future<void> _validateFile(File file) async {
    // Isar 4's MDBX format starts with three metadata pages. A truncated input
    // may silently open using an older, empty metadata page. Check all three
    // before allowing the native engine to open (and potentially repair) it.
    // The 20-byte page header is followed by the magic/version and geometry;
    // the page size is stored in the free-page database's xsize field.
    final input = await file.open();
    try {
      final length = await input.length();
      var pageSize = 0;
      for (var page = 0; page < 3; page++) {
        await input.setPosition(page * pageSize);
        final bytes = await input.read(204);
        if (bytes.length != 204) {
          throw const FormatException('Truncated Isar backup database');
        }
        final header = ByteData.sublistView(bytes);
        final storedPageSize = header.getUint32(64, Endian.little);
        final usedPages = header.getUint32(56, Endian.little);
        if (page == 0) pageSize = storedPageSize;
        if (header.getUint64(20, Endian.little) >> 8 != 0x59659dbdef4c11 ||
            header.getUint32(16, Endian.little) != page ||
            // A torn metadata write can make MDBX fall back to an empty older
            // transaction. A backup must have consistent committed metadata.
            header.getUint64(28, Endian.little) !=
                header.getUint64(196, Endian.little) ||
            pageSize < 256 ||
            pageSize > 65536 ||
            (pageSize & (pageSize - 1)) != 0 ||
            storedPageSize != pageSize ||
            usedPages < 3 ||
            usedPages * pageSize > length) {
          throw const FormatException(
            'Invalid or truncated Isar backup database',
          );
        }
      }
    } finally {
      await input.close();
    }
  }
}
