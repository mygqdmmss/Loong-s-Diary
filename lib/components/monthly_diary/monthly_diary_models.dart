import 'package:moodiary/common/models/isar/diary.dart';

class DiaryMonth {
  const DiaryMonth({
    required this.month,
    required this.dayCount,
    required this.entryCount,
  });

  final DateTime month;
  final int dayCount;
  final int entryCount;
}

class DiaryDay {
  DiaryDay({required DateTime day, required List<Diary> entries})
    : day = localDiaryDate(day),
      entries = List<Diary>.unmodifiable(
        [...entries]..sort((a, b) => b.time.compareTo(a.time)),
      );

  final DateTime day;
  final List<Diary> entries;

  Diary? get cover {
    for (final entry in entries) {
      if (entry.imageName.isNotEmpty) return entry;
    }
    return null;
  }

  String get excerpt {
    if (entries.isEmpty) return '';
    final first = entries.first;
    final title = first.title.trim();
    return title.isNotEmpty ? title : first.contentText.trim();
  }
}

/// The calendar date of an instant in the device's current local timezone.
DateTime localDiaryDate(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

abstract interface class MonthlyDiarySource {
  Future<List<DiaryMonth>> loadMonths({String? categoryId});
  Future<List<DiaryDay>> loadDays(DateTime month, {String? categoryId});
  Future<List<Diary>> loadDay(DateTime day, {String? categoryId});
  Stream<void> watchChanges();
}
