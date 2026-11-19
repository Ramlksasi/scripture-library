import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'library.dart';
import 'reader.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  FirebaseFirestore? db;
  if (projectId.isNotEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        projectId: projectId,
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
      ),
    );
    db = FirebaseFirestore.instance;
    const emulatorHost = String.fromEnvironment('FIRESTORE_EMULATOR_HOST');
    if (emulatorHost.isNotEmpty) {
      const port = int.fromEnvironment(
        'FIRESTORE_EMULATOR_PORT',
        defaultValue: 8080,
      );
      db.useFirestoreEmulator(emulatorHost, port);
    }
  }
  runApp(ScriptureApp(store: LibraryStore(db)));
}

class ScriptureApp extends StatelessWidget {
  const ScriptureApp({super.key, required this.store});

  final LibraryStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Scripture Library',
    debugShowCheckedModeBanner: false,
    theme: libraryTheme(),
    home: LibraryScreen(store: store),
  );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.store});

  final LibraryStore store;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  late Future<List<Book>> _books;
  ReadingPosition? _lastRead;

  @override
  void initState() {
    super.initState();
    _books = widget.store.loadBooks();
    _refreshLastRead();
  }

  Future<void> _refreshLastRead() async {
    try {
      final previous = await widget.store.lastRead();
      if (mounted) setState(() => _lastRead = previous);
    } on Exception {
      // The library can be opened without a saved position.
    }
  }

  Future<void> _openBook(Book book, {bool readDirectly = false}) async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => readDirectly
            ? ReaderScreen(book: book, store: widget.store)
            : BookScreen(book: book, store: widget.store),
      ),
    );
    await _refreshLastRead();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: FutureBuilder<List<Book>>(
              future: _books,
              builder: (context, snapshot) {
                final books = snapshot.data ?? [];
                final query = _search.text.trim();
                final categories = <String, List<Book>>{};
                for (final book in books) {
                  categories.putIfAbsent(book.category, () => []).add(book);
                }
                final names = categories.keys.toList()..sort();
                final results =
                    books.where((book) => book.matches(query)).toList()
                      ..sort((a, b) => a.title.compareTo(b.title));
                final hosted = books.where((book) => book.isHosted);
                final lastBook = hosted
                    .where(
                      (book) =>
                          book.id == _lastRead?.bookId &&
                          book.sections.any(
                            (section) => section.id == _lastRead?.sectionId,
                          ),
                    )
                    .firstOrNull;
                final featured = lastBook ?? hosted.firstOrNull;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                  children: [
                    const Text(
                      'Scripture Library',
                      style: TextStyle(
                        fontFamily: serif,
                        fontSize: 30,
                        color: ink,
                        letterSpacing: -0.9,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search scriptures',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (snapshot.connectionState != ConnectionState.done)
                      const Center(child: CircularProgressIndicator())
                    else if (snapshot.hasError)
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _books = widget.store.loadBooks()),
                          child: const Text('Reload library'),
                        ),
                      )
                    else if (query.isNotEmpty) ...[
                      if (results.isEmpty)
                        const Text('No scriptures match your search.'),
                      for (final book in results)
                        _BookTile(book: book, onTap: () => _openBook(book)),
                    ] else ...[
                      if (featured != null) ...[
                        _Featured(
                          book: featured,
                          resume: lastBook != null,
                          onTap: () => _openBook(featured, readDirectly: true),
                        ),
                        const SizedBox(height: 28),
                      ],
                      if (names.isEmpty)
                        const Text('The library has no published books yet.')
                      else ...[
                        const Text(
                          'Browse',
                          style: TextStyle(
                            fontFamily: serif,
                            fontSize: 23,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final name in names)
                          _CategoryTile(
                            name: name,
                            books: categories[name]!,
                            onTap: () async {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (context) => CategoryScreen(
                                    name: name,
                                    books: categories[name]!,
                                    onBook: _openBook,
                                  ),
                                ),
                              );
                              await _refreshLastRead();
                            },
                          ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Featured extends StatelessWidget {
  const _Featured({
    required this.book,
    required this.resume,
    required this.onTap,
  });

  final Book book;
  final bool resume;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caption = resume
        ? 'Continue reading'
        : (book.sample ? 'Read sample' : 'Read');
    return Material(
      color: const Color(0xFF223C32),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const _Cover(),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontFamily: serif,
                        fontSize: 24,
                        color: paper,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      caption,
                      style: const TextStyle(color: gold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: gold, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 62,
        height: 82,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFFAE7949),
          borderRadius: BorderRadius.circular(5),
          border: const Border(
            left: BorderSide(width: 4, color: Color(0xFF795534)),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 8,
              offset: Offset(3, 4),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE6C89E)),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Center(
            child: Icon(Icons.auto_stories_outlined, color: paper, size: 25),
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.name,
    required this.books,
    required this.onTap,
  });

  final String name;
  final List<Book> books;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 3),
          leading: const Icon(
            Icons.collections_bookmark_outlined,
            color: accent,
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${books.length}', style: const TextStyle(color: muted)),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({
    super.key,
    required this.name,
    required this.books,
    required this.onBook,
  });

  final String name;
  final List<Book> books;
  final ValueChanged<Book> onBook;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Book>>{};
    for (final book in books) {
      grouped.putIfAbsent(book.subcategory, () => []).add(book);
    }
    for (final group in grouped.values) {
      group.sort((a, b) => a.title.compareTo(b.title));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          name,
          style: const TextStyle(fontFamily: serif, fontSize: 18),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              for (final entry in grouped.entries) ...[
                if (entry.key.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
                    child: Text(
                      entry.key,
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ),
                for (final book in entry.value)
                  _BookTile(book: book, onTap: () => onBook(book)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 3),
        title: Text(
          book.title,
          style: const TextStyle(fontFamily: serif, fontSize: 17),
        ),
        trailing: Icon(
          book.isHosted ? Icons.chevron_right : Icons.open_in_new,
          size: 18,
          color: muted,
        ),
      ),
      const Divider(height: 1),
    ],
  );
}

class BookScreen extends StatelessWidget {
  const BookScreen({super.key, required this.book, required this.store});

  final Book book;
  final LibraryStore store;

  Future<void> _openSource(BuildContext context) async {
    try {
      if (await launchUrl(
        book.sourceUrl!,
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } on Exception {
      // Report a launch failure without trapping readers on this screen.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The source website could not be opened.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            children: [
              Text(book.category, style: const TextStyle(color: muted)),
              const SizedBox(height: 8),
              Text(
                book.title,
                style: const TextStyle(
                  fontFamily: serif,
                  fontSize: 32,
                  color: ink,
                ),
              ),
              const SizedBox(height: 24),
              if (book.isHosted)
                FilledButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (context) =>
                          ReaderScreen(book: book, store: store),
                    ),
                  ),
                  child: Text(book.sample ? 'Read sample' : 'Read'),
                ),
              if (book.sourceUrl != null)
                OutlinedButton.icon(
                  onPressed: () => _openSource(context),
                  icon: const Icon(Icons.open_in_new, size: 17),
                  label: Text(
                    book.sample ? 'Open full text' : 'Open source website',
                  ),
                ),
              if (book.sourceName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    book.sourceName,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ),
              if (book.credit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    book.credit,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
