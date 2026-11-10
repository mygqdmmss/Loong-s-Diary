import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/monthly_diary/memory_artwork.dart';
import 'package:moodiary/components/monthly_diary/memory_bubble_field.dart';
import 'package:moodiary/components/monthly_diary/monthly_diary_content.dart';
import 'package:moodiary/components/monthly_diary/monthly_diary_models.dart';
import 'package:moodiary/l10n/l10n.dart';

import 'monthly_day_page.dart';

class MonthlyDiaryPage extends StatefulWidget {
  const MonthlyDiaryPage({
    super.key,
    required this.source,
    required this.month,
    this.categoryId,
    this.onOpenDiary,
  });
  final MonthlyDiarySource source;
  final DateTime month;
  final String? categoryId;
  final Future<void> Function(Diary)? onOpenDiary;

  @override
  State<MonthlyDiaryPage> createState() => _MonthlyDiaryPageState();
}

class _MonthlyDiaryPageState extends State<MonthlyDiaryPage> {
  late DateTime _month = widget.month;
  bool _choosing = false;

  Future<void> _chooseMonth() async {
    if (_choosing) return;
    _choosing = true;
    try {
      final months = await widget.source.loadMonths(
        categoryId: widget.categoryId,
      );
      if (!mounted) return;
      final selected = await showModalBottomSheet<DateTime>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.monthlyChooseMonth,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: months.isEmpty
                    ? MonthlyMessage(message: context.l10n.monthlyEmpty)
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: months.length,
                        itemBuilder: (context, index) {
                          final month = months[index];
                          return ListTile(
                            key: ValueKey(
                              'choose-${month.month.year}-${month.month.month}',
                            ),
                            title: Text(
                              DateFormat.yMMMM(
                                context.l10n.localeName,
                              ).format(month.month),
                            ),
                            subtitle: Text(
                              context.l10n.monthlySummary(
                                month.dayCount,
                                month.entryCount,
                              ),
                            ),
                            trailing: month.month == _month
                                ? const Icon(Icons.check_rounded)
                                : null,
                            onTap: () => Navigator.pop(context, month.month),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
      if (mounted && selected != null && selected != _month) {
        setState(() => _month = selected);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.monthlyLoadError),
            action: SnackBarAction(
              label: context.l10n.monthlyRetry,
              onPressed: _chooseMonth,
            ),
          ),
        );
      }
    } finally {
      _choosing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MemoryArtworkColors(Theme.of(context).colorScheme);
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        title: Text(DateFormat.yMMMM(context.l10n.localeName).format(_month)),
        actions: [
          IconButton(
            key: const ValueKey('choose-month'),
            tooltip: context.l10n.monthlyChooseMonth,
            onPressed: _chooseMonth,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: MonthlySourceBuilder<List<DiaryDay>>(
          source: widget.source,
          queryKey: (_month, widget.categoryId),
          load: () =>
              widget.source.loadDays(_month, categoryId: widget.categoryId),
          builder: (context, snapshot, reload) {
            if (snapshot.hasError) {
              return Center(child: MonthlyMessage(onRetry: reload));
            }
            if (!snapshot.hasData) {
              return const Center(child: MonthlyMessage(loading: true));
            }
            final days = snapshot.requireData;
            if (days.isEmpty) {
              return Center(
                child: MonthlyMessage(message: context.l10n.monthlyEmpty),
              );
            }
            return SingleChildScrollView(
              key: ValueKey((_month, widget.categoryId)),
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 40),
              child: Column(
                children: [
                  Text(
                    context.l10n.monthlySummary(
                      days.length,
                      days.fold<int>(
                        0,
                        (count, day) => count + day.entries.length,
                      ),
                    ),
                    style: TextStyle(color: colors.muted, letterSpacing: 1),
                  ),
                  const SizedBox(height: 24),
                  MemoryBubbleField(
                    children: [
                      for (final day in days)
                        MemoryDayBubble(
                          key: ValueKey(
                            'day-${day.day.year}-${day.day.month}-${day.day.day}',
                          ),
                          day: day.day,
                          dateLabel: DateFormat.MMMEd(
                            context.l10n.localeName,
                          ).format(day.day),
                          excerpt: day.entries.isEmpty
                              ? ''
                              : memoryExcerpt(context, day.entries.first),
                          semanticsLabel:
                              '${DateFormat.yMMMMd(context.l10n.localeName).format(day.day)}, '
                              '${context.l10n.monthlyEntryCount(day.entries.length)}',
                          entryCount: day.entries.length,
                          photo: memoryPhoto(day.cover),
                          accent: day.cover?.imageColor == null
                              ? null
                              : Color(day.cover!.imageColor!),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MonthlyDayPage(
                                source: widget.source,
                                day: day.day,
                                categoryId: widget.categoryId,
                                onOpenDiary: widget.onOpenDiary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
