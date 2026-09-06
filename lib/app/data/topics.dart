/// Topical concordance: curated topics with keyword groups. Verses are
/// pulled live from the bundled translation, so topics always reflect
/// the selected version's actual text.
library;

class TopicDef {
  final String id;
  final String title;
  final String emoji;
  final List<String> keywords;
  final int colorValue;

  const TopicDef({
    required this.id,
    required this.title,
    required this.emoji,
    required this.keywords,
    required this.colorValue,
  });
}

const List<TopicDef> kTopics = [
  TopicDef(
    id: 'love',
    title: 'Love',
    emoji: '❤️',
    keywords: ['love', 'loved', 'loves', 'loving'],
    colorValue: 0xFFF5A3C0,
  ),
  TopicDef(
    id: 'faith',
    title: 'Faith & Trust',
    emoji: '🙏',
    keywords: ['faith', 'trust', 'believe', 'believes'],
    colorValue: 0xFF7ED99A,
  ),
  TopicDef(
    id: 'hope',
    title: 'Hope & Comfort',
    emoji: '🌅',
    keywords: ['hope', 'comfort', 'encourage', 'peace'],
    colorValue: 0xFFF6D743,
  ),
  TopicDef(
    id: 'prayer',
    title: 'Prayer',
    emoji: '🕊️',
    keywords: ['pray', 'prayer', 'prayed', 'asking'],
    colorValue: 0xFF7CC4F5,
  ),
  TopicDef(
    id: 'wisdom',
    title: 'Wisdom & Guidance',
    emoji: '🦉',
    keywords: ['wisdom', 'wise', 'guide', 'direction', 'counsel'],
    colorValue: 0xFFC6A6F2,
  ),
  TopicDef(
    id: 'strength',
    title: 'Strength & Courage',
    emoji: '💪',
    keywords: ['strength', 'strong', 'courage', 'courageous', 'fear not'],
    colorValue: 0xFFE8890C,
  ),
  TopicDef(
    id: 'forgiveness',
    title: 'Forgiveness & Grace',
    emoji: '🤍',
    keywords: ['forgive', 'forgiven', 'grace', 'mercy'],
    colorValue: 0xFF9D7BFF,
  ),
  TopicDef(
    id: 'salvation',
    title: 'Salvation & Eternal Life',
    emoji: '⛵',
    keywords: ['salvation', 'saved', 'eternal', 'everlasting'],
    colorValue: 0xFF5EA8FF,
  ),
  TopicDef(
    id: 'joy',
    title: 'Joy & Thanksgiving',
    emoji: '🎉',
    keywords: ['joy', 'rejoice', 'thanksgiving', 'thanks', 'glad'],
    colorValue: 0xFFF0B429,
  ),
  TopicDef(
    id: 'shepherd',
    title: 'Shepherd & Rest',
    emoji: '🌿',
    keywords: ['shepherd', 'rest', 'green pastures', 'still waters'],
    colorValue: 0xFF7ED99A,
  ),
  TopicDef(
    id: 'endurance',
    title: 'Endurance & Trials',
    emoji: '⛰️',
    keywords: ['endure', 'endurance', 'trial', 'trials', 'perseverance', 'patience'],
    colorValue: 0xFFC2547C,
  ),
  TopicDef(
    id: 'word',
    title: 'The Word of God',
    emoji: '📜',
    keywords: ['scripture', 'word of god', 'lamp', 'light', 'sword'],
    colorValue: 0xFF8B5CF6,
  ),
];
