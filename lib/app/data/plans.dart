/// Reading plans: chapter sequences spanning one or many books, with
/// day-based pacing. Progress is derived purely from the set of chapters
/// the reader has completed.
library;

import 'models.dart';

class PlanDef {
  final String id;
  final String name;
  final String desc;
  final String emoji;
  final int days;
  final List<String> bookSlugs;

  const PlanDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.emoji,
    required this.days,
    required this.bookSlugs,
  });
}

const List<PlanDef> kPlans = [
  PlanDef(
    id: 'whole',
    name: 'The Whole Bible',
    desc: 'Genesis to Revelation in one year',
    emoji: '📖',
    days: 365,
    bookSlugs: [
      // All 66 books, canonical order.
      'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy',
      'joshua', 'judges', 'ruth', '1_samuel', '2_samuel',
      '1_kings', '2_kings', '1_chronicles', '2_chronicles', 'ezra',
      'nehemiah', 'esther', 'job', 'psalms', 'proverbs',
      'ecclesiastes', 'song_of_solomon', 'isaiah', 'jeremiah', 'lamentations',
      'ezekiel', 'daniel', 'hosea', 'joel', 'amos',
      'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk',
      'zephaniah', 'haggai', 'zechariah', 'malachi', 'matthew',
      'mark', 'luke', 'john', 'acts', 'romans',
      '1_corinthians', '2_corinthians', 'galatians', 'ephesians', 'philippians',
      'colossians', '1_thessalonians', '2_thessalonians', '1_timothy', '2_timothy',
      'titus', 'philemon', 'hebrews', 'james', '1_peter',
      '2_peter', '1_john', '2_john', '3_john', 'jude',
      'revelation',
    ],
  ),
  PlanDef(
    id: 'ot',
    name: 'Old Testament',
    desc: 'All 39 books · six months',
    emoji: '📜',
    days: 180,
    bookSlugs: [
      'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy',
      'joshua', 'judges', 'ruth', '1_samuel', '2_samuel',
      '1_kings', '2_kings', '1_chronicles', '2_chronicles', 'ezra',
      'nehemiah', 'esther', 'job', 'psalms', 'proverbs',
      'ecclesiastes', 'song_of_solomon', 'isaiah', 'jeremiah', 'lamentations',
      'ezekiel', 'daniel', 'hosea', 'joel', 'amos',
      'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk',
      'zephaniah', 'haggai', 'zechariah', 'malachi',
    ],
  ),
  PlanDef(
    id: 'nt',
    name: 'New Testament',
    desc: 'All 27 books · 90 days',
    emoji: '✝️',
    days: 90,
    bookSlugs: [
      'matthew', 'mark', 'luke', 'john', 'acts',
      'romans', '1_corinthians', '2_corinthians', 'galatians', 'ephesians',
      'philippians', 'colossians', '1_thessalonians', '2_thessalonians',
      '1_timothy', '2_timothy', 'titus', 'philemon', 'hebrews',
      'james', '1_peter', '2_peter', '1_john', '2_john',
      '3_john', 'jude', 'revelation',
    ],
  ),
  PlanDef(
    id: 'gospels',
    name: 'The Gospels',
    desc: 'Matthew, Mark, Luke & John · 30 days',
    emoji: '🌈',
    days: 30,
    bookSlugs: ['matthew', 'mark', 'luke', 'john'],
  ),
  PlanDef(
    id: 'wisdom',
    name: 'Wisdom & Worship',
    desc: 'Psalms & Proverbs · 31 days',
    emoji: '🕊️',
    days: 31,
    bookSlugs: ['psalms', 'proverbs'],
  ),
  PlanDef(
    id: 'paul',
    name: "Paul's Letters",
    desc: 'Romans through Philemon · 40 days',
    emoji: '✉️',
    days: 40,
    bookSlugs: [
      'romans', '1_corinthians', '2_corinthians', 'galatians', 'ephesians',
      'philippians', 'colossians', '1_thessalonians', '2_thessalonians',
      '1_timothy', '2_timothy', 'titus', 'philemon',
    ],
  ),
];

PlanDef planById(String id) =>
    kPlans.firstWhere((p) => p.id == id, orElse: () => kPlans.first);

/// Builds the ordered list of [VerseRef]s (chapter refs) of a plan,
/// assuming canonical chapter counts (books metadata comes from the repo).
List<VerseRef> planChapters(PlanDef plan, List<BookInfo> books) {
  final bySlug = {for (final b in books) b.slug: b};
  final out = <VerseRef>[];
  for (final slug in plan.bookSlugs) {
    final book = bySlug[slug];
    if (book == null) continue;
    for (var c = 1; c <= book.chapterCount; c++) {
      out.add(VerseRef(slug, c));
    }
  }
  return out;
}

/// Chapters scheduled for a given plan day (1-based). Pacing is even:
/// each day covers `ceil(total / days)` chapters.
List<VerseRef> planDayChapters(PlanDef plan, List<BookInfo> books, int day) {
  final all = planChapters(plan, books);
  if (all.isEmpty) return const [];
  final perDay = (all.length / plan.days).ceil().clamp(1, all.length).toInt();
  final start = (day - 1) * perDay;
  if (start >= all.length) return const [];
  final end = (start + perDay).clamp(0, all.length).toInt();
  return all.sublist(start, end);
}

/// How many chapters of a plan are already marked read.
int planReadCount(PlanDef plan, List<BookInfo> books, Set<String> readKeys) {
  var count = 0;
  for (final ref in planChapters(plan, books)) {
    if (readKeys.contains(ref.chapterKey)) count += 1;
  }
  return count;
}

/// First unread chapter of a plan (or null when complete).
VerseRef? planNextUnread(PlanDef plan, List<BookInfo> books,
    Set<String> readKeys) {
  for (final ref in planChapters(plan, books)) {
    if (!readKeys.contains(ref.chapterKey)) return ref;
  }
  return null;
}

/// The plan-day (1-based) the reader is currently on, derived from
/// completed chapters within the plan.
int currentPlanDay(PlanDef plan, List<BookInfo> books, Set<String> readKeys) {
  final read = planReadCount(plan, books, readKeys);
  final total = planChapters(plan, books).length;
  if (total == 0) return 1;
  final perDay = (total / plan.days).ceil().clamp(1, total).toInt();
  return (read ~/ perDay + 1).clamp(1, plan.days).toInt();
}
