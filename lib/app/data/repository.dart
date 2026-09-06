/// Loads the bundled Scripture dataset (`lib/Holy_Bible-main/bible/...`),
/// caches translation bundles with a small LRU, exposes chapters, the
/// canonical 66-book index and a human reference parser.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

const int kTotalChapters = 1189;

class BibleRepository {
  static const String _assetBase =
      'lib/Holy_Bible-main/bible/translations';
  static const int _bundleCacheLimit = 2;

  final Map<String, Future<BibleBundle>> _bundles = {};
  final Map<String, BibleBundle> _loaded = {};
  final Map<String, int> _lastUse = {};
  int _clock = 0;

  /// Book/chapter counts of the canonical index (identical across all
  /// bundled translations) — built lazily from the KJV bundle so a single
  /// source of truth drives chapter navigation.
  Future<List<BookInfo>> _canonicalBooks() async {
    final bundle = await bundle('kjv');
    return bundle.info;
  }

  Future<BibleBundle> bundle(String code) async {
    final existing = _bundles[code];
    if (existing != null) {
      _lastUse[code] = _clock++;
      return existing;
    }
    final future = _loadBundle(code).then((b) {
      _loaded[code] = b;
      return b;
    });
    _bundles[code] = future;
    _lastUse[code] = _clock++;
    _evictIfNeeded();
    return future;
  }

  BibleBundle? bundleIfLoaded(String code) => _loaded[code];

  ChapterData? chapterIfLoaded(String code, String slug, int chapter) {
    final bundle = _loaded[code];
    if (bundle == null) return null;
    final book = bundle.bookBySlug(slug);
    if (chapter < 1 || chapter > book.chapters.length) return null;
    final verses = book.chapters[chapter - 1];
    return ChapterData(
      code: code,
      book: book.name,
      bookId: book.id,
      chapter: chapter,
      verses: List.generate(
        verses.length,
        (i) => VerseData(i + 1, verses[i]),
      ),
    );
  }

  Future<BibleBundle> _loadBundle(String code) async {
    final raw = await rootBundle.loadString('$_assetBase/$code/all.min.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final booksJson = (json['books'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final books = booksJson.map((b) {
      final chaptersJson = (b['chapters'] as List<dynamic>)
          .map((c) => (c as List<dynamic>).map((v) => v as String).toList())
          .toList();
      return BundledBook(
        id: (b['id'] as num).toInt(),
        name: b['name'] as String,
        slug: b['slug'] as String,
        chapters: chaptersJson,
      );
    }).toList();
    return BibleBundle(
      code: code,
      translation: json['translation'] as String? ?? code.toUpperCase(),
      name: json['name'] as String? ?? translationByCode(code).name,
      books: books,
    );
  }

  void _evictIfNeeded() {
    if (_bundles.length <= _bundleCacheLimit) return;
    final oldest = _bundles.keys.reduce(
      (a, b) => (_lastUse[a] ?? 0) <= (_lastUse[b] ?? 0) ? a : b,
    );
    _bundles.remove(oldest);
    _loaded.remove(oldest);
    _lastUse.remove(oldest);
  }

  /// Chapter content for `code` / `slug` / 1-based `chapter`.
  Future<ChapterData> chapter(String code, String slug, int chapter) async {
    final bundle = await bundle(code);
    final book = bundle.bookBySlug(slug);
    final verses = book.chapters[chapter - 1];
    return ChapterData(
      code: code,
      book: book.name,
      bookId: book.id,
      chapter: chapter,
      verses: List.generate(
        verses.length,
        (i) => VerseData(i + 1, verses[i]),
      ),
    );
  }

  Future<List<BookInfo>> books(String code) async {
    final b = await bundle(code);
    return b.info;
  }

  /// 1-based global chapter index (1..1189) for a reference.
  Future<int> globalFor(String slug, int chapter) async {
    final books = await _canonicalBooks();
    var g = 0;
    for (final book in books) {
      if (book.slug == slug) return g + chapter;
      g += book.chapterCount;
    }
    return chapter.clamp(1, kTotalChapters).toInt();
  }

  /// Reverse mapping: global index -> (slug, chapter).
  Future<VerseRef> refForGlobal(int g) async {
    final books = await _canonicalBooks();
    var remaining = g.clamp(1, kTotalChapters).toInt();
    for (final book in books) {
      if (remaining <= book.chapterCount) {
        return VerseRef(book.slug, remaining);
      }
      remaining -= book.chapterCount;
    }
    return const VerseRef('revelation', 22);
  }

  Future<String> labelForRef(VerseRef ref) async {
    final books = await _canonicalBooks();
    final book = books.firstWhere(
      (b) => b.slug == ref.slug,
      orElse: () => books.first,
    );
    return ref.verse > 0
        ? '${book.name} ${ref.chapter}:${ref.verse}'
        : '${book.name} ${ref.chapter}';
  }

  // ───────────── reference parsing ("John 3:16", "1 cor 5") ─────────────

  static const Map<String, String> _aliases = {
    'gen': 'genesis',
    'exo': 'exodus',
    'lev': 'leviticus',
    'num': 'numbers',
    'deut': 'deuteronomy',
    'jos': 'joshua',
    'judg': 'judges',
    'ruth': 'ruth',
    '1sam': '1_samuel',
    '1sa': '1_samuel',
    '2sam': '2_samuel',
    '2sa': '2_samuel',
    '1kin': '1_kings',
    '2kin': '2_kings',
    '1chr': '1_chronicles',
    '2chr': '2_chronicles',
    'ezr': 'ezra',
    'neh': 'nehemiah',
    'est': 'esther',
    'job': 'job',
    'ps': 'psalms',
    'psa': 'psalms',
    'psalm': 'psalms',
    'song of songs': 'song_of_solomon',
    'songofsongs': 'song_of_solomon',
    'prov': 'proverbs',
    'eccl': 'ecclesiastes',
    'song': 'song_of_solomon',
    'isa': 'isaiah',
    'jer': 'jeremiah',
    'lam': 'lamentations',
    'eze': 'ezekiel',
    'dan': 'daniel',
    'hos': 'hosea',
    'joel': 'joel',
    'amo': 'amos',
    'oba': 'obadiah',
    'jon': 'jonah',
    'mic': 'micah',
    'nah': 'nahum',
    'hab': 'habakkuk',
    'zep': 'zephaniah',
    'hag': 'haggai',
    'zac': 'zechariah',
    'zec': 'zechariah',
    'mal': 'malachi',
    'matt': 'matthew',
    'mar': 'mark',
    'luk': 'luke',
    'jhn': 'john',
    'jn': 'john',
    'act': 'acts',
    'rom': 'romans',
    '1cor': '1_corinthians',
    '2cor': '2_corinthians',
    'gal': 'galatians',
    'eph': 'ephesians',
    'phil': 'philippians',
    'col': 'colossians',
    '1thes': '1_thessalonians',
    '2thes': '2_thessalonians',
    '1tim': '1_timothy',
    '2tim': '2_timothy',
    'tit': 'titus',
    'phlm': 'philemon',
    'heb': 'hebrews',
    'jas': 'james',
    '1pet': '1_peter',
    '2pet': '2_peter',
    '1jn': '1_john',
    '2jn': '2_john',
    '3jn': '3_john',
    'jud': 'jude',
    'rev': 'revelation',
  };

  /// Parses "John 3:16", "1 Jn 4:8", "Psalm 23", "revelation 21:4".
  /// Returns null when no book was recognized.
  Future<VerseRef?> parseRef(String input) async {
    final books = await _canonicalBooks();
    // Keep ":" so chapter:verse survives normalization; strip everything
    // else that is not a letter/digit/colon/space.
    final normalized = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9: ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return null;
    final compact = normalized.replaceAll(' ', '');

    // Build a candidates list: canonical names and aliases, sorted so
    // longer matchers win ("1 John" before "John").
    final candidates = <(String, String)>[];
    for (final book in books) {
      final name = book.name.toLowerCase();
      candidates.add((name, book.slug));
      candidates.add((name.replaceAll(' ', ''), book.slug));
    }
    _aliases.forEach((alias, slug) => candidates.add((alias, slug)));
    candidates.sort((a, b) => b.$1.length.compareTo(a.$1.length));

    for (final (candidate, slug) in candidates) {
      final fromNormalized = normalized.startsWith(candidate);
      final fromCompact = !fromNormalized && compact.startsWith(candidate);
      if (!fromNormalized && !fromCompact) continue;

      final rests = <String>[
        (fromNormalized ? normalized : compact)
            .substring(candidate.length)
            .trim(),
      ];
      // Also allow the compact remainder ("john 3 16" -> "316").
      if (fromNormalized) {
        final c = compact.substring(candidate.length).trim();
        if (c.isNotEmpty && !rests.contains(c)) rests.add(c);
      }

      for (final rest in rests) {
        if (rest.isEmpty) return VerseRef(slug, 1);
        final m = RegExp(r'^(\d+)(?::(\d+))?$').firstMatch(rest);
        if (m == null) continue;
        final ch = int.parse(m.group(1)!);
        final v = m.group(2) != null ? int.parse(m.group(2)!) : 0;
        final book = books.firstWhere(
          (b) => b.slug == slug,
          orElse: () => books.first,
        );
        return VerseRef(
          slug,
          ch.clamp(1, book.chapterCount).toInt(),
          ch >= 1 && ch <= book.chapterCount && v > 0 ? v : 0,
        );
      }
    }
    return null;
  }
}
