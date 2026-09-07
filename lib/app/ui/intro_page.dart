/// First-run onboarding: a short tour of Selah's headline capabilities.
library;

import 'package:flutter/material.dart';

import 'scope.dart';
import 'widgets.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController _pager = PageController();
  int _index = 0;

  static const _slides = [
    (
      icon: Icons.auto_stories,
      title: 'The whole Bible, offline',
      body:
          '66 books · 1,189 chapters · 31,104 verses in five translations — '
          'KJV, NIV, NLT, NWT and the original Hebrew & Greek — '
          'with no internet needed, ever.',
    ),
    (
      icon: Icons.compare_arrows,
      title: 'Study like a scholar',
      body:
          'Parallel reading, an all-five-translations view, 66 book study '
          'guides, topical concordance and instant full-text search.',
    ),
    (
      icon: Icons.record_voice_over,
      title: 'Ears, heart and habit',
      body:
          'Listen to chapters read aloud, drill memorization flashcards, '
          'follow reading plans with streaks, goals and achievements.',
    ),
    (
      icon: Icons.wb_sunny_outlined,
      title: 'A word for every day',
      body:
          'Daily verse, today’s focus with reflect-pray-act prompts, and '
          'journaling — plus 5 hand-tuned themes and OLED mode.',
    ),
  ];

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: TextStyle(color: theme.textDim),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pager,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: theme.accentSoft,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(slide.icon,
                              size: 54, color: theme.accent),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.textDim,
                            fontSize: 14.5,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? theme.accent : theme.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _index + 1 < _slides.length
                      ? () => _pager.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          )
                      : _finish,
                  child: Text(
                    _index + 1 < _slides.length ? 'Continue' : 'Begin reading',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _finish() {
    AppScope.read(context).setOnboarded();
    // First run: no Navigator yet — the app swaps to HomeShell on rebuild.
    // Replay from Settings: pop the pushed route.
    final nav = Navigator.maybeOf(context);
    if (!mounted) return;
    if (nav != null && nav.canPop()) nav.pop();
  }
}
