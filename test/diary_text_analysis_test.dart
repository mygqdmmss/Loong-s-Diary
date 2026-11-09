import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/utils/diary_text_analysis.dart';

Diary syntheticDiary() => Diary()
  ..type = 'text'
  ..content = '新正文'
  ..contentText = '今天去北京看天安门'
  ..tokenizer = ['旧分词']
  ..keywords = ['旧关键词'];

DiaryTextAnalyzer analyzerWith({
  Future<void> Function()? initialize,
  Future<List<String>> Function(String)? cut,
  Future<List<WeightedDiaryKeyword>> Function(String)? extract,
}) => DiaryTextAnalyzer(
  ensureInitialized: initialize ?? () async {},
  cutAll: cut ?? (_) async => ['北京', '天安门'],
  extractKeywords:
      extract ??
      (_) async => [
        (keyword: '北京', weight: 0.2),
        (keyword: '天安门', weight: 0.9),
      ],
);

void main() {
  test('analyzes Chinese text and sorts the five strongest keywords', () async {
    final analyzer = analyzerWith(
      cut: (text) async {
        expect(text, '今天去北京看天安门');
        return ['北京', '天安门'];
      },
      extract: (text) async {
        expect(text, '今天去北京看天安门');
        return [
          (keyword: '六', weight: 0.1),
          (keyword: '四', weight: 0.3),
          (keyword: '二', weight: 0.5),
          (keyword: '一', weight: 0.6),
          (keyword: '三', weight: 0.4),
          (keyword: '五', weight: 0.2),
        ];
      },
    );

    final analysis = await analyzer.analyze('今天去北京看天安门');

    expect(analysis.tokenizer, ['北京', '天安门']);
    expect(analysis.keywords, ['一', '二', '三', '四', '五']);
  });

  test('does not segment text until Rust initialization completes', () async {
    final ready = Completer<void>();
    final calls = <String>[];
    final analyzer = analyzerWith(
      initialize: () => ready.future,
      cut: (_) async {
        calls.add('cut');
        return ['北京'];
      },
      extract: (_) async {
        calls.add('extract');
        return [(keyword: '北京', weight: 1.0)];
      },
    );
    final pending = analyzer.analyze('北京');
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);

    ready.complete();
    final result = await pending;
    expect(calls, ['cut', 'extract']);
    expect(result.keywords, ['北京']);
  });

  test('empty content clears previous fields without requiring Rust', () async {
    final diary = syntheticDiary()..contentText = ' \r\n\t';
    Diary? saved;
    final analyzer = analyzerWith(
      initialize: () => throw StateError('Rust is unavailable'),
    );

    await saveDiaryWithAnalysis(
      diary: diary,
      analyzer: analyzer,
      save: () async => saved = diary.clone(),
    );

    expect(saved, isNotNull);
    expect(saved!.tokenizer, isEmpty);
    expect(saved!.keywords, isEmpty);
  });

  for (final failingStage in ['initialization', 'segmentation', 'keywords']) {
    test(
      '$failingStage failure preserves both old fields and saves new text',
      () async {
        final failure = StateError('$failingStage unavailable');
        final diary = syntheticDiary();
        Diary? saved;
        Object? reported;
        final analyzer = analyzerWith(
          initialize: failingStage == 'initialization'
              ? () async => throw failure
              : null,
          cut: failingStage == 'segmentation'
              ? (_) async => throw failure
              : null,
          extract: failingStage == 'keywords'
              ? (_) async => throw failure
              : null,
        );

        await saveDiaryWithAnalysis(
          diary: diary,
          analyzer: analyzer,
          save: () async => saved = diary.clone(),
          onAnalysisError: (error, _) => reported = error,
        );

        expect(saved, isNotNull);
        expect(saved!.content, '新正文');
        expect(saved!.contentText, '今天去北京看天安门');
        expect(saved!.tokenizer, ['旧分词']);
        expect(saved!.keywords, ['旧关键词']);
        expect(reported, same(failure));
      },
    );
  }

  test('successful analysis replaces both fields before persistence', () async {
    final diary = syntheticDiary();
    Diary? saved;

    await saveDiaryWithAnalysis(
      diary: diary,
      analyzer: analyzerWith(),
      save: () async => saved = diary.clone(),
    );

    expect(saved!.content, '新正文');
    expect(saved!.tokenizer, ['北京', '天安门']);
    expect(saved!.keywords, ['天安门', '北京']);
  });

  test('failed analysis still permits saving a new diary', () async {
    final diary = Diary()
      ..type = 'text'
      ..content = '新建日记'
      ..contentText = '新建日记';
    Diary? saved;

    await saveDiaryWithAnalysis(
      diary: diary,
      analyzer: analyzerWith(
        initialize: () async => throw StateError('offline'),
      ),
      save: () async => saved = diary.clone(),
    );

    expect(saved!.content, '新建日记');
    expect(saved!.keywords, isEmpty);
    expect(saved!.tokenizer, isEmpty);
  });

  test(
    'database errors propagate instead of being treated as analysis failure',
    () async {
      final failure = StateError('database write failed');
      var analysisReported = false;

      await expectLater(
        saveDiaryWithAnalysis(
          diary: syntheticDiary(),
          analyzer: analyzerWith(),
          save: () async => throw failure,
          onAnalysisError: (_, _) => analysisReported = true,
        ),
        throwsA(same(failure)),
      );

      expect(analysisReported, isFalse);
    },
  );
}
