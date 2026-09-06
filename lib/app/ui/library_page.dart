/// Library — books browser (with per-book progress) plus collections of
/// bookmarks, highlights and notes.
library;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../data/topics.dart';
import '../store.dart';
import '../theme.dart';
import 'scope.dart';
import 'widgets.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Builder(
        builder: (context) {
          final theme = appThemeOf(context);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Library'),
              bottom: TabBar(
                labelColor: theme.accent,
                unselectedLabelColor: theme.textDim,
                indicatorColor: theme.accent,
                dividerColor: theme.border,
                tabs: const [
                  Tab(text: 'Books'),
                  Tab(text: 'Bookmarks'),
                  Tab(text: 'Highlights'),
                  Tab(text: 'Notes'),
                  Tab(text: 'Topics'),
                ],
              ),
            ),
            body: TabBarView(
              children: const [
                _BooksTab(),
                _BookmarksTab(),
                _HighlightsTab(),
                _NotesTab(),
                _TopicsTab(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BooksTab extends StatefulWidget {
  const _BooksTab();

  @override
  State<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<_BooksTab> {
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filter.addListener(() {
      if (mounted) setState(() => _query = _filter.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    return FutureBuilder<List<BookInfo>>(
      future: app.repo.books(app.translationCode),
      builder: (context, snapshot) {
        final books = snapshot.data ?? const <BookInfo>[];
        if (books.isEmpty && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final visible = books
            .where(
              (b) => _query.isEmpty || b.name.toLowerCase().contains(_query),
            )
            .toList();
        final ot = visible.where((b) => b.isOldTestament).toList();
        final nt = visible.where((b) => !b.isOldTestament).toList();
        final read = app.chaptersRead;
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'PROGRESS: ${(app.bibleProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  Text(
                    '$read of $kTotalChapters chapters',
                    style: TextStyle(color: theme.textDim, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: app.bibleProgress,
                  minHeight: 6,
                  backgroundColor: theme.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(theme.accent),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: TextField(
                controller: _filter,
                decoration: const InputDecoration(
                  hintText: 'Filter books…',
                  prefixIcon: Icon(Icons.filter_list),
                  isDense: true,
                ),
              ),
            ),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'No book matches',
                  message: 'Try a different name.',
                ),
              )
            else ...[
              if (ot.isNotEmpty) _BookSection(title: 'OLD TESTAMENT', books: ot),
              if (nt.isNotEmpty)
                _BookSection(title: 'NEW TESTAMENT', books: nt),
            ],
          ],
        );
      },
    );
  }
}

class _BookSection extends StatelessWidget {
  final String title;
  final List<BookInfo> books;

  const _BookSection({required this.title, required this.books});

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            title,
            style: TextStyle(
              color: theme.accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
        ),
        for (final book in books) _BookRow(book: book),
      ],
    );
  }
}

class _BookRow extends StatelessWidget {
  final BookInfo book;

  const _BookRow({required this.book});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    var read = 0;
    for (var c = 1; c <= book.chapterCount; c++) {
      if (app.isChapterRead(book.slug, c)) read += 1;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final ref = await _pickChapter(context, app, book);
            if (ref != null) app.openRef(ref);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${book.id}',
                    style: TextStyle(
                      color: theme.textDim,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: book.chapterCount == 0
                              ? 0
                              : read / book.chapterCount,
                          minHeight: 3,
                          backgroundColor: theme.surfaceAlt,
                          valueColor: AlwaysStoppedAnimation(theme.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$read/${book.chapterCount}',
                  style: TextStyle(color: theme.textDim, fontSize: 11.5),
                ),
                Icon(Icons.chevron_right, color: theme.textDim, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<VerseRef?> _pickChapter(
  BuildContext context,
  AppStore app,
  BookInfo book,
) async {
  final ref = await showModalBottomSheet<VerseRef>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.of(sheetContext).size.height * 0.72,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.name,
                style: TextStyle(
                  color: appThemeOf(sheetContext).text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${book.chapterCount} chapters · ${book.testamentLabel}',
                style: TextStyle(
                  color: appThemeOf(sheetContext).textDim,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var c = 1; c <= book.chapterCount; c++)
                        Material(
                          color: app.isChapterRead(book.slug, c)
                              ? appThemeOf(sheetContext).accentSoft
                              : appThemeOf(sheetContext).surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => Navigator.pop(
                                sheetContext, VerseRef(book.slug, c)),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 46,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$c',
                                style: TextStyle(
                                  color: app.isChapterRead(book.slug, c)
                                      ? appThemeOf(sheetContext).accent
                                      : appThemeOf(sheetContext).text,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ref;
}

class _BookmarksTab extends StatelessWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.bookmarks;
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.bookmark_border,
        title: 'No bookmarks yet',
        message: 'Tap any verse in the Reader and choose Bookmark. '
            'Your favorite passages will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        for (final a in items) _AnnotationTile(annotation: a),
      ],
    );
  }
}

class _HighlightsTab extends StatelessWidget {
  const _HighlightsTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.highlights;
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.palette_outlined,
        title: 'No highlights yet',
        message: 'Highlight verses in five colors from the verse menu '
            'to build your personal study set.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        for (final a in items) _AnnotationTile(annotation: a),
      ],
    );
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.notes;
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.sticky_note_2_outlined,
        title: 'No notes yet',
        message: 'Attach reflections to any verse and keep a growing '
            'personal commentary.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        for (final a in items) _AnnotationTile(annotation: a),
      ],
    );
  }
}

class _AnnotationTile extends StatelessWidget {
  final Annotation annotation;

  const _AnnotationTile({required this.annotation});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    final data = app.repo.chapterIfLoaded(
      app.translationCode,
      annotation.slug,
      annotation.chapter,
    );
    final text = data
        ?.verses
        .where((v) => v.number == annotation.verse)
        .firstOrNull
        ?.text;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: () => app.openRef(VerseRef(
          annotation.slug,
          annotation.chapter,
          annotation.verse,
        )),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    annotation.bookmark
                        ? Icons.bookmark
                        : annotation.color != null
                            ? Icons.palette_outlined
                            : Icons.sticky_note_2,
                    size: 16,
                    color: annotation.color != null
                        ? kHighlightPalette[annotation.color!]
                        : theme.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _refLabel(app, annotation),
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (annotation.bookmark)
                    RefChip(
                      'Open',
                      onTap: () => app.openRef(VerseRef(
                        annotation.slug,
                        annotation.chapter,
                        annotation.verse,
                      )),
                      icon: Icons.open_in_new,
                    ),
                ],
              ),
              if (text != null && text.isNotEmpty) ...[
                const SizedBox(height: 8),
                VerseText(
                  text,
                  fontSize: app.fontSize - 2,
                  lineHeight: app.lineHeight,
                  justify: true,
                ),
              ],
              if (annotation.note?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    annotation.note!,
                    style: TextStyle(
                      color: theme.textDim,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _refLabel(AppStore app, Annotation a) {
    final loaded = app.repo.bundleIfLoaded(app.translationCode)?.info;
    final String? name = loaded == null
        ? null
        : loaded
            .firstWhere(
              (b) => b.slug == a.slug,
              orElse: () => loaded.first,
            )
            .name;
    return '$name ${a.chapter}:${a.verse}';
  }
}


class _TopicsTab extends StatelessWidget {
  const _TopicsTab();

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text(
            'STUDY BY TOPIC',
            style: TextStyle(
              color: theme.accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            'Verses are gathered live from the current translation by theme.',
            style: TextStyle(color: theme.textDim, fontSize: 12.5),
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.02,
          children: [
            for (final topic in kTopics)
              Material(
                color: theme.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _TopicView(topic: topic),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(topic.emoji, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 8),
                        Text(
                          topic.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TopicView extends StatefulWidget {
  final TopicDef topic;

  const _TopicView({required this.topic});

  @override
  State<_TopicView> createState() => _TopicViewState();
}

class _TopicHit {
  final BookInfo book;
  final int chapter;
  final int verse;
  final String text;

  const _TopicHit(this.book, this.chapter, this.verse, this.text);
}

class _TopicViewState extends State<_TopicView> {
  List<_TopicHit>? _hits;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    final bundle = await app.repo.bundle(app.translationCode);
    if (!mounted) return;
    final keywords = widget.topic.keywords;
    final out = <_TopicHit>[];
    for (final book in bundle.books) {
      for (var c = 0; c < book.chapters.length && out.length < 60; c++) {
        for (var v = 0; v < book.chapters[c].length && out.length < 60; v++) {
          final text = book.chapters[c][v];
          if (text.isEmpty) continue;
          final lower = text.toLowerCase();
          if (!keywords.any(lower.contains)) continue;
          out.add(_TopicHit(
            BookInfo(
              id: book.id,
              name: book.name,
              slug: book.slug,
              chapterCount: book.chapters.length,
            ),
            c + 1,
            v + 1,
            text,
          ));
        }
      }
    }
    if (mounted) setState(() => _hits = out);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.topic.emoji} ${widget.topic.title}'),
      ),
      body: _hits == null
          ? const Center(child: CircularProgressIndicator())
          : _hits!.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'No verses found',
                  message: 'Try another translation.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${_hits!.length} verses · ${app.translation.name}',
                        style: TextStyle(
                          color: theme.textDim,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final hit in _hits!)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: InkWell(
                          onTap: () => app.openRef(VerseRef(
                            hit.book.slug,
                            hit.chapter,
                            hit.verse,
                          )),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${hit.book.name} ${hit.chapter}:${hit.verse}',
                                  style: TextStyle(
                                    color: theme.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                VerseText(
                                  hit.text,
                                  fontSize: app.fontSize - 2,
                                  lineHeight: app.lineHeight,
                                  justify: true,
                                  family: app.fontFamily,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
