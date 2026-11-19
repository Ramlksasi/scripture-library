import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Section {
  const Section(this.id, this.title);

  factory Section.fromJson(Map<String, dynamic> json) =>
      Section(json['id'] as String, json['title'] as String);

  final String id;
  final String title;
}

class Passage {
  const Passage(this.reference, this.roman, this.english);

  factory Passage.fromJson(Map<String, dynamic> json) {
    final passage = Passage(
      json['reference'] as String,
      json['roman'] as String,
      json['english'] as String,
    );
    if ([
      passage.reference,
      passage.roman,
      passage.english,
    ].any((value) => value.trim().isEmpty)) {
      throw const FormatException('Incomplete passage');
    }
    return passage;
  }

  final String reference;
  final String roman;
  final String english;
}

class Book {
  Book({
    required this.id,
    required this.title,
    required this.category,
    required this.subcategory,
    required this.sourceName,
    required this.sourceUrl,
    required this.editionId,
    required this.sample,
    required this.sections,
    required this.credit,
    required List<String> aliases,
  }) : searchIndex = normalize(
         [title, category, subcategory, ...aliases].join(' '),
       );

  factory Book.fromJson(String id, Map<String, dynamic> json) {
    final url = Uri.tryParse(json['sourceUrl'] as String? ?? '');
    final editionId = json['editionId'] as String?;
    final sections = (json['sections'] as List? ?? [])
        .map(
          (value) => Section.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
    final sourceUrl =
        url != null && url.scheme == 'https' && url.host.isNotEmpty
        ? url
        : null;
    if (editionId != null && sections.isEmpty ||
        editionId == null && sourceUrl == null) {
      throw const FormatException('Book requires readable content');
    }
    return Book(
      id: id,
      title: json['title'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      sourceName: json['sourceName'] as String? ?? '',
      sourceUrl: sourceUrl,
      editionId: editionId,
      sample: json['sample'] == true,
      sections: sections,
      credit: json['credit'] as String? ?? '',
      aliases: (json['aliases'] as List? ?? []).cast<String>(),
    );
  }

  final String id;
  final String title;
  final String category;
  final String subcategory;
  final String sourceName;
  final Uri? sourceUrl;
  final String? editionId;
  final bool sample;
  final List<Section> sections;
  final String credit;
  final String searchIndex;

  bool get isHosted => editionId != null;

  bool matches(String query) =>
      normalize(query).split(' ').every(searchIndex.contains);
}

String normalize(String value) {
  const plain = {
    'ā': 'a',
    'ī': 'i',
    'ū': 'u',
    'ē': 'e',
    'ō': 'o',
    'ṛ': 'r',
    'ṝ': 'r',
    'ḷ': 'l',
    'ḹ': 'l',
    'ṅ': 'n',
    'ñ': 'n',
    'ṇ': 'n',
    'ṭ': 't',
    'ḍ': 'd',
    'ś': 's',
    'ṣ': 's',
    'ḥ': 'h',
    'ṃ': 'm',
    'ṁ': 'm',
  };
  return value
      .toLowerCase()
      .replaceAllMapped(
        RegExp('[${plain.keys.join()}]'),
        (match) => plain[match[0]]!,
      )
      .replaceAll(RegExp(r'[\u0300-\u036F]'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

class ReadingPosition {
  const ReadingPosition(
    this.bookId,
    this.editionId,
    this.sectionId,
    this.reference,
  );

  static ReadingPosition? parse(String? value) {
    if (value == null) return null;
    final parts = value.split('|');
    return parts.length == 4
        ? ReadingPosition(parts[0], parts[1], parts[2], parts[3])
        : null;
  }

  final String bookId;
  final String editionId;
  final String sectionId;
  final String reference;

  String get encoded => [bookId, editionId, sectionId, reference].join('|');
}

class LibraryStore {
  LibraryStore(this.database);

  final FirebaseFirestore? database;
  late final _preferences = SharedPreferencesAsync();
  late final Future<Map<String, dynamic>> _bundle = rootBundle
      .loadString('assets/launch_library.json')
      .then((source) => jsonDecode(source) as Map<String, dynamic>);

  Future<List<Book>> loadBooks() async {
    final bundled = await _bundle;
    final db = database;
    if (db != null) {
      try {
        final snapshot = await db
            .collection('books')
            .where('published', isEqualTo: true)
            .get()
            .timeout(const Duration(seconds: 5));
        if (!snapshot.metadata.isFromCache || snapshot.docs.isNotEmpty) {
          final published = <Book>[];
          for (final doc in snapshot.docs) {
            try {
              published.add(Book.fromJson(doc.id, doc.data()));
            } on FormatException {
              continue;
            } on TypeError {
              continue;
            }
          }
          return published;
        }
      } on FirebaseException {
        // Use the bundled library if Firestore is temporarily unavailable.
      } on Exception {
        // A slow network should still leave the bundled reader accessible.
      }
    }
    return (bundled['books'] as List).map((item) {
      final json = item as Map<String, dynamic>;
      return Book.fromJson(json['id'] as String, json);
    }).toList();
  }

  Future<List<Passage>> loadSection(Book book, String sectionId) async {
    final editionId = book.editionId!;
    final sampleSections = (await _bundle)['sections'] as Map;
    final List? bundled =
        sampleSections[book.id]?[editionId]?[sectionId] as List?;
    final db = database;
    List<dynamic>? rows;
    if (db != null) {
      try {
        final snapshot = await db
            .collection('books')
            .doc(book.id)
            .collection('editions')
            .doc(editionId)
            .collection('sections')
            .doc(sectionId)
            .get()
            .timeout(const Duration(seconds: 8));
        rows = snapshot.data()?['passages'] as List?;
      } on Exception {
        if (bundled == null) rethrow;
      }
    }
    rows ??= bundled;
    if (rows == null || rows.isEmpty) {
      throw const FormatException('Empty section');
    }
    return rows
        .map((row) => Passage.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<ReadingPosition?> lastRead() async => ReadingPosition.parse(
    await _preferences.getString('lastReadingPosition'),
  );

  Future<ReadingPosition?> positionFor(Book book) async =>
      ReadingPosition.parse(
        await _preferences.getString('position-${book.id}'),
      );

  Future<void> savePosition(ReadingPosition position) async {
    await _preferences.setString(
      'position-${position.bookId}',
      position.encoded,
    );
    await _preferences.setString('lastReadingPosition', position.encoded);
  }

  Future<double> textSize() async =>
      await _preferences.getDouble('textSize') ?? 22;
  Future<void> saveTextSize(double value) =>
      _preferences.setDouble('textSize', value);
}
