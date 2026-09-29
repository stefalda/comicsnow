import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Tracks whether the page image has produced its first frame.
///
/// Widgets that paint something *on top of* the image (panel frames, order
/// badges, and the page itself) use this to avoid showing the overlay before
/// the page: without it the panel layout appears first and the artwork pops in
/// afterwards, which is what makes page changes feel janky.
mixin ImageReadinessMixin<T extends StatefulWidget> on State<T> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageProvider? _provider;
  bool _ready = false;

  /// Whether the image has produced at least one frame.
  bool get imageReady => _ready;

  /// The provider being awaited.
  ImageProvider get readinessImage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  /// Call from `didUpdateWidget` when the image may have changed.
  void resetImageReadiness() {
    _detach();
    if (_ready) {
      setState(() => _ready = false);
    }
    _resolve();
  }

  void _resolve() {
    final provider = readinessImage;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (_provider == provider && _stream?.key == stream.key) return;

    _detach();
    _provider = provider;
    _stream = stream;
    // The image is decoded by this listener even before the widget tree shows
    // it, so `imageReady` flips as soon as the first frame exists.
    _listener = ImageStreamListener(
      (_, synchronousCall) => _markReady(synchronous: synchronousCall),
      onError: (_, _) => _markReady(),
    );
    stream.addListener(_listener!);
  }

  void _markReady({bool synchronous = false}) {
    if (!mounted || _ready) return;

    // A cached provider can complete synchronously, i.e. while the widget is
    // still building: flipping the flag is enough, `setState` would throw.
    final duringBuild =
        SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;
    if (synchronous || duringBuild) {
      _ready = true;
      return;
    }

    setState(() => _ready = true);
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) {
      _stream?.removeListener(listener);
    }
    _listener = null;
    _stream = null;
    _provider = null;
  }
}
