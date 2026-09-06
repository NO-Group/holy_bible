/// Reading plans: pick a plan, see today's assigned chapters, follow
/// day-by-day progress and jump straight into the next reading.
library;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/plans.dart';
import '../store.dart';
import '../theme.dart';
import 'scope.dart';
import 'widgets.dart';

class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
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
    return FutureBuilder<List<BookInfo>>(
      future: _booksFuture,
      builder: (context, snapshot) {
        final books = snapshot.data ?? const <BookInfo>[];
        if (books.isEmpty && !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final active = planById(app.activePlanId);
        return Scaffold(
          appBar: AppBar(title: const Text('Reading Plans')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: [
              _HeroPlan(plan: active, books: books),
              const SizedBox(height: 14),
              Text(
                'ALL PLANS',
                style: TextStyle(
                  color: theme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              for (final plan in kPlans)
                _PlanCard(
                  plan: plan,
                  books: books,
                  isActive: plan.id == app.activePlanId,
                ),
              const SizedBox(height: 8),
              Text(
                'Day plans pace evenly — each day covers a handful of '
                'consecutive chapters, in canonical order. Progress is '
                'tracked from the chapters you read in the Reader.',
                style: TextStyle(
                  color: theme.textDim,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroPlan extends StatelessWidget {
  final PlanDef plan;
  final List<BookInfo> books;

  const _HeroPlan({required this.plan, required this.books});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    final total = planChapters(plan, books).length;
    final read = planReadCount(plan, books, app.readChapters);
    final day = currentPlanDay(plan, books, app.readChapters);
    final today = planDayChapters(plan, books, day);
    final next = planNextUnread(plan, books, app.readChapters);
    final pct = total == 0 ? 0.0 : read / total;
    return GradientCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${plan.emoji}  ${plan.name.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plan.desc,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ProgressRing(
                value: pct,
                size: 68,
                color: Colors.white,
                center: Text(
                  '${(pct * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Day $day of ${plan.days} · $read of $total chapters read',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (today.isNotEmpty)
            Text(
              'Today: ${_todayLabel(today)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: theme.accent,
                ),
                onPressed: next == null
                    ? null
                    : () => app.openRef(next),
                child: Text(next == null ? 'Complete ✓' : 'Read day $day'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => app.goTo(1),
                child: const Text('Open Reader →',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _todayLabel(List<VerseRef> today) {
    String label(VerseRef r) => switch (r.slug) {
          'song_of_solomon' => 'Song of Solomon ${r.chapter}',
          _ => '${r.slug.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')} ${r.chapter}',
        };
    if (today.length == 1) return label(today.first);
    return '${label(today.first)} – ${label(today.last)}';
  }
}

class _PlanCard extends StatelessWidget {
  final PlanDef plan;
  final List<BookInfo> books;
  final bool isActive;

  const _PlanCard({
    required this.plan,
    required this.books,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    final total = planChapters(plan, books).length;
    final read = planReadCount(plan, books, app.readChapters);
    final pct = total == 0 ? 0.0 : read / total;
    final next = planNextUnread(plan, books, app.readChapters);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    plan.emoji,
                    style: const TextStyle(fontSize: 21),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        plan.desc,
                        style: TextStyle(
                          color: theme.textDim,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CURRENT',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: theme.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(theme.accent),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '$read of $total chapters · ${plan.days} days',
                  style: TextStyle(color: theme.textDim, fontSize: 11.5),
                ),
                const Spacer(),
                Text(
                  '${(pct * 100).round()}%',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    if (next != null) app.openRef(next);
                  },
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(read == 0 ? 'Start' : 'Continue'),
                ),
                const SizedBox(width: 10),
                if (!isActive)
                  TextButton(
                    onPressed: () {
                      app.setActivePlan(plan.id);
                      showSnack(context, '“${plan.name}” is now your plan');
                    },
                    child: const Text('Make current'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
