import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'library.dart';
import 'theme.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book, required this.store});

  final Book book;
  final LibraryStore store;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  PageController? _controller;
  List<Passage> _passages = [];
  int _section = 0;
  int _page = 0;
  int _request = 0;
  double _textSize = 22;
  double _chapterOverscroll = 0;
  bool _controls = true;
  bool _loading = true;
  bool _failed = false;
  Future<void> _writing = Future<void>.value();

  Book get _book => widget.book;
  LibraryStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    ReadingPosition? previous;
    try {
      previous = await _store.positionFor(_book);
      _textSize = await _store.textSize();
    } on Exception {
      // Reading is available if local settings cannot be opened.
    }
    if (!mounted) return;
    final resume = previous?.bookId == _book.id ? previous : null;
    final section = _book.sections.indexWhere(
      (item) => item.id == resume?.sectionId,
    );
    await _openSection(section < 0 ? 0 : section, reference: resume?.reference);
  }

  Future<void> _openSection(
    int index, {
    String? reference,
    bool last = false,
  }) async {
    final request = ++_request;
    setState(() {
      _section = index;
      _loading = true;
      _failed = false;
    });
    try {
      final passages = await _store.loadSection(
        _book,
        _book.sections[index].id,
      );
      if (!mounted || request != _request) return;
      final found = passages.indexWhere(
        (passage) => passage.reference == reference,
      );
      final page = last ? passages.length - 1 : (found < 0 ? 0 : found);
      final oldController = _controller;
      setState(() {
        _controller = PageController(initialPage: page);
        _passages = passages;
        _page = page;
        _loading = false;
      });
      if (oldController != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => oldController.dispose(),
        );
      }
      _savePage(page);
    } on Exception {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _savePage(int page) {
    final position = ReadingPosition(
      _book.id,
      _book.editionId!,
      _book.sections[_section].id,
      _passages[page].reference,
    );
    _writing = _writing
        .then((_) => _store.savePosition(position))
        .catchError((Object _) {});
  }

  void _turn(int direction) {
    final target = _page + direction;
    if (target < 0 && _section > 0) {
      unawaited(_openSection(_section - 1, last: true));
    } else if (target == _passages.length &&
        _section < _book.sections.length - 1) {
      unawaited(_openSection(_section + 1));
    } else if (target >= 0 && target < _passages.length) {
      unawaited(
        _controller!.animateToPage(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  bool _handlePageScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _chapterOverscroll = 0;
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      _chapterOverscroll += notification.overscroll;
    } else if (notification is ScrollEndNotification &&
        _chapterOverscroll.abs() >= 40) {
      final direction = _chapterOverscroll.isNegative ? -1 : 1;
      _chapterOverscroll = 0;
      final atBoundary = direction < 0
          ? _page == 0 && _section > 0
          : _page == _passages.length - 1 &&
                _section < _book.sections.length - 1;
      if (atBoundary) {
        final request = _request;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_loading && request == _request) {
            _turn(direction);
          }
        });
      }
    }
    return false;
  }

  Future<void> _pickChapter() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'Chapters',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            for (final (index, item) in _book.sections.indexed)
              ListTile(
                title: Text(item.title),
                selected: _section == index,
                trailing: _section == index ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, index),
              ),
          ],
        ),
      ),
    );
    if (mounted && selected != null && selected != _section) {
      await _openSection(selected);
    }
  }

  Future<void> _pickSize() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(
              children: [
                const Text('Text size'),
                Expanded(
                  child: Slider(
                    value: _textSize.clamp(16, 34).toDouble(),
                    min: 16,
                    max: 34,
                    divisions: 9,
                    label: _textSize.round().toString(),
                    onChanged: (value) {
                      setState(() => _textSize = value);
                      setSheetState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await _store.saveTextSize(_textSize);
    } on Exception {
      // The size still applies to this reading session.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = _book.sections[_section];
    final ready = !_loading && !_failed;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Visibility(
                visible: _controls,
                child: Row(
                  children: [
                    const BackButton(),
                    Expanded(
                      child: Text(
                        _book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: serif, fontSize: 17),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chapters',
                      onPressed: ready ? _pickChapter : null,
                      icon: const Icon(Icons.format_list_bulleted_rounded),
                    ),
                    IconButton(
                      tooltip: 'Text size',
                      onPressed: ready ? _pickSize : null,
                      icon: const Icon(Icons.text_fields_rounded),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            Expanded(
              child: switch ((_loading, _failed)) {
                (true, _) => const Center(child: CircularProgressIndicator()),
                (_, true) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('This section could not be loaded.'),
                      TextButton(
                        onPressed: () => _openSection(_section),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
                _ => NotificationListener<ScrollNotification>(
                  onNotification: _handlePageScroll,
                  child: PageView.builder(
                    physics: const ClampingScrollPhysics(),
                    key: ValueKey(section.id),
                    controller: _controller,
                    itemCount: _passages.length,
                    onPageChanged: (page) {
                      setState(() => _page = page);
                      _savePage(page);
                    },
                    itemBuilder: (context, page) {
                      final passage = _passages[page];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _controls = !_controls),
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 540,
                                      ),
                                      child: _PassagePage(
                                        passage: passage,
                                        section: section.title,
                                        textSize: _textSize,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      );
                    },
                  ),
                ),
              },
            ),
            SizedBox(
              height: 56,
              child: Visibility(
                visible: ready && _controls,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Previous passage',
                      onPressed: _section > 0 || _page > 0
                          ? () => _turn(-1)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    if (ready)
                      Text(
                        _passages[_page].reference,
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                    IconButton(
                      tooltip: 'Next passage',
                      onPressed:
                          _section < _book.sections.length - 1 ||
                              _page < _passages.length - 1
                          ? () => _turn(1)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassagePage extends StatelessWidget {
  const _PassagePage({
    required this.passage,
    required this.section,
    required this.textSize,
  });

  final Passage passage;
  final String section;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section, style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 22),
          Text(
            passage.roman,
            style: TextStyle(
              color: ink,
              fontFamily: serif,
              fontSize: textSize,
              height: 1.64,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: SizedBox(width: 38, child: Divider(thickness: 1)),
          ),
          Text(
            passage.english,
            style: TextStyle(
              color: ink,
              fontFamily: serif,
              fontSize: textSize * 0.88,
              height: 1.62,
            ),
          ),
        ],
      ),
    );
  }
}
