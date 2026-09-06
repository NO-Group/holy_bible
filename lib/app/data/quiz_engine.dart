/// Quiz engine — a faithful Dart port of the web app's generator
/// (`lib/Holy_Bible-main/app/js/quiz.js`): random questions are produced
/// from the live translation bundle, so every quiz round differs.
library;

import 'dart:math';

import 'models.dart';
import 'verse_refs.dart';

enum QuizMode {
  mixed('mixed', 'Mixed Challenge', 'All question styles, shuffled'),
  whichBook('whichbook', 'Which Book?', 'Identify the book of a random verse'),
  finishVerse('finish', 'Finish the Verse', 'Complete a famous verse'),
  order('order', 'Book Order', 'Canonical order, counts, testaments');

  final String id;
  final String label;
  final String desc;
  const QuizMode(this.id, this.label, this.desc);

  static QuizMode fromId(String? id) => QuizMode.values.firstWhere(
        (m) => m.id == id,
        orElse: () => QuizMode.mixed,
      );
}

class QuizQuestion {
  final String question;
  final String? quote;
  final List<String> options;
  final int answer;
  final String explain;

  const QuizQuestion({
    required this.question,
    this.quote,
    required this.options,
    required this.answer,
    required this.explain,
  });
}

const int kQuestionsPerRound = 10;

class QuizEngine {
  final BibleBundle bundle;
  final Random rng;

  QuizEngine(this.bundle, [Random? random]) : rng = random ?? Random();

  int _rnd(int n) => rng.nextInt(n);

  List<T> _shuffle<T>(List<T> a) {
    final x = List<T>.of(a);
    for (var i = x.length - 1; i > 0; i--) {
      final j = _rnd(i + 1);
      final tmp = x[i];
      x[i] = x[j];
      x[j] = tmp;
    }
    return x;
  }

  List<T> _sample<T>(List<T> a, int n) => _shuffle(a).take(n).toList();

  /// Random verse of decent length; returns null after too many tries.
  ({int b, int c, int v, String text})? _randomVerse(
    int minWords,
    int maxWords,
  ) {
    for (var tries = 0; tries < 200; tries++) {
      final b = _rnd(bundle.books.length);
      final chapters = bundle.books[b].chapters;
      final c = _rnd(chapters.length);
      final v = _rnd(chapters[c].length);
      final text = chapters[c][v];
      if (text.trim().isEmpty) continue;
      final w = text.split(' ').length;
      if (w >= minWords && w <= maxWords) return (b: b, c: c, v: v, text: text);
    }
    return null;
  }

  String _refLabel(int bIdx, int c, int v) =>
      '${bundle.books[bIdx].name} ${c + 1}:${v + 1}';

  QuizQuestion? _qWhichBook() {
    final ver = _randomVerse(8, 40);
    if (ver == null) return null;
    final correct = bundle.books[ver.b].name;
    final wrongPool =
        bundle.books.map((b) => b.name).where((n) => n != correct).toList();
    final options =
        _shuffle([correct, ..._sample(wrongPool, 3)]);
    return QuizQuestion(
      question: 'Which book is this verse from?',
      quote: '“${ver.text}”',
      options: options,
      answer: options.indexOf(correct),
      explain: _refLabel(ver.b, ver.c, ver.v),
    );
  }

  QuizQuestion? _qFinishVerse() {
    final famous = kFamousVerses[_rnd(kFamousVerses.length)];
    final bIdx = bundle.books.indexWhere((b) => b.slug == famous.slug);
    if (bIdx < 0) return null;
    final chapter = bundle.books[bIdx].chapters[famous.ch - 1];
    if (famous.v - 1 >= chapter.length) return null;
    final text = chapter[famous.v - 1];
    if (text.trim().isEmpty) return null;
    final words = text.split(' ');
    if (words.length < 8) return null;
    final cut = max(4, (words.length * 0.55).floor()).toInt();
    final stem = words.take(cut).join(' ');
    final correct = words.skip(cut).join(' ');
    final wrongs = <String>[];
    for (var i = 0; i < 40 && wrongs.length < 3; i++) {
      final rv = _randomVerse(8, 50);
      if (rv == null) continue;
      final w = rv.text.split(' ');
      final need = words.length - cut;
      final end = w.skip(max(0, w.length - need)).join(' ');
      if (end.isNotEmpty && end != correct && !wrongs.contains(end)) {
        wrongs.add(end);
      }
    }
    if (wrongs.length < 3) return null;
    final options = _shuffle([correct, ...wrongs]);
    return QuizQuestion(
      question: 'Finish the verse:',
      quote: '“$stem …”',
      options: options.map((o) => '… $o').toList(),
      answer: options.indexOf(correct),
      explain: '${bundle.books[bIdx].name} ${famous.ch}:${famous.v}',
    );
  }

  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  QuizQuestion? _qBookOrder() {
    final names = bundle.books.map((b) => b.name).toList();
    final type = _rnd(3);
    if (type == 0) {
      final i = _rnd(names.length - 1);
      final correct = names[i + 1];
      final wrong = _sample(
        names.where((n) => n != correct && n != names[i]).toList(),
        3,
      );
      final options = _shuffle([correct, ...wrong]);
      return QuizQuestion(
        question: 'Which book comes right after ${names[i]}?',
        options: options,
        answer: options.indexOf(correct),
        explain: '${names[i]} → $correct',
      );
    }
    if (type == 1) {
      final i = _rnd(names.length);
      final correct = names[i];
      final wrong = _sample(names.where((n) => n != correct).toList(), 3);
      final options = _shuffle([correct, ...wrong]);
      return QuizQuestion(
        question: 'What is the ${_ordinal(i + 1)} book of the Bible?',
        options: options,
        answer: options.indexOf(correct),
        explain: 'Book #${i + 1} is $correct',
      );
    }
    final i = _rnd(names.length);
    final isOT = i < 39;
    final options = ['Old Testament', 'New Testament'];
    return QuizQuestion(
      question: 'Is ${names[i]} in the Old or New Testament?',
      options: options,
      answer: isOT ? 0 : 1,
      explain:
          '${names[i]} is book #${i + 1}${isOT ? ' (OT has 39 books)' : ' (NT begins with Matthew, #40)'}',
    );
  }

  QuizQuestion? _qChapterCount() {
    final known = bundle.books.where((b) => b.chapters.length >= 10).toList();
    final b = known[_rnd(known.length)];
    final correct = b.chapters.length;
    final wrongs = <int>{};
    const offsets = [-15, -10, -7, -5, -3, 3, 5, 7, 10, 15];
    while (wrongs.length < 3) {
      final w = correct + offsets[_rnd(offsets.length)];
      if (w > 0 && w != correct) wrongs.add(w);
    }
    final options = _shuffle([correct, ...wrongs]).map((e) => '$e').toList();
    return QuizQuestion(
      question: 'How many chapters does ${b.name} have?',
      options: options,
      answer: options.indexOf('$correct'),
      explain: '${b.name} has $correct chapters',
    );
  }

  List<QuizQuestion> buildRound(QuizMode mode) {
    final builders = <QuizQuestion? Function()>[
      if (mode == QuizMode.mixed || mode == QuizMode.whichBook) _qWhichBook,
      if (mode == QuizMode.mixed || mode == QuizMode.finishVerse) _qFinishVerse,
      if (mode == QuizMode.mixed || mode == QuizMode.order) _qBookOrder,
      if (mode == QuizMode.mixed || mode == QuizMode.order) _qChapterCount,
    ];
    final out = <QuizQuestion>[];
    var guard = 0;
    while (out.length < kQuestionsPerRound && guard++ < 300 && builders.isNotEmpty) {
      final q = builders[_rnd(builders.length)]();
      if (q != null &&
          !out.any((x) => x.question == q.question && x.quote == q.quote)) {
        out.add(q);
      }
    }
    return out;
  }
}
