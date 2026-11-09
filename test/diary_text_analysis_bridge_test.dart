import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/src/rust/api/jieba.dart';
import 'package:moodiary/src/rust/frb_generated.dart';
import 'package:moodiary/utils/diary_text_analysis.dart';

class _Keyword extends Fake implements JiebaKeyword {
  _Keyword(this.keyword, this.weight);

  @override
  String keyword;

  @override
  double weight;
}

class _JiebaApi extends Fake implements RustLibApi {
  String? segmentedText;
  String? extractedText;
  BigInt? topK;
  List<String>? allowedPos;

  @override
  Future<List<String>> crateApiJiebaJiebaRsCutAll({
    required String text,
  }) async {
    segmentedText = text;
    return ['北京', '天安门'];
  }

  @override
  Future<List<JiebaKeyword>> crateApiJiebaJiebaRsExtractKeywordsTfidf({
    required String text,
    required BigInt topK,
    required List<String> allowedPos,
  }) async {
    extractedText = text;
    this.topK = topK;
    this.allowedPos = allowedPos;
    return [_Keyword('北京', 0.2), _Keyword('天安门', 0.8)];
  }
}

void main() {
  test('Jieba adapter requests five unrestricted TF-IDF keywords', () async {
    final api = _JiebaApi();
    RustLib.initMock(api: api);
    final analyzer = DiaryTextAnalyzer(ensureInitialized: () async {});

    final analysis = await analyzer.analyze('今天去北京看天安门');

    expect(api.segmentedText, '今天去北京看天安门');
    expect(api.extractedText, '今天去北京看天安门');
    expect(api.topK, BigInt.from(5));
    expect(api.allowedPos, isEmpty);
    expect(analysis.tokenizer, ['北京', '天安门']);
    expect(analysis.keywords, ['天安门', '北京']);
  });
}
