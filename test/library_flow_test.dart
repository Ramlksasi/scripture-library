import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_library/library.dart';
import 'package:scripture_library/main.dart';
import 'package:scripture_library/reader.dart';

class TestAssets extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class TestStore extends LibraryStore {
  TestStore() : super(null, assets: TestAssets());

  ReadingPosition? saved;

  @override
  Future<ReadingPosition?> lastRead() async => saved;

  @override
  Future<ReadingPosition?> positionFor(Book book) async =>
      saved?.bookId == book.id ? saved : null;

  @override
  Future<void> savePosition(ReadingPosition position) async => saved = position;

  @override
  Future<double> textSize() async => 22;
}

void main() {
  Future<void> openLibrary(WidgetTester tester, TestStore store) async {
    await tester.pumpWidget(ScriptureApp(store: store));
    await tester.pumpAndSettle();
  }

  test(
    'loads the complete Besant edition with consecutive verse references',
    () async {
      final store = TestStore();
      final book = (await store.loadBooks()).singleWhere(
        (book) => book.id == 'HSC-0286',
      );
      expect(book.sections, hasLength(18));
      var total = 0;
      for (final section in book.sections) {
        final verses = await store.loadSection(book, section.id);
        expect(
          verses.map((verse) => verse.reference),
          List.generate(verses.length, (index) => '${section.id}.${index + 1}'),
        );
        total += verses.length;
      }
      expect(total, 701);
    },
  );

  testWidgets('finds IAST titles through plain spelling and opens a source', (
    tester,
  ) async {
    await openLibrary(tester, TestStore());
    await tester.enterText(find.byType(TextField), 'isha upanishad');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Īśa Upaniṣad'));
    await tester.pumpAndSettle();
    expect(find.text('Open source website'), findsOneWidget);
  });

  testWidgets('pages, changes chapter and resumes at the saved passage', (
    tester,
  ) async {
    final store = TestStore()
      ..saved = const ReadingPosition(
        'HSC-0286',
        'reading-sample-v1',
        '2',
        '2.47',
      );
    await openLibrary(tester, store);
    await tester.tap(find.text('Continue reading'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(find.text('2.47'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-550, 0));
    await tester.pumpAndSettle();
    expect(find.text('2.48'), findsOneWidget);

    await tester.tap(find.byTooltip('Chapters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chapter 3'));
    await tester.pumpAndSettle();
    expect(find.text('3.1'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue reading'));
    await tester.pumpAndSettle();
    expect(find.text('3.1'), findsOneWidget);
  });

  testWidgets(
    'swipes between the final and first verses of neighboring chapters',
    (tester) async {
      final store = TestStore()
        ..saved = const ReadingPosition(
          'HSC-0286',
          'besant-1922-v1',
          '1',
          '1.47',
        );
      await openLibrary(tester, store);
      await tester.tap(find.text('Continue reading'));
      await tester.pumpAndSettle();
      expect(find.text('1.47'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-160, 0));
      await tester.pumpAndSettle();
      expect(find.text('2.1'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(find.text('1.47'), findsOneWidget);
    },
  );
}
