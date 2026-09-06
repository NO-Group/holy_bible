/// Data models for the Scripture dataset (multi-translation, canonical
/// 66-book structure with 1,189 chapters, identical verse numbering).
library;

/// One translation available in the bundled dataset.
class TranslationMeta {
  final String code;
  final String short;
  final String name;
  final String desc;

  const TranslationMeta(this.code, this.short, this.name, this.desc);

  @override
  String toString() => name;
}

/// Master list of translations bundled with the app (mirrors
/// lib/Holy_Bible-main/bible/translations.json).
const List<TranslationMeta> kTranslations = [
  TranslationMeta('kjv', 'KJV', 'King James Version', 'Classic English, 1611'),
  TranslationMeta('niv', 'NIV', 'New International Version', 'Modern English'),
  TranslationMeta('nlt', 'NLT', 'New Living Translation', 'Easy to read'),
  TranslationMeta('nwt', 'NWT', 'New World Translation', '2013 Revision'),
  TranslationMeta(
    'original',
    'ORIG',
    'Original Manuscripts',
    'Hebrew (OT) · Greek (NT)',
  ),
];

TranslationMeta translationByCode(String code) => kTranslations.firstWhere(
      (t) => t.code == code,
      orElse: () => kTranslations.first,
    );

/// Canonical book metadata (derived from the dataset bundle).
class BookInfo {
  final int id;
  final String name;
  final String slug;
  final int chapterCount;

  const BookInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.chapterCount,
  });

  bool get isOldTestament => id <= 39;

  String get testamentLabel => isOldTestament ? 'Old Testament' : 'New Testament';

  /// Original-language script: Hebrew in the OT, Greek in the NT.
  String get language => isOldTestament ? 'Hebrew' : 'Greek';
}

/// One verse inside a chapter. `text` may be empty for verse slots that
/// carry no text in a given translation (numbering stays aligned).
class VerseData {
  final int number;
  final String text;

  const VerseData(this.number, this.text);

  bool get hasText => text.trim().isNotEmpty;
}

/// A fully loaded chapter (created from the translation bundle).
class ChapterData {
  final String code;
  final String book;
  final int bookId;
  final int chapter;
  final List<VerseData> verses;

  const ChapterData({
    required this.code,
    required this.book,
    required this.bookId,
    required this.chapter,
    required this.verses,
  });

  int get verseCount => verses.length;
}

/// Parsed `all.min.json` bundle for one translation.
class BibleBundle {
  final String code;
  final String translation;
  final String name;
  final List<BundledBook> books;

  const BibleBundle({
    required this.code,
    required this.translation,
    required this.name,
    required this.books,
  });

  BundledBook bookBySlug(String slug) => books.firstWhere(
        (b) => b.slug == slug,
        orElse: () => books.first,
      );

  List<BookInfo> get info =>
      List.unmodifiable(books.map(bookInfoFromBundle));
}

/// A book inside a bundle: chapters are lists of verse strings
/// (index + 1 == verse number).
class BundledBook {
  final int id;
  final String name;
  final String slug;
  final List<List<String>> chapters;

  const BundledBook({
    required this.id,
    required this.name,
    required this.slug,
    required this.chapters,
  });
}

BookInfo bookInfoFromBundle(BundledBook b) => BookInfo(
      id: b.id,
      name: b.name,
      slug: b.slug,
      chapterCount: b.chapters.length,
    );

/// A scripture reference. `verse` is 1-based; 0 means "point at the
/// chapter" (no particular verse).
class VerseRef {
  final String slug;
  final int chapter;
  final int verse;

  const VerseRef(this.slug, this.chapter, [this.verse = 0]);

  String get chapterKey => '$slug/$chapter';

  String get key => verse > 0 ? '$slug/$chapter/$verse' : chapterKey;

  @override
  bool operator ==(Object other) =>
      other is VerseRef &&
      other.slug == slug &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(slug, chapter, verse);

  Map<String, dynamic> toJson() =>
      {'slug': slug, 'ch': chapter, 'v': verse};

  static VerseRef fromJson(Map<String, dynamic> json) => VerseRef(
        json['slug'] as String? ?? 'genesis',
        (json['ch'] as num?)?.toInt() ?? 1,
        (json['v'] as num?)?.toInt() ?? 0,
      );

  @override
  String toString() => '$slug $chapter${verse > 0 ? ':$verse' : ''}';
}

/// A user annotation: highlight and/or note and/or bookmark per verse.
/// `bookmark` is a lightweight flag; a bookmark also carries `note`.
class Annotation {
  final String code;
  final String slug;
  final int chapter;
  final int verse;
  final int? color; // 0..4 = highlight palette index; null = none
  final String? note;
  final bool bookmark;
  final int createdAt;

  const Annotation({
    required this.code,
    required this.slug,
    required this.chapter,
    required this.verse,
    this.color,
    this.note,
    this.bookmark = false,
    required this.createdAt,
  });

  String get refKey => '$slug/$chapter/$verse';

  String get chapterKey => '$slug/$chapter';

  Annotation copyWith({
    int? Function()? color,
    String? Function()? note,
    bool? bookmark,
  }) =>
      Annotation(
        code: code,
        slug: slug,
        chapter: chapter,
        verse: verse,
        color: color != null ? color() : this.color,
        note: note != null ? note() : this.note,
        bookmark: bookmark ?? this.bookmark,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'slug': slug,
        'ch': chapter,
        'v': verse,
        'c': color,
        'note': note,
        'bm': bookmark,
        't': createdAt,
      };

  static Annotation fromJson(Map<String, dynamic> json) => Annotation(
        code: json['code'] as String? ?? 'kjv',
        slug: json['slug'] as String? ?? 'genesis',
        chapter: (json['ch'] as num?)?.toInt() ?? 1,
        verse: (json['v'] as num?)?.toInt() ?? 1,
        color: (json['c'] as num?)?.toInt(),
        note: json['note'] as String?,
        bookmark: json['bm'] as bool? ?? false,
        createdAt: (json['t'] as num?)?.toInt() ?? 0,
      );
}
