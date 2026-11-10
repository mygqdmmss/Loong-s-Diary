import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/pages/monthly_diary/monthly_diary_page.dart';
import 'memory_artwork.dart';
import 'month_package_card.dart';
import 'monthly_diary_content.dart';
import 'monthly_diary_models.dart';

class MonthlyDiarySliver extends StatelessWidget {
  const MonthlyDiarySliver({
    super.key,
    required this.source,
    this.categoryId,
    this.onOpenDiary,
  });
  final MonthlyDiarySource source;
  final String? categoryId;
  final Future<void> Function(Diary)? onOpenDiary;

  @override
  Widget build(BuildContext context) => MonthlySourceBuilder<List<DiaryMonth>>(
    source: source,
    queryKey: categoryId,
    load: () => source.loadMonths(categoryId: categoryId),
    builder: (context, snapshot, reload) {
      if (snapshot.hasError) {
        return SliverToBoxAdapter(child: MonthlyMessage(onRetry: reload));
      }
      if (!snapshot.hasData) {
        return const SliverToBoxAdapter(child: MonthlyMessage(loading: true));
      }
      final months = snapshot.requireData;
      if (months.isEmpty) {
        return SliverToBoxAdapter(
          child: MonthlyMessage(message: context.l10n.monthlyEmpty),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.only(top: 12, bottom: 40),
        sliver: SliverList.builder(
          itemCount: months.length,
          itemBuilder: (context, index) {
            final month = months[index];
            return _MonthPreview(
              key: ValueKey('preview-${month.month}'),
              source: source,
              month: month,
              categoryId: categoryId,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MonthlyDiaryPage(
                    source: source,
                    month: month.month,
                    categoryId: categoryId,
                    onOpenDiary: onOpenDiary,
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

/// Only mounted month bags load their previews, rather than all diary content.
class _MonthPreview extends StatefulWidget {
  const _MonthPreview({
    super.key,
    required this.source,
    required this.month,
    required this.categoryId,
    required this.onTap,
  });
  final MonthlyDiarySource source;
  final DiaryMonth month;
  final String? categoryId;
  final VoidCallback onTap;

  @override
  State<_MonthPreview> createState() => _MonthPreviewState();
}

class _MonthPreviewState extends State<_MonthPreview> {
  late Future<List<DiaryDay>> _covers = _load();
  Future<List<DiaryDay>> _load() =>
      widget.source.loadDays(widget.month.month, categoryId: widget.categoryId);

  @override
  void didUpdateWidget(covariant _MonthPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month ||
        oldWidget.source != widget.source ||
        oldWidget.categoryId != widget.categoryId) {
      _covers = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DiaryDay>>(
    future: _covers,
    builder: (context, snapshot) {
      final month = widget.month;
      final title = DateFormat.yMMMM(
        context.l10n.localeName,
      ).format(month.month);
      final subtitle = context.l10n.monthlySummary(
        month.dayCount,
        month.entryCount,
      );
      final days = snapshot.connectionState == ConnectionState.done
          ? snapshot.data ?? const <DiaryDay>[]
          : const <DiaryDay>[];
      final covers = days
          .map((day) => day.cover)
          .whereType<Diary>()
          .take(2)
          .toList();
      return MonthPackageCard(
        key: ValueKey('month-${month.month.year}-${month.month.month}'),
        month: month.month,
        title: title,
        subtitle: subtitle,
        openLabel: context.l10n.monthlyOpen,
        semanticsLabel: '$title, $subtitle, ${context.l10n.monthlyOpen}',
        photos: covers.isNotEmpty
            ? [for (final diary in covers) memoryPhoto(diary, size: 160)!]
            : [
                for (final diary in days.expand((day) => day.entries).take(2))
                  _MonthNote(excerpt: memoryExcerpt(context, diary)),
              ],
        onTap: widget.onTap,
      );
    },
  );
}

class _MonthNote extends StatelessWidget {
  const _MonthNote({required this.excerpt});

  final String excerpt;

  @override
  Widget build(BuildContext context) {
    final colors = MemoryArtworkColors(Theme.of(context).colorScheme);
    const fontSize = 13.0;
    const lineHeight = 1.2;
    final scaledLineHeight =
        MediaQuery.textScalerOf(context).scale(fontSize) * lineHeight;
    return IgnorePointer(
      child: ClipRect(
        child: ColoredBox(
          color: colors.paper,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: LayoutBuilder(
              builder: (context, constraints) => Text(
                excerpt,
                maxLines: (constraints.maxHeight / scaledLineHeight)
                    .floor()
                    .clamp(1, 4),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  height: lineHeight,
                  color: colors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
