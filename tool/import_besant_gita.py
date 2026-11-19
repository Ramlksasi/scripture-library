"""Import the numbered Sanskrit and English passages from Wikisource chapter HTML."""
import argparse
import json
from pathlib import Path
import re
from unicodedata import normalize

from bs4 import BeautifulSoup
from indic_transliteration import sanscript

BOOK_ID = 'HSC-0286'
EDITION_ID = 'besant-1922-v1'
VERSE_COUNTS = (47, 72, 43, 42, 29, 47, 30, 28, 34, 42, 55, 20, 35, 27, 20, 24, 28, 78)
DEVANAGARI_DIGITS = str.maketrans('०१२३४५६७८९', '0123456789')
VERSE_NUMBER = re.compile(r'॥\s*([०-९]+)\s*॥\s*$')
INVISIBLE = str.maketrans('', '', '\u200b\u200c\u200d\ufeff')
# The surrounding Sanskrit and English match at these positions. The English
# Wikisource number is blank twice and repeats the next verse number twice.
ENGLISH_LABELS = {(10, 31): '', (11, 8): '', (17, 19): '(20)', (18, 14): '(15)'}


def clean(text):
    return normalize('NFC', ' '.join(text.translate(INVISIBLE).split()))


def romanize(element):
    for br in element.find_all('br'):
        br.replace_with('\n')
    text = VERSE_NUMBER.sub('', element.get_text().strip())
    lines = [clean(line).rstrip('।').strip() for line in text.splitlines()]
    text = '\n'.join(line for line in lines if line)
    rendered = sanscript.transliterate(text, sanscript.DEVANAGARI, sanscript.IAST)
    if not rendered or re.search(r'[\u0900-\u097f]', rendered):
        raise ValueError(f'Incomplete Roman transliteration: {rendered!r}')
    return normalize('NFC', rendered)


def read_chapter(path, chapter):
    root = BeautifulSoup(path.read_bytes(), 'html.parser').select_one('.prp-pages-output')
    if root is None:
        raise ValueError(f'{path} has no transcribed chapter')
    for node in root.select('style, .pagenum, sup.reference'):
        node.decompose()

    verses = []
    roman = None
    english = []
    for block in root.find_all(recursive=False):
        matched_sanskrit = False
        if 'wst-block-center' in block.get('class', []):
            for element in block.select('[lang=sa]'):
                raw = element.get_text().strip()
                match = VERSE_NUMBER.search(raw)
                if not match or raw.startswith('इति श्रीमद्भगवद्गीता'):
                    continue
                number = int(match[1].translate(DEVANAGARI_DIGITS))
                if roman is not None or number != len(verses) + 1:
                    raise ValueError(f'{chapter}.{number}: unexpected Sanskrit verse')
                roman = romanize(element)
                matched_sanskrit = True
                break
        if matched_sanskrit:
            continue

        if roman is None:
            continue
        marker = block.select_one('.wst-floatright')
        if marker is not None:
            number = len(verses) + 1
            label = marker.get_text(strip=True)
            allowed_label = ENGLISH_LABELS.get((chapter, number), f'({number})')
            if label.strip('()') != allowed_label.strip('()'):
                raise ValueError(f'{chapter}.{number}: unexpected English label {label!r}')
            marker.decompose()
        if marker is not None or block.name == 'p' or 'wst-center' in block.get('class', []):
            for br in block.find_all('br'):
                br.replace_with('\n')
            paragraph = '\n'.join(line for text in block.get_text().splitlines() if (line := clean(text)))
            if paragraph:
                english.append(paragraph)
        if marker is not None:
            if not english:
                raise ValueError(f'{chapter}.{number}: English text is empty')
            verses.append({
                'reference': f'{chapter}.{number}',
                'roman': roman,
                'english': '\n'.join(english),
            })
            roman = None
            english = []

    if roman is not None or len(verses) != VERSE_COUNTS[chapter - 1]:
        raise ValueError(f'{chapter}: expected {VERSE_COUNTS[chapter - 1]}, found {len(verses)}')
    return verses


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('chapters', type=Path, help='Directory of Wikisource chapter-1.html through chapter-18.html')
    parser.add_argument('--manifest', type=Path, default=Path('assets/launch_library.json'))
    args = parser.parse_args()
    passages = {
        str(chapter): read_chapter(args.chapters / f'chapter-{chapter}.html', chapter)
        for chapter in range(1, 19)
    }
    manifest = json.loads(args.manifest.read_text(encoding='utf-8'))
    book = next(book for book in manifest['books'] if book['id'] == BOOK_ID)
    book.update(
        editionId=EDITION_ID,
        sourceName='English Wikisource',
        sourceUrl='https://en.wikisource.org/wiki/Bhagavad-Gita_(Besant_4th)',
        credit='English translation by Annie Besant (1922, fourth edition). Sanskrit and English transcribed by Wikisource contributors. Sanskrit rendered in Roman letters for this edition.',
        sections=[{'id': chapter, 'title': f'Chapter {chapter}'} for chapter in passages],
    )
    book.pop('sample', None)
    manifest['sections'][BOOK_ID] = {EDITION_ID: passages}
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Imported {sum(map(len, passages.values()))} aligned verses across {len(passages)} chapters')


if __name__ == '__main__':
    main()
