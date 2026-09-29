import 'package:shared_preferences/shared_preferences.dart';

import '../reader/panel_reader.dart';
import '../reader/reader_preferences.dart';

/// Persists the reader preferences between sessions.
class ReaderSettings {
  ReaderSettings(this._preferences);

  static const _readerModeKey = 'reader_mode';
  static const _pagePrefix = 'reading_position_';
  static const _transitionKey = 'panel_transition';
  static const _durationKey = 'animation_duration_ms';
  static const _maxZoomKey = 'max_zoom';

  /// Mode used on a fresh install: show the whole page first, then walk its
  /// panels.
  static const ReaderMode defaultReaderMode = ReaderMode.pageAndPanels;

  final SharedPreferences _preferences;

  // ---------------------------------------------------------------------------
  // Reading mode
  // ---------------------------------------------------------------------------

  /// The saved reading mode, or [defaultReaderMode].
  ReaderMode readMode() {
    final stored = _preferences.getString(_readerModeKey);
    if (stored == null) return defaultReaderMode;

    for (final mode in ReaderMode.values) {
      if (mode.name == stored) return mode;
    }
    return defaultReaderMode;
  }

  Future<void> writeMode(ReaderMode mode) =>
      _preferences.setString(_readerModeKey, mode.name);

  // ---------------------------------------------------------------------------
  // Reading position (page level)
  // ---------------------------------------------------------------------------

  /// Last page read for [comicId], or `null` when the comic was never opened.
  int? readPage(String comicId) => _preferences.getInt('$_pagePrefix$comicId');

  /// Stores the last page read for [comicId].
  Future<void> writePage(String comicId, int pageIndex) =>
      _preferences.setInt('$_pagePrefix$comicId', pageIndex);

  /// Forgets the saved position for [comicId].
  Future<void> clearPage(String comicId) =>
      _preferences.remove('$_pagePrefix$comicId');

  // ---------------------------------------------------------------------------
  // Comfort / animation preferences
  // ---------------------------------------------------------------------------

  /// Animation and comfort options, falling back to [ReaderPreferences.defaults]
  /// for anything never saved (or stored with an unexpected type).
  ReaderPreferences readPreferences() {
    final defaults = ReaderPreferences.defaults;

    final storedTransition = _preferences.getString(_transitionKey);
    final transition = PanelTransition.values.firstWhere(
      (value) => value.name == storedTransition,
      orElse: () => defaults.transition,
    );

    // Read defensively: a value stored with the wrong type must not throw.
    final rawDuration = _preferences.get(_durationKey);
    final durationMs = rawDuration is int
        ? rawDuration
        : defaults.animationDuration.inMilliseconds;

    final rawMaxZoom = _preferences.get(_maxZoomKey);
    final maxZoom = rawMaxZoom is num
        ? rawMaxZoom.toDouble()
        : defaults.maxZoom;

    return ReaderPreferences(
      transition: transition,
      animationDuration: Duration(milliseconds: durationMs),
      maxZoom: maxZoom,
    );
  }

  Future<void> writePreferences(ReaderPreferences preferences) async {
    await _preferences.setString(
      _transitionKey,
      preferences.transition.name,
    );
    await _preferences.setInt(
      _durationKey,
      preferences.animationDuration.inMilliseconds,
    );
    await _preferences.setDouble(_maxZoomKey, preferences.maxZoom);
  }
}
