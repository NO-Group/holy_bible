/// Reading statistics: streak, chapters/verses read, books finished,
/// quiz performance and the 7-day activity chart.
library;

import 'package:flutter/material.dart';

import '../data/achievements.dart';
import '../data/models.dart';
import '../data/plans.dart';
import '../store.dart';
import 'scope.dart';
import 'widgets.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late Future<List<BookInfo>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _booksFuture = AppScope.read(context).repo.books('kjv');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: FutureBuilder<List<BookInfo>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          final books = snapshot.data ?? const <BookInfo>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              // Hero
              GradientCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${app.streakDays}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            app.streakDays == 1
                                ? 'day of reading! Keep the fire alive'
                                : 'day streak — read today to continue',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 54,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.auto_stories,
                      value: '${app.chaptersRead}',
                      label: 'Chapters read',
                      color: theme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.format_align_left,
                      value: _fmt(app.totalVersesRead),
                      label: 'Verses read',
                      color: const Color(0xFF7ED99A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.menu_book,
                      value: '${_booksFinished(books, app)}',
                      label: 'Books finished',
                      color: const Color(0xFF7CC4F5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.event_available,
                      value: '${app.daysRead}',
                      label: 'Active days',
                      color: const Color(0xFFC6A6F2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.quiz,
                      value: '${app.quizzesPlayed}',
                      label: 'Quiz rounds',
                      color: const Color(0xFFF5A3C0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.track_changes,
                      value: '${app.quizAccuracy}%',
                      label: 'Quiz accuracy',
                      color: const Color(0xFFF6D743),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _AchievementsCard(),
              const SizedBox(height: 20),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAST 7 DAYS',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ActivityChart(
                      values: app.activityLastDays(7),
                      height: 84,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BIBLE COMPLETION',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${app.chaptersRead} of ${app.totalChapters} chapters (${(app.bibleProgress * 100).toStringAsFixed(1)}%)',
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ProgressRing(value: app.bibleProgress, size: 56),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: app.bibleProgress,
                        minHeight: 8,
                        backgroundColor: theme.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation(theme.accent),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final plan in kPlans)
                      _PlanMiniProgress(plan: plan, books: books),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  int _booksFinished(List<BookInfo> books, AppStore app) {
    var count = 0;
    for (final b in books) {
      var all = true;
      for (var c = 1; c <= b.chapterCount; c++) {
        if (!app.isChapterRead(b.slug, c)) {
          all = false;
          break;
        }
      }
      if (all) count += 1;
    }
    return count;
  }
}

class _PlanMiniProgress extends StatelessWidget {
  final PlanDef plan;
  final List<BookInfo> books;

  const _PlanMiniProgress({required this.plan, required this.books});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    final total = planChapters(plan, books).length;
    final read = planReadCount(plan, books, app.readChapters);
    final pct = total == 0 ? 0.0 : read / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(plan.emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              plan.name,
              style: TextStyle(
                color: theme.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: theme.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(theme.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              '${(pct * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme.textDim,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _AchievementsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    final unlocked = kAchievements.where((a) => isUnlocked(a, app)).length;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ACHIEVEMENTS',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Text(
                '$unlocked / ${kAchievements.length}',
                style: TextStyle(
                  color: theme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final a in kAchievements)
                Tooltip(
                  message:
                      '${a.title} — ${a.desc} (${a.metric(app).round()}/${a.value.round()})',
                  child: Container(
                    width: 64,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isUnlocked(a, app)
                          ? theme.accentSoft
                          : theme.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: isUnlocked(a, app)
                          ? Border.all(color: theme.accent, width: 1.2)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Opacity(
                          opacity: isUnlocked(a, app) ? 1 : 0.38,
                          child: Text(a.emoji,
                              style: const TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(a.progress(app) / a.value).clamp(0, 1).toDouble() >= 1 ? '✓' : (a.progress(app) / a.value * 100).round().toString() + '%'}',
                          style: TextStyle(
                            color: isUnlocked(a, app)
                                ? theme.accent
                                : theme.textDim,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
