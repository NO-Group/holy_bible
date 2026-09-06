/// Achievement definitions. Every metric is derived from the store's
/// real statistics — nothing is persisted separately, so progress can
/// never drift out of sync.
library;

import '../store.dart';

class AchievementDef {
  final String id;
  final String emoji;
  final String title;
  final String desc;
  final double value; // current metric needed
  final double Function(AppStore store) metric;
  final double Function(AppStore store) progress;

  const AchievementDef({
    required this.id,
    required this.emoji,
    required this.title,
    required this.desc,
    required this.value,
    required this.metric,
    required this.progress,
  });
}

const List<AchievementDef> kAchievements = [
  AchievementDef(
    id: 'ch10',
    emoji: '🌱',
    title: 'First Steps',
    desc: 'Read 10 chapters',
    value: 10,
    metric: _chapters,
    progress: _chapters,
  ),
  AchievementDef(
    id: 'ch50',
    emoji: '📗',
    title: 'Bible Beginner',
    desc: 'Read 50 chapters',
    value: 50,
    metric: _chapters,
    progress: _chapters,
  ),
  AchievementDef(
    id: 'ch100',
    emoji: '📚',
    title: 'Centurion',
    desc: 'Read 100 chapters',
    value: 100,
    metric: _chapters,
    progress: _chapters,
  ),
  AchievementDef(
    id: 'ch250',
    emoji: '🔥',
    title: 'Deep Reader',
    desc: 'Read 250 chapters',
    value: 250,
    metric: _chapters,
    progress: _chapters,
  ),
  AchievementDef(
    id: 'ch500',
    emoji: '⭐',
    title: 'Halfway Hero',
    desc: 'Read 500 chapters',
    value: 500,
    metric: _chapters,
    progress: _chapters,
  ),
  AchievementDef(
    id: 'ch1000',
    emoji: '🏆',
    title: 'Scripture Scholar',
    desc: 'Read 1,000 chapters',
    value: 1000,
    metric: _chapters,
    progress: _chapters,
  ),
  AchievementDef(
    id: 'ch1189',
    emoji: '👑',
    title: 'Whole Bible',
    desc: 'Read all 1,189 chapters',
    value: 1189,
    metric: _chapters,
    progress: _chapters,
  ),
  AchievementDef(
    id: 'streak3',
    emoji: '🌤️',
    title: 'Warm Streak',
    desc: '3-day reading streak',
    value: 3,
    metric: _streak,
    progress: _streak,
  ),
  AchievementDef(
    id: 'streak7',
    emoji: '🌞',
    title: 'Week of Light',
    desc: '7-day reading streak',
    value: 7,
    metric: _streak,
    progress: _streak,
  ),
  AchievementDef(
    id: 'streak30',
    emoji: '🌙',
    title: 'Faithful Month',
    desc: '30-day reading streak',
    value: 30,
    metric: _streak,
    progress: _streak,
  ),
  AchievementDef(
    id: 'streak100',
    emoji: '✨',
    title: 'Unshakable',
    desc: '100-day reading streak',
    value: 100,
    metric: _streak,
    progress: _streak,
  ),
  AchievementDef(
    id: 'quiz5',
    emoji: '🎯',
    title: 'Quiz Apprentice',
    desc: 'Play 5 quiz rounds',
    value: 5,
    metric: _quizzes,
    progress: _quizzes,
  ),
  AchievementDef(
    id: 'quiz25',
    emoji: '🧠',
    title: 'Quiz Champion',
    desc: 'Play 25 quiz rounds',
    value: 25,
    metric: _quizzes,
    progress: _quizzes,
  ),
  AchievementDef(
    id: 'mem10',
    emoji: '🗝️',
    title: 'Treasure Keeper',
    desc: 'Memorize 10 verses',
    value: 10,
    metric: _memorized,
    progress: _memorized,
  ),
  AchievementDef(
    id: 'mem25',
    emoji: '💎',
    title: 'Word in Heart',
    desc: 'Memorize 25 verses',
    value: 25,
    metric: _memorized,
    progress: _memorized,
  ),
  AchievementDef(
    id: 'notes20',
    emoji: '✍️',
    title: 'Scribe',
    desc: 'Write 20 notes',
    value: 20,
    metric: _notes,
    progress: _notes,
  ),
];

double _chapters(AppStore s) => s.chaptersRead.toDouble();
double _streak(AppStore s) => s.streakDays.toDouble();
double _quizzes(AppStore s) => s.quizzesPlayed.toDouble();
double _memorized(AppStore s) => s.memorizedCount.toDouble();
double _notes(AppStore s) => s.notes.length.toDouble();

bool isUnlocked(AchievementDef a, AppStore store) => a.metric(store) >= a.value;
