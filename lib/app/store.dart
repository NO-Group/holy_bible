/// Application state: settings, navigation, reading progress, streak,
/// annotations (bookmarks / highlights / notes), quiz records and recent
/// chapters. Everything persists to [SharedPreferences] as one JSON blob.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/models.dart';
import 'data/quiz_engine.dart' show kQuestionsPerRound;
import 'data/repository.dart';

String _todayKey([DateTime? now]) {
  final d = now ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

String _yesterdayKey(DateTime now) =>
    _todayKey(now.subtract(const Duration(days: 1)));

class AppStore extends ChangeNotifier {
  static const String storageKey = 'selah.state.v1';

  final BibleRepository repo;

  AppStore(this.repo);

  bool isLoaded = false;

  // ── Settings ────────────────────────────────────────────────────────
  String translationCode = 'kjv';
  String themeId = 'midnight';
  double fontSize = 18;
  double lineHeight = 1.75;
  bool showVerseNumbers = true;
  bool justifyText = true;
  String fontFamily = 'serif'; // serif | sans | mono
  String compareCode = 'niv';
  bool compareOn = false;
  bool compareAll = false;
  String activePlanId = 'whole';
  int monthlyGoal = 30;
  bool onboarded = false;

  // ── Navigation ──────────────────────────────────────────────────────
  int navIndex = 0;
  VerseRef? pendingRef;

  // ── Reading / progress ─────────────────────────────────────────────
  VerseRef lastRef = const VerseRef('genesis', 1);
  final Set<String> readChapters = {};
  final Map<String, int> dayCounts = {};
  int totalVersesRead = 0;
  int streakDays = 0;
  String lastReadDate = '';

  // ── Quiz ───────────────────────────────────────────────────────────
  int quizzesPlayed = 0;
  int quizCorrect = 0;
  final Map<String, double> quizBest = {};

  // ── Goals ──────────────────────────────────────────────────────────
  int get monthKeySeed => DateTime.now().year * 100 + DateTime.now().month;

  int get goalMonthTotal => monthCounts[goalMonthKey(DateTime.now())] ?? 0;

  double get goalProgress =>
      monthlyGoal == 0 ? 0 : (goalMonthTotal / monthlyGoal).clamp(0, 1).toDouble();

  static String goalMonthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  // ── Backup / restore ───────────────────────────────────────────────
  String exportBackup() => jsonEncode({
        'selahBackup': 3,
        'translation': translationCode,
        'theme': themeId,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'vnums': showVerseNumbers,
        'justify': justifyText,
        'fontFamily': fontFamily,
        'compareCode': compareCode,
        'compareOn': compareOn,
        'compareAll': compareAll,
        'activePlan': activePlanId,
        'monthlyGoal': monthlyGoal,
        'last': lastRef.toJson(),
        'read': readChapters.toList(),
        'totalVerses': totalVersesRead,
        'streak': streakDays,
        'lastRead': lastReadDate,
        'quizPlayed': quizzesPlayed,
        'quizCorrect': quizCorrect,
        'quizBest': quizBest,
        'annots': annotations.map((a) => a.toJson()).toList(),
        'memorized': memorized.toList(),
        'searchHistory': searchHistory,
      });

  /// Restores settings, progress and annotations from a backup string.
  /// Returns false when the payload is invalid.
  bool importBackup(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['selahBackup'] == null) return false;
      translationCode = data['translation'] as String? ?? 'kjv';
      themeId = data['theme'] as String? ?? 'midnight';
      fontSize = (data['fontSize'] as num?)?.toDouble() ?? fontSize;
      lineHeight = (data['lineHeight'] as num?)?.toDouble() ?? lineHeight;
      showVerseNumbers = data['vnums'] as bool? ?? showVerseNumbers;
      justifyText = data['justify'] as bool? ?? justifyText;
      fontFamily = data['fontFamily'] as String? ?? fontFamily;
      compareCode = data['compareCode'] as String? ?? compareCode;
      compareOn = data['compareOn'] as bool? ?? compareOn;
      compareAll = data['compareAll'] as bool? ?? compareAll;
      activePlanId = data['activePlan'] as String? ?? activePlanId;
      monthlyGoal = (data['monthlyGoal'] as num?)?.toInt() ?? monthlyGoal;
      lastRef = VerseRef.fromJson(
          (data['last'] as Map<String, dynamic>?) ?? const {});
      readChapters
        ..clear()
        ..addAll((data['read'] as List<dynamic>? ?? const []).map((e) => e as String));
      totalVersesRead = (data['totalVerses'] as num?)?.toInt() ?? totalVersesRead;
      streakDays = (data['streak'] as num?)?.toInt() ?? streakDays;
      lastReadDate = data['lastRead'] as String? ?? lastReadDate;
      quizzesPlayed = (data['quizPlayed'] as num?)?.toInt() ?? quizzesPlayed;
      quizCorrect = (data['quizCorrect'] as num?)?.toInt() ?? quizCorrect;
      final best = data['quizBest'] as Map<String, dynamic>? ?? const {};
      quizBest
        ..clear()
        ..addAll(best.map((k, v) => MapEntry(k, (v as num).toDouble())));
      annotations
        ..clear()
        ..addAll((data['annots'] as List<dynamic>? ?? const [])
            .map((e) => Annotation.fromJson(e as Map<String, dynamic>)));
      memorized
        ..clear()
        ..addAll((data['memorized'] as List<dynamic>? ?? const [])
            .map((e) => e as String));
      searchHistory
        ..clear()
        ..addAll(
            (data['searchHistory'] as List<dynamic>? ?? const []).map((e) => e as String));
      notifyListeners();
      persist();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Memory (memorized verses) ──────────────────────────────────────
  int get memorizedCount => memorized.length;

  bool isMemorized(String slug, int chapter, int verse) =>
      memorized.contains('$slug/$chapter/$verse');

  void toggleMemorized(VerseRef ref) {
    final key = '${ref.slug}/${ref.chapter}/${ref.verse}';
    if (!memorized.add(key)) memorized.remove(key);
    notifyListeners();
    persist();
  }

  // ── Annotations ────────────────────────────────────────────────────
  final List<Annotation> annotations = [];
  List<VerseRef> recents = [];
  final Set<String> memorized = {};
  final Map<String, int> monthCounts = {};
  final List<String> searchHistory = [];

  TranslationMeta get translation => translationByCode(translationCode);

  // ── Load / save ────────────────────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        translationCode = data['translation'] as String? ?? 'kjv';
        themeId = data['theme'] as String? ?? 'midnight';
        fontSize = (data['fontSize'] as num?)?.toDouble() ?? 18;
        lineHeight = (data['lineHeight'] as num?)?.toDouble() ?? 1.75;
        showVerseNumbers = data['vnums'] as bool? ?? true;
        justifyText = data['justify'] as bool? ?? true;
        fontFamily = data['fontFamily'] as String? ?? 'serif';
        compareCode = data['compareCode'] as String? ?? 'niv';
        compareOn = data['compareOn'] as bool? ?? false;
        compareAll = data['compareAll'] as bool? ?? false;
        activePlanId = data['activePlan'] as String? ?? 'whole';
        monthlyGoal = (data['monthlyGoal'] as num?)?.toInt() ?? 30;
        onboarded = data['onboarded'] as bool? ?? false;
        lastRef = VerseRef.fromJson(
          (data['last'] as Map<String, dynamic>?) ?? const {},
        );
        final read = data['read'] as List<dynamic>? ?? const [];
        readChapters
          ..clear()
          ..addAll(read.map((e) => e as String));
        final counts = data['dayCounts'] as Map<String, dynamic>? ?? const {};
        dayCounts
          ..clear()
          ..addAll(counts.map((k, v) => MapEntry(k, (v as num).toInt())));
        totalVersesRead = (data['totalVerses'] as num?)?.toInt() ?? 0;
        streakDays = (data['streak'] as num?)?.toInt() ?? 0;
        lastReadDate = data['lastRead'] as String? ?? '';
        quizzesPlayed = (data['quizPlayed'] as num?)?.toInt() ?? 0;
        quizCorrect = (data['quizCorrect'] as num?)?.toInt() ?? 0;
        final best = data['quizBest'] as Map<String, dynamic>? ?? const {};
        quizBest
          ..clear()
          ..addAll(
            best.map((k, v) => MapEntry(k, (v as num).toDouble())),
          );
        final anns = data['annots'] as List<dynamic>? ?? const [];
        annotations
          ..clear()
          ..addAll(
            anns.map(
              (e) => Annotation.fromJson(e as Map<String, dynamic>),
            ),
          );
        final r = data['recents'] as List<dynamic>? ?? const [];
        recents = r
            .map((e) => VerseRef.fromJson(e as Map<String, dynamic>))
            .toList();
        final mem = data['memorized'] as List<dynamic>? ?? const [];
        memorized
          ..clear()
          ..addAll(mem.map((e) => e as String));
        final months = data['monthCounts'] as Map<String, dynamic>? ?? const {};
        monthCounts
          ..clear()
          ..addAll(months.map((k, v) => MapEntry(k, (v as num).toInt())));
        final hist = data['searchHistory'] as List<dynamic>? ?? const [];
        searchHistory
          ..clear()
          ..addAll(hist.map((e) => e as String));
      } catch (_) {
        // Corrupt state: fall back to defaults.
      }
    }
    isLoaded = true;
    notifyListeners();
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'translation': translationCode,
      'theme': themeId,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'vnums': showVerseNumbers,
      'justify': justifyText,
      'fontFamily': fontFamily,
      'compareCode': compareCode,
      'compareOn': compareOn,
      'compareAll': compareAll,
      'activePlan': activePlanId,
      'monthlyGoal': monthlyGoal,
      'onboarded': onboarded,
      'last': lastRef.toJson(),
      'read': readChapters.toList(),
      'dayCounts': dayCounts,
      'totalVerses': totalVersesRead,
      'streak': streakDays,
      'lastRead': lastReadDate,
      'quizPlayed': quizzesPlayed,
      'quizCorrect': quizCorrect,
      'quizBest': quizBest,
      'annots': annotations.map((a) => a.toJson()).toList(),
      'recents': recents.map((r) => r.toJson()).toList(),
      'memorized': memorized.toList(),
      'monthCounts': monthCounts,
      'searchHistory': searchHistory,
    };
    await prefs.setString(storageKey, jsonEncode(data));
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    translationCode = 'kjv';
    themeId = 'midnight';
    fontSize = 18;
    lineHeight = 1.75;
    showVerseNumbers = true;
    justifyText = true;
    compareCode = 'niv';
    compareOn = false;
    activePlanId = 'whole';
    navIndex = 0;
    pendingRef = null;
    lastRef = const VerseRef('genesis', 1);
    readChapters.clear();
    dayCounts.clear();
    memorized.clear();
    monthCounts.clear();
    searchHistory.clear();
    compareAll = false;
    monthlyGoal = 30;
    onboarded = false;
    totalVersesRead = 0;
    streakDays = 0;
    lastReadDate = '';
    quizzesPlayed = 0;
    quizCorrect = 0;
    quizBest.clear();
    annotations.clear();
    recents = [];
    notifyListeners();
  }

  // ── Convenience setters ────────────────────────────────────────────
  void setTranslation(String code) {
    if (translationCode == code) return;
    translationCode = code;
    notifyListeners();
    persist();
  }

  void setTheme(String id) {
    themeId = id;
    notifyListeners();
    persist();
  }

  void setFontSize(double v) {
    fontSize = v.clamp(13, 30).toDouble();
    notifyListeners();
    persist();
  }

  void setLineHeight(double v) {
    lineHeight = v.clamp(1.3, 2.2).toDouble();
    notifyListeners();
    persist();
  }

  void setShowVerseNumbers(bool v) {
    showVerseNumbers = v;
    notifyListeners();
    persist();
  }

  void setJustify(bool v) {
    justifyText = v;
    notifyListeners();
    persist();
  }

  void setFontFamily(String family) {
    if (!const ['serif', 'sans', 'mono'].contains(family)) return;
    fontFamily = family;
    notifyListeners();
    persist();
  }

  void setCompareCode(String code) {
    compareCode = code;
    notifyListeners();
    persist();
  }

  void setCompareOn(bool v) {
    compareOn = v;
    notifyListeners();
    persist();
  }

  void setCompareAll(bool v) {
    compareAll = v;
    notifyListeners();
    persist();
  }

  void setMonthlyGoal(int v) {
    monthlyGoal = v.clamp(5, 500);
    notifyListeners();
    persist();
  }

  void setOnboarded() {
    if (onboarded) return;
    onboarded = true;
    notifyListeners();
    persist();
  }

  void addSearchHistory(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    searchHistory
      ..remove(q)
      ..insert(0, q);
    if (searchHistory.length > 10) {
      searchHistory.removeRange(10, searchHistory.length);
    }
    notifyListeners();
    persist();
  }

  void clearSearchHistory() {
    searchHistory.clear();
    notifyListeners();
    persist();
  }

  void setActivePlan(String id) {
    activePlanId = id;
    notifyListeners();
    persist();
  }

  void goTo(int index) {
    if (navIndex == index) return;
    navIndex = index;
    notifyListeners();
  }

  /// Open a reference from anywhere: switches to the Reader tab and lets
  /// the reader consume [pendingRef].
  void openRef(VerseRef ref) {
    pendingRef = ref;
    navIndex = 1;
    notifyListeners();
  }

  VerseRef? consumePendingRef() {
    final r = pendingRef;
    pendingRef = null;
    return r;
  }

  // ── Progress ───────────────────────────────────────────────────────
  int get chaptersRead => readChapters.length;

  int get totalChapters => kTotalChapters;

  double get bibleProgress =>
      readChapters.isEmpty ? 0 : (readChapters.length / kTotalChapters);

  int get daysRead => dayCounts.length;

  bool isChapterRead(String slug, int chapter) =>
      readChapters.contains('$slug/$chapter');

  /// Called whenever a chapter is opened. Returns true when this chapter
  /// counts as newly read (so callers can toast).
  bool markChapterRead(String slug, int chapter, int verseCount) {
    final key = '$slug/$chapter';
    final isNew = readChapters.add(key);
    if (!isNew) return false;
    totalVersesRead += verseCount;
    final today = _todayKey();
    final month = today.substring(0, 7);
    monthCounts[month] = (monthCounts[month] ?? 0) + 1;
    dayCounts[today] = (dayCounts[today] ?? 0) + 1;
    final now = DateTime.now();
    if (lastReadDate == today) {
      // already credited today
    } else if (lastReadDate == _yesterdayKey(now)) {
      streakDays += 1;
    } else {
      streakDays = 1;
    }
    lastReadDate = today;
    _pruneDayCounts();
    notifyListeners();
    persist();
    return true;
  }

  void _pruneDayCounts() {
    final keys = dayCounts.keys.toList()..sort();
    while (keys.length > 90) {
      dayCounts.remove(keys.removeAt(0));
    }
  }

  /// Chapters read per day for the last `days` days (oldest → newest).
  List<int> activityLastDays(int days) {
    final now = DateTime.now();
    final out = <int>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      out.add(dayCounts[_todayKey(day)] ?? 0);
    }
    return out;
  }

  void remember(VerseRef ref) {
    lastRef = ref;
    recents
      ..removeWhere((r) => r.slug == ref.slug && r.chapter == ref.chapter)
      ..insert(0, ref);
    if (recents.length > 12) recents = recents.sublist(0, 12);
    notifyListeners();
    persist();
  }

  // ── Annotations ────────────────────────────────────────────────────
  Annotation? annotationFor(String slug, int chapter, int verse) =>
      annotations
          .where((a) =>
              a.slug == slug &&
              a.chapter == chapter &&
              a.verse == verse)
          .firstOrNull;

  List<Annotation> get bookmarks =>
      annotations.where((a) => a.bookmark).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Annotation> get highlights =>
      annotations.where((a) => a.color != null).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Annotation> get notes =>
      annotations.where((a) => a.note?.trim().isNotEmpty ?? false).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  bool isBookmarked(String slug, int chapter, int verse) =>
      annotationFor(slug, chapter, verse)?.bookmark ?? false;

  void toggleBookmark(VerseRef ref) {
    final existing = _find(ref);
    if (existing != null) {
      _upsert(existing.copyWith(bookmark: !existing.bookmark));
    } else {
      _upsert(Annotation(
        code: translationCode,
        slug: ref.slug,
        chapter: ref.chapter,
        verse: ref.verse,
        bookmark: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  void setHighlight(VerseRef ref, int? colorIndex) {
    final existing = _find(ref);
    if (existing != null) {
      _upsert(existing.copyWith(color: () => colorIndex));
    } else {
      _upsert(Annotation(
        code: translationCode,
        slug: ref.slug,
        chapter: ref.chapter,
        verse: ref.verse,
        color: colorIndex,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  void setNote(VerseRef ref, String? text) {
    final value = text?.trim();
    final finalText = (value == null || value.isEmpty) ? null : value;
    final existing = _find(ref);
    if (existing != null) {
      _upsert(existing.copyWith(note: () => finalText));
    } else {
      _upsert(Annotation(
        code: translationCode,
        slug: ref.slug,
        chapter: ref.chapter,
        verse: ref.verse,
        note: finalText,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  Annotation? _find(VerseRef ref) => annotations
      .where((a) =>
          a.slug == ref.slug &&
          a.chapter == ref.chapter &&
          a.verse == ref.verse)
      .firstOrNull;

  void _upsert(Annotation a) {
    final idx = annotations.indexWhere((x) => x.refKey == a.refKey);
    if (idx >= 0) {
      annotations[idx] = a;
    } else {
      annotations.add(a);
    }
    annotations.removeWhere(
      (x) => !x.bookmark && x.color == null && (x.note?.isEmpty ?? true),
    );
    notifyListeners();
    persist();
  }

  // ── Quiz records ───────────────────────────────────────────────────
  void recordQuiz(QuizResult record) {
    quizzesPlayed += 1;
    quizCorrect += record.correct;
    final pct = record.percent;
    final current = quizBest[record.modeId] ?? 0;
    if (pct > current) quizBest[record.modeId] = pct;
    notifyListeners();
    persist();
  }

  int get quizAccuracy => quizzesPlayed == 0
      ? 0
      : (quizCorrect / (quizzesPlayed * kQuestionsPerRound) * 100).round();
}

/// Result of one completed quiz round.
class QuizResult {
  final String modeId;
  final int correct;
  final int total;

  QuizResult(this.modeId, this.correct, this.total);

  double get percent => total == 0 ? 0 : correct / total * 100;
}
