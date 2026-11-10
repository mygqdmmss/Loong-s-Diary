import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/monthly_diary/memory_artwork.dart';
import 'package:moodiary/components/monthly_diary/monthly_diary_content.dart';
import 'package:moodiary/components/monthly_diary/monthly_diary_models.dart';
import 'package:moodiary/l10n/l10n.dart';

import 'monthly_diary_navigation.dart';

class MonthlyDayPage extends StatefulWidget {
  const MonthlyDayPage({
    super.key,
    required this.source,
    required this.day,
    this.categoryId,
    this.onOpenDiary,
  });
  final MonthlyDiarySource source;
  final DateTime day;
  final String? categoryId;
  final Future<void> Function(Diary)? onOpenDiary;

  @override
  State<MonthlyDayPage> createState() => _MonthlyDayPageState();
}

class _MonthlyDayPageState extends State<MonthlyDayPage> {
  bool _opening = false;

  Future<void> _open(Diary diary, VoidCallback reload) async {
    if (_opening) return;
    _opening = true;
    try {
      await (widget.onOpenDiary ?? openMonthlyDiary)(diary);
      if (mounted) reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.monthlyLoadError)));
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MemoryArtworkColors(Theme.of(context).colorScheme);
    final locale = context.l10n.localeName;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        title: Text(DateFormat.yMMMMd(locale).format(widget.day)),
      ),
      body: SafeArea(
        top: false,
        child: MonthlySourceBuilder<List<Diary>>(
          source: widget.source,
          queryKey: (widget.day, widget.categoryId),
          load: () =>
              widget.source.loadDay(widget.day, categoryId: widget.categoryId),
          builder: (context, snapshot, reload) {
            if (snapshot.hasError) {
              return Center(child: MonthlyMessage(onRetry: reload));
            }
            if (!snapshot.hasData) {
              return const Center(child: MonthlyMessage(loading: true));
            }
            final entries = snapshot.requireData;
            if (entries.isEmpty) {
              return Center(
                child: MonthlyMessage(message: context.l10n.monthlyEmptyDay),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final diary = entries[index];
                final photo = memoryPhoto(diary);
                final title = memoryExcerpt(context, diary);
                final time = DateFormat.Hm(locale).format(diary.time.toLocal());
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: MemoryArtworkButton(
                        key: ValueKey('entry-${diary.id}'),
                        label:
                            '$time, $title, ${context.l10n.monthlyReadEntry}',
                        onTap: () => _open(diary, reload),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: colors.accent.withValues(alpha: .14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (photo != null)
                                SizedBox(height: 180, child: photo),
                              Padding(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      time,
                                      style: TextStyle(
                                        color: colors.accent,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(height: 1.5),
                                    ),
                                    if (diary.title.trim().isNotEmpty &&
                                        diary.contentText
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        diary.contentText.trim(),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.muted,
                                          height: 1.7,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 22),
                                    Wrap(
                                      spacing: 10,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          context.l10n.monthlyReadEntry,
                                          style: TextStyle(
                                            color: colors.accent,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                          color: colors.accent,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
