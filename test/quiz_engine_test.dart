import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:holy_bible/app/data/models.dart';
import 'package:holy_bible/app/data/quiz_engine.dart';

BibleBundle _syntheticBundle() {
  List<List<String>> chapters(int count, String prefix) => [
        for (var c = 0; c < count; c++)
          [
            for (var v = 0; v < 6; v++)
              '$prefix verse $v: the steadfast love of the Lord endures forever amen',
          ],
      ];
  return BibleBundle(
    code: 'test',
    translation: 'TEST',
    name: 'Test Translation',
    books: [
      BundledBook(
        id: 1,
        name: 'Genesis',
        slug: 'genesis',
        chapters: chapters(3, 'Genesis'),
      ),
      BundledBook(
        id: 40,
        name: 'Matthew',
        slug: 'matthew',
        chapters: chapters(12, 'Matthew'),
      ),
      BundledBook(
        id: 66,
        name: 'Revelation',
        slug: 'revelation',
        chapters: chapters(2, 'Revelation'),
      ),
    ],
  );
}

void main() {
  final bundle = _syntheticBundle();

  test('every mode builds a round of questions', () {
    for (final mode in QuizMode.values) {
      final questions = QuizEngine(bundle).buildRound(mode);
      expect(questions, isNotEmpty, reason: mode.id);
      for (final q in questions) {
        expect(q.options.length, greaterThanOrEqualTo(2));
        expect(q.answer, inInclusiveRange(0, q.options.length - 1));
        expect(q.explain, isNotEmpty);
      }
    }
  });

  test('mixed mode includes all question styles', () {
    final questions = QuizEngine(bundle).buildRound(QuizMode.mixed);
    final prompt = questions.map((q) => '${q.question}|${q.quote ?? ''}');
    expect(prompt.length, lessThanOrEqualTo(10),
        reason: 'rounds cap at ten questions');
  });

  test('generated questions are well-formed across seeds', () {
    for (var i = 0; i < 25; i++) {
      final q = QuizEngine(bundle, Random(i)).buildRound(QuizMode.mixed);
      for (final item in q) {
        expect(item.options.length, greaterThanOrEqualTo(2));
        expect(item.answer, inInclusiveRange(0, item.options.length - 1));
        expect(item.options.toSet().length, item.options.length,
            reason: 'options should be unique');
      }
    }
  });
}
