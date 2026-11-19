"""Validate and publish a library manifest with Firestore admin credentials."""
import argparse
import json
from pathlib import Path
from urllib.parse import urlsplit


def require(condition, message):
    if not condition:
        raise ValueError(message)


def valid_id(value):
    return isinstance(value, str) and value not in ('', '.', '..') and all(
        char not in value for char in '/|'
    )


def validate(manifest):
    books = manifest['books']
    content = manifest['sections']
    seen_books = set()
    for book in books:
        book_id = book['id']
        require(valid_id(book_id) and book_id not in seen_books, f'Invalid book ID: {book_id}')
        seen_books.add(book_id)
        for field in ('title', 'category'):
            require(book[field].strip(), f'{book_id} needs {field}')
        require(isinstance(book['subcategory'], str), f'{book_id} needs a subcategory')
        url = urlsplit(book.get('sourceUrl', ''))
        has_link = url.scheme == 'https' and bool(url.hostname)
        edition = book.get('editionId')
        if not edition:
            require(has_link, f'{book_id} needs a reading link')
            continue
        require(valid_id(edition), f'{book_id} has an invalid edition ID')
        require(book.get('credit', '').strip(), f'{book_id} needs an edition credit')
        sections = book['sections']
        data = content[book_id][edition]
        ids = [section['id'] for section in sections]
        require(sections and set(ids) == set(data) and len(ids) == len(data),
                f'{book_id} has an invalid section manifest')
        references = set()
        for section in sections:
            section_id = section['id']
            require(valid_id(section_id) and section['title'].strip(),
                    f'{book_id} has an invalid section')
            passages = data[section_id]
            require(isinstance(passages, list) and passages,
                    f'{book_id}/{section_id} has no passages')
            require(len(json.dumps(passages, ensure_ascii=False).encode()) < 600 * 1024,
                    f'{book_id}/{section_id} is too large. Split it into shorter sections.')
            for passage in passages:
                require(all(passage[key].strip() for key in ('reference', 'roman', 'english')),
                        f'{book_id}/{section_id} has an incomplete passage')
                reference = passage['reference']
                require(valid_id(reference) and reference not in references,
                        f'{book_id} has an invalid or duplicate reference: {reference}')
                references.add(reference)


def publish(manifest, project):
    from google.api_core.exceptions import AlreadyExists
    from google.cloud import firestore

    def create_once(document, data):
        try:
            document.create(data)
        except AlreadyExists:
            if document.get().to_dict() != data:
                raise ValueError(f'{document.path} changed. Publish with a new edition ID.')

    database = firestore.Client(project=project)
    for entry in manifest['books']:
        payload = dict(entry)
        book_id = payload.pop('id')
        book = database.collection('books').document(book_id)
        edition_id = payload.get('editionId')
        if edition_id:
            edition = book.collection('editions').document(edition_id)
            passages_by_section = manifest['sections'][book_id][edition_id]
            for section_id, passages in passages_by_section.items():
                doc = edition.collection('sections').document(section_id)
                create_once(doc, {'passages': passages})
            create_once(edition, {'credit': payload['credit'], 'sections': payload['sections']})
        # Public clients can read the edition only after the book points to it.
        book.set(payload)
        print(f'Wrote {book_id}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, default=Path('assets/launch_library.json'))
    parser.add_argument('--project', help='Explicit Firestore project ID')
    parser.add_argument('--apply', action='store_true', help='Write validated entries')
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding='utf-8'))
    validate(manifest)
    print(f"Validated {len(manifest['books'])} book entries")
    if args.apply:
        if not args.project:
            parser.error('--apply requires --project')
        publish(manifest, args.project)


if __name__ == '__main__':
    main()
