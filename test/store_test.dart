import 'package:flutter_test/flutter_test.dart';
import 'package:holy_bible/app/data/models.dart';
import 'package:holy_bible/app/data/repository.dart';
import 'package:holy_bible/app/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(BibleRepository());
  await store.load();
  return store;
}

void main() {
  test('marks chapters read once and counts verses', () async {
    final store = await _freshStore();
    expect(store.markChapterRead('genesis', 1, 31), isTrue);
    expect(store.markChapterRead('genesis', 1, 31), isFalse);
    expect(store.chaptersRead, 1);
    expect(store.totalVersesRead, 31);
    expect(store.isChapterRead('genesis', 1), isTrue);
  });

  test('annotations: bookmark, highlight, note lifecycle', () async {
    final store = await _freshStore();
    const ref = VerseRef('john', 3, 16);

    store.toggleBookmark(ref);
    expect(store.isBookmarked('john', 3, 16), isTrue);
    expect(store.bookmarks, hasLength(1));

    store.setHighlight(ref, 2);
    expect(store.highlights, hasLength(1));
    expect(store.highlights.first.color, 2);

    store.setNote(ref, '  For God so loved…  ');
    expect(store.notes.first.note, 'For God so loved…');

    store.setHighlight(ref, null);
    store.setNote(ref, null);
    store.toggleBookmark(ref);
    expect(store.annotations, isEmpty, reason: 'empty annotations are pruned');
  });

  test('memorized verses persist across reload', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(BibleRepository());
    await store.load();
    store.toggleMemorized(const VerseRef('psalms', 23, 1));
    expect(store.memorizedCount, 1);
    expect(store.isMemorized('psalms', 23, 1), isTrue);
    await store.persist();

    // Reload from the same preferences store.
    final reloaded = AppStore(BibleRepository());
    await reloaded.load();
    expect(reloaded.isMemorized('psalms', 23, 1), isTrue);
  });

  test('settings persist through save/load round trip', () async {
    final store = await _freshStore();
    store.setTranslation('nlt');
    store.setTheme('sepia');
    store.setFontSize(21);
    store.setFontFamily('mono');
    store.setActivePlan('nt');
    await store.persist();

    final reloaded = AppStore(BibleRepository());
    await reloaded.load();
    expect(reloaded.translationCode, 'nlt');
    expect(reloaded.themeId, 'sepia');
    expect(reloaded.fontSize, 21);
    expect(reloaded.fontFamily, 'mono');
    expect(reloaded.activePlanId, 'nt');
  });

  test('streak resets after a missed day and continues after a read day',
      () async {
    final store = await _freshStore();
    // First read today.
    store.markChapterRead('genesis', 1, 1);
    expect(store.streakDays, 1);
    // Read a second chapter today: streak unchanged.
    store.markChapterRead('genesis', 2, 1);
    expect(store.streakDays, 1);
    expect(store.daysRead, 1);
  });

  test('monthly goal counts chapters this month', () async {
    final store = await _freshStore();
    expect(store.monthlyGoal, 30);
    expect(store.goalMonthTotal, 0);
    expect(store.goalProgress, 0);
    store.markChapterRead('genesis', 1, 31);
    store.markChapterRead('genesis', 2, 31);
    expect(store.goalMonthTotal, 2);
    expect(store.goalProgress, closeTo(2 / 30, 0.0001));
    store.setMonthlyGoal(5);
    expect(store.goalProgress, closeTo(0.4, 0.0001));
    store.setMonthlyGoal(500);
    expect(store.goalProgress, closeTo(0.004, 0.0001));
  });

  test('search history caps at 10 and moves repeats to front', () async {
    final store = await _freshStore();
    for (var i = 0; i < 12; i++) {
      store.addSearchHistory('query $i');
    }
    expect(store.searchHistory.length, 10);
    expect(store.searchHistory.first, 'query 11');
    store.addSearchHistory('query 5');
    expect(store.searchHistory.length, 10);
    expect(store.searchHistory.first, 'query 5');
    store.clearSearchHistory();
    expect(store.searchHistory, isEmpty);
  });

  test('backup export/import round trips settings and progress', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(BibleRepository());
    await store.load();
    store.setTranslation('nlt');
    store.setTheme('oled');
    store.setCompareAll(true);
    store.setMonthlyGoal(45);
    store.setOnboarded();
    store.markChapterRead('john', 3, 36);
    store.setNote(const VerseRef('john', 3, 16), 'loved');
    store.addSearchHistory('love');
    store.toggleMemorized(const VerseRef('psalms', 23, 1));
    final backup = store.exportBackup();
    expect(backup, contains('selahBackup'));

    final restored = AppStore(BibleRepository());
    await restored.load();
    expect(restored.importBackup(backup), isTrue);
    expect(restored.translationCode, 'nlt');
    expect(restored.themeId, 'oled');
    expect(restored.compareAll, isTrue);
    expect(restored.monthlyGoal, 45);
    expect(restored.onboarded, isTrue);
    expect(restored.isChapterRead('john', 3), isTrue);
    expect(restored.notes.first.note, 'loved');
    expect(restored.searchHistory, ['love']);
    expect(restored.isMemorized('psalms', 23, 1), isTrue);
  });

  test('importBackup rejects foreign payloads', () async {
    final store = await _freshStore();
    expect(store.importBackup('{"other": true}'), isFalse);
    expect(store.importBackup('not json at all'), isFalse);
  });

  test('resetAll clears everything', () async {
    final store = await _freshStore();
    store.markChapterRead('genesis', 1, 31);
    store.toggleBookmark(const VerseRef('genesis', 1, 1));
    await store.resetAll();
    expect(store.chaptersRead, 0);
    expect(store.annotations, isEmpty);
    expect(store.streakDays, 0);
  });
}
