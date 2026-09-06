/// Memorize — hide-and-reveal flashcard practice with curated famous
/// verses. First-letter hints train recall; "Mark memorized" keeps a
/// personal treasury of verses hidden in the heart.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/verse_refs.dart';
import 'scope.dart';
import 'widgets.dart';

class MemorizePage extends StatefulWidget {
  const MemorizePage({super.key});

  @override
  State<MemorizePage> createState() => _MemorizePageState();
}

class _MemorizePageState extends State<MemorizePage> {
  Ref3 _current = kFamousVerses[0];
  Future<ChapterData>? _future;
  bool _revealed = false;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _pickNext();
  }

  void _pickNext() {
    final app = AppScope.read(context);
    final pool = kFamousVerses
        .where((r) => !app.isMemorized(r.slug, r.ch, r.v))
        .toList();
    final source = pool.isEmpty ? kFamousVerses : pool;
    _current = source[_rng.nextInt(source.length)];
    _future = app.repo.chapter(
      app.translationCode,
      _current.slug,
      _current.ch,
    );
    _revealed = false;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memorize'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: RefChip(
                '${app.memorizedCount} memorized',
                icon: Icons.bookmark_added,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<ChapterData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final verse = data?.verses
              .where((v) => v.number == _current.v)
              .firstOrNull;
          final text = (verse != null && verse.hasText) ? verse.text : null;
          final bookLabel = _bookLabel(_current.slug);
          final isMem = app.isMemorized(_current.slug, _current.ch, _current.v);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              GradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined,
                            color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'HIDE & RECALL',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '$bookLabel ${_current.ch}:${_current.v}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _revealed || text == null
                          ? (text ?? '…')
                          : _firstLetters(text),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        height: 1.55,
                        fontWeight:
                            _revealed ? FontWeight.w400 : FontWeight.w700,
                        fontFamilyFallback: const ['Georgia', 'serif'],
                        letterSpacing: _revealed ? 0.1 : 2.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _revealed = !_revealed),
                      icon: Icon(
                        _revealed ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                      ),
                      label: Text(_revealed ? 'Hide again' : 'Reveal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isMem
                          ? null
                          : () {
                              app.toggleMemorized(VerseRef(
                                _current.slug,
                                _current.ch,
                                _current.v,
                              ));
                              setState(() {});
                            },
                      icon: Icon(
                        isMem ? Icons.check : Icons.bookmark_add_outlined,
                        size: 18,
                      ),
                      label: Text(isMem ? 'Memorized ✓' : 'Mark memorized'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () => setState(_pickNext),
                icon: const Icon(Icons.refresh),
                label: const Text('Next verse'),
              ),
              const SizedBox(height: 22),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOW TO USE',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '1. Read the reference out loud.\n'
                      '2. Recall the verse with only the first letters shown.\n'
                      '3. Tap Reveal to check yourself.\n'
                      '4. Mark it memorized and come back tomorrow.\n\n'
                      '“Thy word have I hid in mine heart.” — Psalm 119:11',
                      style: TextStyle(
                        color: theme.textDim,
                        fontSize: 12.5,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _firstLetters(String text) => text
      .split(' ')
      .map((w) => w.isEmpty ? '' : w[0])
      .join(' ');

  String _bookLabel(String slug) => switch (slug) {
        'song_of_solomon' => 'Song of Solomon',
        _ => slug
            .split('_')
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' '),
      };
}
