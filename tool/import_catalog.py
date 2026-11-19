"""Convert the Scripture Catalogue worksheet to editorial JSON."""
import argparse
import json
from pathlib import Path

import openpyxl

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('workbook', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()

fields = ('id', 'category', 'subcategory', 'title', 'recordType', 'parent',
          'originalLanguage', 'phase', 'acquisitionStatus', 'notes', 'researchUrl')
workbook = openpyxl.load_workbook(args.workbook, read_only=True, data_only=True)
rows = workbook['Scripture Catalogue'].values
header = next(rows)
if header[:4] != ('ID', 'Category', 'Subcategory', 'Title'):
    raise ValueError('The Scripture Catalogue worksheet has unexpected columns')

catalog = [dict(zip(fields, row)) for row in rows if row[0]]
if len({book['id'] for book in catalog}) != len(catalog):
    raise ValueError('Duplicate catalog ID')
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Exported {len(catalog)} candidate entries')
