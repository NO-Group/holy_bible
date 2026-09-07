/// The Reader. A swipeable pager over the 1,189 canonical chapters;
/// five translations (incl. original Hebrew/Greek), parallel-comparison
/// mode, per-verse bookmarks/highlights/notes, tap-to-jump references,
/// random chapters and a full reading settings sheet.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../audio/tts_service.dart';
import '../data/repository.dart';
import '../store.dart';
import '../theme.dart';
import 'guide_sheet.dart';
import 'scope.dart';
import 'widgets.dart';

class ReaderTabView extends StatefulWidget {
  const ReaderTabView({super.key});

  @override
  State<ReaderTabView> createState() => _ReaderTabViewState();
}

class _ReaderTabViewState extends State<ReaderTabView> {
  static const int _pad = kTotalChapters;

  late final PageController _pager;
  late AppStore _app;
  int _page = _pad; // padded page index; center = global chapter 1
  int _currentGlobal = 1;
  VerseRef? _target;
  int? _targetGlobal;
  int? _flashVerse;
  Timer? _flashTimer;
  Timer? _markTimer;
  final Set<String> _justMarked = {};

  int _pageForGlobal(int g) => g - 1 + _pad;
  int _globalForPage(int page) =>
      (page - _pad + 1).clamp(1, kTotalChapters).toInt();

  @override
  void initState() {
    super.initState();
    _app = AppScope.read(context);
    _pager = PageController(initialPage: _page);
    _app.addListener(_onStoreChanged);
    _restoreLastPosition();
  }

  @override
  void dispose() {
    _app.removeListener(_onStoreChanged);
    _flashTimer?.cancel();
    _markTimer?.cancel();
    _pager.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    final ref = _app.consumePendingRef();
    if (ref != null && mounted) _goTo(ref);
  }

  Future<void> _restoreLastPosition() async {
    final ref = _app.lastRef;
    final g = await _app.repo.globalFor(ref.slug, ref.chapter);
    if (!mounted || _target != null) return;
    if (g == _currentGlobal) {
      if (ref.verse > 0) {
        setState(() {
          _target = ref;
          _targetGlobal = g;
        });
      }
      return;
    }
    final targetPage = _pageForGlobal(g);
    _page = targetPage;
    _currentGlobal = g;
    if (ref.verse > 0) _target = ref;
    if (_pager.hasClients) {
      _pager.jumpToPage(targetPage);
    }
    if (mounted) setState(() {});
    _onChapterVisible(g);
  }

  Future<void> _goTo(VerseRef ref) async {
    final g = await _app.repo.globalFor(ref.slug, ref.chapter);
    if (!mounted) return;
    final targetPage = _pageForGlobal(g);
    setState(() {
      _target = ref;
      _targetGlobal = g;
      _flashVerse = ref.verse > 0 ? ref.verse : null;
    });
    _flashTimer?.cancel();
    if (_flashVerse != null) {
      _flashTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _flashVerse = null);
      });
    }
    if (_pager.hasClients) {
      if ((_pager.page ?? _page).round() != targetPage) {
        _pager.jumpToPage(targetPage);
      }
    } else {
      _page = targetPage;
    }
    _onChapterVisible(g);
  }

  String _bookLabel(String slug) => switch (slug) {
        'song_of_solomon' => 'Song of Solomon',
        _ => slug
            .split('_')
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' '),
      };

  void _onPageChanged(int page) {
    final g = _globalForPage(page);
    if (g == _currentGlobal) return;
    setState(() {
      _page = page;
      _currentGlobal = g;
    });
    _onChapterVisible(g);
  }

  Future<void> _onChapterVisible(int global) async {
    final app = _app;
    final ref = await app.repo.refForGlobal(global);
    final data =
        await app.repo.chapter(app.translationCode, ref.slug, ref.chapter);
    if (!mounted) return;
    app.remember(ref);
    if (_justMarked.contains(ref.chapterKey)) return;
    final isNew = app.markChapterRead(ref.slug, ref.chapter, data.verseCount);
    if (isNew) {
      _justMarked.add(ref.chapterKey);
      _markTimer?.cancel();
      _markTimer = Timer(const Duration(seconds: 4), () {
        _justMarked.remove(ref.chapterKey);
      });
    }
  }

  void _jumpBy(int delta) {
    final next =
        (_currentGlobal + delta).clamp(1, kTotalChapters).toInt();
    _pager.animateToPage(
      _pageForGlobal(next),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<VerseRef>(
          future: app.repo.refForGlobal(_currentGlobal),
          builder: (context, snapshot) {
            final ref = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref == null
                      ? '…'
                      : '${_bookLabel(ref.slug)} ${ref.chapter}',
                  style: const TextStyle(fontSize: 19),
                ),
                Text(
                  app.translation.short,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: app.compareOn
                ? 'Parallel: ${translationByCode(app.compareCode).name}'
                : 'Parallel reading',
            onPressed: () => _showTranslationSheet(context),
            icon: Icon(
              Icons.compare_arrows,
              color: app.compareOn ? theme.accent : null,
            ),
          ),
          IconButton(
            tooltip: 'Reading settings',
            onPressed: () => _showSettingsSheet(context),
            icon: const Icon(Icons.text_fields),
          ),
          IconButton(
            tooltip: 'Random chapter',
            onPressed: () async {
              final books = await app.repo.books(app.translationCode);
              if (books.isEmpty) return;
              final book = books[Random().nextInt(books.length)];
              final ch = 1 + Random().nextInt(book.chapterCount);
              _goTo(VerseRef(book.slug, ch));
            },
            icon: const Icon(Icons.shuffle),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pager,
              itemCount: _pad * 3,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, i) {
                final global = _globalForPage(i);
                final isTarget = _targetGlobal != null &&
                    _targetGlobal == global &&
                    _target != null;
                return ChapterPage(
                  key: ValueKey('chp-$i'),
                  global: global,
                  focusVerse: isTarget ? _target!.verse : null,
                  flashVerse: isTarget ? _flashVerse : null,
                );
              },
            ),
          ),
          _ReaderBottomBar(
            currentGlobal: _currentGlobal,
            onPick: () => _showChapterPicker(context),
            onPrev: () => _jumpBy(-1),
            onNext: () => _jumpBy(1),
          ),
        ],
      ),
    );
  }

  void _showChapterPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        maxChildSize: 0.94,
        builder: (context, controller) => _ChapterPickerSheet(
          scrollController: controller,
          onSelect: (ref) {
            Navigator.pop(context);
            _goTo(ref);
          },
        ),
      ),
    );
  }

  void _showTranslationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _TranslationSheet(onChanged: () {
        if (mounted) setState(() {});
      }),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReaderSettingsSheet(onChanged: () {
        if (mounted) setState(() {});
      }),
    );
  }
}

class ChapterPage extends StatefulWidget {
  final int global;
  final int? focusVerse;
  final int? flashVerse;

  const ChapterPage({
    super.key,
    required this.global,
    this.focusVerse,
    this.flashVerse,
  });

  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  Future<ChapterData>? _primaryFuture;
  Future<ChapterData>? _secondaryFuture;
  String? _primaryCode;
  String? _secondaryCode;
  VerseRef? _ref;
  bool _scrolled = false;
  bool _awaitingScroll = false;

  final TtsService _tts = TtsService();
  bool _speaking = false;
  int? _speakingVerse;

  @override
  void initState() {
    super.initState();
    _tts.available();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (app.translationCode != _primaryCode) {
      _stopSpeak();
      _primaryCode = app.translationCode;
      _ref = null;
      _scrolled = false;
      _primaryFuture = _fetch(app.translationCode);
    }
    if (app.compareOn && !app.compareAll) {
      if (app.compareCode != _secondaryCode) {
        _secondaryCode = app.compareCode;
        _secondaryFuture = _fetch(app.compareCode);
      }
    } else {
      _secondaryFuture = null;
      _secondaryCode = null;
    }
  }

  Future<void> _toggleSpeak(ChapterData data) async {
    if (_speaking) {
      await _stopSpeak();
      return;
    }
    setState(() => _speaking = true);
    try {
      for (final verse in data.verses) {
        if (!verse.hasText) continue;
        if (!mounted || !_speaking) break;
        setState(() => _speakingVerse = verse.number);
        await _tts.speak(verse.text);
      }
    } catch (_) {
      // Missing engine / interrupted playback: just stop silently.
    } finally {
      if (mounted) {
        setState(() {
          _speaking = false;
          _speakingVerse = null;
        });
      }
    }
  }

  Future<void> _stopSpeak() async {
    await _tts.stop();
    if (mounted && (_speaking || _speakingVerse != null)) {
      setState(() {
        _speaking = false;
        _speakingVerse = null;
      });
    }
  }

  Future<ChapterData> _fetch(String code) {
    final repo = AppScope.read(context).repo;
    final refFuture = repo.refForGlobal(widget.global);
    return refFuture.then((ref) {
      _ref = ref;
      return repo.chapter(code, ref.slug, ref.chapter);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final future = _primaryFuture ?? _fetch(app.translationCode);
    _primaryFuture = future;
    return FutureBuilder<ChapterData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 10),
                Text('${snapshot.error}'),
              ],
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final ref = _ref;
        final secondary = app.compareOn ? _secondaryFuture : null;
        if (!_scrolled) _scheduleScrollIfNeeded(context, ref, data);
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
          children: [
            _ChapterHeader(
              data: data,
              compare: app.compareOn,
              compareAll: app.compareAll,
              speaking: _speaking,
              slug: ref?.slug ?? '',
              onListen: () => _toggleSpeak(data),
            ),
            const SizedBox(height: 14),
            if (app.compareAll)
              _PolyglotBody(
                primary: data,
                ref: ref,
                store: app,
                focusVerse: widget.focusVerse,
                flashVerse: widget.flashVerse,
                speakingVerse: _speakingVerse,
              )
            else if (secondary != null)
              _CompareBody(
                primary: data,
                ref: ref,
                secondaryFuture: secondary,
                store: app,
                focusVerse: widget.focusVerse,
                flashVerse: widget.flashVerse,
                speakingVerse: _speakingVerse,
              )
            else
              for (final verse in data.verses)
                if (verse.hasText)
                  _VerseRow(
                    verse: verse,
                    ref: ref ?? const VerseRef('genesis', 1, 1),
                    store: app,
                    focus: widget.focusVerse == verse.number,
                    flash: widget.flashVerse == verse.number,
                    spoken: _speakingVerse == verse.number,
                  ),
          ],
        );
      },
    );
  }

  void _scheduleScrollIfNeeded(
      BuildContext context, VerseRef? ref, ChapterData data) {
    final target = widget.focusVerse;
    if (ref == null || target == null || target <= 0) return;
    if (_awaitingScroll) return;
    _awaitingScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _findVerseContext(context, target);
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          alignment: 0.22,
        );
      }
      _scrolled = true;
      _awaitingScroll = false;
    });
  }

  BuildContext? _findVerseContext(BuildContext context, int verse) {
    BuildContext? found;
    void visit(Element element) {
      if (found != null) return;
      final w = element.widget;
      if ((w is _VerseRow && w.verse.number == verse) ||
          (w is _PolyglotRow && w.number == verse)) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }
}

class _ChapterHeader extends StatelessWidget {
  final ChapterData data;
  final bool compare;
  final bool compareAll;
  final bool speaking;
  final String slug;
  final VoidCallback onListen;

  const _ChapterHeader({
    required this.data,
    required this.compare,
    required this.compareAll,
    required this.speaking,
    required this.slug,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    final translation = translationByCode(data.code);
    final secondary = compare
        ? translationByCode(AppScope.of(context).compareCode)
        : null;
    final words = data.verses.fold<int>(0, (n, v) => n + v.text.split(' ').length);
    final minutes = (words / 200).ceil().clamp(1, 99);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data.book.toUpperCase(),
                style: TextStyle(
                  color: theme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
            ),
            if (compare)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  compareAll
                      ? '${translation.short} + 4 more'
                      : '${translation.short} + ${secondary!.name}',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${data.chapter}',
          style: TextStyle(
            color: theme.text,
            fontSize: 56,
            height: 1.05,
            fontWeight: FontWeight.w800,
            fontFamilyFallback: const ['Georgia', 'serif'],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          translation.name,
          style: TextStyle(color: theme.textDim, fontSize: 12.5),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '$words words · ~$minutes min read',
                style: TextStyle(color: theme.textDim, fontSize: 13),
              ),
            ),
            IconButton(
              onPressed: () => showGuideSheet(context, slug),
              tooltip: 'Book study guide',
              icon: Icon(Icons.menu_book, size: 20, color: theme.textDim),
            ),
            TextButton.icon(
              onPressed: onListen,
              icon: Icon(
                speaking
                    ? Icons.stop_circle_outlined
                    : Icons.volume_up_outlined,
                size: 18,
                color: speaking ? theme.accent : theme.textDim,
              ),
              label: Text(
                speaking ? 'Stop' : 'Listen',
                style: TextStyle(
                  color: speaking ? theme.accent : theme.textDim,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 24),
      ],
    );
  }
}

class _CompareBody extends StatelessWidget {
  final ChapterData primary;
  final VerseRef? ref;
  final Future<ChapterData> secondaryFuture;
  final AppStore store;
  final int? focusVerse;
  final int? flashVerse;
  final int? speakingVerse;

  const _CompareBody({
    required this.primary,
    required this.ref,
    required this.secondaryFuture,
    required this.store,
    this.focusVerse,
    this.flashVerse,
    this.speakingVerse,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChapterData>(
      future: secondaryFuture,
      builder: (context, snapshot) {
        final sec = snapshot.data;
        if (sec == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final count = min(primary.verses.length, sec.verses.length);
        return Column(
          children: [
            for (var i = 0; i < count; i++)
              if (primary.verses[i].hasText || sec.verses[i].hasText)
                _CompareRow(
                  primary: primary.verses[i],
                  secondary: sec.verses[i],
                  ref: ref ?? const VerseRef('genesis', 1, 1),
                  store: store,
                  focus: focusVerse == primary.verses[i].number,
                  flash: flashVerse == primary.verses[i].number,
                  spoken: speakingVerse == primary.verses[i].number,
                ),
          ],
        );
      },
    );
  }
}

class _CompareRow extends StatelessWidget {
  final VerseData primary;
  final VerseData secondary;
  final VerseRef ref;
  final AppStore store;
  final bool focus;
  final bool flash;
  final bool spoken;

  const _CompareRow({
    required this.primary,
    required this.secondary,
    required this.ref,
    required this.store,
    required this.focus,
    required this.flash,
    this.spoken = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    final ann = store.annotationFor(ref.slug, ref.chapter, primary.number);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${primary.number}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme.verseNumber,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: spoken
                    ? theme.accent.withValues(alpha: 0.22)
                    : focus || flash
                        ? theme.accentSoft
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (primary.hasText)
                    VerseText(
                      primary.text,
                      fontSize: store.fontSize - 1.5,
                      lineHeight: store.lineHeight,
                      justify: store.justifyText,
                      family: store.fontFamily,
                    ),
                  if (primary.hasText && secondary.hasText)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: theme.border),
                    ),
                  if (secondary.hasText)
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text:
                              '${translationByCode(store.compareCode).short} · ',
                          style: TextStyle(
                            color: theme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: secondary.text,
                          style: TextStyle(
                            color: theme.textDim,
                            fontSize: store.fontSize - 2,
                            height: store.lineHeight,
                            fontFamilyFallback: const ['Georgia', 'serif'],
                          ),
                        ),
                      ]),
                    ),
                  if (ann?.bookmark ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(Icons.bookmark,
                          size: 13, color: theme.accent),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseRow extends StatelessWidget {
  final VerseData verse;
  final VerseRef ref;
  final AppStore store;
  final bool focus;
  final bool flash;
  final bool spoken;

  const _VerseRow({
    required this.verse,
    required this.ref,
    required this.store,
    required this.focus,
    required this.flash,
    this.spoken = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    final ann = store.annotationFor(ref.slug, ref.chapter, verse.number);
    final highlightColor = ann?.color != null
        ? highlightWithTheme(kHighlightPalette[ann!.color!], theme)
        : null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showVerseSheet(
        context,
        store,
        VerseRef(ref.slug, ref.chapter, verse.number),
      ),
      onLongPress: () {
        store.setHighlight(VerseRef(ref.slug, ref.chapter, verse.number), 0);
        showSnack(context, 'Highlighted in gold — tap again for more options');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          color: spoken
              ? theme.accent.withValues(alpha: 0.22)
              : focus || flash
                  ? theme.accentSoft
                  : highlightColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '${verse.number}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: theme.verseNumber,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: VerseText(
                verse.text,
                fontSize: store.fontSize,
                lineHeight: store.lineHeight,
                justify: store.justifyText,
                family: store.fontFamily,
              ),
            ),
            if (ann?.bookmark ?? false)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 4),
                child: Icon(Icons.bookmark, size: 14, color: theme.accent),
              ),
            if (ann?.note?.trim().isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Icon(Icons.sticky_note_2, size: 14, color: theme.textDim),
              ),
          ],
        ),
      ),
    );
  }
}

void _showVerseSheet(
  BuildContext context,
  AppStore store,
  VerseRef ref,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _VerseActionSheet(store: store, ref: ref),
  );
}

class _VerseActionSheet extends StatelessWidget {
  final AppStore store;
  final VerseRef ref;

  const _VerseActionSheet({required this.store, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    final data = store.repo.chapterIfLoaded(
      store.translationCode,
      ref.slug,
      ref.chapter,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final ann = store.annotationFor(ref.slug, ref.chapter, ref.verse);
            final text = data?.verses
                    .where((v) => v.number == ref.verse)
                    .firstOrNull
                    ?.text ??
                '';
            return ListView(
              shrinkWrap: true,
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
                Text(
                  _refLabel(),
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text.isEmpty ? '—' : '“$text”',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: store.fontSize + 1,
                    height: store.lineHeight,
                    fontFamilyFallback: const ['Georgia', 'serif'],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  translationByCode(store.translationCode).name,
                  style: TextStyle(color: theme.textDim, fontSize: 12),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SheetAction(
                        icon: Icons.copy,
                        label: 'Copy',
                        onTap: () {
                          copyToClipboard(
                              context, '“$text” — ${_refLabel()}');
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SheetAction(
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () {
                          copyToClipboard(
                            context,
                            '“$text” — ${_refLabel()}',
                            message: 'Verse copied — paste anywhere to share',
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SheetAction(
                        icon: ann?.bookmark ?? false
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        label: ann?.bookmark ?? false
                            ? 'Bookmarked'
                            : 'Bookmark',
                        highlight: ann?.bookmark ?? false,
                        onTap: () => store.toggleBookmark(ref),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SheetAction(
                        icon: store.isMemorized(ref.slug, ref.chapter, ref.verse)
                            ? Icons.bookmark_added
                            : Icons.bookmark_add_outlined,
                        label: store.isMemorized(ref.slug, ref.chapter, ref.verse)
                            ? 'Memorized'
                            : 'Memorize',
                        highlight: store.isMemorized(
                            ref.slug, ref.chapter, ref.verse),
                        onTap: () => store.toggleMemorized(ref),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SheetAction(
                        icon: Icons.palette_outlined,
                        label: ann?.color != null
                            ? 'Highlighted'
                            : 'Highlight',
                        highlight: ann?.color != null,
                        onTap: () => _showHighlightPicker(context, ref),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SheetAction(
                        icon: Icons.sticky_note_2_outlined,
                        label: ann?.note?.trim().isNotEmpty ?? false
                            ? 'Edit note'
                            : 'Add note',
                        onTap: () async {
                          final text = await promptText(
                            context,
                            title: 'Note on ${_refLabel()}',
                            initial: ann?.note ?? '',
                            hint: 'Write your reflection…',
                          );
                          if (text != null) store.setNote(ref, text);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SheetAction(
                        icon: Icons.translate,
                        label: 'Original',
                        onTap: () {
                          store.setTranslation('original');
                          store.openRef(ref);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
                if (ann != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      store.setHighlight(ref, null);
                      store.setNote(ref, null);
                      if (ann.bookmark) store.toggleBookmark(ref);
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Remove all annotations on this verse'),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  String _refLabel() {
    final loaded =
        store.repo.bundleIfLoaded(store.translationCode)?.info;
    final String? name = loaded == null
        ? null
        : loaded
            .firstWhere(
              (b) => b.slug == ref.slug,
              orElse: () => loaded.first,
            )
            .name;
    return '$name ${ref.chapter}:${ref.verse}';
  }

  void _showHighlightPicker(BuildContext context, VerseRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (pickerContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Highlight color',
                style: TextStyle(
                  color: appThemeOf(context).text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < kHighlightPalette.length; i++)
                    InkWell(
                      onTap: () {
                        store.setHighlight(ref, i);
                        Navigator.pop(pickerContext);
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: kHighlightPalette[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: appThemeOf(context).border,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            kHighlightNames[i][0],
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () {
                  store.setHighlight(ref, null);
                  Navigator.pop(pickerContext);
                },
                child: const Text('Clear highlight'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return Material(
      color: highlight ? theme.accentSoft : theme.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            children: [
              Icon(icon,
                  size: 21, color: highlight ? theme.accent : theme.textDim),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolyglotBody extends StatefulWidget {
  final ChapterData primary;
  final VerseRef? ref;
  final AppStore store;
  final int? focusVerse;
  final int? flashVerse;
  final int? speakingVerse;

  const _PolyglotBody({
    required this.primary,
    required this.ref,
    required this.store,
    this.focusVerse,
    this.flashVerse,
    this.speakingVerse,
  });

  @override
  State<_PolyglotBody> createState() => _PolyglotBodyState();
}

class _PolyglotBodyState extends State<_PolyglotBody> {
  late Future<List<ChapterData>> _allFuture;

  @override
  void initState() {
    super.initState();
    _allFuture = _load();
  }

  Future<List<ChapterData>> _load() {
    final ref = widget.ref;
    if (ref == null) {
      return Future.value(const []);
    }
    return Future.wait([
      widget.store.repo.chapter('kjv', ref.slug, ref.chapter),
      widget.store.repo.chapter('niv', ref.slug, ref.chapter),
      widget.store.repo.chapter('nlt', ref.slug, ref.chapter),
      widget.store.repo.chapter('nwt', ref.slug, ref.chapter),
      widget.store.repo.chapter('original', ref.slug, ref.chapter),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChapterData>>(
      future: _allFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final list = snapshot.data!;
        if (list.isEmpty) return const SizedBox.shrink();
        // Lead with the reader's active translation, then the other four.
        final ordered = [
          widget.primary,
          ...list.where((c) => c.code != widget.primary.code),
        ];
        final count = ordered
            .map((c) => c.verses.length)
            .reduce((a, b) => a < b ? a : b);
        return Column(
          children: [
            for (var i = 0; i < count; i++)
              if (ordered.any((c) => c.verses[i].hasText))
                _PolyglotRow(
                  number: i + 1,
                  texts: [for (final c in ordered) c.verses[i]],
                  codes: [for (final c in ordered) c.code],
                  ref: widget.ref ?? const VerseRef('genesis', 1, 1),
                  store: widget.store,
                  focus: widget.focusVerse == i + 1,
                  flash: widget.flashVerse == i + 1,
                  spoken: widget.speakingVerse == i + 1,
                ),
          ],
        );
      },
    );
  }
}

class _PolyglotRow extends StatelessWidget {
  final int number;
  final List<VerseData> texts;
  final List<String> codes;
  final VerseRef ref;
  final AppStore store;
  final bool focus;
  final bool flash;
  final bool spoken;

  const _PolyglotRow({
    required this.number,
    required this.texts,
    required this.codes,
    required this.ref,
    required this.store,
    required this.focus,
    required this.flash,
    required this.spoken,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$number',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: theme.verseNumber,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: spoken
                    ? theme.accent.withValues(alpha: 0.22)
                    : focus || flash
                        ? theme.accentSoft
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < texts.length; i++)
                    if (texts[i].hasText) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: '${translationByCode(codes[i]).short} · ',
                                style: TextStyle(
                                  color: theme.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: texts[i].text,
                                style: TextStyle(
                                  color: i == 0 ? theme.text : theme.textDim,
                                  fontSize: i == 0
                                      ? store.fontSize
                                      : store.fontSize - 2.5,
                                  height: store.lineHeight,
                                  fontFamilyFallback: const [
                                    'Georgia',
                                    'serif',
                                  ],
                                ),
                              ),
                            ]),
                          ),
                        )
                      else
                        VerseText(
                          texts[i].text,
                          fontSize: store.fontSize,
                          lineHeight: store.lineHeight,
                          justify: store.justifyText,
                          family: store.fontFamily,
                        ),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderBottomBar extends StatelessWidget {
  final int currentGlobal;
  final VoidCallback onPick;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _ReaderBottomBar({
    required this.currentGlobal,
    required this.onPick,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: theme.card,
          border: Border(top: BorderSide(color: theme.border)),
        ),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('Chapters'),
            ),
            const Spacer(),
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous chapter',
            ),
            Text(
              '$currentGlobal / $kTotalChapters',
              style: TextStyle(color: theme.textDim, fontSize: 12),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next chapter',
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterPickerSheet extends StatefulWidget {
  final ScrollController scrollController;
  final ValueChanged<VerseRef> onSelect;

  const _ChapterPickerSheet({
    required this.scrollController,
    required this.onSelect,
  });

  @override
  State<_ChapterPickerSheet> createState() => _ChapterPickerSheetState();
}

class _ChapterPickerSheetState extends State<_ChapterPickerSheet> {
  String? _bookSlug;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    return FutureBuilder<List<BookInfo>>(
      future: app.repo.books(app.translationCode),
      builder: (context, snapshot) {
        final books = snapshot.data ?? const <BookInfo>[];
        if (books.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final ot = books.where((b) => b.isOldTestament).toList();
        final nt = books.where((b) => !b.isOldTestament).toList();
        final selected = _bookSlug == null
            ? null
            : books.firstWhere(
                (b) => b.slug == _bookSlug,
                orElse: () => books.first,
              );
        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            Text(
              'Browse the Bible',
              style: TextStyle(
                color: theme.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${app.chaptersRead} of $kTotalChapters chapters read',
              style: TextStyle(color: theme.textDim, fontSize: 12.5),
            ),
            if (app.recents.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in app.recents.take(6))
                    RefChip(
                      _shortLabel(r),
                      onTap: () => widget.onSelect(r),
                      icon: Icons.history,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (selected == null) ...[
              _BookGroup(
                title: 'OLD TESTAMENT',
                books: ot,
                app: app,
                onSelect: (slug) => setState(() => _bookSlug = slug),
              ),
              _BookGroup(
                title: 'NEW TESTAMENT',
                books: nt,
                app: app,
                onSelect: (slug) => setState(() => _bookSlug = slug),
              ),
            ] else ...[
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _bookSlug = null),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('All books'),
                  ),
                  const Spacer(),
                  Text(
                    selected.name,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var c = 1; c <= selected.chapterCount; c++)
                    _ChapterChip(
                      chapter: c,
                      read: app.isChapterRead(selected.slug, c),
                      current: app.lastRef.slug == selected.slug &&
                              app.lastRef.chapter == c
                          ? true
                          : false,
                      onTap: () => widget.onSelect(VerseRef(selected.slug, c)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  String _shortLabel(VerseRef r) => switch (r.slug) {
        'song_of_solomon' =>
          'Song of Solomon ${r.chapter}${r.verse > 0 ? ':${r.verse}' : ''}',
        _ => '${r.slug.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')} ${r.chapter}${r.verse > 0 ? ':${r.verse}' : ''}',
      };
}

class _BookGroup extends StatelessWidget {
  final String title;
  final List<BookInfo> books;
  final AppStore app;
  final ValueChanged<String> onSelect;

  const _BookGroup({
    required this.title,
    required this.books,
    required this.app,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
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
        for (final book in books)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(book.slug),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${book.id}',
                        style: TextStyle(
                          color: theme.textDim,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        book.name,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${book.chapterCount} ch',
                      style: TextStyle(
                        color: theme.textDim,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 54,
                      child: LinearProgressIndicator(
                        value: _bookProgress(book),
                        minHeight: 4,
                        backgroundColor: theme.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation(theme.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _bookProgress(BookInfo book) {
    if (book.chapterCount == 0) return 0;
    var read = 0;
    for (var c = 1; c <= book.chapterCount; c++) {
      if (app.isChapterRead(book.slug, c)) read += 1;
    }
    return read / book.chapterCount;
  }
}

class _ChapterChip extends StatelessWidget {
  final int chapter;
  final bool read;
  final bool current;
  final VoidCallback onTap;

  const _ChapterChip({
    required this.chapter,
    required this.read,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeOf(context);
    return Material(
      color: current
          ? theme.accentSoft
          : read
              ? theme.surfaceAlt
              : theme.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: current ? Border.all(color: theme.accent, width: 1.4) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$chapter',
            style: TextStyle(
              color: read ? theme.accent : theme.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TranslationSheet extends StatelessWidget {
  final VoidCallback onChanged;

  const _TranslationSheet({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    return SafeArea(
      child: AnimatedBuilder(
        animation: app,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Text(
              'Translation',
              style: TextStyle(
                color: theme.text,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'The full Bible is bundled offline for every version.',
              style: TextStyle(color: theme.textDim, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            for (final t in kTranslations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
                  color: t.code == app.translationCode
                      ? theme.accentSoft
                      : theme.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () {
                      app.setTranslation(t.code);
                      onChanged();
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          Container(
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
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.name,
                                  style: TextStyle(
                                    color: theme.text,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  t.desc,
                                  style: TextStyle(
                                    color: theme.textDim,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (t.code == app.translationCode)
                            Icon(Icons.check_circle,
                                color: theme.accent, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: app.compareOn,
              onChanged: (v) => app.setCompareOn(v),
              title: Text(
                'Parallel mode',
                style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Compare two translations side-by-side',
                style: TextStyle(color: theme.textDim, fontSize: 12),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: app.compareAll,
              onChanged: (v) {
                app.setCompareAll(v);
                onChanged();
              },
              title: Text(
                'Show all 5 translations',
                style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Stack KJV, NIV, NLT, NWT and the original text per verse',
                style: TextStyle(color: theme.textDim, fontSize: 12),
              ),
            ),
            if (app.compareOn) ...[
              const SizedBox(height: 4),
              Text(
                'Secondary translation',
                style: TextStyle(
                  color: theme.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in kTranslations)
                    if (t.code != app.translationCode)
                      ChoiceChip(
                        label: Text(t.short),
                        selected: app.compareCode == t.code,
                        onSelected: (_) {
                          app.setCompareCode(t.code);
                          onChanged();
                        },
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReaderSettingsSheet extends StatelessWidget {
  final VoidCallback onChanged;

  const _ReaderSettingsSheet({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = appThemeOf(context);
    return SafeArea(
      child: AnimatedBuilder(
        animation: app,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Text(
              'Reading settings',
              style: TextStyle(
                color: theme.text,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Text size — ${app.fontSize.round()}',
              style: TextStyle(color: theme.textDim, fontSize: 12.5),
            ),
            Row(
              children: [
                Icon(Icons.format_size, color: theme.textDim, size: 17),
                Expanded(
                  child: Slider(
                    value: app.fontSize,
                    min: 13,
                    max: 30,
                    divisions: 17,
                    onChanged: (v) => app.setFontSize(v),
                  ),
                ),
              ],
            ),
            Text(
              'Line height — ${app.lineHeight.toStringAsFixed(2)}',
              style: TextStyle(color: theme.textDim, fontSize: 12.5),
            ),
            Row(
              children: [
                Icon(Icons.vertical_align_center,
                    color: theme.textDim, size: 17),
                Expanded(
                  child: Slider(
                    value: app.lineHeight,
                    min: 1.3,
                    max: 2.2,
                    divisions: 9,
                    onChanged: (v) => app.setLineHeight(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Font',
              style: TextStyle(color: theme.textDim, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'serif', label: Text('Serif')),
                ButtonSegment(value: 'sans', label: Text('Sans')),
                ButtonSegment(value: 'mono', label: Text('Mono')),
              ],
              selected: {app.fontFamily},
              showSelectedIcon: false,
              onSelectionChanged: (v) {
                app.setFontFamily(v.first);
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: app.showVerseNumbers,
              onChanged: (v) => app.setShowVerseNumbers(v),
              title: const Text('Verse numbers'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: app.justifyText,
              onChanged: (v) => app.setJustify(v),
              title: const Text('Justified text'),
            ),
            const Divider(height: 28),
            Text(
              'THEME',
              style: TextStyle(
                color: theme.accent,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kAppThemes)
                  ChoiceChip(
                    avatar: Icon(t.icon, size: 16),
                    label: Text(t.label),
                    selected: app.themeId == t.id,
                    onSelected: (_) {
                      app.setTheme(t.id);
                      onChanged();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
