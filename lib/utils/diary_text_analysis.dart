import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/src/rust/api/jieba.dart';
import 'package:moodiary/utils/rust_util.dart';

typedef WeightedDiaryKeyword = ({String keyword, double weight});

class DiaryTextAnalysis {
  DiaryTextAnalysis({
    required Iterable<String> tokenizer,
    required Iterable<String> keywords,
  }) : tokenizer = List.unmodifiable(tokenizer),
       keywords = List.unmodifiable(keywords);

  final List<String> tokenizer;
  final List<String> keywords;

  void applyTo(Diary diary) {
    diary.tokenizer = List.of(tokenizer);
    diary.keywords = List.of(keywords);
  }
}

class DiaryTextAnalyzer {
  DiaryTextAnalyzer({
    Future<void> Function()? ensureInitialized,
    Future<List<String>> Function(String)? cutAll,
    Future<List<WeightedDiaryKeyword>> Function(String)? extractKeywords,
  }) : _ensureInitialized = ensureInitialized ?? RustUtil.ensureInitialized,
       _cutAll = cutAll ?? ((text) => JiebaRs.cutAll(text: text)),
       _extractKeywords = extractKeywords ?? _extractJiebaKeywords;

  static const _keywordLimit = 5;

  final Future<void> Function() _ensureInitialized;
  final Future<List<String>> Function(String) _cutAll;
  final Future<List<WeightedDiaryKeyword>> Function(String) _extractKeywords;

  Future<DiaryTextAnalysis> analyze(String text) async {
    if (text.trim().isEmpty) {
      return DiaryTextAnalysis(tokenizer: [], keywords: []);
    }

    await _ensureInitialized();
    final tokenizer = await _cutAll(text);
    final keywords = List<WeightedDiaryKeyword>.of(await _extractKeywords(text))
      ..sort((a, b) => b.weight.compareTo(a.weight));
    return DiaryTextAnalysis(
      tokenizer: tokenizer,
      keywords: keywords.take(_keywordLimit).map((entry) => entry.keyword),
    );
  }

  static Future<List<WeightedDiaryKeyword>> _extractJiebaKeywords(
    String text,
  ) async {
    final keywords = await JiebaRs.extractKeywordsTfidf(
      text: text,
      topK: BigInt.from(_keywordLimit),
      allowedPos: [],
    );
    return keywords
        .map((entry) => (keyword: entry.keyword, weight: entry.weight))
        .toList();
  }
}

/// Derived metadata must not prevent the user's text from being saved.
/// A failed analysis leaves both existing fields intact; persistence errors
/// still propagate to the caller.
Future<void> saveDiaryWithAnalysis({
  required Diary diary,
  required Future<void> Function() save,
  DiaryTextAnalyzer? analyzer,
  void Function(Object, StackTrace)? onAnalysisError,
}) async {
  try {
    final analysis = await (analyzer ?? DiaryTextAnalyzer()).analyze(
      diary.contentText,
    );
    analysis.applyTo(diary);
  } catch (error, stackTrace) {
    onAnalysisError?.call(error, stackTrace);
  }
  await save();
}
