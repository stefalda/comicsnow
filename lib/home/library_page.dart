import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_services.dart';
import '../comic/app_storage.dart';
import '../comic/comic_archive_reader.dart';
import '../comic/page_repository.dart';
import '../domain/comic.dart';
import '../domain/recent_comic.dart';
import '../platform/open_with.dart';
import '../reader/panel_reader_page.dart';

/// Landing screen: the library of recently opened comics, plus opening a new
/// archive.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.services});

  final AppServices services;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _reader = ComicArchiveReader(documentsDirectory: appStorageDirectory);

  bool _busy = false;
  String? _error;

  /// Progress of the current extraction, when the reader reports it.
  (int done, int total)? _progress;

  List<RecentComic> _recents = const [];
  bool _loadingRecents = true;

  /// Files the OS asks us to open ("Apri con", Files, doppio clic).
  StreamSubscription<String>? _openWith;

  @override
  void initState() {
    super.initState();
    unawaited(_reloadRecents());

    // Subscribe before initializing: the stream buffers what arrives while the
    // app is still starting, and only one listener is expected.
    _openWith = OpenWith.incoming.listen((path) => unawaited(_openIncoming(path)));
    unawaited(OpenWith.initialize());
  }

  @override
  void dispose() {
    unawaited(_openWith?.cancel());
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Library
  // ---------------------------------------------------------------------------

  Future<void> _reloadRecents() async {
    final recents = await widget.services.recentComics.list();
    if (!mounted) return;
    setState(() {
      _recents = recents;
      _loadingRecents = false;
    });
  }

  int? _lastPageOf(RecentComic recent) =>
      widget.services.settings.readPage(recent.id);

  Future<void> _openRecent(RecentComic recent) async {
    setState(() {
      _error = null;
      _busy = true;
      _progress = null;
    });

    try {
      // Reopening is instant while the pages are still extracted; if the OS
      // cleared them, the app rebuilds them from its own copy of the archive.
      final comic = await _reader.reopen(
        recent.id,
        title: recent.title,
        archivePath: recent.archivePath,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() => _progress = (done, total));
        },
      );

      if (!mounted) return;
      if (comic == null) {
        setState(
          () => _error =
              '«${recent.title}» non è più disponibile: non c’è più né la copia '
              'dell’archivio né le pagine estratte. Riapri il file.',
        );
        return;
      }

      await _openReader(comic);
    } catch (error, stackTrace) {
      debugPrint('ComicsNow: reopen failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _error = 'Impossibile riaprire «${recent.title}»: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _removeRecent(RecentComic recent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rimuovere «${recent.title}»?'),
        content: const Text(
          'Viene rimossa dalla libreria e le pagine estratte vengono '
          'eliminate. Il file originale non viene toccato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _reader.removeComic(recent.id, archivePath: recent.archivePath);
    await widget.services.coverCache.remove(recent.id);
    await widget.services.settings.clearPage(recent.id);
    await widget.services.recentComics.remove(recent.id);
    await _reloadRecents();
  }

  // ---------------------------------------------------------------------------
  // Opening a file
  // ---------------------------------------------------------------------------

  /// No type filter on purpose.
  ///
  /// Both `file_selector` and `file_picker` filter macOS by `UTType`, and
  /// `.cbz`/`.cbr` have no system UTI, so those files would be greyed out and
  /// unselectable. On Android the filter maps extensions to MIME types, which
  /// drops `cbz`/`cbr` the same way. The archive is validated by magic number
  /// in [ComicArchiveReader] anyway.
  Future<void> _openComic() async {
    setState(() => _error = null);

    final String? path;
    try {
      // file_picker copies the picked file to the app cache with streams and
      // returns only its path. file_selector read the whole file into memory to
      // return its bytes, which OOMs on a large CBZ.
      final file = await FilePicker.pickFile();
      path = file?.path;
      debugPrint('ComicsNow: file picker returned: $path');
    } catch (error, stackTrace) {
      debugPrint('ComicsNow: file picker failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _error = 'Selettore file non disponibile: $error');
      }
      return;
    }

    if (path == null || path.isEmpty) return;
    await _load(File(path), fromPicker: true);
  }

  /// Opens a file the system handed us ("Apri con", Files, doppio clic).
  ///
  /// The platform side already copied it into the app container, so this is a
  /// normal path; the archive reader takes the copy over from here.
  Future<void> _openIncoming(String path) async {
    debugPrint('ComicsNow: apertura richiesta dal sistema: $path');
    await _load(File(path));
  }

  Future<void> _openByPath() async {
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apri da percorso'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '/Users/.../fumetto.cbz',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Apri'),
          ),
        ],
      ),
    );

    if (path == null || path.trim().isEmpty) return;
    await _load(File(path.trim()));
  }

  /// Removes the copy the file picker made in the app cache.
  ///
  /// Only used when [ComicArchiveReader] could not take ownership of it: that
  /// copy is dead weight — hundreds of megabytes for a big archive — once the
  /// pages are extracted and the archive is stored by the library.
  Future<void> _deletePickerCopy(File file) async {
    try {
      final tempDirectory = await getTemporaryDirectory();
      if (!p.isWithin(tempDirectory.path, file.path)) return;
      await file.delete();
      debugPrint('ComicsNow: removed picker cache copy ${file.path}');
    } catch (_) {
      // Best effort: a leftover cache file is harmless.
    }
  }

  Future<void> _load(File file, {bool fromPicker = false}) async {
    if (!mounted) return;

    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });

    try {
      if (!await file.exists()) {
        throw FileSystemException('File non trovato', file.path);
      }

      final stopwatch = Stopwatch()..start();
      final comic = await _reader.read(
        file,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() => _progress = (done, total));
        },
      );
      debugPrint(
        'ComicsNow: ${comic.pages.length} pagine pronte in '
        '${stopwatch.elapsedMilliseconds}ms',
      );

      if (comic.pages.isEmpty) {
        throw const FormatException('Nessuna immagine trovata nell’archivio');
      }

      await widget.services.recentComics.touch(
        id: comic.id,
        title: comic.title,
        pageCount: comic.pages.length,
        archivePath: comic.sourcePath,
      );
      // The cover is nice to have: generate it in the background.
      unawaited(_storeCover(comic));

      // The reader moves the picker's copy into the app storage; if that failed
      // the temporary copy is still there and can go.
      if (fromPicker && p.isWithin((await getTemporaryDirectory()).path, file.path)) {
        await _deletePickerCopy(file);
      }

      await _openReader(comic);
    } catch (error, stackTrace) {
      debugPrint('ComicsNow: open failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _error = 'Impossibile aprire il file: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  /// Renders the cover of the first page and stores it in the library.
  Future<void> _storeCover(Comic comic) async {
    if (comic.pages.isEmpty) return;

    final coverPath = await widget.services.coverCache.store(
      comicId: comic.id,
      pagePath: comic.pages.first.imagePath,
    );
    if (coverPath == null) return;

    await widget.services.recentComics.touch(
      id: comic.id,
      title: comic.title,
      pageCount: comic.pages.length,
      coverPath: coverPath,
    );
    await _reloadRecents();
  }

  Future<void> _openReader(Comic comic) async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PanelReaderPage(
          repository: PageRepository(comic),
          queue: widget.services.analysisQueue,
          imageLoader: widget.services.imageLoader,
          direction: widget.services.readingDirection,
          initialPageIndex: widget.services.settings.readPage(comic.id) ?? 0,
          initialMode: widget.services.settings.readMode(),
          onModeChanged: widget.services.settings.writeMode,
          initialPreferences: widget.services.settings.readPreferences(),
          onPreferencesChanged: widget.services.settings.writePreferences,
          onPageChanged: (index) =>
              widget.services.settings.writePage(comic.id, index),
        ),
      ),
    );

    // The reading position changed: refresh the progress shown in the grid.
    await _reloadRecents();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ComicsNow'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'path') unawaited(_openByPath());
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'path', child: Text('Apri da percorso…')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _openComic,
        icon: const Icon(Icons.folder_open),
        label: const Text('Apri CBZ / CBR'),
      ),
      body: Column(
        children: [
          if (_busy) _buildBusy(),
          if (_error != null) _buildError(),
          Expanded(
            child: _loadingRecents
                ? const Center(child: CircularProgressIndicator())
                : _recents.isEmpty
                ? _buildEmpty()
                : _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildBusy() {
    final progress = _progress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          progress == null
              ? const LinearProgressIndicator()
              : LinearProgressIndicator(
                  value: progress.$2 == 0 ? null : progress.$1 / progress.$2,
                ),
          const SizedBox(height: 8),
          Text(
            progress == null
                ? 'Estrazione delle pagine…'
                : 'Estrazione delle pagine… ${progress.$1}/${progress.$2}',
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!)),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Lettura vignetta per vignetta, in locale.\nCBZ, CBR (RAR), ZIP.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Motore: ${widget.services.detectorDescription}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            const Text(
              'Nessun fumetto nella libreria: apri un archivio per iniziare.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.60,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: _recents.length,
      itemBuilder: (context, index) {
        final recent = _recents[index];
        return _RecentComicTile(
          recent: recent,
          lastPage: _lastPageOf(recent),
          onOpen: () => unawaited(_openRecent(recent)),
          onRemove: () => unawaited(_removeRecent(recent)),
        );
      },
    );
  }
}

class _RecentComicTile extends StatelessWidget {
  const _RecentComicTile({
    required this.recent,
    required this.lastPage,
    required this.onOpen,
    required this.onRemove,
  });

  final RecentComic recent;
  final int? lastPage;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = recent.progressFor(lastPage);
    final percent = (progress * 100).round();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCover(context),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Material(
                      color: Colors.black45,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onRemove,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (progress > 0.99)
                    const Positioned(
                      left: 6,
                      top: 6,
                      child: _FinishedBadge(),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                recent.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pagina ${(lastPage ?? 0) + 1} di ${recent.pageCount} · '
                    '$percent%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    final coverPath = recent.coverPath;
    if (coverPath == null) return const _CoverPlaceholder();

    return Image.file(
      File(coverPath),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const _CoverPlaceholder(),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black12,
      child: Center(
        child: Icon(
          Icons.menu_book,
          size: 40,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'Finito',
          style: TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}
