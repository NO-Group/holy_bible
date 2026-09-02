#!/usr/bin/env python3
"""Add the 'original' translation: original-language manuscripts.

- Old Testament: Westminster Leningrad Codex (WLC) -- the Hebrew
  Masoretic Text (the oldest complete Hebrew Bible manuscript, dated
  1008 CE), remapped from Hebrew (BHS) versification to the KJV
  versification used across this dataset via the OpenHebrewBible
  BHSA->KJV mapping (github.com/eliranwong/OpenHebrewBible).
- New Testament: Textus Receptus (1550/1894) Greek text, which follows
  KJV versification natively.

Sources (JSON): github.com/scrollmapper/bible_databases
Expected inputs in /tmp/orig: WLC.json, TR.json, map.csv

The output uses the exact same layout & schema as the other
translations, with identical verse slots per chapter:
  bible/translations/original/books.json
  bible/translations/original/{book_slug}/chapter_{n}.json

Slot conventions (same as elsewhere):
  {"verse": n, "text": "..."}                 normal verse
  {"verse": n, "text": "", "omitted": true}   no counterpart in the
                                              manuscript tradition
  {"verse": n, "text": "", "merged_with": m}  Hebrew verse spans several
                                              KJV verse numbers; text is
                                              on verse m
"""
import json
import os
import re
import unicodedata
from collections import defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'bible'))
SRC = '/tmp/orig'

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
ALIAS = {
    "I Samuel": "1 Samuel", "II Samuel": "2 Samuel",
    "I Kings": "1 Kings", "II Kings": "2 Kings",
    "I Chronicles": "1 Chronicles", "II Chronicles": "2 Chronicles",
    "I Corinthians": "1 Corinthians", "II Corinthians": "2 Corinthians",
    "I Thessalonians": "1 Thessalonians",
    "II Thessalonians": "2 Thessalonians",
    "I Timothy": "1 Timothy", "II Timothy": "2 Timothy",
    "I Peter": "1 Peter", "II Peter": "2 Peter",
    "I John": "1 John", "II John": "2 John", "III John": "3 John",
    "Revelation of John": "Revelation",
}


def slug(book):
    return book.lower().replace(' ', '_')


def clean(text):
    text = unicodedata.normalize('NFC', text)
    text = text.replace('\u00a0', ' ')
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def load_source(fname):
    """scrollmapper format -> {canonical book name: {ch: {v: text}}}"""
    data = json.load(open(os.path.join(SRC, fname), encoding='utf-8'))
    out = {}
    for b in data['books']:
        name = ALIAS.get(b['name'], b['name'])
        chapters = {}
        for c in b['chapters']:
            verses = {v['verse']: clean(v['text'])
                      for v in c['verses'] if v['text'].strip()}
            if verses:
                chapters[c['chapter']] = verses
        if chapters:
            out[name] = chapters
    return out


def load_mapping():
    """KJV (book,ch,v) -> list of BHS (book,ch,v), canonical book numbers."""
    pat = re.compile(
        r'〔(\d+)｜(\d+)｜(\d+)｜(\d+)〕\t〔(\d*)｜?(\d*)｜?(\d*)｜?(\d*)〕')
    m = defaultdict(list)
    lines = open(os.path.join(SRC, 'map.csv'),
                 encoding='utf-8').read().splitlines()[1:]
    for ln in lines:
        if not ln.strip():
            continue
        g = pat.match(ln)
        if not g or not g.group(6):
            continue
        kb, kc, kv = int(g.group(2)), int(g.group(3)), int(g.group(4))
        bb, bc, bv = int(g.group(6)), int(g.group(7)), int(g.group(8))
        m[(kb, kc, kv)].append((bb, bc, bv))
    return m


def main():
    wlc = load_source('WLC.json')   # Hebrew OT (BHS versification)
    tr = load_source('TR.json')     # Greek NT (KJV versification)
    kjv_map = load_mapping()

    # BHS lookup: (book_no, ch, v) -> hebrew text
    bhs = {}
    for name, chapters in wlc.items():
        bno = BOOKS.index(name) + 1
        for c, verses in chapters.items():
            for v, t in verses.items():
                bhs[(bno, c, v)] = t

    # When several KJV verses map to ONE BHS verse, put the text on the
    # first KJV verse and mark the rest merged_with.
    bhs_first_kjv = {}
    for key in sorted(kjv_map):
        for tgt in kjv_map[key]:
            bhs_first_kjv.setdefault(tgt, key)

    code, tname = 'original', \
        'Original Manuscripts (Hebrew Masoretic Text / Greek Textus Receptus)'
    root = os.path.join(ROOT, 'translations', code)
    books_index = []
    stats = {'text': 0, 'omitted': 0, 'merged': 0}

    for i, book in enumerate(BOOKS):
        bno = i + 1
        is_ot = bno <= 39
        bslug = slug(book)
        bdir = os.path.join(root, bslug)
        os.makedirs(bdir, exist_ok=True)

        # replicate the exact verse slots of the existing dataset
        kjv_bdir = os.path.join(ROOT, 'translations', 'kjv', bslug)
        chapters = sorted(int(f.split('_')[1].split('.')[0])
                          for f in os.listdir(kjv_bdir)
                          if f.startswith('chapter_'))
        total = text_total = 0
        for n in chapters:
            ref = json.load(open(os.path.join(kjv_bdir, f'chapter_{n}.json'),
                                 encoding='utf-8'))
            verses = []
            for slot in ref['verses']:
                v = slot['verse']
                if is_ot:
                    targets = kjv_map.get((bno, n, v), [])
                    texts, merged_from = [], None
                    for tgt in targets:
                        if bhs_first_kjv.get(tgt) != (bno, n, v):
                            merged_from = bhs_first_kjv[tgt]
                            continue
                        if tgt in bhs:
                            texts.append(bhs[tgt])
                    if texts:
                        verses.append({'verse': v, 'text': ' '.join(texts)})
                        stats['text'] += 1
                    elif merged_from and merged_from[0] == bno \
                            and merged_from[1] == n:
                        verses.append({'verse': v, 'text': '',
                                       'merged_with': merged_from[2]})
                        stats['merged'] += 1
                    else:
                        verses.append({'verse': v, 'text': '',
                                       'omitted': True})
                        stats['omitted'] += 1
                else:
                    text = tr.get(book, {}).get(n, {}).get(v, '')
                    if text:
                        verses.append({'verse': v, 'text': text})
                        stats['text'] += 1
                    else:
                        verses.append({'verse': v, 'text': '',
                                       'omitted': True})
                        stats['omitted'] += 1
            payload = {
                'translation': code.upper(),
                'book': book,
                'book_id': bno,
                'chapter': n,
                'verses': verses,
            }
            with open(os.path.join(bdir, f'chapter_{n}.json'), 'w',
                      encoding='utf-8') as fh:
                json.dump(payload, fh, ensure_ascii=False, indent=2)
                fh.write('\n')
            total += len(verses)
            text_total += sum(1 for v in verses if v['text'])

        books_index.append({
            'id': bno,
            'name': book,
            'slug': bslug,
            'testament': 'OT' if is_ot else 'NT',
            'language': 'Hebrew' if is_ot else 'Greek',
            'chapters': len(chapters),
            'verses': total,
            'text_verses': text_total,
        })

    with open(os.path.join(root, 'books.json'), 'w', encoding='utf-8') as fh:
        json.dump({'translation': code.upper(), 'name': tname,
                   'books': books_index}, fh, ensure_ascii=False, indent=2)
        fh.write('\n')

    # register in the master index
    idx_path = os.path.join(ROOT, 'translations.json')
    idx = json.load(open(idx_path, encoding='utf-8'))
    idx['translations'] = [t for t in idx['translations']
                           if t['code'] != code]
    idx['translations'].append({
        'code': code,
        'name': tname,
        'path': f'translations/{code}',
        'books_index': f'translations/{code}/books.json',
        'chapter_path_pattern':
            f'translations/{code}/{{book_slug}}/chapter_{{n}}.json',
    })
    with open(idx_path, 'w', encoding='utf-8') as fh:
        json.dump(idx, fh, ensure_ascii=False, indent=2)
        fh.write('\n')

    print(f"original: text={stats['text']} omitted={stats['omitted']} "
          f"merged={stats['merged']} "
          f"total={sum(stats.values())}")


if __name__ == '__main__':
    main()
