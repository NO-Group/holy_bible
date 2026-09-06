/// Full-text search across every verse of the selected translation
/// (offline, instant), with book/OT/NT scopes, match highlighting,
/// result grouping and a smart reference parser ("John 3:16" jumps
/// straight to the verse).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../store.dart';
import '../theme.dart';
import 'scope.dart';
import 'widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchResult {
  final BookInfo book;
  final int chapter;
  final int verse;
  final String text;

  const _SearchResult(this.book, this.chapter, this.verse, this.text);
}

enum _Scope { all, ot, nt, book }

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  _Scope _scope = _Scope.all;
  String? _bookScope;
  List<BookInfo> _books = const [];
  List<_SearchResult> _results = const [];
  int _bookHits = 0;
  bool _searching = false;
  Future<VerseRef?> _parsedRef = Future.value(null);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await AppScope.read(context).repo.books('kjv');
    if (!mounted) return;
    setState(() => _books = books);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _parsedRef = _query.isEmpty
            ? Future.value(null)
            : AppScope.read(context).repo.parseRef(_query);
        if (_query.isEmpty) {
          _results = const [];
          _searching = false;
        } else {
          _searching = true;
          _runSearch();
        }
      });
    });
  }

  void _runSearch() {
    final app = AppScope.read(context);
    final repo = app.repo;
    final bundle = repo.bundleIfLoaded(app.translationCode);
    if (bundle == null) {
      repo.bundle(app.translationCode).then((_) {
        if (mounted) setState(() {
          _searching = true;
          _runSearch();
        });
      });
      return;
    }
    final q = _query.toLowerCase();
    final out = <_SearchResult>[];
    final limit = 400;
    var bookHits = 0;
    for (final book in bundle.books) {
      var inBook = 0;
      final name = book.name;
      for (var c = 0; c < book.chapters.length && out.length < limit; c++) {
        final chapter = book.chapters[c];
        for (var v = 0; v < chapter.length && out.length < limit; v++) {
          final text = chapter[v];
          if (text.isEmpty || !text.toLowerCase().contains(q)) continue;
          if (_scope != _Scope.all) {
            final isOT = book.id <= 39;
            if (_scope == _Scope.book && book.slug != _bookScope) continue;
            if (_scope == _Scope.ot && !isOT) continue;
            if (_scope == _Scope.nt && isOT) continue;
          }
          out.add(_SearchResult(
            BookInfo(
              id: book.id,
              name: name,
              slug: book.slug,
              chapterCount: book.chapters.length,
            ),
            c + 1,
            v + 1,
            text,
          ));
          if (++inBook == 1) bookHits += 1;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _results = out;
      _bookHits = bookHits;
      _searching = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: RefChip(
                app.translation.short,
                icon: Icons.translate,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search the Bible, or type a reference (John 3:16)…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _scopeChip(_Scope.all, 'Whole Bible'),
                _scopeChip(_Scope.ot, 'Old Testament'),
                _scopeChip(_Scope.nt, 'New Testament'),
                _scopeChip(_Scope.book, _bookScope == null
                    ? 'Book…'
                    : _books
                            .firstWhere(
                              (b) => b.slug == _bookScope,
                              orElse: () => _books.first,
                            )
                            .name),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(theme),
          ),
        ],
      ),
    );
  }

  Widget _scopeChip(_Scope scope, String label) {
    final theme = appThemeOf(context);
    final selected =
        _scope == scope || (scope == _Scope.book && _scope == _Scope.book);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: theme.accentSoft,
        labelStyle: TextStyle(
          color: selected ? theme.accent : theme.textDim,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        showCheckmark: false,
        onSelected: (_) async {
          if (scope == _Scope.book) {
            final slug = await _pickBook();
            if (!mounted || slug == null) return;
            setState(() {
              _scope = _Scope.book;
              _bookScope = slug;
            });
          } else {
            setState(() => _scope = scope);
          }
          if (_query.isNotEmpty) _runSearch();
        },
      ),
    );
  }

  Future<String?> _pickBook() async {
    final books = _books;
    final slug = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                'Choose a book',
                style: TextStyle(
                  color: appThemeOf(sheetContext).text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              for (final b in books)
                ListTile(
                  dense: true,
                  title: Text(
                    b.name,
                    style: TextStyle(color: appThemeOf(sheetContext).text),
                  ),
                  subtitle: Text(
                    '${b.chapterCount} chapters',
                    style: TextStyle(
                      color: appThemeOf(sheetContext).textDim,
                      fontSize: 11.5,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, b.slug),
                ),
            ],
          ),
        ),
      ),
    );
    return slug;
  }

  Widget _buildBody(AppTheme theme) {
    if (_query.isEmpty) {
      return const EmptyState(
        icon: Icons.manage_search,
        title: 'Search the Scriptures',
        message: 'Every word is available offline. Try “faith”, “mercy”, '
            '“shepherd” — or type a reference like “Psalm 23” to jump.',
      );
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No results',
        message: 'Nothing matched that phrase in this translation. '
            'Try fewer words or another version.',
      );
    }
    final grouped = <String, List<_SearchResult>>{};
    for (final r in _results) {
      (grouped[r.book.name] ??= []).add(r);
    }
    return FutureBuilder<VerseRef?>(
      future: _parsedRef,
      builder: (context, snapshot) {
        final parsed = snapshot.data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          children: [
            if (parsed != null)
              GradientCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.north_east, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Open ${_refLabel(parsed)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: theme.accent,
                      ),
                      onPressed: () =>
                          AppScope.of(context).openRef(parsed),
                      child: const Text('Go'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '${_results.length} matches · $_bookHits book${_bookHits == 1 ? '' : 's'}',
                style: TextStyle(
                  color: theme.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Text(
                  entry.key.toUpperCase(),
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              for (final r in entry.value)
                _ResultTile(
                  result: r,
                  query: _query,
                  onTap: () => AppScope.of(context).openRef(
                    VerseRef(r.book.slug, r.chapter, r.verse),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  String _refLabel(VerseRef ref) {
    final book = _books.firstWhere(
      (b) => b.slug == ref.slug,
      orElse: () => _books.first,
    );
    return ref.verse > 0
        ? '${book.name} ${ref.chapter}:${ref.verse}'
        : '${book.name} ${ref.chapter}';
  }
}

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  final String query;
  final VoidCallback onTap;

  const _ResultTile({
    required this.result,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    final app = AppScope.of(context);
    final spans = _highlightSpans(result.text, query, theme);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.accentSoft,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${result.chapter}:${result.verse}',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: spans),
                  style: TextStyle(
                    color: theme.text,
                    fontSize: app.fontSize - 2,
                    height: 1.45,
                    fontFamilyFallback: const ['Georgia', 'serif'],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TextSpan> _highlightSpans(String text, String query, AppTheme theme) {
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    var index = 0;
    while (true) {
      final found = lower.indexOf(q, index);
      if (found < 0) {
        spans.add(TextSpan(text: text.substring(index)));
        break;
      }
      if (found > index) {
        spans.add(TextSpan(text: text.substring(index, found)));
      }
      spans.add(TextSpan(
        text: text.substring(found, found + q.length),
        style: TextStyle(
          backgroundColor: theme.accentSoft,
          color: theme.accent,
          fontWeight: FontWeight.w800,
        ),
      ));
      index = found + q.length;
      if (index >= text.length) break;
    }
    return spans;
  }
}
