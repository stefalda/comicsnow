import 'dart:io';

import 'package:comicsnow/comic/cover_cache.dart';
import 'package:comicsnow/domain/recent_comic.dart';
import 'package:comicsnow/persistence/database.dart';
import 'package:comicsnow/persistence/recent_comics_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  group('RecentComic.progressFor', () {
    final comic = RecentComic(
      id: 'x',
      title: 'T',
      pageCount: 100,
      lastOpenedAt: DateTime(2026),
    );

    test('is zero when the comic was never read', () {
      expect(comic.progressFor(null), 0);
    });

    test('counts the current page as read', () {
      expect(comic.progressFor(0), closeTo(0.01, 1e-9));
      expect(comic.progressFor(49), closeTo(0.5, 1e-9));
      expect(comic.progressFor(99), closeTo(1, 1e-9));
    });

    test('is zero for a comic without pages', () {
      final empty = RecentComic(
        id: 'y',
        title: 'T',
        pageCount: 0,
        lastOpenedAt: DateTime(2026),
      );
      expect(empty.progressFor(3), 0);
    });
  });

  group('RecentComicsStore', () {
    late ComicDatabase database;
    late RecentComicsStore store;

    setUp(() {
      database = ComicDatabase.withExecutor(NativeDatabase.memory());
      store = RecentComicsStore(database);
    });

    tearDown(() => database.close());

    test('is empty at first', () async {
      expect(await store.list(), isEmpty);
    });

    test('lists the most recently opened first', () async {
      await store.touch(
        id: 'a',
        title: 'Alfa',
        pageCount: 10,
        openedAt: DateTime(2026, 1, 1),
      );
      await store.touch(
        id: 'b',
        title: 'Beta',
        pageCount: 20,
        openedAt: DateTime(2026, 1, 2),
      );

      final list = await store.list();

      expect(list.map((c) => c.id), ['b', 'a']);
      expect(list.first.pageCount, 20);
    });

    test('re-opening updates the entry instead of duplicating it', () async {
      await store.touch(id: 'a', title: 'Alfa', pageCount: 10);
      await store.touch(id: 'a', title: 'Alfa', pageCount: 12);

      final list = await store.list();

      expect(list, hasLength(1));
      expect(list.single.pageCount, 12);
    });

    test('keeps the stored cover when a later open has none yet', () async {
      await store.touch(
        id: 'a',
        title: 'Alfa',
        pageCount: 10,
        coverPath: '/tmp/cover.jpg',
      );
      await store.touch(id: 'a', title: 'Alfa', pageCount: 10);

      expect((await store.find('a'))!.coverPath, '/tmp/cover.jpg');
    });

    test('keeps the page count when the new value is unknown', () async {
      await store.touch(id: 'a', title: 'Alfa', pageCount: 10);
      await store.touch(id: 'a', title: 'Alfa', pageCount: 0);

      expect((await store.find('a'))!.pageCount, 10);
    });

    test('removes an entry', () async {
      await store.touch(id: 'a', title: 'Alfa', pageCount: 10);
      await store.remove('a');

      expect(await store.find('a'), isNull);
      expect(await store.list(), isEmpty);
    });
  });

  group('CoverCache', () {
    late Directory work;

    setUp(() {
      work = Directory.systemTemp.createTempSync('comicsnow_cover');
    });

    tearDown(() {
      if (work.existsSync()) work.deleteSync(recursive: true);
    });

    test('stores a downscaled jpeg cover', () async {
      final page = File(p.join(work.path, 'page.png'));
      // Wider than the cover limit, so it must be resized.
      page.writeAsBytesSync(
        img.encodePng(img.Image(width: 1200, height: 1800)),
      );

      final cache = CoverCache(directory: () async => work);
      final coverPath = await cache.store(comicId: 'comic1', pagePath: page.path);

      expect(coverPath, isNotNull);
      final cover = File(coverPath!);
      expect(cover.existsSync(), isTrue);
      expect(p.extension(cover.path), '.jpg');

      final decoded = img.decodeImage(cover.readAsBytesSync())!;
      expect(decoded.width, CoverCache.maxWidth);
      expect(decoded.height, lessThan(1800));
    });

    test('returns null when the page cannot be read', () async {
      final cache = CoverCache(directory: () async => work);
      final coverPath = await cache.store(
        comicId: 'comic1',
        pagePath: p.join(work.path, 'missing.png'),
      );

      expect(coverPath, isNull);
    });

    test('removes a cover', () async {
      final page = File(p.join(work.path, 'page.png'))
        ..writeAsBytesSync(img.encodePng(img.Image(width: 10, height: 10)));

      final cache = CoverCache(directory: () async => work);
      final coverPath = await cache.store(comicId: 'comic1', pagePath: page.path);

      await cache.remove('comic1');

      expect(File(coverPath!).existsSync(), isFalse);
    });
  });
}
