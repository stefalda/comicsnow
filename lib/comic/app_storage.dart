import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Name of the directory where the platform side puts the files the system asks
/// the app to open (`OpenWith`).
///
/// It is created inside the app's temporary directory — `cache` on Android,
/// `Library/Caches` on Apple platforms — so that [ComicArchiveReader] treats the
/// copy as its own: it moves it next to the library data and deletes the empty
/// folder.
const String kOpenWithInboxName = 'inbox';

/// Where the app keeps its own data: stored archives and covers.
///
/// On mobile `Documents` is the app's own container, which is the right place.
/// On desktop it is the *user's* folder — and on macOS one that the system
/// protects with a consent prompt, where a write from a background task simply
/// fails. Desktop apps keep their files in `Application Support`.
Future<Directory> appStorageDirectory() {
  if (Platform.isAndroid || Platform.isIOS) {
    return getApplicationDocumentsDirectory();
  }
  return getApplicationSupportDirectory();
}
