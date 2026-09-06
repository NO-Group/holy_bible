/// Settings: translation, theme, reading preferences, data management
/// and app information.
library;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../store.dart';
import '../theme.dart';
import 'scope.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: app,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            _SectionTitle('TRANSLATION'),
            for (final t in kTranslations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: t.code == app.translationCode
                      ? theme.accentSoft
                      : theme.surfaceAlt,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.code == app.translationCode
                          ? theme.accent
                          : theme.card,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t.short,
                      style: TextStyle(
                        color: t.code == app.translationCode
                            ? theme.textOnAccent
                            : theme.textDim,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  title: Text(
                    t.name,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    t.desc,
                    style: TextStyle(color: theme.textDim, fontSize: 11.5),
                  ),
                  trailing: t.code == app.translationCode
                      ? Icon(Icons.check_circle, color: theme.accent, size: 20)
                      : null,
                  onTap: () => app.setTranslation(t.code),
                ),
              ),
            _SectionTitle('THEME'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kAppThemes)
                  ChoiceChip(
                    avatar: Icon(t.icon, size: 16),
                    label: Text(t.label),
                    selected: app.themeId == t.id,
                    onSelected: (_) => app.setTheme(t.id),
                  ),
              ],
            ),
            _SectionTitle('READING'),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: theme.surfaceAlt,
              leading: const Icon(Icons.format_size),
              title: const Text('Text size'),
              subtitle: Slider(
                value: app.fontSize,
                min: 13,
                max: 26,
                divisions: 13,
                onChanged: (v) => app.setFontSize(v),
              ),
              trailing: Text('${app.fontSize.round()}'),
            ),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: theme.surfaceAlt,
              leading: const Icon(Icons.vertical_align_center),
              title: const Text('Line height'),
              subtitle: Slider(
                value: app.lineHeight,
                min: 1.3,
                max: 2.2,
                divisions: 9,
                onChanged: (v) => app.setLineHeight(v),
              ),
              trailing: Text(app.lineHeight.toStringAsFixed(2)),
            ),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: theme.surfaceAlt,
              leading: const Icon(Icons.font_download_outlined),
              title: const Text('Font family'),
              subtitle: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'serif', label: Text('Serif')),
                  ButtonSegment(value: 'sans', label: Text('Sans')),
                  ButtonSegment(value: 'mono', label: Text('Mono')),
                ],
                selected: {app.fontFamily},
                showSelectedIcon: false,
                onSelectionChanged: (v) => app.setFontFamily(v.first),
              ),
            ),
            SwitchListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: theme.surfaceAlt,
              value: app.showVerseNumbers,
              onChanged: (v) => app.setShowVerseNumbers(v),
              title: const Text('Verse numbers'),
            ),
            SwitchListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: theme.surfaceAlt,
              value: app.justifyText,
              onChanged: (v) => app.setJustify(v),
              title: const Text('Justified text'),
            ),
            _SectionTitle('DATA'),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: theme.surfaceAlt,
              leading: const Icon(Icons.delete_outline),
              title: const Text('Reset all data'),
              subtitle: const Text(
                'Bookmarks, highlights, notes, progress and settings',
              ),
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Reset app data?',
                  message: 'This permanently clears bookmarks, highlights, '
                      'notes, reading progress, streaks and settings. '
                      'This cannot be undone.',
                  confirmLabel: 'Reset everything',
                );
                if (ok) {
                  await app.resetAll();
                  if (context.mounted) {
                    showSnack(context, 'All app data was cleared');
                  }
                }
              },
            ),
            _SectionTitle('ABOUT SELAH'),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selah — an advanced, fully offline Bible companion',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selah v2.0 — 66 books · 1,189 chapters · 31,104 verses '
                    'per version\n'
                    '• Five translations bundled: KJV, NIV, NLT, NWT and the '
                    'original Hebrew (Masoretic Text) & Greek (Textus '
                    'Receptus) manuscripts\n'
                    '• Parallel reading, chapter audio (device speech), '
                    'full-text search, reading plans, topical study, quizzes, '
                    'memorization drills, notes, highlights and bookmarks — '
                    'all offline\n'
                    '• Scripture text © their respective publishers; '
                    'original-language text via public-domain editions '
                    '(WLC, Textus Receptus).',
                    style: TextStyle(
                      color: theme.textDim,
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(
        title,
        style: TextStyle(
          color: theme.accent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
