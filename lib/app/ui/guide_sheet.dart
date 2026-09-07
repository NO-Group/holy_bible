/// Book study-guide sheet: authorship, era, theme, summary and the book's
/// key verse, with one-tap jump into the Reader.
library;

import 'package:flutter/material.dart';

import '../data/book_guides.dart';
import '../data/models.dart';
import 'scope.dart';
import 'widgets.dart';

void showGuideSheet(BuildContext context, String slug) {
  final guide = guideBySlug(slug);
  if (guide == null) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GuideSheet(guide: guide),
  );
}

class _GuideSheet extends StatelessWidget {
  final BookGuide guide;

  const _GuideSheet({required this.guide});

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide.theme.toUpperCase(),
                        style: TextStyle(
                          color: theme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        guide.slug
                            .split('_')
                            .map((w) =>
                                w[0].toUpperCase() + w.substring(1))
                            .join(' '),
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.menu_book, color: theme.accent, size: 28),
              ],
            ),
            const SizedBox(height: 14),
            _GuideLine(icon: Icons.edit_outlined, label: 'Author',
                value: guide.author),
            _GuideLine(icon: Icons.schedule, label: 'Era',
                value: guide.era),
            const SizedBox(height: 12),
            Text(
              guide.summary,
              style: TextStyle(
                color: theme.text,
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: theme.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  AppScope.of(context).openRef(VerseRef(
                    guide.keySlug,
                    guide.keyChapter,
                    guide.keyVerse,
                  ));
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.star_outline, color: theme.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KEY VERSE',
                              style: TextStyle(
                                color: theme.textDim,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${guide.keySlug.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')} '
                              '${guide.keyChapter}:${guide.keyVerse}',
                              style: TextStyle(
                                color: theme.accent,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: theme.textDim),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _GuideLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.textDim),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(
              color: theme.textDim,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.text,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
