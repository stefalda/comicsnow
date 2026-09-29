import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// An [ImageProvider] that resolves synchronously to a small test image, so
/// widget tests do not depend on the asynchronous image pipeline.
class StubImageProvider extends ImageProvider<StubImageProvider> {
  StubImageProvider(this.image);

  final ui.Image image;

  @override
  Future<StubImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<StubImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    StubImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: image)),
    );
  }
}

Future<StubImageProvider> createStubImageProvider({
  int width = 20,
  int height = 30,
}) async {
  return StubImageProvider(
    await createTestImage(width: width, height: height),
  );
}
