import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/monthly_diary/monthly_diary_models.dart';
import 'package:moodiary/persistence/monthly_diary_repository.dart';

Diary entry(
  String id,
  DateTime time, {
  String? categoryId,
  bool show = true,
  String title = '',
  String contentText = '',
  List<String> images = const [],
}) => Diary()
  ..id = id
  ..time = time
  ..categoryId = categoryId
  ..show = show
  ..title = title
  ..contentText = contentText
  ..imageName = images
  ..type = 'markdown';

List<String> ids(Iterable<Diary> entries) =>
    entries.map((entry) => entry.id).toList();

void main() {
  group('DiaryDay', () {
    test('normalizes the local date and snapshots entries newest first', () {
      final older = entry('older', DateTime(2026, 11, 9, 8));
      final newest = entry(
        'newest',
        DateTime(2026, 11, 9, 19),
        title: ' newest title ',
      );
      final photo = entry(
        'photo',
        DateTime(2026, 11, 9, 12),
        images: ['photo.jpg'],
      );
      final input = [older, newest, photo];
      final day = DiaryDay(
        day: DateTime(2026, 11, 9, 14).toUtc(),
        entries: input,
      );

      expect(day.day, DateTime(2026, 11, 9));
      expect(day.day.isUtc, false);
      expect(ids(day.entries), ['newest', 'photo', 'older']);
      expect(ids(input), ['older', 'newest', 'photo']);
      expect(day.cover, same(photo));
      expect(day.excerpt, 'newest title');
      expect(() => day.entries.add(older), throwsUnsupportedError);
      input.clear();
      expect(day.entries, hasLength(3));
    });

    test('uses only the first entry for the excerpt and trims its text', () {
      final day = DiaryDay(
        day: DateTime(2026, 11, 9),
        entries: [
          entry('older', DateTime(2026, 11, 9, 8), title: 'older title'),
          entry(
            'newest',
            DateTime(2026, 11, 9, 19),
            title: '  \n ',
            contentText: '  the latest memory \n ',
          ),
        ],
      );
      expect(day.excerpt, 'the latest memory');
      expect(day.cover, isNull);
    });

    test('empty days and blank first entries have empty excerpts', () {
      expect(DiaryDay(day: DateTime(2026, 11, 9), entries: []).excerpt, '');
      final day = DiaryDay(
        day: DateTime(2026, 11, 9),
        entries: [entry('blank', DateTime(2026, 11, 9), contentText: ' \n ')],
      );
      expect(day.excerpt, '');
      expect(day.cover, isNull);
    });
  });

  group('MonthlyDiaryRepository', () {
    late Directory directory;
    late Isar isar;
    late MonthlyDiarySource source;
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
      directory = await Directory.systemTemp.createTemp('monthly-diary-test-');
      isar = Isar.open(
        schemas: [DiarySchema],
        directory: directory.path,
        name: 'monthly-${instance++}',
        inspector: false,
      );
      source = MonthlyDiaryRepository(isar);
    });

    tearDown(() async {
      if (isar.isOpen) isar.close();
      await directory.delete(recursive: true);
    });

    void seed(List<Diary> entries) {
      isar.write((db) => db.diarys.putAll(entries));
    }

    test(
      'orders numeric months across years and counts every visible entry',
      () async {
        seed([
          for (var i = 0; i < 40; i++)
            entry('latest-$i', DateTime(2027, 1, 1, 12, i)),
          entry('october-first', DateTime(2026, 10, 1, 8)),
          entry('october-later', DateTime(2026, 10, 1, 19)),
          entry('october-second', DateTime(2026, 10, 2)),
          entry('september', DateTime(2026, 9, 30)),
          entry('previous-year', DateTime(2025, 12, 31)),
          entry('recycled-only-month', DateTime(2026, 4, 1), show: false),
          entry('recycled-same-month', DateTime(2026, 10, 3), show: false),
        ]);

        final months = await source.loadMonths();
        expect(months.map((month) => month.month), [
          DateTime(2027, 1),
          DateTime(2026, 10),
          DateTime(2026, 9),
          DateTime(2025, 12),
        ]);
        expect(months.map((month) => month.entryCount), [40, 3, 1, 1]);
        expect(months.map((month) => month.dayCount), [1, 2, 1, 1]);
        expect(months.every((month) => !month.month.isUtc), true);
      },
    );

    test(
      'null category includes uncategorized and all categorized entries',
      () async {
        seed([
          entry('uncategorized', DateTime(2026, 10, 1, 8)),
          entry('family', DateTime(2026, 10, 1, 12), categoryId: 'family'),
          entry('work', DateTime(2026, 10, 2, 18), categoryId: 'work'),
          entry('recycled', DateTime(2026, 10, 3), show: false),
        ]);

        final month = (await source.loadMonths(categoryId: null)).single;
        expect(month.entryCount, 3);
        expect(month.dayCount, 2);
        final days = await source.loadDays(DateTime(2026, 10, 17, 9));
        expect(days.map((day) => day.day), [
          DateTime(2026, 10, 2),
          DateTime(2026, 10, 1),
        ]);
        expect(ids(days[1].entries), ['family', 'uncategorized']);
        expect(ids(await source.loadDay(DateTime(2026, 10, 1, 21))), [
          'family',
          'uncategorized',
        ]);
      },
    );

    test(
      'specific category filters months days and entries before grouping',
      () async {
        seed([
          entry('uncategorized', DateTime(2026, 10, 1, 8)),
          entry(
            'family-early',
            DateTime(2026, 10, 1, 12),
            categoryId: 'family',
          ),
          entry('family-late', DateTime(2026, 10, 1, 19), categoryId: 'family'),
          entry('work', DateTime(2026, 9, 2), categoryId: 'work'),
          entry(
            'recycled-family',
            DateTime(2026, 8, 1),
            categoryId: 'family',
            show: false,
          ),
        ]);

        final months = await source.loadMonths(categoryId: 'family');
        expect(months.map((month) => month.month), [DateTime(2026, 10)]);
        expect(months.single.entryCount, 2);
        expect(months.single.dayCount, 1);
        final days = await source.loadDays(
          DateTime(2026, 10),
          categoryId: 'family',
        );
        expect(days.map((day) => day.day), [DateTime(2026, 10, 1)]);
        expect(ids(days.single.entries), ['family-late', 'family-early']);
        expect(
          ids(
            await source.loadDay(DateTime(2026, 10, 1), categoryId: 'family'),
          ),
          ['family-late', 'family-early'],
        );
        expect(await source.loadMonths(categoryId: 'missing'), isEmpty);
        expect(
          await source.loadDays(DateTime(2026, 10), categoryId: 'missing'),
          isEmpty,
        );
        expect(
          await source.loadDay(DateTime(2026, 10, 1), categoryId: 'missing'),
          isEmpty,
        );
      },
    );

    test(
      'UTC instants are grouped by local month and day using half-open limits',
      () async {
        final start = DateTime(2026, 10, 1);
        final nextDay = DateTime(2026, 10, 2);
        final nextMonth = DateTime(2026, 11, 1);
        seed([
          entry(
            'before-month',
            start.subtract(const Duration(milliseconds: 1)).toUtc(),
          ),
          entry('start', start.toUtc()),
          entry(
            'end-of-day',
            nextDay.subtract(const Duration(milliseconds: 1)).toUtc(),
          ),
          entry('next-day', nextDay.toUtc()),
          entry(
            'end-of-month',
            nextMonth.subtract(const Duration(milliseconds: 1)).toUtc(),
          ),
          entry('next-month', nextMonth.toUtc()),
        ]);

        final months = await source.loadMonths();
        expect(months.map((month) => month.month), [
          DateTime(2026, 11),
          DateTime(2026, 10),
          DateTime(2026, 9),
        ]);
        expect(months.map((month) => month.entryCount), [1, 4, 1]);
        expect(months.map((month) => month.dayCount), [1, 3, 1]);
        // UTC arguments refer to their local calendar month/day, even when their
        // raw UTC fields belong to the preceding date.
        final days = await source.loadDays(start.toUtc());
        expect(days.map((day) => day.day), [
          DateTime(2026, 10, 31),
          DateTime(2026, 10, 2),
          DateTime(2026, 10, 1),
        ]);
        expect(ids(days.last.entries), ['end-of-day', 'start']);
        expect(ids(await source.loadDay(start.toUtc())), [
          'end-of-day',
          'start',
        ]);
      },
    );

    test(
      'calendar month and day ranges cross a year and include leap day',
      () async {
        seed([
          entry('december', DateTime(2026, 12, 31, 23, 59)),
          entry('january', DateTime(2027, 1, 1)),
          entry('leap-day', DateTime(2024, 2, 29, 23, 59)),
          entry('march', DateTime(2024, 3, 1)),
        ]);
        expect(
          ids((await source.loadDays(DateTime(2026, 12))).single.entries),
          ['december'],
        );
        expect(ids(await source.loadDay(DateTime(2026, 12, 31))), ['december']);
        expect(ids((await source.loadDays(DateTime(2024, 2))).single.entries), [
          'leap-day',
        ]);
        expect(ids(await source.loadDay(DateTime(2024, 2, 29))), ['leap-day']);
      },
    );

    test('empty data has no packages or bubbles', () async {
      expect(await source.loadMonths(), isEmpty);
      expect(await source.loadDays(DateTime(2026, 10)), isEmpty);
      expect(await source.loadDay(DateTime(2026, 10, 1)), isEmpty);
    });

    test(
      'reads preserve original stored record data',
      () async {
        seed([
          entry(
              'read-only',
              DateTime(2026, 10, 1).toUtc(),
              images: ['memory.jpg'],
            )
            ..content = '{"original":"content"}'
            ..tags = ['original-tag'],
        ]);
        final before = isar.diarys.where().findAll().single.toJson();
        await source.loadMonths();
        await source.loadDays(DateTime(2026, 10));
        await source.loadDay(DateTime(2026, 10, 1));
        expect(isar.diarys.count(), 1);
        expect(isar.diarys.where().findAll().single.toJson(), before);
      },
    );

    test('watchChanges emits after collection writes and recycling', () async {
      final inserted = source.watchChanges().first.timeout(
        const Duration(seconds: 5),
      );
      seed([entry('watched', DateTime(2026, 10, 1))]);
      await inserted;
      expect((await source.loadMonths()).single.entryCount, 1);

      final recycled = source.watchChanges().first.timeout(
        const Duration(seconds: 5),
      );
      isar.write((db) {
        final diary = db.diarys.where().findAll().single;
        diary.show = false;
        db.diarys.put(diary);
      });
      await recycled;
      expect(await source.loadMonths(), isEmpty);
    });
  });
}
