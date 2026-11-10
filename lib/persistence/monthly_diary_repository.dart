import 'package:isar/isar.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/monthly_diary/monthly_diary_models.dart';

class MonthlyDiaryRepository implements MonthlyDiarySource {
  MonthlyDiaryRepository(this._isar);

  final Isar _isar;

  QueryBuilder<Diary, Diary, QAfterFilterCondition> _visibleEntries(
    String? categoryId,
  ) {
    final query = _isar.diarys.where().showEqualTo(true);
    return categoryId == null ? query : query.categoryIdEqualTo(categoryId);
  }

  @override
  Future<List<DiaryMonth>> loadMonths({String? categoryId}) async {
    // Month packages need timestamps only, including records beyond the home
    // list's page limit. Full diary content is loaded after a month is opened.
    final times = await _visibleEntries(
      categoryId,
    ).timeProperty().findAllAsync();
    final entryCounts = <DateTime, int>{};
    final days = <DateTime, Set<int>>{};
    for (final time in times) {
      final local = time.toLocal();
      final month = DateTime(local.year, local.month);
      entryCounts.update(month, (count) => count + 1, ifAbsent: () => 1);
      (days[month] ??= <int>{}).add(local.day);
    }
    final months = entryCounts.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final month in months)
        DiaryMonth(
          month: month,
          dayCount: days[month]!.length,
          entryCount: entryCounts[month]!,
        ),
    ];
  }

  @override
  Future<List<DiaryDay>> loadDays(DateTime month, {String? categoryId}) async {
    final local = month.toLocal();
    final start = DateTime(local.year, local.month);
    final end = DateTime(local.year, local.month + 1);
    final entries = await _loadRange(start, end, categoryId);
    final groups = <DateTime, List<Diary>>{};
    for (final entry in entries) {
      (groups[localDiaryDate(entry.time)] ??= []).add(entry);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final day in days) DiaryDay(day: day, entries: groups[day]!)];
  }

  @override
  Future<List<Diary>> loadDay(DateTime day, {String? categoryId}) {
    final start = localDiaryDate(day);
    final end = DateTime(start.year, start.month, start.day + 1);
    return _loadRange(start, end, categoryId);
  }

  Future<List<Diary>> _loadRange(
    DateTime start,
    DateTime end,
    String? categoryId,
  ) => _visibleEntries(categoryId)
      .timeGreaterThanOrEqualTo(start)
      .timeLessThan(end)
      .sortByTimeDesc()
      .findAllAsync();

  @override
  Stream<void> watchChanges() => _isar.diarys.watchLazy();
}
