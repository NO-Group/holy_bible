#!/usr/bin/env python3
"""One-time migration script that rebuilt this repo into a single
consistent JSON structure (kept for reference / provenance).

It consumed the original heterogeneous sources:
  - KJV/<Book>.json                 (per-book, string numbers)   [removed]
  - NIV/<Book with spaces>.json     (per-book, extra count key)  [removed]
  - bible/translations/nlt/<Book>_<n>.json  (flat per-chapter)   [removed]
  - NWT 2013 plain-text dump (from github.com/Witty-Kitty/ALP-MT,
    datasets/raw/english) parsed from /tmp/ALP-MT

and produced the current layout:
  bible/translations.json
  bible/translations/{code}/books.json
  bible/translations/{code}/{book_slug}/chapter_{n}.json

Chapter schema (identical for every translation):
{
  "translation": "KJV",
  "book": "Genesis",
  "book_id": 1,
  "chapter": 1,
  "verses": [ {"verse": 1, "text": "..."} ]
}
"""
import json
import os
import re
import shutil
import sys
import unicodedata

REPO = '/home/user/Holy_Bible'
OUT = os.path.join(REPO, 'bible')

# ---------------------------------------------------------------- canonical
BOOKS = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua",
    "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
    "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
    "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah",
    "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
    "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai",
    "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John", "Acts",
    "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
    "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
    "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James",
    "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation",
]
CHAPTER_COUNTS = [50, 40, 27, 36, 34, 24, 21, 4, 31, 24, 22, 25, 29, 36, 10,
                  13, 10, 42, 150, 31, 12, 8, 66, 52, 5, 48, 12, 14, 3, 9, 1,
                  4, 7, 3, 3, 3, 2, 14, 4, 28, 16, 24, 21, 28, 16, 16, 13, 6,
                  6, 4, 4, 5, 3, 6, 4, 3, 1, 13, 5, 5, 3, 5, 1, 1, 1, 22]
TESTAMENT = ['OT'] * 39 + ['NT'] * 27

assert len(BOOKS) == 66 and len(CHAPTER_COUNTS) == 66
assert sum(CHAPTER_COUNTS) == 1189


def slug(book):
    return book.lower().replace(' ', '_')


def clean(text):
    """Normalize verse text to clean, tag-free plain text.

    - NFC unicode normalization, nbsp -> space
    - strip embedded HTML: <br> becomes a space, <i>/<b> tags are dropped
      (their contents kept)  [present in the NLT source]
    - '`' used as an apostrophe becomes a right single quote
      [present in the NIV source]
    - collapse runs of whitespace
    """
    text = unicodedata.normalize('NFC', text)
    text = text.replace('\u00a0', ' ')            # nbsp -> space
    text = re.sub(r'<br\s*/?>', ' ', text)        # line breaks -> space
    text = re.sub(r'</?(?:i|b|em|strong)>', '', text)
    text = text.replace('`', '\u2019')            # backtick apostrophe
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def omitted(text):
    """True for placeholder/omitted verses (empty or dash-only).

    Modern translations (NIV, NLT, NWT) omit certain late-manuscript
    verses (e.g. Matthew 17:21, Acts 8:37); some sources mark them with
    '' or '\u2014\u2014'. We drop such placeholders so every translation
    consistently just skips omitted verse numbers.
    """
    return not text or not re.sub(r'[\u2014\u2013\u2012\u2010\-\s]', '', text)


# ---------------------------------------------------------------- loaders
def load_kjv():
    """KJV/<Book>.json : {book, chapters:[{chapter,'verses':[{verse,text}]}]}"""
    out = {}
    for i, book in enumerate(BOOKS):
        fname = book.replace(' ', '')
        path = os.path.join(REPO, 'KJV', f'{fname}.json')
        data = json.load(open(path, encoding='utf-8'))
        chapters = {}
        for ch in data['chapters']:
            cnum = int(ch['chapter'])
            chapters[cnum] = [(int(v['verse']), clean(v['text']))
                              for v in ch['verses']
                              if not omitted(clean(v['text']))]
        out[book] = chapters
    return out


def load_niv():
    """NIV/<Book with spaces>.json : same shape + count field."""
    out = {}
    for book in BOOKS:
        name = 'Song Of Solomon' if book == 'Song of Solomon' else book
        path = os.path.join(REPO, 'NIV', f'{name}.json')
        data = json.load(open(path, encoding='utf-8'))
        chapters = {}
        for ch in data['chapters']:
            cnum = int(ch['chapter'])
            chapters[cnum] = [(int(v['verse']), clean(v['text']))
                              for v in ch['verses']
                              if not omitted(clean(v['text']))]
        out[book] = chapters
    return out


def load_nlt():
    """bible/translations/nlt/<Book>_<n>.json : per-chapter files."""
    src = os.path.join(REPO, 'bible', 'translations', 'nlt')
    out = {}
    for book in BOOKS:
        stem = book.replace(' ', '_')
        chapters = {}
        for n in range(1, CHAPTER_COUNTS[BOOKS.index(book)] + 1):
            path = os.path.join(src, f'{stem}_{n}.json')
            data = json.load(open(path, encoding='utf-8'))
            chapters[n] = [(int(v['verse']), clean(v['text']))
                           for v in data['verses']
                           if not omitted(clean(v['text']))]
        out[book] = chapters
    return out


def load_nwt():
    """Parse NWT plain-text books (raw dump from the 2013 revision)."""
    src = '/tmp/ALP-MT/datasets/raw/english'
    files = sorted(os.listdir(src), key=lambda f: int(f.split('.')[0]))
    out = {}
    for f in files:
        num = int(f.split('.')[0])
        book = BOOKS[num - 1]
        lines = open(os.path.join(src, f), encoding='utf-8').read().splitlines()
        chapters = {}
        cur = None
        for ln in lines:
            ln = ln.rstrip()
            if not ln:
                continue
            m_ch = re.match(r'^(\d+) \xa0(.*)$', ln)        # chapter start
            m_v = re.match(r'^(\d+)\xa0[\xa0 ](.*)$', ln)    # verse line
            if m_ch:
                cur = int(m_ch.group(1))
                rest = m_ch.group(2)
                # chapter may open at a verse other than 1 (e.g. John 8:12,
                # because NWT omits John 7:53-8:11). Detect leading verse no.
                m_lead = re.match(r'^(\d+)\xa0[\xa0 ](.*)$', rest)
                if m_lead:
                    chapters[cur] = [(int(m_lead.group(1)),
                                      clean(m_lead.group(2)))]
                else:
                    chapters[cur] = [(1, clean(rest))]
            elif m_v:
                if cur is None:
                    cur = 1
                    chapters[cur] = []
                chapters[cur].append((int(m_v.group(1)), clean(m_v.group(2))))
            else:
                raise SystemExit(f'NWT parse error in {f}: {ln[:60]!r}')
        out[book] = {c: sorted((v, t) for v, t in vs if not omitted(t))
                     for c, vs in chapters.items()}
    return out


# ---------------------------------------------------------------- validation
def validate(code, data):
    errors = []
    if set(data) != set(BOOKS):
        errors.append(f'{code}: book set mismatch: '
                      f'missing={set(BOOKS) - set(data)} '
                      f'extra={set(data) - set(BOOKS)}')
    for i, book in enumerate(BOOKS):
        chapters = data.get(book, {})
        want = CHAPTER_COUNTS[i]
        if sorted(chapters) != list(range(1, want + 1)):
            errors.append(f'{code} {book}: chapters {sorted(chapters)[:3]}...'
                          f' expected 1..{want}')
            continue
        for cnum, verses in chapters.items():
            if not verses:
                errors.append(f'{code} {book} {cnum}: no verses')
                continue
            nums = [v for v, _ in verses]
            if len(nums) != len(set(nums)):
                errors.append(f'{code} {book} {cnum}: duplicate verse numbers')
            if nums != sorted(nums):
                errors.append(f'{code} {book} {cnum}: verses out of order')
            for v, t in verses:
                if not t:
                    errors.append(f'{code} {book} {cnum}:{v}: empty text')
    return errors


# ---------------------------------------------------------------- writer
def write_translation(code, name, data):
    root = os.path.join(OUT, 'translations', code)
    os.makedirs(root, exist_ok=True)
    books_index = []
    for i, book in enumerate(BOOKS):
        bslug = slug(book)
        bdir = os.path.join(root, bslug)
        os.makedirs(bdir, exist_ok=True)
        chapters = data[book]
        books_index.append({
            'id': i + 1,
            'name': book,
            'slug': bslug,
            'testament': TESTAMENT[i],
            'chapters': len(chapters),
            'verses': sum(len(v) for v in chapters.values()),
        })
        for cnum in sorted(chapters):
            payload = {
                'translation': code.upper(),
                'book': book,
                'book_id': i + 1,
                'chapter': cnum,
                'verses': [{'verse': v, 'text': t} for v, t in chapters[cnum]],
            }
            path = os.path.join(bdir, f'chapter_{cnum}.json')
            with open(path, 'w', encoding='utf-8') as fh:
                json.dump(payload, fh, ensure_ascii=False, indent=2)
                fh.write('\n')
    with open(os.path.join(root, 'books.json'), 'w', encoding='utf-8') as fh:
        json.dump({'translation': code.upper(), 'name': name,
                   'books': books_index}, fh, ensure_ascii=False, indent=2)
        fh.write('\n')


def main():
    translations = [
        ('kjv', 'King James Version', load_kjv),
        ('niv', 'New International Version', load_niv),
        ('nlt', 'New Living Translation', load_nlt),
        ('nwt', 'New World Translation (2013 Revision)', load_nwt),
    ]

    loaded = {}
    all_errors = []
    for code, name, loader in translations:
        print(f'loading {code}...')
        data = loader()
        errs = validate(code, data)
        all_errors += errs
        loaded[code] = (name, data)
        total_v = sum(len(v) for chs in data.values() for v in chs.values())
        print(f'  {code}: 66 books, '
              f'{sum(len(c) for c in data.values())} chapters, '
              f'{total_v} verses, {len(errs)} errors')

    if all_errors:
        print('\nVALIDATION ERRORS:')
        for e in all_errors[:50]:
            print(' ', e)
        sys.exit(1)

    # wipe old NLT flat layout before writing the new tree
    old_nlt = os.path.join(OUT, 'translations', 'nlt')
    if os.path.isdir(old_nlt):
        shutil.rmtree(old_nlt)

    for code, (name, data) in loaded.items():
        print(f'writing {code}...')
        write_translation(code, name, data)

    index = {
        'format_version': 1,
        'books': 66,
        'chapters_per_bible': 1189,
        'translations': [
            {'code': code, 'name': name,
             'path': f'translations/{code}',
             'books_index': f'translations/{code}/books.json',
             'chapter_path_pattern':
                 'translations/{code}/{book_slug}/chapter_{n}.json'
                 .replace('{code}', code)}
            for code, (name, _) in loaded.items()
        ],
    }
    with open(os.path.join(OUT, 'translations.json'), 'w',
              encoding='utf-8') as fh:
        json.dump(index, fh, ensure_ascii=False, indent=2)
        fh.write('\n')
    print('done.')


if __name__ == '__main__':
    main()
