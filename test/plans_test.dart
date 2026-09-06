import 'package:flutter_test/flutter_test.dart';
import 'package:holy_bible/app/data/models.dart';
import 'package:holy_bible/app/data/plans.dart';

final List<BookInfo> gospels = const [
  BookInfo(id: 40, name: 'Matthew', slug: 'matthew', chapterCount: 28),
  BookInfo(id: 41, name: 'Mark', slug: 'mark', chapterCount: 16),
  BookInfo(id: 42, name: 'Luke', slug: 'luke', chapterCount: 24),
  BookInfo(id: 43, name: 'John', slug: 'john', chapterCount: 21),
];

void main() {
  final plan = planById('gospels');

  test('gospels plan covers all chapters in canonical order', () {
    final chapters = planChapters(plan, gospels);
    expect(chapters, hasLength(89));
    expect(chapters.first.slug, 'matthew');
    expect(chapters.first.chapter, 1);
    expect(chapters.last.slug, 'john');
    expect(chapters.last.chapter, 21);
  });

  test('day chunks divide the plan evenly', () {
    final day1 = planDayChapters(plan, gospels, 1);
    final day30 = planDayChapters(plan, gospels, 30);
    expect(day1, isNotEmpty);
    expect(day1.length, (89 / 30).ceil());
    expect(day30, anyElement(isNotNull));
  });

  test('progress derives from the read-chapter set', () {
    final read = <String>{'matthew/1', 'matthew/2'};
    expect(planReadCount(plan, gospels, read), 2);
    final next = planNextUnread(plan, gospels, read);
    expect(next, const VerseRef('matthew', 3));
  });

  test('completed plan reports null next', () {
    final all = planChapters(plan, gospels)
        .map((r) => r.chapterKey)
        .toSet();
    expect(planNextUnread(plan, gospels, all), isNull);
    expect(planReadCount(plan, gospels, all), 89);
  });

  test('current day follows reading pace', () {
    expect(currentPlanDay(plan, gospels, {}), 1);
    final read = <String>{};
    for (var c = 1; c <= 3; c++) {
      read.add('matthew/$c');
    }
    expect(currentPlanDay(plan, gospels, read), 2);
  });
}
