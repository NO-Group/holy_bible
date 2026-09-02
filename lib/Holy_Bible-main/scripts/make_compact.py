#!/usr/bin/env python3
"""Generate one compact JSON file per translation for fast loading
(search, quiz, offline apps):

  bible/translations/{code}/all.min.json

Format (minimal size; verse numbers are implicit — index + 1 — which is
safe because every chapter has continuous verse numbering 1..N):

{
  "translation": "KJV",
  "name": "King James Version",
  "books": [
    {"id": 1, "name": "Genesis", "slug": "genesis",
     "chapters": [ ["verse 1 text", "verse 2 text", ...], ... ]}
  ]
}

Placeholder slots (omitted/merged verses) are empty strings "".
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'bible'))


def main():
    idx = json.load(open(os.path.join(ROOT, 'translations.json'),
                         encoding='utf-8'))
    for t in idx['translations']:
        code = t['code']
        bi = json.load(open(os.path.join(ROOT, 'translations', code,
                                         'books.json'), encoding='utf-8'))
        books = []
        for b in bi['books']:
            chapters = []
            for n in range(1, b['chapters'] + 1):
                d = json.load(open(os.path.join(
                    ROOT, 'translations', code, b['slug'],
                    f'chapter_{n}.json'), encoding='utf-8'))
                chapters.append([v['text'] for v in d['verses']])
            books.append({'id': b['id'], 'name': b['name'],
                          'slug': b['slug'], 'chapters': chapters})
        out = {'translation': bi['translation'], 'name': bi['name'],
               'books': books}
        path = os.path.join(ROOT, 'translations', code, 'all.min.json')
        with open(path, 'w', encoding='utf-8') as fh:
            json.dump(out, fh, ensure_ascii=False, separators=(',', ':'))
        print(f'{code}: {os.path.getsize(path) / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
