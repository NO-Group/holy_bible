import 'package:flutter_test/flutter_test.dart';
import 'package:holy_bible/app/data/models.dart';
import 'package:holy_bible/app/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = BibleRepository();

  group('BibleRepository (real bundled assets)', () {
    test('loads all five translations with 66 books / 1189 chapters', () async {
      for (final code in ['kjv', 'niv', 'nlt', 'nwt', 'original']) {
        final bundle = await repo.bundle(code);
        expect(bundle.books, hasLength(66));
        final chapters = bundle.books.fold<int>(
            0, (n, b) => n + b.chapters.length);
        expect(chapters, 1189, reason: code);
      }
    });

    test('chapter data matches bundle text', () async {
      final data = await repo.chapter('kjv', 'genesis', 1);
      expect(data.book, 'Genesis');
      expect(data.verses, isNotEmpty);
      expect(data.verses.first.number, 1);
      expect(data.verses.first.text, contains('In the beginning'));
    });

    test('global index maps every reference and back', () async {
      final books = await repo.books('kjv');
      var global = 0;
      for (final book in books) {
        final g = await repo.globalFor(book.slug, 1);
        expect(g, global + 1, reason: book.slug);
        final back = await repo.refForGlobal(g);
        expect(back.slug, book.slug);
        global += book.chapterCount;
      }
      expect(global, 1189);
    });

    test('parses common references', () async {
      expect(
        await repo.parseRef('John 3:16'),
        const VerseRef('john', 3, 16),
      );
      expect(
        await repo.parseRef('1 cor 5:2'),
        const VerseRef('1_corinthians', 5, 2),
      );
      expect(
        await repo.parseRef('psalm 23'),
        const VerseRef('psalms', 23, 0),
      );
      expect(
        await repo.parseRef('rev 21:4'),
        const VerseRef('revelation', 21, 4),
      );
      expect(
        await repo.parseRef('Song of Solomon 2:1'),
        const VerseRef('song_of_solomon', 2, 1),
      );
      expect(await repo.parseRef('xyz 5'), isNull);
    });
  });
}
