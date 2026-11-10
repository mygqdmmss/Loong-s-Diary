import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/view_mode.dart';
import 'package:moodiary/components/monthly_diary/monthly_diary_models.dart';
import 'package:moodiary/components/monthly_diary/monthly_diary_sliver.dart';
import 'package:moodiary/l10n/app_localizations.dart';

void main() {
  setUpAll(() => initializeDateFormatting('zh'));
  test('saved list and grid values remain compatible', () {
    expect(ViewModeType.getType(0), ViewModeType.list);
    expect(ViewModeType.getType(1), ViewModeType.grid);
  });

  test('saved monthly value selects the new view', () {
    expect(ViewModeType.getType(2).name, 'monthly');
  });

  test('unknown saved view values fall back to the list', () {
    expect(ViewModeType.getType(-1), ViewModeType.list);
    expect(ViewModeType.getType(99), ViewModeType.list);
  });

  testWidgets('month to day to entry keeps all entries on the selected day', (
    tester,
  ) async {
    final source = FakeMonthlySource([
      entry('evening', DateTime(2026, 10, 30, 20)),
      entry('morning', DateTime(2026, 10, 30, 9)),
      entry('another-day', DateTime(2026, 10, 28)),
      entry('older-month', DateTime(2025, 12, 1)),
    ]);
    String? opened;
    await pumpMonthly(
      tester,
      source,
      onOpenDiary: (diary) async {
        opened = diary.id;
      },
    );
    await tester.tap(find.byKey(const ValueKey('month-2026-10')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('day-2026-10-30')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-2026-10-28')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('day-2026-10-30')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-evening')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-morning')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-another-day')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('entry-evening')));
    await tester.pumpAndSettle();
    expect(opened, 'evening');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await source.close();
  });

  testWidgets('removing the final entry refreshes day, month and home bags', (
    tester,
  ) async {
    final source = FakeMonthlySource([
      entry('last', DateTime(2026, 10, 30)),
      entry('older', DateTime(2025, 12, 1)),
    ]);
    await pumpMonthly(
      tester,
      source,
      onOpenDiary: (diary) async {
        source.entries.removeWhere((item) => item.id == diary.id);
        source.changed();
      },
    );
    await tester.tap(find.byKey(const ValueKey('month-2026-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-2026-10-30')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-last')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-last')), findsNothing);
    expect(find.text('这一天还没有可显示的日记。'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('day-2026-10-30')), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('month-2026-10')), findsNothing);
    expect(find.byKey(const ValueKey('month-2025-12')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(source.listeners, 0);
    await source.close();
  });

  testWidgets('category scope follows month and day navigation', (
    tester,
  ) async {
    final source = FakeMonthlySource([
      entry('mine', DateTime(2026, 10, 30), category: 'travel'),
      entry('other', DateTime(2026, 10, 30), category: 'work'),
    ]);
    await pumpMonthly(tester, source, categoryId: 'travel');
    await tester.tap(find.byKey(const ValueKey('month-2026-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-2026-10-30')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-mine')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-other')), findsNothing);
    expect(source.requestedCategories, everyElement('travel'));
    await tester.pumpWidget(const SizedBox());
    await source.close();
  });

  testWidgets('loading failure offers a working retry', (tester) async {
    final source = FakeMonthlySource([entry('first', DateTime(2026, 10, 1))])
      ..fail = true;
    await pumpMonthly(tester, source);
    expect(find.text('暂时没能打开这些回忆。'), findsOneWidget);
    source.fail = false;
    await tester.tap(find.text('再试一次'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('month-2026-10')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await source.close();
  });

  testWidgets(
    'text-only month shows its scoped note and opens at narrow large text',
    (tester) async {
      const excerpt = '雨停以后，沿着河边慢慢走，记下今天的心情。';
      const otherExcerpt = '另一分类里的日记不应露出。';
      final source = FakeMonthlySource([
        entry('mine', DateTime(2026, 10, 30), category: 'travel')
          ..title = ' '
          ..contentText = excerpt,
        entry('other', DateTime(2026, 10, 31), category: 'work')
          ..title = ''
          ..contentText = otherExcerpt,
      ]);
      await pumpMonthly(
        tester,
        source,
        categoryId: 'travel',
        viewport: const Size(320, 920),
        textScale: 1.8,
      );
      expect(find.text(excerpt), findsOneWidget);
      expect(find.text(otherExcerpt), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('month-2026-10')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-2026-10-30')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-2026-10-31')), findsNothing);
      expect(source.requestedCategories, everyElement('travel'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await source.close();
    },
  );

  testWidgets(
    'month picker opens an older month without showing previous days',
    (tester) async {
      final source = FakeMonthlySource([
        entry('recent', DateTime(2026, 10, 30)),
        entry('older', DateTime(2025, 12, 1)),
      ]);
      await pumpMonthly(tester, source);
      await tester.tap(find.byKey(const ValueKey('month-2026-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-month')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-2025-12')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-2026-10-30')), findsNothing);
      expect(find.byKey(const ValueKey('day-2025-12-1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('day-2025-12-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('entry-older')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await source.close();
    },
  );

  testWidgets('moving the final entry changes its day and month package', (
    tester,
  ) async {
    final source = FakeMonthlySource([entry('moving', DateTime(2026, 10, 30))]);
    await pumpMonthly(
      tester,
      source,
      onOpenDiary: (diary) async {
        diary.time = DateTime(2026, 11, 1);
        source.changed();
      },
    );
    await tester.tap(find.byKey(const ValueKey('month-2026-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-2026-10-30')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-moving')));
    await tester.pumpAndSettle();
    expect(find.text('这一天还没有可显示的日记。'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('day-2026-10-30')), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('month-2026-10')), findsNothing);
    expect(find.byKey(const ValueKey('month-2026-11')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await source.close();
  });

  testWidgets(
    'category and source changes ignore late results and dispose listeners',
    (tester) async {
      final first = DelayedMonthlySource();
      final second = DelayedMonthlySource();
      Future<void> show(MonthlyDiarySource source, String category) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  MonthlyDiarySliver(source: source, categoryId: category),
                ],
              ),
            ),
          ),
        );
      }

      await show(first, 'travel');
      await show(first, 'work');
      first.pending[1].complete([
        DiaryMonth(month: _workMonth, dayCount: 1, entryCount: 1),
      ]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('month-2026-11')), findsOneWidget);
      first.pending[0].complete([
        DiaryMonth(month: _travelMonth, dayCount: 1, entryCount: 1),
      ]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('month-2026-10')), findsNothing);
      await show(second, 'work');
      await tester.pump();
      expect(find.byKey(const ValueKey('month-2026-11')), findsNothing);
      expect(first.listeners, 0);
      await tester.pumpWidget(const SizedBox());
      second.pending.single.completeError(
        StateError('late read after disposal'),
      );
      await tester.pump();
      expect(second.listeners, 0);
      expect(tester.takeException(), isNull);
      await first.close();
      await second.close();
    },
  );
}

final _workMonth = DateTime(2026, 11);
final _travelMonth = DateTime(2026, 10);

class DelayedMonthlySource extends FakeMonthlySource {
  DelayedMonthlySource() : super([]);
  final pending = <Completer<List<DiaryMonth>>>[];
  @override
  Future<List<DiaryMonth>> loadMonths({String? categoryId}) {
    final completer = Completer<List<DiaryMonth>>();
    pending.add(completer);
    return completer.future;
  }
}

Diary entry(String id, DateTime time, {String? category}) => Diary()
  ..id = id
  ..time = time
  ..categoryId = category
  ..title = id
  ..contentText = 'A quiet moment from this day.'
  ..type = 'markdown';

Future<void> pumpMonthly(
  WidgetTester tester,
  FakeMonthlySource source, {
  String? categoryId,
  Future<void> Function(Diary)? onOpenDiary,
  Size viewport = const Size(420, 920),
  double textScale = 1,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            MonthlyDiarySliver(
              source: source,
              categoryId: categoryId,
              onOpenDiary: onOpenDiary ?? (_) async {},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class FakeMonthlySource implements MonthlyDiarySource {
  FakeMonthlySource(this.entries) {
    _changes = StreamController<void>.broadcast(
      onListen: () => listeners++,
      onCancel: () => listeners--,
    );
  }
  final List<Diary> entries;
  final List<String?> requestedCategories = [];
  late final StreamController<void> _changes;
  int listeners = 0;
  bool fail = false;

  List<Diary> _visible(String? categoryId) {
    requestedCategories.add(categoryId);
    if (fail) throw StateError('test read failure');
    return entries
        .where(
          (entry) =>
              entry.show &&
              (categoryId == null || entry.categoryId == categoryId),
        )
        .toList()
      ..sort((a, b) => b.time.compareTo(a.time));
  }

  @override
  Future<List<DiaryMonth>> loadMonths({String? categoryId}) async {
    final months = <DateTime, List<Diary>>{};
    for (final diary in _visible(categoryId)) {
      final date = diary.time.toLocal();
      months.putIfAbsent(DateTime(date.year, date.month), () => []).add(diary);
    }
    return months.entries
        .map(
          (month) => DiaryMonth(
            month: month.key,
            dayCount: month.value
                .map((diary) => diary.time.toLocal().day)
                .toSet()
                .length,
            entryCount: month.value.length,
          ),
        )
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));
  }

  @override
  Future<List<DiaryDay>> loadDays(DateTime month, {String? categoryId}) async {
    final days = <DateTime, List<Diary>>{};
    for (final diary in _visible(categoryId)) {
      final date = diary.time.toLocal();
      if (date.year != month.year || date.month != month.month) continue;
      days
          .putIfAbsent(DateTime(date.year, date.month, date.day), () => [])
          .add(diary);
    }
    return days.entries
        .map((day) => DiaryDay(day: day.key, entries: day.value))
        .toList()
      ..sort((a, b) => b.day.compareTo(a.day));
  }

  @override
  Future<List<Diary>> loadDay(DateTime day, {String? categoryId}) async =>
      _visible(categoryId).where((diary) {
        final date = diary.time.toLocal();
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).toList();

  @override
  Stream<void> watchChanges() => _changes.stream;
  void changed() => _changes.add(null);
  Future<void> close() => _changes.close();
}
