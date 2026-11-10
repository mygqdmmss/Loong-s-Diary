import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/base/image.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/utils/file_util.dart';

import 'memory_artwork.dart';
import 'monthly_diary_models.dart';

/// Owns one live query and discards results from an earlier scope or request.
class MonthlySourceBuilder<T> extends StatefulWidget {
  const MonthlySourceBuilder({
    super.key,
    required this.source,
    required this.queryKey,
    required this.load,
    required this.builder,
  });

  final MonthlyDiarySource source;
  final Object? queryKey;
  final Future<T> Function() load;
  final Widget Function(BuildContext, AsyncSnapshot<T>, VoidCallback) builder;

  @override
  State<MonthlySourceBuilder<T>> createState() =>
      _MonthlySourceBuilderState<T>();
}

class _MonthlySourceBuilderState<T> extends State<MonthlySourceBuilder<T>> {
  StreamSubscription<void>? _subscription;
  AsyncSnapshot<T> _snapshot = AsyncSnapshot<T>.nothing();
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _bind();
    _reload();
  }

  void _bind() {
    _subscription = widget.source.watchChanges().listen((_) => _reload());
  }

  @override
  void didUpdateWidget(covariant MonthlySourceBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _subscription?.cancel();
      _bind();
    }
    if (oldWidget.source != widget.source ||
        oldWidget.queryKey != widget.queryKey) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final request = ++_request;
    setState(() => _snapshot = AsyncSnapshot<T>.waiting());
    try {
      final value = await widget.load();
      if (!mounted || request != _request) return;
      setState(
        () => _snapshot = AsyncSnapshot.withData(ConnectionState.done, value),
      );
    } catch (error, stack) {
      if (!mounted || request != _request) return;
      setState(
        () => _snapshot = AsyncSnapshot.withError(
          ConnectionState.done,
          error,
          stack,
        ),
      );
    }
  }

  @override
  void dispose() {
    _request++;
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _snapshot, _reload);
}

String memoryExcerpt(BuildContext context, Diary diary) {
  if (diary.title.trim().isNotEmpty) return diary.title.trim();
  if (diary.contentText.trim().isNotEmpty) return diary.contentText.trim();
  if (diary.audioName.isNotEmpty) return context.l10n.monthlyAudioMemory;
  if (diary.videoName.isNotEmpty) return context.l10n.monthlyVideoMemory;
  return context.l10n.monthlyTextMemory;
}

Widget? memoryPhoto(Diary? diary, {int size = 300}) {
  if (diary == null || diary.imageName.isEmpty) return null;
  return IgnorePointer(
    child: MoodiaryImage(
      imagePath: FileUtil.getRealPath('image', diary.imageName.first),
      size: size,
      fit: BoxFit.cover,
      errorBuilder: (context) {
        final colors = MemoryArtworkColors(Theme.of(context).colorScheme);
        return ColoredBox(
          color: colors.sage,
          child: Center(
            child: Icon(
              Icons.local_florist_outlined,
              color: colors.accent,
              size: 36,
            ),
          ),
        );
      },
    ),
  );
}

class MonthlyMessage extends StatelessWidget {
  const MonthlyMessage({
    super.key,
    this.message,
    this.onRetry,
    this.loading = false,
  });
  final String? message;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = MemoryArtworkColors(Theme.of(context).colorScheme);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const CircularProgressIndicator()
          else ...[
            Icon(
              onRetry == null ? Icons.spa_outlined : Icons.cloud_off_outlined,
              size: 36,
              color: colors.accent,
            ),
            const SizedBox(height: 20),
            Text(
              message ?? context.l10n.monthlyLoadError,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.monthlyRetry),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
