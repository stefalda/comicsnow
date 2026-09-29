import 'package:comicsnow/reader/panel_reader.dart';
import 'package:comicsnow/reader/reader_preferences.dart';
import 'package:comicsnow/settings/reader_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ReaderSettings> settings(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    return ReaderSettings(await SharedPreferences.getInstance());
  }

  test('defaults to "page + panels"', () async {
    final subject = await settings({});

    expect(subject.readMode(), ReaderMode.pageAndPanels);
    expect(ReaderSettings.defaultReaderMode, ReaderMode.pageAndPanels);
  });

  test('persists the selected mode across instances', () async {
    final subject = await settings({});
    await subject.writeMode(ReaderMode.page);

    // A new instance sharing the same store sees the saved value.
    final reloaded = ReaderSettings(await SharedPreferences.getInstance());
    expect(reloaded.readMode(), ReaderMode.page);
  });

  test('falls back to the default for unknown stored values', () async {
    final subject = await settings({'reader_mode': 'nonsense'});

    expect(subject.readMode(), ReaderMode.pageAndPanels);
  });

  test('round-trips every mode', () async {
    for (final mode in ReaderMode.values) {
      final subject = await settings({});
      await subject.writeMode(mode);
      final reloaded = ReaderSettings(await SharedPreferences.getInstance());
      expect(reloaded.readMode(), mode);
    }
  });

  group('reading position', () {
    test('is null until the comic has been opened', () async {
      final subject = await settings({});

      expect(subject.readPage('comic_a'), isNull);
    });

    test('round-trips the page for a comic', () async {
      final subject = await settings({});
      await subject.writePage('comic_a', 42);

      final reloaded = ReaderSettings(await SharedPreferences.getInstance());
      expect(reloaded.readPage('comic_a'), 42);
    });

    test('keeps a separate position per comic', () async {
      final subject = await settings({});
      await subject.writePage('comic_a', 3);
      await subject.writePage('comic_b', 17);

      final reloaded = ReaderSettings(await SharedPreferences.getInstance());
      expect(reloaded.readPage('comic_a'), 3);
      expect(reloaded.readPage('comic_b'), 17);
      expect(reloaded.readPage('comic_c'), isNull);
    });

    test('can be cleared', () async {
      final subject = await settings({});
      await subject.writePage('comic_a', 5);
      await subject.clearPage('comic_a');

      expect(subject.readPage('comic_a'), isNull);
    });
  });

  group('comfort preferences', () {
    test('default to a comfortable zoom', () async {
      final subject = await settings({});
      final preferences = subject.readPreferences();

      expect(preferences.transition, PanelTransition.zoom);
      expect(preferences.animationDuration, const Duration(milliseconds: 200));
      expect(preferences.maxZoom, 3.5);
      expect(ReaderPreferences.defaults, preferences);
    });

    test('round-trip every option', () async {
      final subject = await settings({});
      const preferences = ReaderPreferences(
        transition: PanelTransition.fade,
        animationDuration: Duration(milliseconds: 320),
        maxZoom: 4.5,
      );

      await subject.writePreferences(preferences);

      final reloaded = ReaderSettings(await SharedPreferences.getInstance());
      expect(reloaded.readPreferences(), preferences);
    });

    test('fall back to the default for unknown stored values', () async {
      final subject = await settings({
        'panel_transition': 'nonsense',
        'animation_duration_ms': 'not-a-number',
      });

      expect(subject.readPreferences(), ReaderPreferences.defaults);
    });
  });
}
