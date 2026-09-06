/// Quiz — rounds of ten questions generated live from the bundled
/// Scripture (which book, finish the famous verse, book order, chapter
/// counts). Tracks best scores per mode.
library;

import 'package:flutter/material.dart';

import '../data/quiz_engine.dart';
import '../store.dart';
import 'scope.dart';
import 'widgets.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

enum _QuizStage { menu, loading, playing, results }

class _QuizPageState extends State<QuizPage> {
  _QuizStage _stage = _QuizStage.menu;
  QuizMode _mode = QuizMode.mixed;
  List<QuizQuestion> _questions = const [];
  int _index = 0;
  int? _picked;
  int _correct = 0;

  Future<void> _start(QuizMode mode) async {
    setState(() {
      _stage = _QuizStage.loading;
      _mode = mode;
    });
    final app = AppScope.read(context);
    final bundle = await app.repo.bundle(app.translationCode);
    if (!mounted) return;
    final engine = QuizEngine(bundle);
    final questions = engine.buildRound(mode);
    setState(() {
      _questions = questions;
      _index = 0;
      _picked = null;
      _correct = 0;
      _stage = _QuizStage.playing;
    });
  }

  void _pick(int i) {
    if (_picked != null) return;
    final q = _questions[_index];
    setState(() {
      _picked = i;
      if (i == q.answer) _correct += 1;
    });
  }

  void _next() {
    if (_index + 1 < _questions.length) {
      setState(() {
        _index += 1;
        _picked = null;
      });
    } else {
      final app = AppScope.read(context);
      app.recordQuiz(QuizResult(_mode.id, _correct, _questions.length));
      setState(() => _stage = _QuizStage.results);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scripture Quiz'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_stage == _QuizStage.playing) {
              setState(() => _stage = _QuizStage.menu);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: switch (_stage) {
        _QuizStage.menu => _MenuView(
            onStart: _start,
          ),
        _QuizStage.loading => const Center(child: CircularProgressIndicator()),
        _QuizStage.playing => _buildQuestion(),
        _QuizStage.results => _ResultsView(
            correct: _correct,
            total: _questions.length,
            mode: _mode,
            onRetry: () => _start(_mode),
            onHome: () => Navigator.pop(context),
          ),
      },
    );
  }

  Widget _buildQuestion() {
    final theme = appThemeOf(context);
    final q = _questions[_index];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Text(
                '${_index + 1} / ${_questions.length}',
                style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / _questions.length,
                    minHeight: 6,
                    backgroundColor: theme.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation(theme.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              Text(
                _mode.label.toUpperCase(),
                style: TextStyle(
                  color: theme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                q.question,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              if (q.quote != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    q.quote!,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 15,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                      fontFamilyFallback: const ['Georgia', 'serif'],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              for (var i = 0; i < q.options.length; i++)
                _OptionTile(
                  index: i,
                  text: q.options[i],
                  picked: _picked,
                  answer: q.answer,
                  onTap: () => _pick(i),
                ),
              if (_picked != null) ...[
                const SizedBox(height: 14),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: 1,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _picked == q.answer
                          ? const Color(0xFF7ED99A).withValues(alpha: 0.18)
                          : const Color(0xFFF5A3C0).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _picked == q.answer
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _picked == q.answer
                              ? const Color(0xFF2E9E62)
                              : const Color(0xFFC2547C),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q.explain,
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 13.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _next,
                  child: Text(
                    _index + 1 < _questions.length ? 'Next question' : 'See results',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final int index;
  final String text;
  final int? picked;
  final int answer;
  final VoidCallback onTap;

  const _OptionTile({
    required this.index,
    required this.text,
    required this.picked,
    required this.answer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    final isAnswer = picked != null && index == answer;
    final isPickedWrong = picked == index && index != answer;
    final isDisabled = picked != null;
    Color bg = theme.surfaceAlt;
    BoxBorder? border;
    if (picked != null) {
      if (isAnswer) {
        bg = const Color(0xFF7ED99A).withValues(alpha: 0.20);
        border = const Border.all(color: Color(0xFF2E9E62), width: 1.4);
      } else if (isPickedWrong) {
        bg = const Color(0xFFF5A3C0).withValues(alpha: 0.20);
        border = const Border.all(color: Color(0xFFC2547C), width: 1.4);
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: border,
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isAnswer
                        ? const Color(0xFF2E9E62)
                        : isPickedWrong
                            ? const Color(0xFFC2547C)
                            : theme.card,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: TextStyle(
                      color: isAnswer || isPickedWrong
                          ? Colors.white
                          : theme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14.5,
                      height: 1.35,
                    ),
                  ),
                ),
                if (isAnswer)
                  const Icon(Icons.check, color: Color(0xFF2E9E62)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuView extends StatelessWidget {
  final ValueChanged<QuizMode> onStart;

  const _MenuView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        GradientCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.quiz, color: Colors.white, size: 30),
              const SizedBox(height: 12),
              const Text(
                'Test what you know',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '10 questions per round, generated from the actual text of '
                '${app.translation.name}. ${app.quizzesPlayed} round${app.quizzesPlayed == 1 ? '' : 's'} played · '
                '${app.quizAccuracy}% lifetime accuracy',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'CHOOSE A MODE',
          style: TextStyle(
            color: theme.accent,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        for (final mode in QuizMode.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Card(
              child: InkWell(
                onTap: () => onStart(mode),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        mode == QuizMode.mixed
                            ? Icons.auto_awesome
                            : mode == QuizMode.whichBook
                                ? Icons.help_outline
                                : mode == QuizMode.finishVerse
                                    ? Icons.format_quote
                                    : Icons.format_list_numbered,
                        color: theme.accent,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.label,
                              style: TextStyle(
                                color: theme.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              mode.desc,
                              style: TextStyle(
                                color: theme.textDim,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((app.quizBest[mode.id] ?? 0) > 0)
                        Text(
                          'Best ${app.quizBest[mode.id]!.round()}%',
                          style: TextStyle(
                            color: theme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Icon(Icons.chevron_right, color: theme.textDim),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ResultsView extends StatelessWidget {
  final int correct;
  final int total;
  final QuizMode mode;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const _ResultsView({
    required this.correct,
    required this.total,
    required this.mode,
    required this.onRetry,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    final pct = (correct / total * 100).round();
    final message = pct >= 90
        ? 'Outstanding! You truly know the Word. ✨'
        : pct >= 70
            ? 'Great work — solid command of Scripture!'
            : pct >= 50
                ? 'A good round. Keep reading and you’ll soar!'
                : 'Every round builds knowledge — try again!';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ProgressRing(
              value: correct / total,
              size: 140,
              stroke: 10,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$pct%',
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '$correct / $total',
                    style: TextStyle(
                      color: theme.textDim,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${mode.label} round',
              style: TextStyle(color: theme.textDim, fontSize: 12.5),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Play again'),
                ),
                OutlinedButton.icon(
                  onPressed: onHome,
                  icon: const Icon(Icons.home),
                  label: const Text('Home'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
