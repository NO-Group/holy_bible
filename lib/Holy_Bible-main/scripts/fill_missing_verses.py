#!/usr/bin/env python3
"""Fill missing verse numbers so every translation has identical,
continuous verse numbering per chapter.

Three cases are handled:

1. Omitted verses -- modern translations (NIV, NLT, NWT) omit certain
   late-manuscript verses (e.g. Matthew 17:21, Acts 8:37, and in NWT
   Mark 16:9-20 / John 7:53-8:11). These get a placeholder entry:
       {"verse": n, "text": "", "omitted": true}

2. Merged ranges -- the NLT combines some verses into one entry whose
   text starts with "[a-b] ". The prefix is stripped, the text stays on
   verse `a`, and verses a+1..b get:
       {"verse": n, "text": "", "merged_with": a}

3. Versification extras -- a few verses exist in some translations only
   (3 John 1:15 in NIV/NLT, Revelation 12:18 in NLT). Translations that
   fold that content into a neighbouring verse get an omitted
   placeholder so the union numbering stays aligned everywhere.

After this pass every chapter file contains the same set of verse
numbers in every translation, and books.json counts are updated
(`verses` = total entries incl. placeholders, `text_verses` = entries
with actual text).
"""
import json
import os
import re
from collections import defaultdict

ROOT = os.path.join(os.path.dirname(__file__), '..', 'bible')
ROOT = os.path.abspath(ROOT)

RANGE_RE = re.compile(r'^\[(\d+)-(\d+)\]\s*(.*)$')


def load_index():
    return json.load(open(os.path.join(ROOT, 'translations.json'),
                          encoding='utf-8'))


def chapter_path(code, slug, n):
    return os.path.join(ROOT, 'translations', code, slug,
                        f'chapter_{n}.json')


def main():
    idx = load_index()
    codes = [t['code'] for t in idx['translations']]
    books = json.load(open(os.path.join(
        ROOT, 'translations', codes[0], 'books.json'),
        encoding='utf-8'))['books']

    # ---------------- pass 1: load everything, expand NLT merged ranges
    # data[code][(slug, ch)] = list of verse dicts
    data = {c: {} for c in codes}
    merged_report = []
    for code in codes:
        for b in books:
            for n in range(1, b['chapters'] + 1):
                d = json.load(open(chapter_path(code, b['slug'], n),
                                   encoding='utf-8'))
                verses = []
                for v in d['verses']:
                    m = RANGE_RE.match(v['text'])
                    if m:
                        a, z, text = int(m.group(1)), int(m.group(2)), \
                            m.group(3).strip()
                        first = min(a, v['verse'])
                        verses.append({'verse': first, 'text': text})
                        for extra in range(first + 1, z + 1):
                            verses.append({'verse': extra, 'text': '',
                                           'merged_with': first})
                        merged_report.append(
                            f"{code} {b['name']} {n}:{a}-{z}")
                    else:
                        verses.append(dict(v))
                data[code][(b['slug'], n)] = verses

    print(f'expanded {len(merged_report)} merged ranges '
          f'({merged_report[0]} ... {merged_report[-1]})')

    # ---------------- pass 2: union verse set per chapter, fill gaps
    filled = defaultdict(int)
    for b in books:
        for n in range(1, b['chapters'] + 1):
            key = (b['slug'], n)
            union = set()
            for code in codes:
                union |= {v['verse'] for v in data[code][key]}
            full = set(range(1, max(union) + 1)) | union
            for code in codes:
                have = {v['verse'] for v in data[code][key]}
                for miss in sorted(full - have):
                    data[code][key].append(
                        {'verse': miss, 'text': '', 'omitted': True})
                    filled[code] += 1
                data[code][key].sort(key=lambda v: v['verse'])
                # continuity check
                nums = [v['verse'] for v in data[code][key]]
                assert nums == list(range(1, len(nums) + 1)), \
                    f'{code} {key}: not continuous'

    for code in codes:
        print(f'{code}: filled {filled[code]} placeholder verses')

    # ---------------- pass 3: write chapters + refresh books.json
    for t in idx['translations']:
        code = t['code']
        bidx_path = os.path.join(ROOT, 'translations', code, 'books.json')
        bidx = json.load(open(bidx_path, encoding='utf-8'))
        for b in bidx['books']:
            total = text_total = 0
            for n in range(1, b['chapters'] + 1):
                verses = data[code][(b['slug'], n)]
                total += len(verses)
                text_total += sum(1 for v in verses if v['text'])
                path = chapter_path(code, b['slug'], n)
                payload = json.load(open(path, encoding='utf-8'))
                payload['verses'] = verses
                with open(path, 'w', encoding='utf-8') as fh:
                    json.dump(payload, fh, ensure_ascii=False, indent=2)
                    fh.write('\n')
            b['verses'] = total
            b['text_verses'] = text_total
        with open(bidx_path, 'w', encoding='utf-8') as fh:
            json.dump(bidx, fh, ensure_ascii=False, indent=2)
            fh.write('\n')
        print(f'{code}: books.json refreshed')

    print('done.')


if __name__ == '__main__':
    main()
