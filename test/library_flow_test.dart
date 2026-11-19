import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_library/library.dart';
import 'package:scripture_library/main.dart';
import 'package:scripture_library/reader.dart';

class TestStore extends LibraryStore {
  TestStore() : super(null);

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
  setUp(() => rootBundle.evict('assets/launch_library.json'));

  testWidgets('finds IAST titles through plain spelling and opens a source', (
    tester,
  ) async {
    await tester.pumpWidget(ScriptureApp(store: TestStore()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'isha upanishad');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Īśa Upaniṣad'));
    await tester.pumpAndSettle();
    expect(find.text('Open source website'), findsOneWidget);
  });

  testWidgets('pages, changes chapter and resumes at the saved passage', (
    tester,
  ) async {
    final store = TestStore();
    await tester.pumpWidget(ScriptureApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read sample'));
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
    expect(find.text('3.19'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue reading'));
    await tester.pumpAndSettle();
    expect(find.text('3.19'), findsOneWidget);
  });
}
