/// Home dashboard: verse of the day, continue reading, active plan,
/// quick actions and the 7-day reading chart.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/plans.dart';
import '../data/verse_refs.dart';
import '../store.dart';
import 'scope.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'quiz_page.dart';
import 'memorize_page.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<ChapterData> _votdFuture;
  late Future<List<BookInfo>> _booksFuture;
  String _votdCode = '';

  @override
  void initState() {
    super.initState();
    _loadVotd();
    _booksFuture = AppScope.read(context).repo.books('kjv');
  }

  void _loadVotd() {
    final app = AppScope.read(context);
    _votdCode = app.translationCode;
    final ref = kVerseOfTheDay[verseOfTheDayIndex(DateTime.now())];
    _votdFuture = app.repo.chapter(app.translationCode, ref.slug, ref.ch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.read(context);
    if (app.translationCode != _votdCode) _loadVotd();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    final votd = kVerseOfTheDay[verseOfTheDayIndex(DateTime.now())];
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(_loadVotd);
            await Future<void>.delayed(const Duration(milliseconds: 300));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              // ── Header ─────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SELAH',
                          style: TextStyle(
                            color: theme.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateLabel(today),
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _greeting(today),
                          style: TextStyle(
                            color: theme.textDim,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StreakChip(days: app.streakDays),
                ],
              ),
              const SizedBox(height: 18),

              // ── Verse of the day ───────────────────────────────────
              FutureBuilder<ChapterData>(
                future: _votdFuture,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  String text = 'The word of God — light for your path.';
                  String ref = '${translationByCode(app.translationCode).short} · verse of the day';
                  if (data != null) {
                    final verse = data.verses
                        .where((v) => v.number == votd.v)
                        .firstOrNull;
                    if (verse != null && verse.hasText) {
                      text = verse.text;
                      ref =
                          '${data.book} ${data.chapter}:${votd.v} · ${translationByCode(app.translationCode).short}';
                    }
                  }
                  return GradientCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny_outlined,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'VERSE OF THE DAY',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        VerseText(
                          text,
                          fontSize: app.fontSize + 1,
                          lineHeight: app.lineHeight,
                          justify: true,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '— $ref',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            _RoundIcon(
                              icon: Icons.open_in_new,
                              onTap: () => app.openRef(VerseRef(
                                  votd.slug, votd.ch, votd.v)),
                            ),
                            const SizedBox(width: 8),
                            _RoundIcon(
                              icon: Icons.copy,
                              onTap: () => copyToClipboard(
                                  context, '“$text” — $ref'),
                            ),
                            const SizedBox(width: 8),
                            _RoundIcon(
                              icon: Icons.share,
                              onTap: () => copyToClipboard(
                                context,
                                '“$text” — $ref',
                                message: 'Shared via clipboard',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // ── Today's focus ──────────────────────────────────────
              _FocusCard(today: today),
              const SizedBox(height: 16),

              // ── Monthly goal ───────────────────────────────────────
              SectionCard(
                child: Row(
                  children: [
                    ProgressRing(
                      value: app.goalProgress,
                      size: 62,
                      center: Text(
                        '${(app.goalProgress * 100).round()}%',
                        style: TextStyle(
                          color: theme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MONTHLY GOAL',
                            style: TextStyle(
                              color: theme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${app.goalMonthTotal} of ${app.monthlyGoal} chapters this month',
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            app.goalProgress >= 1
                                ? 'Goal reached — what a month! 🎉'
                                : '${app.monthlyGoal - app.goalMonthTotal} to go',
                            style: TextStyle(
                              color: theme.textDim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Adjust goal',
                      icon: Icon(Icons.tune, color: theme.textDim, size: 20),
                      onPressed: () => _adjustGoal(context, app),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Continue reading ───────────────────────────────────
              FutureBuilder<List<BookInfo>>(
                future: _booksFuture,
                builder: (context, snapshot) {
                  final books = snapshot.data ?? const <BookInfo>[];
                  final book = books.firstWhere(
                    (b) => b.slug == app.lastRef.slug,
                    orElse: () => books.isEmpty
                        ? const BookInfo(
                            id: 1,
                            name: 'Genesis',
                            slug: 'genesis',
                            chapterCount: 50)
                        : books.first,
                  );
                  var readInBook = 0;
                  for (var c = 1; c <= book.chapterCount; c++) {
                    if (app.isChapterRead(book.slug, c)) readInBook += 1;
                  }
                  return SectionCard(
                    onTap: () => app.openRef(app.lastRef),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.accentSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.book_outlined,
                              color: theme.accent),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CONTINUE READING',
                                style: TextStyle(
                                  color: theme.textDim,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                app.lastRef.verse > 0
                                    ? '${book.name} ${app.lastRef.chapter}:${app.lastRef.verse}'
                                    : '${book.name} ${app.lastRef.chapter}',
                                style: TextStyle(
                                  color: theme.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: book.chapterCount == 0
                                      ? 0
                                      : readInBook / book.chapterCount,
                                  minHeight: 5,
                                  backgroundColor: theme.surfaceAlt,
                                  valueColor: AlwaysStoppedAnimation(
                                      theme.accent),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$readInBook of ${book.chapterCount} chapters in ${book.name}',
                                style: TextStyle(
                                  color: theme.textDim,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: theme.textDim),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // ── Quick actions ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.casino_outlined,
                      label: 'Random chapter',
                      onTap: () async {
                        final books = await app.repo.books(
                            app.translationCode);
                        if (books.isEmpty) return;
                        final book = books[rng.nextInt(books.length)];
                        final ch = 1 +
                            rng.nextInt(book.chapterCount);
                        app.openRef(VerseRef(book.slug, ch));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.quiz_outlined,
                      label: 'Quiz',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuizPage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.bookmark_add_outlined,
                      label: 'Memorize',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MemorizePage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.bar_chart,
                      label: 'Stats',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StatsPage(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // ── Active plan ────────────────────────────────────────
              FutureBuilder<List<BookInfo>>(
                future: _booksFuture,
                builder: (context, snapshot) {
                  final books = snapshot.data ?? const <BookInfo>[];
                  final plan = planById(app.activePlanId);
                  final total = planChapters(plan, books).length;
                  final read = planReadCount(plan, books, app.readChapters);
                  final pct = total == 0 ? 0.0 : read / total;
                  final next = planNextUnread(plan, books, app.readChapters);
                  final day = currentPlanDay(plan, books, app.readChapters);
                  return SectionCard(
                    onTap: () => app.goTo(4),
                    child: Row(
                      children: [
                        ProgressRing(value: pct, size: 62),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${plan.emoji} ${plan.name.toUpperCase()}',
                                style: TextStyle(
                                  color: theme.accent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Day $day of ${plan.days} · $read of $total chapters',
                                style: TextStyle(
                                  color: theme.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                next == null
                                    ? 'Plan complete — amazing! 🎉'
                                    : 'Next: ${next.slug == 'song_of_solomon' ? 'Song of Solomon' : _bookName(books, next.slug)} ${next.chapter}',
                                style: TextStyle(
                                  color: theme.textDim,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: () {
                            if (next != null) app.openRef(next);
                          },
                          child: const Text('Read'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),

              // ── This week ──────────────────────────────────────────
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'THIS WEEK',
                            style: TextStyle(
                              color: theme.textDim,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Text(
                          '${app.activityLastDays(7).fold<int>(0, (a, b) => a + b)} chapters',
                          style: TextStyle(
                            color: theme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ActivityChart(values: app.activityLastDays(7)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '${app.chaptersRead} of ${app.totalChapters} chapters · '
                  '${(app.bibleProgress * 100).toStringAsFixed(1)}% of the Bible',
                  style: TextStyle(color: theme.textDim, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _bookName(List<BookInfo> books, String slug) => books
      .firstWhere((b) => b.slug == slug, orElse: () => books.first)
      .name;

  String _dateLabel(DateTime now) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning — begin with light ☀️';
    if (now.hour < 17) return 'Good afternoon — steady your heart 🌤️';
    return 'Good evening — rest in the Word 🌙';
  }
}

final Random rng = Random();

class _StreakChip extends StatelessWidget {
  final int days;

  const _StreakChip({required this.days});

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            days > 0 ? Icons.local_fire_department : Icons.local_fire_department_outlined,
            color: const Color(0xFFF59E0B),
            size: 19,
          ),
          const SizedBox(width: 6),
          Text(
            '$days',
            style: TextStyle(
              color: theme.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'day${days == 1 ? '' : 's'}',
            style: TextStyle(color: theme.textDim, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: theme.accent, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}


Future<void> _adjustGoal(BuildContext context, AppStore app) async {
  final theme = appThemeOf(context);
  await showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Monthly reading goal'),
      content: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${app.monthlyGoal} chapters / month',
              style: TextStyle(
                color: theme.accent,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Slider(
              value: app.monthlyGoal.toDouble(),
              min: 10,
              max: 120,
              divisions: 22,
              onChanged: (v) => setState(() => app.setMonthlyGoal(v.round())),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _FocusCard extends StatelessWidget {
  final DateTime today;

  const _FocusCard({required this.today});

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    final app = AppScope.of(context);
    final idx = verseOfTheDayIndex(today);
    const reflect = [
      'Read the verse slowly. Which word stops you?',
      'What does this reveal about who God is?',
      'Where in your life does this verse speak first?',
      'Say the promise back to God in your own words.',
    ];
    const pray = [
      'Lord, shape my heart around this truth today.',
      'Father, help me live this verse where I am.',
      'God, thank you for a word that endures.',
      'Spirit, remind me of this when I forget.',
    ];
    const act = [
      'Share the verse with one person today.',
      'Write it where you will see it this week.',
      'Turn it into a one-line prayer for someone.',
      'Read it aloud twice before you sleep.',
    ];
    final votd = kVerseOfTheDay[idx];
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S FOCUS",
            style: TextStyle(
              color: theme.accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          _FocusLine(icon: Icons.visibility_outlined, label: 'Reflect',
              text: reflect[idx % reflect.length]),
          _FocusLine(icon: Icons.volunteer_activism_outlined, label: 'Pray',
              text: pray[idx % pray.length]),
          _FocusLine(icon: Icons.wb_sunny_outlined, label: 'Act',
              text: act[idx % act.length]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final text = await promptText(
                context,
                title: 'Journal on today’s verse',
                initial: '',
                hint:
                    '${votd.slug.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')} ${votd.ch}:${votd.v} — what do you want to remember?',
              );
              if (text != null && text.trim().isNotEmpty) {
                app.setNote(VerseRef(votd.slug, votd.ch, votd.v), text);
                if (context.mounted) {
                  showSnack(context, 'Journal entry saved to your notes');
                }
              }
            },
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('Journal on this verse'),
          ),
        ],
      ),
    );
  }
}

class _FocusLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;

  const _FocusLine({
    required this.icon,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.accent),
          const SizedBox(width: 10),
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: TextStyle(
                color: theme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: theme.text,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
